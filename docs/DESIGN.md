# Design spec: Whydunit (website and app)

**Why:** the owner's verdict (2026-09-29): the sites and apps "look cheap". They must look modern, premium and 3D, on
par with Mole, Recordly, Maccy, Rectangle, VoiceInk and MaCursor, while staying lightweight and secure.
**Authority:** this file is authoritative for visual design (tokens, surfaces, compositions, type). `docs/MOTION.md`
stays authoritative for motion and is referenced by section; where they conflict, §2.7 lists what changed. BUILD_PLAN
§6 lines that need amending are listed in §9, not amended here. Safety rules, copy, data flow and the checker's
contract are unchanged.
**Shared system:** §1–§3 are identical in the Tirekick repo's `docs/DESIGN.md`; change both together. §4–§9 are
Whydunit's.
**Status:** nothing here has been run in this repo. The Whydunit site tokens, header pill, buttons, key-caps, cards,
FAQ rows and sky stage were prototyped in Chromium on Windows (light and dark, 1440px) in the Daylight proposal, on a
standalone page that is not in the repo; the ghost plane, proof strip and stacked cards were not. Contrast figures
were recomputed with the checker's formula. The Swift is written, not compiled; anything unconfirmed is marked VERIFY.

## 1. The verdict (shared, identical in both repos)

Two directions were proposed: "Night Studio" (dark, cinematic, one lit object on a dark stage) and "Daylight"
(light, crisp, tactile key-caps, the product in its own small world). Judged against the reference screenshots
(Mole, Recordly, Maccy, Rectangle, VoiceInk, MaCursor), the premium ones share one mechanism, not one palette: **the
product sits inside a world, on a page that is otherwise restrained.** Mole and VoiceInk are light with a wallpaper
frame around the app; Recordly and MaCursor are dark with a sky or a halo behind it. Rectangle and Maccy, the two
plainest, put the product on bare white with nothing behind it, which is exactly what our sites do today.

So the family rule is **one product, one world, one accent**, and each brand picks the world that fits its job:

| | Whydunit | Tirekick |
|---|---|---|
| World | **Sky**: daylight over iCloud, dusk at night. Light-first, follows the system (`prefers-color-scheme`). | **Bay**: a warm-graphite inspection bay lit from above. Dark on every page, in both schemes. |
| Why | Ordinary Mac users with a stuck file want calm and trust. Apple's own iCloud language is white and blue. Mole and VoiceInk prove light reads premium when the product is framed. | A buyer at a meetup wants a tool that looks like an instrument. Dark graphite, mono readouts and one hi-vis accent are distinct from every other Mac utility and from Whydunit. |
| Accent | Sky blue `#2457E0` (`#3461EA` at dusk), also the app's AccentColor. | Hi-vis lime `#C6F23C`, black text on it. Only the one prominent button, the beam, tested keys and eyebrow indices. The app keeps the user's accent for controls. |
| Type voice | Centered, soft pills, `ui-rounded` numerals. | Left-aligned, machined 12px corners, `ui-monospace` eyebrows and readouts. |
| Hero object | The app window floating over a cloud in a sky frame, a ghost Finder window behind it. | A CSS laptop standing back-left, the white report card leaning in front-right, on a tread-marked floor with a lime horizon. |
| Signature scroll moment | Three safe fixes as sticky stacking cards. | Six key-cap test tiles and a paper fan of the shareable card. |

What each brand takes from the other direction: Whydunit takes Night Studio's volumetric cloud, proof strip,
"Finder says / Whydunit says" pairs, type ladder and System Settings–style sidebar tiles. Tirekick takes Daylight's
key-cap recipe, contact shadows, verdict plate on the report card, `StepBar` with a hidden title bar, and its
prototype-tested stage structure.

**Not doing, in either brand:** a webfont (every real visitor is on a Mac and gets SF Pro; Windows gets Segoe UI
Variable, which the Daylight prototype showed is fine), a CSP meta tag (the sites load only same-origin files; it
would only force the `style="--i"` stagger to be rewritten), a nav CTA that hides itself (needs JS for no gain),
mesh blobs, gradient text, emoji icons, live star counts, autoplay video, glass on content.

### 1.1 The eight rules

1. **One world per product.** The sky or the bay appears behind the hero scene, the finale and the download page's
   icon. Every other section is paper (Whydunit) or graphite (Tirekick), separated by whitespace, never by bands.
2. **One accent.** Green, orange and red mean a verdict or a status, and appear only in symbols, tag dots and fills
   behind primary text. Severity never glows: a red "Walk away" is lit exactly like a green "Clean" (MOTION.md §1.1).
3. **Light, not lines.** A key light at the top of the stage, the brand light behind the object, a lit top edge on
   every raised surface, shadows tinted with the brand's ink (navy or warm black), never neutral gray, never animated.
4. **Everything you can press is a key-cap:** a gradient lighter at the top, `inset 0 1px 0` highlight, a hairline,
   and a press that sinks 1px.
5. **Concentric radii:** outer radius = inner radius + padding. Whydunit 10/14/20/28 and pills; Tirekick 6/10/14/20
   and 12px buttons.
6. **Grain on big gradients only** (3–6% noise from an inline SVG, under 1 KB), never under body text. It stops
   8-bit banding, the commonest "cheap dark gradient" tell.
7. **Zero bytes added:** no fonts, images, scripts, CDNs or third-party requests. Illustrations are HTML and CSS.
   `motion.js` stays byte-identical in both repos.
8. **The apps stay native.** Navigation, tables, forms, sheets, Settings and the toolbar are system parts. Premium
   comes from the accent, a static wash, icon wells, tags, key-caps, one lifted object per stage screen, and the
   precision of the type. No custom chrome, and glass only where the macOS 26 SDK draws it by itself.

## 2. Shared web foundation

### 2.1 The contract with `tools/build_site.py`

- `contrast()` reads exactly two `:root { }` blocks and only 6-digit hex tokens. Whydunit's blocks are light then
  dark. Tirekick's are the base (dark) palette then `@media (prefers-contrast: more)`; the checker's "light"/"dark"
  labels are just labels. Everything else overrides on `html` or a class (MOTION.md §1.6).
- `--on-button` is measured against `--button` and `--button-hover` once infra applies the one-line change in the
  brand section. Until then Tirekick's black-on-lime fails the hard-coded white check.
- `data-theme` and `localStorage` must not appear anywhere, including comments.
- All numbers in the token comments were computed with the checker's own WCAG formula (`<scratchpad>/design_contrast.py`, 2026-09-29).

### 2.2 Type: SF Pro, zero bytes

Stack: `-apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI Variable Text", "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif`.
Numerals: Whydunit `ui-rounded` (SF Pro Rounded in Safari), Tirekick `ui-monospace` (SF Mono). Both are system fonts.

```css
/* Type ladder (docs/DESIGN.md §2.2). Every size on the site is one of these; nothing in between.
   h1     clamp(2.6rem, 1.4rem + 5vw, 4.75rem) / 1.02, -.032em, 700, text-wrap: balance
   h2     clamp(2rem, 1.2rem + 3vw, 3.1rem)    / 1.06, -.026em, 700, balance
   lede   clamp(1.1rem, 1rem + .5vw, 1.3rem)  / 1.45, -.011em, 400, --text-2
   h3     1.2rem / 1.3, -.015em, 600          body 17px / 1.55, -.011em          prose 17px / 1.6 (guides)
   card   15px / 1.5                          meta 13px / 1.4 (facts, captions)  floor 12px / 1.2, 600 (chrome, tags)
   eyebrow: Whydunit 13px 600 --accent; Tirekick 12px 600 mono, .06em, sentence case (BUILD_PLAN §8: no ALL CAPS). */
```

