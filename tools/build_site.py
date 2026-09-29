"""Build the product website: site/src + site/static + CHANGELOG.md -> site/_dist (BUILD_PLAN §10.2).

Stdlib only. Pages are site/src/pages/**/*.html: a first line `<!--meta {json}-->` (title, description, optional
"noindex": true, optional "redirect": "<value key>", which shows "Coming soon" instead while the target is a
placeholder or CHANGELOG.md has no released version), then the body, which site/src/layout.html wraps.
{{key}} is replaced by site.json values and the computed values in values(); an unknown key fails the build.
Sources link root-relative (href="/support/"); the build prefixes those with baseURL's path, so the site works as a
GitHub Pages project site (https://OWNER.github.io/whydunit-releases) and on a custom domain (https://example.com).
Canonicals, og:image, the sitemap, the feed, robots.txt and llms.txt use the full baseURL.

  python tools/build_site.py           writes site/_dist
  python tools/build_site.py --check   builds into temp dirs for baseURL, its bare origin and a /<releases repo>
                                       project path, then checks internal links (inside the path prefix), anchors,
                                       assets, meta tags, headings, alt text, XML, sitemap/feed/llms.txt URLs,
                                       placeholders, text contrast, theme switches, the CSP (no inline code),
                                       rel="noopener noreferrer" on external links and size budgets; exit 1 on
                                       any problem
"""
import datetime
import html
import json
import re
import shutil
import sys
import tempfile
import xml.etree.ElementTree as ET
from email.utils import format_datetime
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urljoin, urlsplit

sys.path.insert(0, str(Path(__file__).resolve().parent))
import changelog  # noqa: E402  tools/changelog.py (owned by release): parse(path), to_html(md)

ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / "site"
PLACEHOLDER = re.compile("REPLACE_ME|OWNER")
# Body of /download/ until it can redirect (build()); check() still needs its one <h1>.
SOON = SITE / "src" / "soon.html"
# layout.html's Content-Security-Policy must forbid inline code; check() enforces the markup that makes it hold.
UNSAFE_CSP = re.compile(r"unsafe-|\*")


class Raw(str):
    """Already HTML: inserted without escaping."""


def fill(template, values, where, esc=html.escape):
    def sub(m):
        if m.group(1) not in values:
            sys.exit(f"{where}: unknown {{{{{m.group(1)}}}}}")
        v = values[m.group(1)]
        return v if isinstance(v, Raw) else esc(str(v))
    return re.sub(r"\{\{(\w+)\}\}", sub, template)


def pretty(iso):
    d = datetime.date.fromisoformat(str(iso))
    return f"{d.day} {d:%B %Y}"


def values(site):
    v = dict(site)
    base = site["baseURL"]
    v["year"] = datetime.date.today().year
    v["updated"] = pretty(site["legalUpdated"])
    v["downloadURL"] = f"https://github.com/{site['releasesRepo']}/releases/latest/download/{site['dmgName']}"
    v["issuesURL"] = f"https://github.com/{site['releasesRepo']}/issues"
    ld = {"@context": "https://schema.org", "@type": "SoftwareApplication", "name": site["name"],
          "operatingSystem": f"macOS {site['minMacOS']} or later", "applicationCategory": "UtilitiesApplication",
          "description": site["tagline"], "url": base + "/", "image": base + "/og.png",
          "offers": {"@type": "Offer", "price": "0", "priceCurrency": "USD"}}
    v["softwareJSON"] = Raw(json.dumps(ld, ensure_ascii=False).replace("</", "<\\/"))
    return v


def pages():
    """(output path, url, meta, body) for every page source."""
    src = SITE / "src" / "pages"
    for f in sorted(src.rglob("*.html"), key=lambda f: f.relative_to(src).as_posix().removesuffix("index.html")):
        rel = f.relative_to(src).as_posix()
        text = f.read_text(encoding="utf-8")
        m = re.match(r"<!--meta (\{.*?\})-->\n", text, re.S)
        if not m:
            sys.exit(f"{rel}: first line must be <!--meta {{...}}-->")
        yield rel, "/" + rel.removesuffix("index.html"), json.loads(m.group(1)), text[m.end():]


def changelog_html(entries):
    if not entries:
        return Raw('<p class="release muted">No releases yet. Whydunit 1.0 is on its way.</p>')
    out = []
    for e in entries:
        ver = html.escape(e["version"])
        out.append(f'<section class="release" id="v{ver}"><h2><span class="tag info">{ver}</span> <time datetime="{e["date"]}">{pretty(e["date"])}</time></h2>'
                   f'{changelog.to_html(e["body_md"])}</section>')
    return Raw("\n".join(out))