- **Two-tone headings** on every h1 and h2 that has a reassurance clause: `<h2>Built to never lose a file. <span class="dim">Every change is logged.</span></h2>`.
- **Numbers** are `font-variant-numeric: tabular-nums` everywhere they line up.
- VERIFY headline tracking by eye in Safari on a Mac: SF Pro Display already tightens above 20px, so −.032em may
  want to relax to −.028em.

### 2.3 Space, widths and radii

- Widths: `.wrap` 1080px (content), `.wide` 1200px (stages), `.read` 720px (prose, FAQ). Gutter 20px.
- Section padding `clamp(72px, 11vw, 128px)`. Gaps are 12, 16, 24, 32, 48 or 64px.
- Radii tokens `--r-s / --r-m / --r-l / --r-xl` and `--r-btn` come from each brand's `:root`.
- `scroll-padding-top: 84px` so anchors clear the floating header.

### 2.4 Shared component CSS (identical in both repos, about 7.5 KB)

These rules read only tokens; each brand's `:root` blocks supply the values. They **replace** the old rules of the
same name (`.site-header`, `.nav`, `.button*`, `.card`, `details`, `summary`, `.site-footer`) and MOTION.md §1.7's
`.button { transition: … }` line. Delete `.band`, `section:not(.band) .card` and `.hero-icon`.

```css
/* Design system (docs/DESIGN.md §2.4). Brand lives in the two :root blocks; these rules only read tokens. */
h1 { font-size: clamp(2.6rem, 1.4rem + 5vw, 4.75rem); letter-spacing: -.032em; line-height: 1.02; text-wrap: balance; }
h2 { font-size: clamp(2rem, 1.2rem + 3vw, 3.1rem); letter-spacing: -.026em; line-height: 1.06; text-wrap: balance; }
.dim { color: var(--text-2); }
.eyebrow { margin: 0 0 14px; color: var(--accent); font-size: 13px; font-weight: 600; }
main > section { padding-block: clamp(72px, 11vw, 128px); }
.wrap { max-width: 1080px; }
.wide { max-width: 1200px; margin-inline: auto; padding-inline: 20px; }
.read { max-width: 720px; }
html { scroll-padding-top: 84px; }

/* Header: a floating glass pill (Mole). Glass only here, never inside a 3D scene (MOTION.md §1.6). */
.site-header { position: sticky; top: 10px; z-index: 10; padding-inline: 12px; background: none; border: 0; -webkit-backdrop-filter: none; backdrop-filter: none; }
.nav { max-width: 1000px; height: 52px; margin: 10px auto 0; padding: 0 8px 0 16px; gap: 20px; border-radius: 999px; background: var(--header); -webkit-backdrop-filter: saturate(180%) blur(20px); backdrop-filter: saturate(180%) blur(20px); box-shadow: var(--z1); }
.brand { font-weight: 600; letter-spacing: -.02em; }
.brand img { border-radius: 6px; box-shadow: 0 1px 2px rgb(var(--ink) / .25); }
.nav .button + .button { margin-left: -8px; }

/* Buttons: key-caps. The fill only darkens toward the bottom, so the label never drops below the measured
   --on-button/--button contrast; the light is an inset line plus a glow in the brand colour. */
.button { gap: 10px; min-height: 48px; padding: 0 22px; border: 1px solid transparent; border-radius: var(--r-btn); font-size: 16px; font-weight: 600; letter-spacing: -.01em; color: var(--on-button);
  background: linear-gradient(var(--button), color-mix(in srgb, var(--button) 88%, #000));
  box-shadow: inset 0 1px 0 rgb(255 255 255 / .25), 0 1px 2px rgb(var(--ink) / .25), 0 10px 24px -8px color-mix(in srgb, var(--button) 60%, transparent); }
.button:hover { background: linear-gradient(var(--button-hover), color-mix(in srgb, var(--button-hover) 88%, #000)); text-decoration: none; }
.button svg { flex: none; width: 18px; height: 18px; }
.button .sep { align-self: stretch; width: 1px; margin-block: 13px; background: currentColor; opacity: .28; }   /* glyph | label (Maccy) */
.button.secondary { color: var(--text); background: linear-gradient(var(--cap-top), var(--cap-bot)); box-shadow: var(--cap); }
.button.small { min-height: 36px; padding: 0 16px; font-size: 14px; }
.skip { color: var(--on-button); }
@media (prefers-reduced-motion: no-preference) {
  .button { transition: background-color .2s, translate var(--t-fast) var(--ease-out), scale var(--t-fast) var(--ease-out); }   /* replaces MOTION §1.7's line; :active { scale: .97 } stays */
}
@media (prefers-reduced-motion: no-preference) and (hover: hover) { .button:hover { translate: 0 -1px; } }

/* Kicker chip over the h1 (Whydunit) and the facts line under the CTAs (both). */
.kicker { display: inline-flex; align-items: center; gap: 8px; margin: 0 0 22px; padding: 6px 12px 6px 7px; border-radius: 999px; font-size: 13px; font-weight: 600; background: linear-gradient(var(--cap-top), var(--cap-bot)); box-shadow: var(--cap); }
.kicker svg { width: 20px; height: 20px; padding: 3px; border-radius: 50%; color: var(--accent); background: color-mix(in srgb, var(--accent) 14%, var(--card)); }
.facts { margin: 0; font-size: 13px; color: var(--text-2); }

/* Cards are raised objects: a hairline, a lit top edge (inside --z2) and an ink-tinted two-layer shadow. */
.card { padding: 26px; border-radius: var(--r-l); background: var(--card); box-shadow: var(--z2); }
.card h3 { margin: 16px 0 6px; }
.card p { font-size: 15px; line-height: 1.5; }
/* Icon well: recessed, tinted with the accent, holds a 1.7-stroke inline SVG. */
.well { display: grid; place-items: center; width: 44px; height: 44px; border-radius: 12px; color: var(--accent);
  background: linear-gradient(color-mix(in srgb, var(--accent) 14%, var(--card)), color-mix(in srgb, var(--accent) 6%, var(--card)));
  box-shadow: inset 0 0 0 .5px color-mix(in srgb, var(--accent) 30%, transparent), inset 0 1px 2px rgb(var(--ink) / .08); }
.well svg { width: 22px; height: 22px; }
/* Tags: colour lives in the dot and the fill; the text stays --text, so it always passes. */
.tag { display: inline-flex; align-items: center; gap: 6px; padding: 2px 9px; border-radius: 999px; font-size: 12px; font-weight: 600; font-variant-numeric: tabular-nums; color: var(--text);
  background: color-mix(in srgb, var(--c, var(--text-2)) 14%, var(--card)); box-shadow: inset 0 0 0 .5px color-mix(in srgb, var(--c, var(--text-2)) 40%, transparent); }
.tag::before { content: ""; width: 6px; height: 6px; border-radius: 50%; background: var(--c, var(--text-2)); }
.tag.ok { --c: var(--ok); } .tag.warn { --c: var(--warn); } .tag.bad { --c: var(--bad); } .tag.info { --c: var(--accent); }

/* Proof strip (VoiceInk): facts in the display face; the hairlines are the grid gap, so wrapping never breaks them. */
.proof { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 200px), 1fr)); gap: 1px; margin: 0; overflow: clip; border-radius: var(--r-l); background: var(--line); box-shadow: var(--z1); }
.proof div { display: flex; flex-direction: column-reverse; gap: 8px; padding: 22px 26px; background: var(--card); }
.proof dd { margin: 0; font: 700 clamp(28px, 3vw, 40px)/1 var(--font-num); letter-spacing: -.03em; font-variant-numeric: tabular-nums; }
.proof dt { font-size: 13px; color: var(--text-2); }

/* "They say / we find" pairs: a quiet claim card with the finding card lying on top of it. */
.pair { display: grid; }
.pair .claim { padding: 18px 20px 44px; border-radius: var(--r-l); background: var(--bg-alt); box-shadow: inset 0 0 0 1px var(--line); color: var(--text-2); }
.pair .finding { margin: -30px 0 0 10%; padding: 16px 18px; border-radius: var(--r-m); background: var(--card); box-shadow: var(--shadow); }
.pair .finding .tag { margin-bottom: 8px; }

/* FAQ: native <details> as rows you can pick up. MOTION's unfold and +/− turn are unchanged. */
.faq { display: grid; gap: 32px 64px; }
@media (min-width: 900px) { .faq { grid-template-columns: 5fr 7fr; } .faq-head { position: sticky; top: 96px; align-self: start; } }
details { border: 0; padding-inline: 20px; border-radius: var(--r-m); background: var(--card); box-shadow: var(--z1); }
details + details { margin-top: 10px; }
details:first-of-type { margin-top: 0; border-top: 0; }
details[open] { box-shadow: var(--z2); }
summary { padding-block: 18px; font-size: 1.05rem; }
details p { margin-bottom: 20px; }

/* The stage: a still backdrop behind the 3D scene (only .scene moves, MOTION §1.1). Brands paint ::before. */
.stage { position: relative; isolation: isolate; }
.stage::before { content: ""; position: absolute; z-index: -2; inset: 0; border-radius: var(--r-xl); box-shadow: inset 0 0 0 1px rgb(var(--ink) / .06); }
@media (max-width: 640px) { .stage { margin-inline: -20px; } .stage::before, .stage::after { border-radius: 0; } }

/* Finale: the app icon as an object in the world, then the last CTA. Brands paint .panel. */
.finale { text-align: center; }
.finale .panel { position: relative; overflow: clip; padding: 72px 24px; border-radius: var(--r-xl); box-shadow: var(--z2); }
.finale .icon { display: block; width: 112px; height: 112px; margin: 0 auto 28px; filter: drop-shadow(0 24px 30px rgb(var(--ink) / .3)); }
.finale h2 { margin-bottom: 24px; }
@media (max-width: 640px) { .finale .panel { margin-inline: -20px; border-radius: 0; } }
@media (prefers-reduced-motion: no-preference) and (hover: hover) and (pointer: fine) {
  .finale .panel { perspective: var(--persp-card); }
  .finale .icon[data-tilt] { --tilt: 12deg; transform: rotateX(calc(var(--py) * var(--tilt) * -1)) rotateY(calc(var(--px) * var(--tilt))); transition: transform var(--t-slow) var(--ease-out); }
  .finale .icon.tilting { transition-duration: var(--t-fast); }
}

/* Reading pages: boxes and code as objects, nothing moves. */
.summary { background: var(--card); box-shadow: var(--z1); }
code { background: var(--bg-alt); box-shadow: inset 0 0 0 .5px rgb(var(--ink) / .1); }
.release { padding: 22px 24px; border-radius: var(--r-l); background: var(--card); box-shadow: var(--z1); }
.release + .release { margin-top: 20px; border-top: 0; }
.release .tag { font-family: var(--font-mono); }

/* Footer: one slab plus the official-sources line (Maccy, Mole): quiet, and security-relevant. */
.site-footer { padding: 56px 0 40px; border-top: 1px solid var(--line); background: var(--bg-alt); }
.official { display: flex; gap: 10px; align-items: flex-start; margin: 28px 0 0; padding: 12px 14px; border-radius: var(--r-s); background: var(--card); box-shadow: var(--z1); color: var(--text-2); font-size: 13px; }
.official svg { flex: none; width: 18px; height: 18px; margin-top: 1px; color: var(--accent); }

/* Accessibility variants and print. */
@media (prefers-reduced-transparency: reduce) { .nav { background: var(--card); -webkit-backdrop-filter: none; backdrop-filter: none; } }
@media (prefers-contrast: more) {
  html { --grain: none; --glare: transparent; }
  .card, details, .nav, .button, .kicker, .official, .tag, .proof { box-shadow: 0 0 0 2px var(--text); }
}
@media (forced-colors: active) { .button, .card, details, .tag, .well, .proof div { border: 1px solid CanvasText; } }
@media print {
  html { --bg: #fff; --bg-alt: #fff; --card: #fff; --text: #000; --text-2: #333; --accent: #0645ad; --grain: none; }
  .site-header, .site-footer, .skip, .stage::before, .stage::after, .finale { display: none; }
  .card, details, .summary, .release { box-shadow: 0 0 0 1px #ccc; }
}
```

Markup that goes with it (both sites):

- **Sprite:** add `<symbol id="i-down" viewBox="0 0 24 24"><path fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" d="M12 4v11m0 0-4.5-4.5M12 15l4.5-4.5M4.5 19.5h15"/></symbol>`.
- **Nav** (`layout.html`): `<a class="button secondary small" href="https://github.com/{{releasesRepo}}">Source</a><a class="button small" href="/download/">Download</a>`. No star count, so no request.
- **Footer** (`layout.html`), after the columns: `<p class="official"><svg aria-hidden="true"><use href="#i-check"/></svg>The only official site is {{baseURL}}. Downloads come only from github.com/{{releasesRepo}}/releases.</p>`. The sprite must then live in `layout.html`, not each page. After the signed 1.0 ships, add "Every release is signed with an Apple Developer ID and notarized by Apple."
- **Illustrations** keep their "Illustration with sample data" caption and `role="img"` labels.

### 2.5 Where gradients, grain and glass are allowed

| Effect | Allowed on | Never on |
|---|---|---|
| Large gradient (sky, bay) | the hero stage, the finale panel, the download page's icon panel, the media wells of stacked cards | paper sections or cards |
| Small gradient (cap, well, orb, button) | key-caps, wells, step orbs, buttons | text |
| Grain (`--grain`) | large gradients only; `none` under `prefers-contrast: more` and in print | body text, paper |
| Glass (`backdrop-filter`) | the header pill only | anything inside `.stage` (Safari flattens it) or on cards |
| Gradient text, mesh blobs, orbs, marquees | nowhere | everywhere |

### 2.6 Sub-pages (download, changelog, guides, support, legal, 404)

- **Reading pages stay still** (MOTION.md): no stage, no tilt. Header strip: `.eyebrow`, h1 at `clamp(2.1rem, 5vw, 3.2rem)`, one meta line in `--text-2`. Prose is `.read` (720px) at 17px/1.6. `.summary` boxes are cards with `--z1`; `code` and `pre` are recessed.
- **Download:** the icon as an object on a small world panel (the finale `.panel` at 220px tall, the icon 128px with `data-tilt`), then h1, the button, the requirements line, three numbered steps (Open the DMG · Drag to Applications · Open the app), the beta note, and the official-sources line. After 1.0: the Developer ID team name, "notarized by Apple" and a link to the release's SHA-256.
- **Changelog:** each release is a `.release` card with the version in a mono `.tag` and the date in `--text-2`.
- **Guides:** reading layout. Tirekick's meetup checklist keeps printing clean (the shared print rules strip stages and shadows).
- **Support and legal:** reading layout only. Support repeats the official-sources line under its h1.
- **404:** the brand's world panel at 240px tall with its object, one line in the product's voice, and a Home button.