def feed(v, entries):
    # Root-relative links in the notes get the full baseURL, like the pages' href/src rewrite in build().
    notes = lambda md: re.sub(r'\b(href|src)="/(?!/)', rf'\1="{v["baseURL"]}/', changelog.to_html(md))
    items = "".join(
        f"<item><title>{html.escape(v['name'])} {html.escape(e['version'])}</title>"
        f"<link>{v['baseURL']}/changelog/#v{html.escape(e['version'])}</link>"
        f"<guid isPermaLink=\"false\">{html.escape(v['name'])}-{html.escape(e['version'])}</guid>"
        f"<pubDate>{format_datetime(datetime.datetime.fromisoformat(str(e['date'])).replace(tzinfo=datetime.timezone.utc))}</pubDate>"
        f"<description>{html.escape(notes(e['body_md']))}</description></item>"
        for e in entries)
    return ('<?xml version="1.0" encoding="utf-8"?>\n<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom"><channel>'
            f"<title>{html.escape(v['name'])} changelog</title><link>{v['baseURL']}/changelog/</link>"
            f'<atom:link href="{v["baseURL"]}/feed.xml" rel="self" type="application/rss+xml"/>'
            f"<description>New versions of {html.escape(v['name'])}</description><language>en</language>{items}"
            "</channel></rss>\n")


def build(out, site):
    assert out.name == "_dist", out   # rmtree below: never point this anywhere else
    log = ROOT / "CHANGELOG.md"
    entries = changelog.parse(str(log)) if log.exists() else []
    v = values(site)
    v["changelog"] = changelog_html(entries)
    v["version"] = entries[0]["version"] if entries else "beta"   # the footer's mono version
    layout = (SITE / "src" / "layout.html").read_text(encoding="utf-8")
    prefix = urlsplit(site["baseURL"]).path   # "/whydunit-releases" on a project site, "" on a custom domain

    if out.exists():
        shutil.rmtree(out)
    shutil.copytree(SITE / "static", out)
    css = out / "styles.css"   # its comments and indentation are for editors too (budget: check())
    css.write_text(re.sub(r"/\*.*?\*/\n?|^[ \t]+", "", css.read_text(encoding="utf-8"), flags=re.S | re.M),
                   encoding="utf-8", newline="\n")
    (out / ".nojekyll").write_text("")   # serve files as-is on GitHub Pages
    listed = []
    for rel, url, meta, body in pages():
        meta = {k: fill(x, v, rel, str) if isinstance(x, str) else x for k, x in meta.items()}
        head = []
        if meta.get("noindex") or meta.get("redirect"):
            head.append('<meta name="robots" content="noindex">')
        if meta.get("redirect"):
            target = v[meta["redirect"]]
            # Before the first release (no CHANGELOG row on main) or with a placeholder target there is nothing to
            # download: show "Coming soon" instead of redirecting into a 404.
            if not PLACEHOLDER.search(target) and entries:
                head.append(f'<meta http-equiv="refresh" content="0; url={html.escape(target)}">')
                head.append('<script src="/redirect.js"></script>')   # the JS half (§9.2); a file, for the CSP
            else:
                body = SOON.read_text(encoding="utf-8")
        else:
            listed += [(url, meta)] if not meta.get("noindex") else []
        page = dict(v, title=meta["title"], description=meta["description"], canonical=v["baseURL"] + url,
                    head=Raw("\n".join(head)), body=Raw(fill(body, v, rel)))
        dest = out / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        # srcset too: a <picture>'s <source> carries one URL (DESIGN.md §2.6).
        text = re.sub(r'\b(href|src|srcset)="/(?!/)', rf'\1="{prefix}/', fill(layout, page, "layout.html"))
        # External links (pages, layout and changelog notes alike) leak neither the opener nor the referrer.
        text = re.sub(r'<a (?![^>]*\brel=)(?=[^>]*\bhref="https?://)', '<a rel="noopener noreferrer" ', text)
        # Source comments and indentation are for editors, not visitors (no <pre> on the site). Budget: check().
        text = re.sub(r"<!--.*?-->\n?|^[ \t]+", "", text, flags=re.S | re.M)
        dest.write_text(text, encoding="utf-8", newline="\n")

    (out / "feed.xml").write_text(feed(v, entries), encoding="utf-8", newline="\n")
    (out / "sitemap.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        + "".join(f"<url><loc>{v['baseURL']}{u}</loc></url>\n" for u, _ in listed) + "</urlset>\n",
        encoding="utf-8", newline="\n")
    # Crawlers read robots.txt only at a host's root, so on a project site this file does nothing (harmless).
    (out / "robots.txt").write_text(f"User-agent: *\nAllow: /\n\nSitemap: {v['baseURL']}/sitemap.xml\n",
                                    encoding="utf-8", newline="\n")
    v["pageList"] = Raw("\n".join(f"- [{m['title']}]({v['baseURL']}{u}): {m['description']}" for u, m in listed))
    llms = fill((SITE / "src" / "llms.txt").read_text(encoding="utf-8"), v, "llms.txt", str)
    (out / "llms.txt").write_text(llms, encoding="utf-8", newline="\n")
    return v