### 2.7 What this supersedes in MOTION.md

MOTION.md stays authoritative for motion: the hero sequences, tilt, glare, reveal, flips, `motion.js` and the
Reduce Motion table are unchanged and referenced by section below. Where the two conflict, this file wins:

| MOTION.md | Now |
|---|---|
| §1.7 `--z1`, `--z2`, `--glare` values, and the existing `--shadow` | ink-tinted values in each brand's `:root` (§4.1); the names are unchanged, so the motion CSS keeps working |
| §1.7 `.button { transition: background-color .2s, scale … }` | §2.4's transition line (adds `translate`) |
| §1.7 "light then dark" `:root` blocks | Whydunit unchanged; Tirekick's second block is `prefers-contrast: more` |
| §2.3 `.cloud { fill: var(--glare) }` | `fill: url(#g-cloud)`, a volumetric cloud (Whydunit §4.3) |
| §4.3 `.scene` side-by-side grid at ≥900px, `.beam` blue, `.lid`/`.deck` flat fills | overlap composition at ≥1100px, lime beam, graphite and aluminium materials (Tirekick §4.3) |
| §5.1 `TileButtonStyle` | `KeyCapStyle` (Tirekick §5.2), same tilt, press and bounce behaviour |
| §3 "no card backgrounds on content", "no custom glass" (BUILD_PLAN quotes) | amended as listed in §9 of each brand |

## 3. Shared app foundation (SwiftUI; written, not compiled)

**What stays native:** `NavigationSplitView`, `Table`, `Form(.grouped)`, the toolbar, sheets, Settings, system
materials, the user's accent, and on macOS 26 the SDK's automatic Liquid Glass on toolbars and sidebars.
**What is added:** the brand's static wash, icon wells, tags, key-caps, one lifted object per stage screen, and (Tirekick)
a step bar. Every API below is macOS 13 so both apps can share it; Whydunit-only additions are in its §5.

### 3.1 `App/DesignSystem/Tokens.swift` additions (both apps)

```swift
extension View {
    /// A symbol in a recessed, tinted squircle: the site's icon well. Pure fills, so ImageRenderer-safe.
    func well(_ tint: Color, size: CGFloat = 44) -> some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
        return frame(width: size, height: size)
            .background(shape.fill(tint.opacity(0.16).gradient))          // Color.gradient: macOS 13
            .overlay(shape.strokeBorder(tint.opacity(0.24), lineWidth: 0.5))
    }

    /// A raised object (app icon, laptop, report card; never a row): a tight contact shadow plus a wide soft one,
    /// like the site's --shadow. compositingGroup so glyphs don't cast their own shadows (MOTION.md §1.4).
    func lifted() -> some View {
        compositingGroup()
            .shadow(color: .black.opacity(0.10), radius: 1.5, y: 1)
            .shadow(color: .black.opacity(0.20), radius: 24, y: 14)
    }
}

/// A count or a word in a tinted capsule. Colour sits in the dot and the fill; the text stays primary, so it always
/// has full contrast ("only symbols carry colour"). Increase Contrast adds a stroke.
struct Tag: View {
    let text: String
    var tint: Color = .secondary
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(tint).frame(width: 6, height: 6).accessibilityHidden(true)
            Text(text).font(.caption.weight(.semibold)).monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(tint.opacity(0.14), in: Capsule())
        .overlay(Capsule().strokeBorder(contrast == .increased ? Color.primary.opacity(0.4) : tint.opacity(0.3), lineWidth: contrast == .increased ? 1 : 0.5))
    }
}
```

### 3.2 Performance and accessibility (both apps)

- Everything added is static fills and gradients plus at most 6 `lifted()` shadows per screen. Idle CPU stays 0%;
  motion follows MOTION.md §3/§5 exactly, and the only loops are the scan glyph and the laptop beam.
- Wells hide duplicate symbols from VoiceOver; `SeverityIcon`/`VerdictIcon` keep speaking their words; combined
  elements are unchanged. Differentiate Without Color still shows the words.
- Reduce Transparency turns materials solid by itself. Increase Contrast: tags and wells get a 1pt primary stroke,
  and the wash falls back to the plain window background.
- No `drawingGroup()`, no animated `blur` or `shadow`. `ReportCardView` (the PNG) gets no effects around it.

## 4. Whydunit website: Sky

### 4.1 Tokens (replace the two `:root` blocks in `site/static/styles.css`)

```css
:root {
  color-scheme: light dark;
  /* contrast(), light, worst of bg / bg-alt / card: text 16.8:1, text-2 5.75:1, accent 5.82:1;
     on-button on button 5.97:1, on hover 7.62:1. */
  --bg: #fbfcfe;
  --bg-alt: #f1f4f9;
  --card: #ffffff;
  --text: #0b1324;
  --text-2: #556074;
  --accent: #1d54d4;
  --button: #2457e0;
  --button-hover: #1c48c2;
  --on-button: #ffffff;
  --line: #dce2ec;
  --header: rgb(251 252 254 / .72);
  --ink: 16 28 60;                    /* every shadow and hairline is this navy at an alpha, never grey */
  --ok: #34c759; --warn: #ff9f0a; --bad: #ff3b30;
  /* The world: a daylight sky, only behind the hero scene, the finale and the download icon. */
  --sky-1: #8ec2ff; --sky-2: #c9e2ff; --sky-3: #edf5ff;
  --cloud: rgb(255 255 255 / .95);
  --haze: rgb(255 255 255 / .85);
  --glow: rgb(36 87 224 / .22);       /* brand light behind the object */
  --orb-a: #6fb2ff; --orb-b: #2a3ab8; /* step coins */
  /* Key-caps: everything you can press or pick up. */
  --cap-top: #ffffff; --cap-bot: #f5f7fb;
  --cap: inset 0 1px 0 rgb(255 255 255 / .9), 0 0 0 1px rgb(var(--ink) / .10), 0 1px 2px rgb(var(--ink) / .08), 0 6px 16px -8px rgb(var(--ink) / .22);
  /* Depth (MOTION §1.4 names, ink-tinted values): z1 hugs, z2 cards, shadow floats. */
  --z1: 0 0 0 1px rgb(var(--ink) / .06), 0 1px 2px rgb(var(--ink) / .05), 0 4px 12px -2px rgb(var(--ink) / .06);
  --z2: inset 0 1px 0 rgb(255 255 255 / .9), 0 0 0 1px rgb(var(--ink) / .07), 0 2px 4px rgb(var(--ink) / .05), 0 14px 32px -10px rgb(var(--ink) / .18);
  --shadow: 0 0 0 .5px rgb(var(--ink) / .22), 0 2px 6px rgb(var(--ink) / .08), 0 24px 48px -12px rgb(var(--ink) / .28), 0 60px 120px -30px rgb(var(--ink) / .3);
  --glare: rgb(36 87 224 / .08);
  /* Grain: 6% grey fractal noise, about 420 bytes, only on big gradients (stops 8-bit banding). */
  --grain: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='160' height='160'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.85' numOctaves='3' stitchTiles='stitch'/%3E%3CfeColorMatrix values='.33 .33 .33 0 0 .33 .33 .33 0 0 .33 .33 .33 0 0 0 0 0 0 .06'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E");
  --font: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI Variable Text", "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  --font-mono: ui-monospace, "SF Mono", SFMono-Regular, Menlo, Consolas, monospace;
  --font-num: ui-rounded, var(--font);       /* SF Pro Rounded for big friendly numerals (Health-style) */
  --r-s: 10px; --r-m: 14px; --r-l: 20px; --r-xl: 28px; --r-btn: 999px;
  /* MOTION.md §1.7: --ease-*, --t-*, --persp-* unchanged, here. */
  /* Window illustration (role="img", not measured). */
  --win-bg: #f4f6fa; --win-bar: #eef1f6; --win-bar-top: #f8f9fc; --win-side: #e6ebf3; --win-group: #ffffff;
  --win-line: rgb(0 0 0 / .08); --win-sel: #2457e0; --win-icon: #2457e0;
}
@media (prefers-color-scheme: dark) {
  :root {
    /* dark (worst): text 15.8:1, text-2 7.0:1, accent 7.3:1; on-button on button 5.19:1, on hover 6.49:1. */
    --bg: #090d16; --bg-alt: #0e1320; --card: #141a28;
    --text: #f1f4f9; --text-2: #9aa5b9;
    --accent: #7ea7ff; --button: #3461ea; --button-hover: #2a52d2;
    --line: #222b3d; --header: rgb(9 13 22 / .72);
    --ink: 0 0 0;
    --ok: #30d158; --warn: #ff9f0a; --bad: #ff453a;
    /* The same sky after sunset. */
    --sky-1: #0b1433; --sky-2: #1a2658; --sky-3: #2e3478;
    --cloud: rgb(150 160 255 / .22); --haze: rgb(126 167 255 / .22); --glow: rgb(52 97 234 / .38);
    --cap-top: #1b2232; --cap-bot: #151b29;
    --cap: inset 0 1px 0 rgb(255 255 255 / .07), 0 0 0 1px rgb(255 255 255 / .09), 0 6px 16px -8px rgb(0 0 0 / .7);
    --z1: 0 0 0 1px rgb(255 255 255 / .07), 0 4px 12px -2px rgb(0 0 0 / .5);
    --z2: inset 0 1px 0 rgb(255 255 255 / .05), 0 0 0 1px rgb(255 255 255 / .08), 0 14px 32px -10px rgb(0 0 0 / .7);
    --shadow: 0 0 0 1px rgb(255 255 255 / .1), 0 24px 48px -12px rgb(0 0 0 / .7), 0 60px 120px -30px rgb(0 0 0 / .8);
    --glare: rgb(255 255 255 / .1);
    --win-bg: #1e1e20; --win-bar: #262628; --win-bar-top: #2a2d35; --win-side: #2a2a2d; --win-group: #2c2c2e;
    --win-line: rgb(255 255 255 / .09); --win-sel: #3461ea; --win-icon: #3461ea;
  }
}
```

`layout.html`: `theme-color` `#fbfcfe` (light) and `#090d16` (dark).

### 4.2 Home page, section by section

| # | Section | Composition | Motion (MOTION.md) |
|---|---|---|---|
| 0 | Header pill | icon, wordmark · How it works, Safety, FAQ, Support · **Source** (secondary small) · **Download** (small) | none |
| 1 | Hero | centered: kicker chip, two-tone h1 (the promise; the wordmark lives in the nav), lede, Download + View source, facts line; then the **sky stage** (§4.3) | §2.1 sequence once, 5° tilt, phone scroll lean |
| 2 | Proof strip | `dl.proof`, 4 cells in `--font-num`: **0 bytes** "of file contents read" · **SHA-256** "on every backup copy" · **1 at a time** "retries, each re-checked first" · **1 server** "it ever talks to: its update feed" | reveal |
| 3 | Finder says / Whydunit says (replaces "Sound familiar?") | `.split`: eyebrow, h2 "Finder shows a status. *Whydunit tells you why.*", lede; right: one `.pair` (Finder row "Thesis.pages · Waiting to upload…" as the claim, the finding card "12 files haven't uploaded to iCloud (1.2 GB)" with a `.tag.warn`, one line, and two fake key-caps "Back Up…" "Retry Upload…") | the finding card: 7° tilt, glare, reveal |
| 4 | How it works | 4 coin orbs on a rail (§4.4) | reveal, coin turn |
| 5 | Three fixes, each one safe | `.stack` of 3 `.feature` cards: Back Up, Retry Upload, Restart iCloud Sync, each with a mini sheet mock on a sky well (§4.4) | sticky stacking (CSS only) |
| 6 | Built to never lose a file | 6 `.card`s with `.well` icons; "Trash, never delete" first | reveal, tilt, glare |
| 7 | Free | one centered card: a big rounded "Free", the line, the checklist | reveal only |
| 8 | Questions | `.faq`: sticky two-tone head left, `<details>` cards right | unfold |
| 9 | Finale | `.finale .panel` on the sky: the icon floating with a halo, "See what's stuck. *It's free.*", the button, facts | icon tilt 12° |
| 10 | Footer | slab, columns, official-sources line, trademark line | none |

No `.band` sections. The sky appears in 1, 5 (wells) and 9 only.

### 4.3 Hero: the 3D scene in a sky frame

The MOTION.md §2.1 sequence is kept exactly (window rises, files rise into the cloud, check lands, chips pop, then
5° tilt). It gains a world and a fourth plane.

```html
<section class="hero" aria-labelledby="hero-h">
  <div class="wrap center hero-copy">
    <p class="kicker"><svg aria-hidden="true"><use href="#i-cloud"/></svg>For iCloud Drive on macOS {{minMacOS}} or later</p>
    <h1 id="hero-h">See why your files won't upload. <span class="dim">Fix them without losing a thing.</span></h1>
    <p class="lede center">Whydunit finds iCloud Drive files that are stuck, explains why in plain English, and backs them up before it changes anything.</p>
    <p class="actions">
      <a class="button" href="/download/"><svg aria-hidden="true"><use href="#i-down"/></svg><span class="sep" aria-hidden="true"></span>Download free</a>
      <a class="button secondary" href="https://github.com/{{releasesRepo}}">View source</a>
    </p>
    <p class="facts">Free · No account · macOS {{minMacOS}} or later · Apple silicon and Intel</p>
  </div>
  <div class="wide">
    <div class="stage daylight" data-tilt>
      <div class="scene">
        <!-- MOTION.md §2.2 unchanged: .sky (cloud, 3 .doc, .cloud-ok) … -->
        <div class="ghost" aria-hidden="true"><i></i><i></i><i></i></div>   <!-- the Finder window the user already knows -->
        <figure class="window" role="img" aria-label="…unchanged…">…unchanged…</figure>
        <!-- … the two .chip paragraphs -->
      </div>
    </div>
    <p class="small dim center">Illustration with sample data</p>
  </div>
</section>
```

Add to the sprite: `<radialGradient id="g-cloud" cx=".5" cy=".35" r=".7"><stop offset="0" stop-color="#fff"/><stop offset=".55" stop-color="#bfe0ff"/><stop offset="1" stop-color="#4f8dff" stop-opacity=".35"/></radialGradient>`.