class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links, self.ids, self.meta, self.title, self.h1, self.noalt = [], set(), {}, "", 0, 0
        self.csp, self.inline, self.leaky = None, [], 0
        self._title = False

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if "id" in a:
            self.ids.add(a["id"])
        self.links += [a[k] for k in ("href", "src") if a.get(k)]
        self.links += [u.split()[0] for u in (a.get("srcset") or "").split(",") if u.strip()]
        if tag == "meta" and (a.get("name") or a.get("property")):
            self.meta[a.get("name") or a.get("property")] = a.get("content") or ""
        if tag == "link" and a.get("rel") == "canonical":
            self.meta["canonical"] = a.get("href") or ""
        self._title |= tag == "title"
        self.h1 += tag == "h1"
        self.noalt += tag == "img" and "alt" not in a
        if tag == "meta" and (a.get("http-equiv") or "").lower() == "content-security-policy":
            self.csp = a.get("content") or ""
        # What the CSP blocks: <style>, style="", on*="" and <script> without src (JSON-LD is data, not code).
        handlers = [k for k in a if k == "style" or k.startswith("on")]
        if handlers or tag == "style" or tag == "script" and not a.get("src") and a.get("type") != "application/ld+json":
            self.inline.append(" ".join([f"<{tag}>"] + handlers))
        self.leaky += (tag == "a" and urlsplit(a.get("href") or "").scheme in ("http", "https")
                       and not {"noopener", "noreferrer"} <= set((a.get("rel") or "").split()))

    def handle_endtag(self, tag):
        self._title &= tag != "title"

    def handle_data(self, data):
        if self._title:
            self.title += data


def contrast(css):
    """WCAG AA (4.5:1) for the text colors on the page backgrounds, light and dark (the dark :root overrides light)."""
    # ponytail: only 6-digit hex tokens are measured (not rgb() ones like --header or --win-sel), and not the --win-*
    # window illustration, a picture of the app (role="img"). Add pairs here when a color lands on a new background.
    def lum(c):
        c = [int(c[i:i + 2], 16) / 255 for i in (1, 3, 5)]
        c = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
        return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
    blocks = re.findall(r":root\s*\{([^}]*)\}", css)   # light, then the dark override
    light, dark = (dict(re.findall(r"--([\w-]+):\s*(#[0-9a-fA-F]{6})\b", b)) for b in blocks)
    pairs = [(f, b) for f in ("text", "text-2", "accent") for b in ("bg", "bg-alt", "card")]
    on = "on-button" if "on-button" in light else "#ffffff"   # .button and .skip text (DESIGN.md §2.1)
    pairs += [(on, "button"), (on, "button-hover"), ("#ffffff", "button")]   # the last: .steps numbers
    errors = []
    for scheme, t in (("light", light), ("dark", {**light, **dark})):
        for fg, bg in pairs:
            hi, lo = sorted((lum(t.get(fg, fg)), lum(t[bg])), reverse=True)
            if (hi + 0.05) / (lo + 0.05) < 4.5:
                errors.append(f"styles.css: {fg} on --{bg} is {(hi + 0.05) / (lo + 0.05):.2f}:1 in {scheme}, want 4.5:1")
    return errors