```css
/* Sky stage (DESIGN.md §4.3): the window's lower edge hangs off the sky onto paper, like a product shot. */
.hero { overflow: clip; padding-top: clamp(64px, 9vw, 104px); }
.hero .lede { margin: 20px auto 0; }
.stage.daylight { margin-top: 56px; padding: 0 clamp(12px, 5vw, 72px); }
.stage.daylight::before { inset: 0 0 14%;
  background: var(--grain),
    radial-gradient(55% 45% at 80% 8%, var(--haze), transparent 70%),        /* sun haze, top right */
    radial-gradient(34% 22% at 12% 100%, var(--cloud), transparent 72%),     /* cloud bank along the bottom */
    radial-gradient(40% 26% at 46% 104%, var(--cloud), transparent 72%),
    radial-gradient(30% 20% at 88% 100%, var(--cloud), transparent 72%),
    linear-gradient(var(--sky-1), var(--sky-2) 55%, var(--sky-3)); }
.cloud { fill: url(#g-cloud); }                                   /* MOTION's back cloud, now volumetric */
.sky::before { content: ""; position: absolute; inset: -40% -30%; background: radial-gradient(closest-side, var(--glow), transparent); }   /* bloom behind it */
/* Fourth plane: a ghost Finder window with orange "Waiting to upload" dots, behind the app window. */
.ghost { position: absolute; left: 3%; top: 20%; width: 36%; aspect-ratio: 4 / 3; padding: 34px 14px 0; border-radius: 10px;
  background: var(--win-bg); box-shadow: var(--z2); opacity: .75; transform: translateZ(-80px); pointer-events: none; }
.ghost i { display: block; height: 10px; margin: 10px 0; border-radius: 4px;
  background: linear-gradient(90deg, var(--line) 0 70%, transparent 0 88%, var(--warn) 0 92%, transparent 0); }
@media (max-width: 640px) { .ghost { display: none; } }
/* Window chrome: lit title bar, the app's own sky wash at the top of the content, accent selection, a severity well. */
.win-bar { background: linear-gradient(var(--win-bar-top), var(--win-bar)); }
.win-main { background: linear-gradient(color-mix(in srgb, var(--button) 8%, var(--win-bg)), var(--win-bg) 160px); }
.side-row.selected { background: var(--win-sel); color: #fff; }
.side-row.selected svg, .side-row.selected .badge { color: #fff; }
.win-hero svg { box-sizing: content-box; padding: 9px; border-radius: 12px; background: color-mix(in srgb, var(--warn) 16%, var(--win-group)); }
.win-row { border-left: 3px solid var(--warn); padding-left: 11px; }
.win-row .tag { flex: none; }                                     /* trailing count, e.g. <span class="tag warn">14</span> */
.chip { border-radius: var(--r-m); background: linear-gradient(var(--cap-top), var(--cap-bot)); box-shadow: var(--cap), 0 18px 36px -12px rgb(var(--ink) / .35); }
```

Planes, front to back: chips (+90/+60, move most under tilt), the window (0), the ghost (−80), the cloud and files
(−160). The ghost is a child of the `preserve-3d` `.scene`, so its `opacity` flattens nothing (MOTION §1.6). At rest
the window is flat and sharp; the sky gives the depth. Prototype notes: in dark mode the dusk sky and the light rims
draw the window's edges; every colour must come from tokens, because literal `#fff` fills broke dark mode.

### 4.4 The new sections

```css
/* Finder says / Whydunit says */
.split { display: grid; gap: 40px; align-items: center; }
@media (min-width: 900px) { .split { grid-template-columns: 5fr 7fr; } }
.split .claim { display: flex; align-items: center; gap: 10px; font-style: normal; }   /* a Finder row: doc icon, name, dotted cloud, status */
.split .finding .caps { display: flex; gap: 8px; margin-top: 12px; }
.split .finding .caps span { padding: 6px 12px; border-radius: 999px; font-size: 12px; font-weight: 600; background: linear-gradient(var(--cap-top), var(--cap-bot)); box-shadow: var(--cap); }

/* How it works: coin orbs on a rail (MaCursor). MOTION's coin animation still runs on li::before. */
.steps { position: relative; }
@media (min-width: 900px) { .steps::before { content: ""; position: absolute; top: 24px; left: 12%; right: 12%; height: 2px; background: linear-gradient(90deg, transparent, var(--line) 15% 85%, transparent); } }
.steps li { position: relative; }
.steps li::before { width: 48px; height: 48px; font-weight: 700; color: #fff;
  background: radial-gradient(circle at 34% 28%, rgb(255 255 255 / .35), transparent 42%), linear-gradient(160deg, var(--orb-a), var(--button) 60%, var(--orb-b));
  box-shadow: 0 0 0 5px var(--bg), 0 8px 18px -4px color-mix(in srgb, var(--button) 60%, transparent); }

/* Three fixes: sticky stacking cards (Recordly). Pure CSS depth while scrolling; nothing animates. */
.stack { display: grid; gap: 24px; margin-top: 48px; }
.feature { display: grid; gap: 16px; align-items: center; min-height: 380px; padding: 16px; border-radius: var(--r-l); background: var(--card); box-shadow: var(--shadow); }
.feature .media { align-self: stretch; display: grid; place-items: center; padding: 28px; border-radius: var(--r-m); background: var(--grain), linear-gradient(var(--sky-2), var(--sky-3)); }
.feature .text { padding: 16px 24px; }
.sheet { width: min(100%, 420px); padding: 18px; border-radius: 12px; background: var(--win-bg); box-shadow: var(--shadow); font-size: 13px; letter-spacing: 0; }
@media (min-width: 900px) {
  .feature { grid-template-columns: 7fr 5fr; position: sticky; top: 88px; }
  .feature:nth-child(2) { top: 102px; } .feature:nth-child(3) { top: 116px; }
  .feature + .feature { box-shadow: 0 -40px 80px -40px rgb(var(--ink) / .5), var(--shadow); }   /* the overlap reads as depth */
}

/* Free: one card, a big rounded word, a 1px accent rim. */
.free .card { max-width: 560px; margin-inline: auto; text-align: center; box-shadow: var(--z2), inset 0 1px 0 color-mix(in srgb, var(--accent) 35%, transparent); }
.free .big { margin: 0; font: 700 clamp(3.5rem, 8vw, 5.5rem)/1 var(--font-num); letter-spacing: -.04em; }
.free .checks { text-align: left; }

/* Finale: the icon floating in the sky with a halo. */
.finale .panel { background: var(--grain), radial-gradient(40% 40% at 50% 38%, var(--glow), transparent 70%), linear-gradient(var(--sky-1), var(--sky-2) 60%, var(--sky-3)); }
.finale .panel h2, .finale .panel .facts { color: var(--text); }
```

- Each `.sheet` is a small HTML drawing of the real sheet (`role="img"` with a label): a title, three rows with
  `.tag`s, two fake buttons as `span`s. Back Up ends on `<span class="tag ok">SHA-256 verified</span>`; Retry Upload
  shows per-item outcomes; Restart iCloud Sync shows the consent sentence and a Cancel/Restart pair, with copy from
  `RestartSyncSheet`.
- Sticky cards go `position: static` below 900px.
- The finale panel's text sits on `--sky-3` (light) or `--sky-1` (dark); `--text` on both is above 12:1.

### 4.5 Sub-pages, Whydunit specifics

- **Download:** the icon panel uses the finale's sky; copy under it: "Only from github.com/EverydayOpen/whydunit/releases."
- **404:** the sky panel with MOTION's cloud (no files), "This page didn't upload either.", Home.
- **Guides:** `.summary` callouts keep a 3px accent left rule.

## 5. Whydunit app (macOS 15). Written, not compiled.

### 5.1 Tokens (`App/DesignSystem/Tokens.swift`, `App/DesignSystem/SeverityIcon.swift`, `Assets.xcassets`)

- **AccentColor.colorset:** `#2457E0` light, `#3461EA` dark. The user's non-Multicolor accent choice still wins
  (HIG; VERIFY on a Mac). Sidebar selection, `.borderedProminent`, toggles and links take the brand colour with no
  code. VERIFY that XcodeGen (`project.yml`) sets `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor`.
- §3.1's `well`, `lifted` and `Tag` go in `Tokens.swift`, beside MOTION §3.1's `Motion`, `flipIn` and `cardSwap`.

```swift
/// Daylight on the top of a stage screen: the accent at 9% (16% in dark) fading out over 240pt, plus a faint
/// key light. Static, never animated, never keyed to a verdict. Increase Contrast gets the plain window.
struct Sky: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Group {
            if contrast == .increased {
                Color(nsColor: .windowBackgroundColor)
            } else {
                ZStack(alignment: .top) {
                    Color(nsColor: .windowBackgroundColor)
                    LinearGradient(colors: [Color.accentColor.opacity(scheme == .dark ? 0.16 : 0.09), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 240)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
```

**System Settings tiles** (a white symbol on a rounded square of one colour) for the sidebar and severities:

```swift
extension View {
    /// System Settings tile. Used by SeverityIcon(tile:) and the sidebar rows.
    func tile(_ color: Color, size: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
        return font(.system(size: size * 0.55, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: shape)
            .overlay(shape.strokeBorder(.white.opacity(0.22), lineWidth: 0.5))
    }
}
```

`SeverityIcon` gets `var tile = false`; with `tile` and a `size` it draws
`Image(systemName: severity.symbol).tile(severity == .info || severity == .unknown ? .gray : severity.color, size: s)`.
It stays the only view that draws a severity, and the word for VoiceOver and Differentiate Without Color is unchanged.

### 5.2 Screens

- **Window and chrome.** Unified toolbar, translucent sidebar and inspector, unchanged. On macOS 26 the SDK makes
  them glass by itself; Whydunit adds no glass and no custom chrome.
- **Sidebar.** Structure unchanged. Rows get 20pt tiles: Summary `Image(systemName: "icloud.fill").tile(.accentColor, size: 20)`,
  each finding `SeverityIcon(tile: true, size: 20)`, Backups `clock.arrow.circlepath` on `.teal`, Activity
  `list.bullet.rectangle` on `.gray`. Badges stay native; tiles keep their colour on the selected row, as in System
  Settings.
- **Welcome** (never scanned): a 480pt column over `Sky()`:
  1. the app icon at 112pt with MOTION §3.2's entrance and `HoverTilt(max: 12, glare: true)`, resting on a still contact
     shadow `Ellipse().fill(.black.opacity(0.18)).frame(width: 84, height: 10).blur(radius: 8).offset(y: 62)` (static
     blur, drawn once);
  2. the sentence in `.system(size: 26, weight: .bold)` with `.tracking(-0.4)`, copy unchanged;
  3. the privacy line, `.callout` secondary, unchanged;
  4. **Scan iCloud Drive**: `.borderedProminent`, `.buttonBorderShape(.capsule)`, `.controlSize(.extraLarge)`
     (VERIFY both, macOS 14+), default action unchanged;
  5. three quiet `Label`s in `.caption.weight(.medium)` secondary, in a `ViewThatFits` row: "Reads status, not
     contents" `doc.text.magnifyingglass` · "Backs up first" `externaldrive.badge.checkmark` · "Trash, never delete"
     `trash`. Copy owner to confirm; they are the site's safety cards.
- **First scan.** MOTION §3.3's `ScanGlyph` over `Sky()`, cloud at 72pt with `.symbolRenderingMode(.hierarchical)`
  and `.foregroundStyle(.tint)`. The linear `ProgressView`, phase text and count stay; the count is
  `.font(.system(.callout, design: .rounded)).monospacedDigit()`.
- **Summary.** `Form(.grouped)` with `.scrollContentBackground(.hidden)` and `.background { Sky() }` (VERIFY the
  grouped cells keep their fill).
  - Hero section: `SeverityIcon(tile: true, size: 44)` on a `RadialGradient(colors: [Color.accentColor.opacity(0.35), .clear], …)`
    halo (always the accent, never the severity colour), the title in `.title2.weight(.bold)`, the meta line with
    numbers in `.monospacedDigit()`. `.accessibilityElement(children: .combine)` unchanged; the flip-in follows MOTION §3.4.
  - Findings rows: MOTION's `FindingRow` with `SeverityIcon(tile: true, size: 24)`, a trailing
    `Tag(text: n.formatted(), tint: severity.color)` before the chevron.
  - iCloud Drive section: unchanged `LabeledContent`, values `.monospacedDigit()`; the Sync check value leads with a
    6pt status dot via `Tag`.
- **Finding detail header.** `SeverityIcon(tile: true, size: 40)`, the title in `.title2.weight(.bold)`, the
  explanation. Steps: each number in a 20pt circle,
  `Text("\(i + 1)").font(.caption.weight(.bold)).frame(width: 20, height: 20).background(Color.accentColor.opacity(0.14), in: Circle())`,
  text primary. The one `.borderedProminent` action uses `.buttonBorderShape(.capsule)`; the rest stay `.bordered`.
  The `Table` is untouched (MOTION §3.6); its Status column shows `Tag(status.label, tint:)` (accent waiting, red
  failed, gray otherwise); Size and Modified use `.monospacedDigit()`.
- **Inspector.** Native. Section headers 11pt semibold uppercase `.tracking(0.6)` secondary with a trailing borderless
  Copy; values `.system(.callout, design: .monospaced)`, selectable. Empty state unchanged.
- **Sheets** (Back Up, Retry Upload, Restart iCloud Sync) share one header:

  ```swift
  /// A sheet's first lines: the action's symbol in a well, the title, one sentence. The same in all three sheets.
  struct SheetHeader: View {
      let symbol: String
      let title: String
      let detail: String

      var body: some View {
          HStack(alignment: .top, spacing: Space.s) {
              Image(systemName: symbol).font(.system(size: 22, weight: .semibold)).foregroundStyle(.tint)
                  .well(.accentColor, size: 48).accessibilityHidden(true)
              VStack(alignment: .leading, spacing: Space.xxs) {
                  Text(title).font(.title2.weight(.bold))
                  Text(detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
              }
          }
          .accessibilityElement(children: .combine)
      }
  }
  ```

  Symbols (VERIFY in the SF Symbols app, macOS 15): `externaldrive.badge.checkmark`, `icloud.and.arrow.up`,
  `arrow.clockwise.icloud`. Guarantees block: a grouped list of `checkmark.circle.fill` green rows with mono facts
  ("18.2 GB free · needs 2.4 GB", "Every item is on this Mac"). Step dots top right: the current one 18×6 in `.tint`,
  others 6×6 `.quaternary`, `accessibilityHidden`. Done: `checkmark.seal.fill` 40pt hierarchical green with
  `.symbolEffect(.bounce, value: done)` and `.symbolEffectsRemoved(reduceMotion)`, "12 copies verified" and
  `Tag(text: "SHA-256", tint: .green)`. Step swaps: MOTION §3.5 `cardSwap`, unchanged.