def check(out, site, v):
    errors = []
    base = v["baseURL"]
    host, prefix = urlsplit(base).netloc, urlsplit(base).path
    parsed = {}
    for f in sorted(out.rglob("*.html")):
        p = Page()
        p.feed(f.read_text(encoding="utf-8"))
        parsed[f] = p

    def resolve(rel, page, link):
        u = urlsplit(urljoin(page, link))
        if u.scheme not in ("http", "https") or u.netloc != host:
            return   # mailto:, external
        if not u.path.startswith(prefix + "/"):
            errors.append(f"{rel}: link {link} is outside {base}/")
            return
        target = out / u.path[len(prefix) + 1:]
        if u.path.endswith("/"):
            target /= "index.html"
        if not target.is_file():
            errors.append(f"{rel}: broken link {link}")
        elif u.fragment and target in parsed and u.fragment not in parsed[target].ids:
            errors.append(f"{rel}: missing anchor {link}")

    for f, p in parsed.items():
        rel = f.relative_to(out).as_posix()
        url = "/" + rel.removesuffix("index.html")
        for key in ("description", "canonical", "og:title", "og:description", "og:image", "og:url"):
            if not p.meta.get(key):
                errors.append(f"{rel}: missing {key}")
        if not p.title.strip():
            errors.append(f"{rel}: missing <title>")
        if p.meta.get("canonical") != base + url:
            errors.append(f"{rel}: canonical {p.meta.get('canonical')} != {base + url}")
        if p.h1 != 1:
            errors.append(f"{rel}: {p.h1} <h1> elements, want 1")
        if p.noalt:
            errors.append(f"{rel}: {p.noalt} <img> without alt")
        if p.csp is None or "script-src 'self'" not in p.csp or UNSAFE_CSP.search(p.csp):
            errors.append(f"{rel}: needs a Content-Security-Policy meta with script-src 'self' and nothing unsafe")
        errors += [f"{rel}: inline code ({x}) is blocked by the CSP; move it to a static file" for x in p.inline]
        if p.leaky:
            errors.append(f'{rel}: {p.leaky} external links without rel="noopener noreferrer"')
        for link in p.links + [p.meta.get("og:image", "")]:
            resolve(rel, base + url, link)
    for f in sorted(out.rglob("*")):
        rel = f.relative_to(out).as_posix()
        if f.suffix in (".html", ".xml", ".txt"):
            text = f.read_text(encoding="utf-8")
            if f.suffix != ".html":   # sitemap, feed, robots.txt, llms.txt
                for link in re.findall(re.escape(base) + r'[^\s"<>)&]*', text):
                    resolve(rel, base, link)
            for key in site.get("placeholders", []):
                text = text.replace(html.escape(str(site[key])), "").replace(str(site[key]), "")
            if PLACEHOLDER.search(text):
                errors.append(f"{rel}: {PLACEHOLDER.search(text)[0]} not from a site.json placeholder")
        if f.suffix in (".html", ".css") and re.search(r"data-theme|localStorage", f.read_text(encoding="utf-8")):
            errors.append(f"{rel}: data-theme/localStorage (use prefers-color-scheme only)")
        if f.suffix == ".xml":
            try:
                ET.parse(f)
            except ET.ParseError as e:
                errors.append(f"{f.name}: {e}")
    for key, val in site.items():
        if PLACEHOLDER.search(str(val)) and key not in site.get("placeholders", []):
            errors.append(f"site.json: {key} is a placeholder but not listed in \"placeholders\"")
    errors += contrast((out / "styles.css").read_text(encoding="utf-8"))
    # Budgets (docs/MOTION.md §6.1, docs/DESIGN.md §8): the site stays light.
    caps = [("styles.css", 40_000), ("motion.js", 5_000), ("index.html", 36_000)]
    caps += [(f.relative_to(out).as_posix(), 32_000) for f in out.glob("fonts/*.woff2")]
    caps += [(f.relative_to(out).as_posix(), 110_000) for f in out.glob("shots/*")]
    for name, cap in caps:
        if (out / name).stat().st_size > cap:
            errors.append(f"{name}: {(out / name).stat().st_size} bytes, over the {cap} byte budget")
    return errors, len(parsed)


def main():
    site = json.loads((SITE / "site.json").read_text(encoding="utf-8"))
    site["baseURL"] = site["baseURL"].rstrip("/")
    if "--check" not in sys.argv[1:]:
        build(SITE / "_dist", site)
        print(f"built {SITE / '_dist'} for {site['baseURL']}")
        return
    # baseURL, plus the other shape it can take: a bare origin (custom domain) or a GitHub Pages project path.
    u = urlsplit(site["baseURL"])
    origin = f"{u.scheme}://{u.netloc}"
    failed = False
    for base in dict.fromkeys([site["baseURL"], origin, f"{origin}/{site['releasesRepo'].split('/')[-1]}"]):
        s = dict(site, baseURL=base)
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "_dist"
            errors, n = check(out, s, build(out, s))
        for e in errors:
            print("error:", e)
        print(f"checked {n} pages for {base}: {len(errors)} errors")
        failed |= bool(errors)
    todo = [k for k in site.get("placeholders", []) if PLACEHOLDER.search(str(site[k]))]
    print(("placeholders still to fill: " + ", ".join(todo) + "; " if todo else "")
          + ("legal pages reviewed" if site.get("legalReviewed") else "legal pages not reviewed yet"))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