- **Backups and Activity.** Native lists. Backups rows: a folder tile, the date in mono, `Tag("Verified · 14 items", tint: .green)`.
  Activity: a 64pt mono time column, a 6pt dot by event kind, the text.
- **Empty and error states** (iCloud Drive Is Off, Permission Needed, The Scan Didn't Finish): the native
  `ContentUnavailableView` over `Sky()`, its symbol hierarchical in `.tint`.
- **Settings:** stock.

## 6. Icon and social image (release owner: `tools/make_icon.py`, `tools/make_og.py`, stdlib SDF renderers)

- **Icon.** Keep the cloud, lens and check. Body: sky gradient `#6FB6FF` → `#2457E0` → `#2A2F9E`, a soft elliptical
  specular band across the top quarter (white at 18%). Cloud: frosted glass, white at 90%, an inner top highlight and a
  cool underside shade `#E4EEFF`, so it reads as a volume. Lens: a brighter rim and a small highlight. Later, on a Mac:
  an Icon Composer `.icon` with three layers (background, cloud, lens) for Liquid Glass; VERIFY how the PNG renders on 26.
- **OG (1200×630).** The sky gradient, the icon at 256 with a halo, the two-tone headline on the left in the white
  wordmark's SDF strokes, and a simplified window turned `rotateY(-12deg)` off the right edge. No sentence in the image;
  `og:title` carries it.

## 7. What to delete from the current look

- The 128px icon as the hero and the product name as the h1. The promise is the h1; the icon moves to the finale and
  the download page.
- Apple.com's stock palette (`#0071e3`, `#f5f5f7`, `#1d1d1f`, pure `#000` dark) and the flat `--bg-alt` card slabs.
- The one untinted grey `--shadow`; the banded sections and `section:not(.band) .card`.
- The full-width sticky header bar with its border; the bare-hairline FAQ; the flat blue step dots; the grey footer
  block without an official-sources line.
- "Sound familiar?" as three grey quote cards (it becomes the Finder/Whydunit pair).
- In the app: the empty Welcome pane, blue everywhere by default, the plain `chevron.right` rows with no counts.

## 8. Acceptance and budgets

**Looks premium (a judge checks these against screenshots, light and dark, 1440 and 360):**

- [ ] The page background is never pure white or pure black; cards are white (or `#141a28`) objects with a visible
  hairline and a soft navy-tinted shadow, never grey slabs.
- [ ] The hero product sits in a sky frame with rounded corners and hangs off its lower edge onto paper; a ghost Finder
  window and two chips sit at different depths; at rest the window is flat and sharp.
- [ ] Exactly one accent is visible on the page (sky blue); green, orange and red appear only in tag dots and symbols.
- [ ] The header is a floating pill, not a bar. Buttons show a lit top edge and a blue glow; secondary buttons and
  chips read as key-caps.
- [ ] Headlines are tight (−.03em), two-tone, `text-wrap: balance`; big numbers are rounded; nothing is ALL CAPS.
- [ ] No band edges anywhere; sections are separated by whitespace. No emoji, no stock icon set, no gradient text.
- [ ] Dark mode is the same world at dusk (indigo sky, light rims on every surface), not an inverted page.
- [ ] The footer names the only official site and download source.

**Functional (on top of MOTION.md §6.2):**

- [ ] `python tools/build_site.py --check` passes; exactly two `:root` blocks; no `data-theme`/`localStorage`.
- [ ] 1440 and 360, light and dark: no horizontal scroll, the stage is full-bleed at ≤640px, the ghost and chips are
  hidden on phones, sticky cards are static below 900px.
- [ ] Reduced motion: nothing moves, rest state complete. Reduced transparency: solid header. `prefers-contrast: more`:
  2px outlines, no grain. Forced colors: bordered buttons and cards. Print: no stage, no shadows.
- [ ] JS off: the page is complete. CLS 0; LCP is the h1.
- [ ] Owner, Safari on a Mac: headline tracking, the 3D sort of the ghost plane, `color-mix`, the header glass.
- [ ] App (once CI compiles it): MOTION's greps pass; `grep -rn "glassEffect" App/` finds nothing; idle CPU 0% within
  2 s; VoiceOver labels unchanged; Increase Contrast shows strokes on tags and wells and a plain window background.

**Budgets** (caps from MOTION.md §6.1; measure with `wc -c`):

| Item | Cap | Today | Estimate |
|---|---|---|---|
| `site/static/styles.css` | 40 KB | 12.5 KB (19.2 with MOTION) | about 31 KB |
| `site/static/motion.js` | 5 KB | 2.7 KB (MOTION) | 2.7 KB, byte-identical |
| Home HTML, built | 26 KB | 16.8 KB | about 23 KB (pair, three sheet mocks, proof strip) |
| New fonts, images, scripts, requests | 0 | 0 | 0 |
| App: new assets or dependencies | 0 | 0 | 0 (AccentColor is a colorset, not an image) |

## 9. Changes for other owners, decisions for the lead, VERIFY list

**Other owners (proposals, not made here):**

1. **Lead, BUILD_PLAN §6:** "system colors only" → "system colors plus the brand AccentColor (the user's
   non-Multicolor choice wins)"; "No card backgrounds on content" → "no card backgrounds around rows; wells, tags, the
   Sky wash, tiles and the sheet header are allowed"; add "Design: docs/DESIGN.md; motion: docs/MOTION.md". "No custom
   glass" stays true.
2. **Release owner, `tools/build_site.py contrast()`:** `on = "on-button" if "on-button" in light else "#ffffff"`, then
   measure `(on, "button")` and `(on, "button-hover")`. Backward-compatible; Whydunit passes either way. Add the
   MOTION §6.4 size caps.
3. **Release owner:** `AccentColor.colorset` in `Assets.xcassets`; app-shell: the `project.yml` setting (§5.1).
4. **Release owner:** icon and OG (§6).
5. **Site owner:** §2.4 markup (sprite into `layout.html`, nav Source pill, official-sources line, theme-color), §4.
6. **AGENTS.md:** add "Design: docs/DESIGN.md (tokens, compositions); motion: docs/MOTION.md."
7. **CI:** once real windows can be captured on the macOS runner (`screencapture -l <windowid>`; VERIFY Screen
   Recording permission there), a Mole-style "See it" gallery: WebP, width and height set, lazy after the first,
   ≤120 KB each, framed on the sky. Never commit third-party screenshots.

**Decisions for the lead:**

- Whydunit has **no `LICENSE` file**. The site must not say "open source" until one is added; "View source" is fine.
- "Signed and notarized" enters the facts line and footer only in the change that enables the signed 1.0 download.
- Copy owner: the new h1, lede, proof stats, pair copy and the Welcome facts row need a pass against UI_SPEC §5.

**VERIFY:** `buttonBorderShape(.capsule)` and `controlSize(.extraLarge)` on macOS 14+; `Form(.grouped)` cells over a
hidden scroll background; the three sheet symbols; XcodeGen's accent setting; `text-wrap: balance`, `color-mix` and
`ui-rounded` in Safari; the ghost plane's 3D sort in Safari; dark-mode banding with the grain.
