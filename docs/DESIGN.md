# Design spec: Whydunit (website and app)

**Why:** the owner's verdict (2026-09-29): the sites and apps "look cheap". They must look modern, premium and 3D, on
par with Mole, Recordly, Maccy, Rectangle, VoiceInk and MaCursor, while staying lightweight and secure.
**Authority:** this file is authoritative for visual design (tokens, surfaces, compositions, type). `docs/MOTION.md`
stays authoritative for motion and is referenced by section; §2.8 lists exactly where this file overrides it.
BUILD_PLAN lines that need amending are listed in §9, not amended here. Safety rules, copy, data flow and the
checker's contract are unchanged.
**Shared system:** §1–§3 are identical in the Tirekick repo's `docs/DESIGN.md`; change both together. §4–§9 are
Whydunit's.
**Status:** nothing in this file has been built. Two directions were proposed ("Afterglow", dark-first and
cinematic; "Daylight Native", light-first and object-based); this is the final judgement and the spec builders
implement. Every contrast figure was recomputed with `tools/build_site.py`'s own `contrast()` formula
(`<scratchpad>/final_contrast.py`, 2026-09-29). The Swift is written, not compiled; anything unconfirmed is marked
VERIFY.

## 1. The verdict (shared, identical in both repos)

Judged against the reference captures, the premium references share one mechanism, not one palette: **a real
product object sits inside a small world that has one light source, on a page that is otherwise quiet.** Recordly
(dark page) floats its window over a blue sky; Mole (light page) floats its window over a silk wallpaper; VoiceInk's
social card stands its icon on a lit horizon; MaCursor, the weakest of the six, is a generic dark-blue template with
nothing lit. Rectangle and Maccy, the plainest, put the product on bare white, which is where our sites are today.

Neither proposal wins outright. Each brand takes the direction whose *world* fits its job, and grafts the other's
best mechanics:

| | Whydunit | Tirekick |
|---|---|---|
| Direction | **Daylight Native** (light-first, dark follows the system). | **Night Bay** (dark on every page, in both schemes). |
| Why | iCloud's own language is white and blue; the app is light by default; Mole and VoiceInk prove light reads premium when the product is framed in a world. Calm is the brand. | The white report card must be the brightest object on the page, which only a dark bay gives. A hard lime laser, a floor grid and mono readouts read as an instrument, distinct from every other Mac utility and from Whydunit. |
| World | A **macOS desktop diorama**: a dawn wallpaper with a horizon glow, a menu bar, a Finder window behind, the Whydunit window in front, a notification landing top right. Real Mac objects, no cartoon cloud. | An **inspection bay**: a full-bleed night band, a perspective floor grid, one lime laser line, the CSS laptop behind and the paper report card in front. |
| Grafted from the other | From Afterglow: one key light per scene (the horizon glow), lit top rims on every raised surface, real CI captures only at half scale, small-caps labels, severity only in dots and tags, the sidebar without an orange wall, `Horizon` under one object per stage screen. | From Daylight: the `<mark>` highlighter on the h1, a paper-stack edge on the report card, key-caps that sink on `:active`, the StepBar loses its lime, the verdict header without a box, the `html[lang]` fix, real screenshots below the fold. |
| Accent | Sky blue `#2457E0` (`#3563EA` at night). The app keeps AccentColor. | Hi-vis lime `#C6F23C`, black text on it. Only the one prominent button, the laser, LEDs and eyebrow indices. |
| Type voice | Inter Display 600 headlines, centered hero, `ui-rounded` numerals, pills. | Inter Display 600 headlines, left-aligned hero, `ui-monospace` readouts, 12px machined corners. |
| Signature scroll moment | Three safe fixes as sticky stacking cards; a real-screens filmstrip. | Six key-cap test tiles; a paper fan of the shareable card. |

**Decided, in both brands** (each reverses an earlier rule; the reasons are in the sections named):

1. **One webfont**, Inter Display SemiBold, Latin subset, ≤ 32 KB, byte-identical in both repos (§2.2). The owner
   judges the sites on Windows, where every headline currently renders in Segoe UI Bold: the single cheapest thing on
   either page. Body and UI text stay on the system stack.
2. **Real CI screenshots below the fold**, shown at half their pixel width (§2.6). The hero stays HTML.
3. **Content surfaces are porcelain panels**, never grey grouped cells, in both apps (§3.1). Glass exists only on the
   controls layer, and only where the macOS 26 SDK or `barSurface()` draws it (§3.2).
4. **No serif clause, no `ui-serif`.** VoiceInk's italic is lovely, but a second display voice on top of Inter
   Display is one voice too many, and Windows would render it in Georgia. One display face.
5. **Whydunit keeps its toolbar actions** (BUILD_PLAN §6); no floating selection bar. Tirekick keeps its floating bar.
6. **Icons are unchanged for now.** The OG images are redone (§6). An Icon Composer `.icon` waits for a Mac.

**Not doing, in either brand:** a CDN, a tracker, a second font, a live star count, autoplay video, mesh blobs,
gradient text, emoji icons, glass on content, a nav CTA that hides itself, `style=""` attributes, `data-theme`.

### 1.1 The eight rules

1. **One world per product, and it appears only behind objects:** the hero scene, the fixes' media wells, the finale
   and the download page's icon. Every other section is paper (Whydunit) or graphite (Tirekick), paced by whitespace.
2. **One key light per scene.** Whydunit's is the dawn glow on the wallpaper's horizon; Tirekick's is the lime laser.
   Nothing else glows, and a glow is never severity-coloured (MOTION §1.1 rule 3).
3. **Light, not lines.** Every raised surface has a lit top edge (`inset 0 1px 0`), a 0.5px hairline (a 1px light
   rim in dark, because black swallows shadows) and a shadow tinted with the brand's ink, never neutral grey, never
   animated (MOTION §1.4).
4. **One accent.** Green, orange and red mean a status and appear only in 6px dots, symbols and tag fills behind
   primary text. Severity never gets a coloured panel: a red "Walk away" is set exactly like a green "Clean".
5. **Objects, not illustrations.** Every product visual is a faithful Mac object: a window, a sheet, a notification,
   a Finder list, the report card, the laptop. No cartoon clouds, orbs or glossy coins.
6. **Everything you can press is a key-cap:** a gradient lighter at the top, a lit rim, a hairline, a side wall in
   Tirekick, and a press that sinks 1–2px with the shadow swapped instantly (never transitioned).
7. **Concentric radii:** outer radius = inner radius + padding. Whydunit 8/12/18/28 and pills; Tirekick 6/10/14/20
   and 12px buttons. Grain (≤ 6%, inline SVG) only on wallpaper and bay gradients, never under body text.
8. **The apps stay native.** Navigation, tables, sheets, Settings, the toolbar and the inspector are system parts.
   Premium comes from the wash, porcelain panels, one lifted object per stage screen, the accent, tags, key-caps and
   the precision of the type. Nothing moves at idle.

## 2. Shared web foundation

### 2.1 The contract with `tools/build_site.py`

- `contrast()` reads exactly two `:root { }` blocks and only 6-digit hex tokens. Whydunit's blocks are light then
  `@media (prefers-color-scheme: dark)`. Tirekick's are the base (dark) palette then `@media (prefers-contrast:
  more)`. Every other override sits on `html[lang]` (§2.7), never on a third `:root`.
- Hero copy sits on `--bg` in both brands (the diorama and the bay are behind objects only), so no new pairs are
  needed. The window replica (`--win-*`) and the report card (`--paper*`) are `role="img"` pictures, not measured.
- `data-theme` and `localStorage` must not appear anywhere, including comments.
- Tirekick's `CSP` constant and `layout.html` meta must gain `font-src 'self'` (tools owner, §9). Whydunit's
  `default-src 'self'` already permits the font.
- `build_site.py` rewrites `href="/` and `src="/`; it must also rewrite and link-check `srcset="/` before the real
  screens ship (§2.6; tools owner).

### 2.2 Type: Inter Display for headlines, the system for everything else

**File.** Inter Display SemiBold from Inter 4.x (SIL OFL 1.1, `github.com/rsms/inter` releases), subset once to
Latin with fonttools on a dev machine (a one-off, not a repo tool), committed with `OFL.txt` at
`site/static/fonts/InterDisplay-SemiBold.woff2` in both repos, byte-identical. Expected 20–30 KB; the cap is 32 KB
(VERIFY after subsetting). `font-display: optional` plus a preload: it paints on the first frame or not at all for
that view, so CLS is 0 and the h1 stays the LCP.

```css
/* Relative URL: the site is served under a project path and the build doesn't rewrite CSS url(). */
@font-face { font-family: "Inter Display"; src: url("fonts/InterDisplay-SemiBold.woff2") format("woff2"); font-weight: 600; font-style: normal; font-display: optional; }
```
```html
<!-- layout.html, before the stylesheet; the build prefixes href="/ -->
<link rel="preload" href="/fonts/InterDisplay-SemiBold.woff2" as="font" type="font/woff2" crossorigin>
```

Stacks (first `:root` block):

```css
--font: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI Variable Text", "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
--font-display: "Inter Display", -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI Variable Display", "Segoe UI", sans-serif;
--font-mono: ui-monospace, "SF Mono", SFMono-Regular, Menlo, "Cascadia Mono", Consolas, monospace;
```

**Type ladder.** Put this comment at the top of both `styles.css` files; no size outside it.

```css
/* Type ladder (docs/DESIGN.md §2.2). Display = var(--font-display) 600; everything else = var(--font).
   h1       display  clamp(2.75rem, 1.5rem + 4.8vw, 5.25rem) / 1.0,  -.038em, text-wrap: balance
   h2       display  clamp(2rem, 1.35rem + 2.6vw, 3.25rem)   / 1.04, -.032em, balance
   feature  display  clamp(1.5rem, 1.2rem + 1vw, 2rem)       / 1.1,  -.025em
   card h3  system   17px / 1.3, -.015em, 600
   lede     system   clamp(1.125rem, 1rem + .45vw, 1.3125rem) / 1.45, -.012em, --text-2
   body     17px / 1.55, -.011em        small 15px / 1.5        meta 13px / 1.4, 500
   numerals display, tabular-nums: 40px (proof strip), 64–88px (finale)
   labels   13px 600 with font-variant-caps: all-small-caps and .04em tracking (styling, not ALL CAPS copy)
   eyebrow  Whydunit 13px 600 --accent · Tirekick 12px 500 mono "01 · Checks", index in --accent
   numerals in UI: Whydunit ui-rounded, Tirekick ui-monospace, both tabular */
h1, h2, .display, .feature h3, .proof dd, .brand { font-family: var(--font-display); font-weight: 600; }
```

Weight 600, not 700: at 44–84px, Inter Display SemiBold at −.038em reads engineered; Bold reads loud. Recordly
makes the same choice. Two-tone headings stay (`<span class="dim">`); numbers that line up are `tabular-nums`.

### 2.3 Space, widths and radii

- Widths: `.wrap` 1080px (content), `.wide` 1240px (stages), `.read` 720px (prose, FAQ). Gutter 20px, 16px under 480.
- `main > section { padding-block: clamp(72px, 10vw, 136px) }`: more silence, fewer sections. Gaps are 12, 16, 24,
  32, 48 or 64px. `scroll-padding-top: 84px`.
- Radii tokens `--r-s / --r-m / --r-l / --r-xl` and `--r-btn` come from each brand's `:root`.

### 2.4 Light and depth (MOTION §1.4 names, retuned values)

Every shadow and hairline is the brand's ink at an alpha. Light recipe (dark values are in each brand's tokens):

| Token | Role | Recipe |
|---|---|---|
| `--hi` | lit top edge on raised surfaces | `rgb(255 255 255 / .9)`; dark `/ .06` |
| `--z1` | hairline plus contact: rows, pills, the header | `0 0 0 .5px ink/.12, 0 1px 2px ink/.05` |
| `--z2` | porcelain card | `inset 0 1px 0 var(--hi), 0 0 0 .5px ink/.12, 0 2px 4px ink/.04, 0 12px 28px -12px ink/.16` |
| `--shadow` | a floating object on paper | `0 0 0 .5px ink/.22, 0 2px 4px ink/.06, 0 24px 48px -16px ink/.30, 0 64px 128px -32px ink/.34` |
| `--shadow-win` | a window on the wallpaper | `0 0 0 .5px rgb(0 0 0 / .28), 0 2px 6px rgb(0 0 0 / .08), 0 28px 56px -12px wp-ink/.45, 0 72px 140px -24px wp-ink/.5` |
| `--cap` | key-caps (buttons, pills, test keys) | `inset 0 1px 0 var(--hi), 0 0 0 .5px ink/.18, 0 1px 2px ink/.08, 0 4px 10px -4px ink/.12` |

In dark every shadow is black at .5–.8 and the hairline becomes a `0 0 0 1px rgb(255 255 255 / .07–.10)` rim. Never
animate `box-shadow` or `filter`; a state swap with no transition is fine.

### 2.5 Shared components (identical CSS in both repos; tokens differ)

These replace the current rules of the same name. Everything else in the current files stays.

```css
/* Header pill: 48px, the only backdrop-filter on the page. */
.nav { height: 48px; max-width: 980px; padding: 0 6px 0 14px; border-radius: 999px; background: var(--header);
  -webkit-backdrop-filter: saturate(180%) blur(20px); backdrop-filter: saturate(180%) blur(20px);
  box-shadow: inset 0 1px 0 var(--hi), var(--z1); }
.brand { font-size: 17px; letter-spacing: -.02em; }

/* Section head: editorial, left-aligned; heading left, lede right on wide screens. */
.sec-head { display: grid; gap: 16px 64px; align-items: end; margin-bottom: clamp(40px, 5vw, 64px); }
@media (min-width: 900px) { .sec-head { grid-template-columns: 7fr 5fr; } }
.sec-head h2, .sec-head .lede { margin: 0; }

/* Primary button: a key-cap whose fill only darkens downward, so the label keeps its measured contrast. */
.button { border-radius: var(--r-btn); min-height: 48px; padding: 0 22px; font: 600 16px/1 var(--font); color: var(--on-button);
  background: linear-gradient(var(--button), color-mix(in srgb, var(--button) 88%, #000));
  box-shadow: inset 0 1px 0 rgb(255 255 255 / .3), inset 0 -1px 0 rgb(0 0 0 / .18), var(--cap); }
.button.secondary { color: var(--text); background: linear-gradient(var(--cap-top), var(--cap-bot)); box-shadow: var(--cap); }
.button:active { translate: 0 1px; box-shadow: inset 0 1px 0 rgb(255 255 255 / .3), 0 0 0 .5px rgb(var(--ink) / .18); }

/* Porcelain card. */
.card { border-radius: var(--r-l); background: var(--card); box-shadow: var(--z2); }

/* Proof strip: hairlines only, no box. */
.proof { display: grid; grid-template-columns: repeat(4, 1fr); gap: 0; border-block: 1px solid var(--line); }
.proof div { padding: 24px 28px 24px 0; } .proof div + div { border-left: 1px solid var(--line); padding-left: 28px; }
.proof dd { font: 600 clamp(28px, 3.2vw, 44px)/1 var(--font-display); letter-spacing: -.03em; font-variant-numeric: tabular-nums; }
@media (max-width: 720px) { .proof { grid-template-columns: 1fr 1fr; } .proof div:nth-child(odd) { border-left: 0; padding-left: 0; } }

/* Ledger: rules as a spec sheet. Replaces icon-well card grids. */
.rules { margin: 0; padding: 0; list-style: none; border-top: 1px solid var(--line); }
.rules li { display: grid; grid-template-columns: 1fr auto; gap: 4px 24px; padding: 20px 0; border-bottom: 1px solid var(--line); }
.rules h3 { margin: 0; font: 600 17px/1.3 var(--font); letter-spacing: -.015em; }
.rules p { margin: 0; color: var(--text-2); font-size: 15px; }
.rules code { grid-column: 2; grid-row: 1 / span 2; align-self: center; }

/* FAQ: one grouped panel with hairline rows (System Settings), not a stack of cards. "+" turns into "×", no JS. */
.faq-list { border-radius: var(--r-l); background: var(--card); box-shadow: var(--z2); }
.faq-list details { padding-inline: 20px; } .faq-list details + details { border-top: 1px solid var(--line); }
.faq-list summary::after { content: "+"; transition: rotate var(--t-base) var(--ease-spring); }
.faq-list details[open] summary::after { rotate: 45deg; }

/* Real screens: a scroll-snap filmstrip (§2.6). Keyboard-scrollable, no lightbox, no JS. */
.film { display: grid; grid-auto-flow: column; grid-auto-columns: min(560px, 84vw); gap: 24px; overflow-x: auto;
  scroll-snap-type: x mandatory; overscroll-behavior-x: contain; padding: 8px 20px 36px; scrollbar-width: thin; }
.film figure { margin: 0; scroll-snap-align: center; }
.film img { display: block; width: 100%; height: auto; border-radius: 10px; background: var(--win-bg); box-shadow: var(--shadow); }
.film figcaption { margin-top: 12px; font-size: 13px; color: var(--text-2); }

/* Finale: the app icon standing on a glossy floor. Chrome and Safari reflect; Firefox simply doesn't. */
.finale .icon { width: 128px; height: 128px; -webkit-box-reflect: below 6px linear-gradient(transparent 62%, rgb(0 0 0 / .22)); }   /* VERIFY inside a 3D parent in Safari */

/* Small-caps labels. */
.label { font: 600 13px/1.3 var(--font); font-variant-caps: all-small-caps; letter-spacing: .04em; color: var(--text-2); }
```

### 2.6 Imagery: an HTML hero, real screenshots below the fold

- **Hero:** an HTML replica of the app (0 image bytes, sharp at any DPI, follows the scheme). Caption: "Illustration
  with sample data". Its copy matches `App/Demo.swift`, so the replica and the CI captures agree.
- **Real screens:** 3 CI captures per brand in the `.film` strip, one image per scheme.
  - **The half-scale rule.** The CI runner's display is 1x: a 1120×760pt window captures at 1136×804 with the
    shadow. An image shown at half its pixel width is exact 2x on Retina, so a 1120px capture is shown at 560 CSS px.
    Never show a capture at a size that upscales it.
  - **Pipeline (CI owner, `screens.yml`):** add a no-shadow variant `screencapture -x -o -l "$ID"`; convert with
    `sips -s format jpeg -s formatOptions 82 in.png --out shots/<screen>-<mode>.jpg` (VERIFY the percent syntax;
    VERIFY whether `sips --formats` lists WebP as writable on the runner and prefer it); cap each file at 110 KB. The
    lead commits the chosen files to `site/static/shots/`; they're our own app.
  - **Markup:** `<picture>` with a dark `<source>`, `width` and `height`, `loading="lazy" decoding="async"`, a
    real `alt`. `img { border-radius: 10px }` hides the JPEG's filled corners (VERIFY by eye against the window
    radius at half scale).
  - Ship the section only once the captures are committed; until then leave it out of the page.

### 2.7 Accessibility media, and a bug to fix first

**Bug (both sites).** The `html { --grain: none; … }` overrides under `prefers-contrast: more` and `@media print`
never apply: `:root` has specificity (0,1,0) and beats `html` (0,0,1) whatever the order (Whydunit `styles.css`
lines 468 and 473, Tirekick 479 and 484). Tirekick therefore prints light text on white paper. Fix: `html[lang] { … }`
(0,1,1) wins, and it doesn't match the checker's `:root\s*\{` regex, so the two-block rule holds. Both `layout.html`
files already set `<html lang="en">`.

```css
@media (prefers-contrast: more) { html[lang] { --grain: none; --glare: transparent; --glow: transparent; }
  .card, details, .nav, .button, .tag, .proof, .faq-list, .note, .window, .report { box-shadow: 0 0 0 2px var(--text); } .finale .icon { -webkit-box-reflect: unset; } }
@media (prefers-reduced-transparency: reduce) { .nav { -webkit-backdrop-filter: none; backdrop-filter: none; background: var(--card); } }
@media (forced-colors: active) { .button, .card, details, .tag, .well, .proof div, .nav, .note { border: 1px solid CanvasText; } }
@media print { html[lang] { color-scheme: light; --bg: #fff; --bg-alt: #fff; --card: #fff; --text: #000; --text-2: #333; --grain: none; }
  .site-header, .site-footer, .skip, .stage, .finale, .film { display: none; } }
```

Also keep: visible 3px focus rings, 44px hit areas, content visible without JS (`.reveal` hides only after
`motion.js` adds `.reveal-io`), no `style=""` (stagger uses `:nth-child`), and every image with `width`/`height`.

### 2.8 What this supersedes in MOTION.md

MOTION.md stays authoritative for motion: tilt, glare, reveal, flips, `motion.js`, the Reduce Motion table and the
performance rules are unchanged and referenced by section. Where the two conflict, this file wins:

| MOTION.md | Now |
|---|---|
| §1.7 `--z1`, `--z2`, `--glare`, `--shadow` values | §2.4 recipes with each brand's ink; names unchanged, so the motion CSS keeps working |
| §1.7 `.button { transition: … }` | §2.5's button (adds `translate` on `:active`, shadow swapped instantly) |
| §2.1 Whydunit story (cloud, rising files, check) | the diorama sequence, 2.0 s (Whydunit §4.3); `.sky`, `.cloud`, `.cloud-ok`, `.doc`, `.ghost` and `upload` are deleted |
| §2.3 `.cloud { fill: … }` | gone with the cloud |
| §4.1 Tirekick story (chips fly from the screen to the card) | laser snaps on, lid opens, card deals in, beam sweeps the card, verdict settles; 2.45 s (Tirekick §4.3). The lid and card-deal keyframes are kept and retimed |
| §4.3 `--tread` floor, `.horizon` bloom, blue `.beam` | perspective floor grid, 1px lime laser with a tight spill, lime beam (Tirekick §4.3) |
| §5.1 `TileButtonStyle` | `KeyCapStyle` with a real side wall (Tirekick §5.2); same tilt, press and bounce |
| §3.4 Summary hero "lands" as a card | the verdict plate (a porcelain surface) lands with the same `flipIn`; the Form is gone (Whydunit §5.2) |
| §1.8 `Sky`/`Bay` as the only backgrounds | `Sky` grows a sun (Whydunit §5.1); `Bay` gets a per-step key light and loses its grey ramp in light (Tirekick §5.1) |

New motion, both within MOTION §1.1's rules: a notification slides in from the right with `--ease-spring`; key-caps
sink 2px on `:active` with the translate transitioned and the shadow swapped; Tirekick's key light moves 0.35 s per
step. Reduce Motion shows final states (MOTION §1.5) throughout.

## 3. Shared app foundation (SwiftUI; written, not compiled)

**Material hierarchy, in order:** the system window (sidebars and toolbars stay system; on macOS 26 the SDK makes
them glass by itself) → a static wash at the top of stage screens (`Sky` / `Bay`) → porcelain surfaces for content
groups → controls. One accent; severity only as symbol tint, tag fill and dot. One lifted object per stage screen.
Nothing moves at idle (MOTION §1.6: zero CPU, springs only, at most 8 `HoverTilt` on screen).

### 3.1 `App/DesignSystem/Tokens.swift` additions (identical in both apps; macOS 13 APIs only)

```swift
extension View {
    /// Porcelain surface: white (a 5.5% white lift in dark), a hairline rim, a tight contact shadow plus a wide soft
    /// one tinted with the brand's ink. Concentric: pass the outer radius; content inside pads by radius - inner.
    /// Replaces grey grouped Form cells and `.quaternary` slabs. Never glass, never on a single row.
    func surface(_ radius: CGFloat = 16) -> some View { modifier(Surface(radius: radius)) }
}

private struct Surface: ViewModifier {
    let radius: CGFloat
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let dark = scheme == .dark, strong = contrast == .increased
        content
            .background(dark ? AnyShapeStyle(Color.white.opacity(0.055)) : AnyShapeStyle(.background), in: shape)
            .overlay { shape.strokeBorder(strong ? Color.primary.opacity(0.5) : Color.primary.opacity(dark ? 0.10 : 0.07), lineWidth: strong ? 1 : 0.5) }
            .compositingGroup()   // glyphs inside don't cast their own shadows (MOTION §1.4)
            .shadow(color: .black.opacity(dark ? 0.35 : 0.05), radius: 1, y: 1)
            .shadow(color: Brand.ink.opacity(dark ? 0.5 : 0.10), radius: 16, y: 8)
    }
}

/// An object standing on a glossy floor: the view, its mirror fading out over 45% of its height, and a still
/// contact shadow. Drawn once. Pass a stateless view: it is drawn twice. None of the mirror under Reduce Transparency.
struct OnFloor<Content: View>: View {
    var height: CGFloat
    @ViewBuilder var content: Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(spacing: 2) {
            content
            if !reduceTransparency {
                content
                    .scaleEffect(x: 1, y: -1)
                    .frame(height: height * 0.45, alignment: .top).clipped()
                    .mask(LinearGradient(colors: [.black.opacity(0.22), .clear], startPoint: .top, endPoint: .bottom))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .background(alignment: .center) {
            Ellipse().fill(.black.opacity(0.16)).frame(width: height * 0.7, height: height * 0.08).blur(radius: 6)
                .offset(y: height * 0.02)   // VERIFY by eye: the ellipse should sit at the object's base
                .accessibilityHidden(true)
        }
    }
}

/// The key light under a lifted object: a pool of light and a thin bright line. Static; drawn once per size.
/// `soft`: Whydunit's dawn bloom. Tirekick passes false: a hard line with a tight spill. Decorative, hidden from VoiceOver.
struct Horizon: View {
    var tint: Color
    var width: CGFloat = 420
    var soft = true
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        ZStack {
            if contrast != .increased {
                RadialGradient(colors: [tint.opacity(soft ? 0.42 : 0.22), tint.opacity(soft ? 0.10 : 0), .clear],
                               center: .center, startRadius: 0, endRadius: width / 2)
                    .frame(width: width, height: width * (soft ? 0.32 : 0.14))
            }
            LinearGradient(colors: [.clear, tint, .white.opacity(0.9), tint, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: width * 0.86, height: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A small-caps label over a big number. One VoiceOver element. Whydunit passes .rounded, Tirekick .monospaced.
struct Metric: View {
    let label: String
    let value: String
    var unit: String? = nil
    var dot: Color? = nil
    var design: Font.Design = .rounded

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption.weight(.semibold).smallCaps()).foregroundStyle(.secondary)   // VERIFY small caps with SF
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if let dot { Circle().fill(dot).frame(width: 6, height: 6).accessibilityHidden(true) }
                Text(value).font(.system(size: 26, weight: .semibold, design: design)).monospacedDigit()
                if let unit { Text(unit).font(.callout.weight(.medium)).foregroundStyle(.secondary) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
```

`Brand.ink`: Whydunit navy `Color(red: 0.06, green: 0.11, blue: 0.24)`; Tirekick olive-black `Color(red: 0.09,
green: 0.10, blue: 0.04)`. `Tag`, `well`, `lifted`, `HoverTilt`, `flipIn`/`flip` and `cardSwap` are unchanged.

**Type in the apps:** SF only. Stage headlines `.system(size: 28–30, weight: .semibold)` with `.tracking(-0.5)`
(Tirekick's Welcome keeps `.heavy` + `.width(.expanded)`, VERIFY on macOS 13); plate titles 22pt semibold; rows 13pt
with a 12pt secondary line; every number `.monospacedDigit()`; big metrics 26pt semibold rounded (Whydunit) or
monospaced (Tirekick); small-caps labels only on metric labels, inspector and section headers. Radii: 18 (plates),
14 (tiles), 12 (rows and inner groups), 8 (chips), capsules for buttons.

### 3.2 The controls layer: glass only here

Whydunit has no floating bar, so it adds nothing; the macOS 26 SDK draws its sidebar and toolbar glass by itself.
Tirekick's `FloatingBar` and `StepBar` call this, in `Compat.swift` (the only file allowed `#available`,
BUILD_PLAN §10):

```swift
extension View {
    /// Liquid Glass on macOS 26; a material with a hairline before. Floating bars and the StepBar only, never content.
    @ViewBuilder func barSurface() -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular, in: Capsule())                       // VERIFY: glassEffect(_:in:) signature, Xcode 26 SDK
        } else {
            background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
        }
    }
}
```

Materials and glass handle Reduce Transparency themselves.

### 3.3 Performance and accessibility (both apps)

- Everything added is static: `surface`, `OnFloor`, `Horizon`, `Sky`/`Bay` draw once per size. At most 6 shadows
  per screen, no `drawingGroup()` over text. Idle CPU stays 0%; the only loops are `ScanGlyph` and Tirekick's
  checking beam, inside their scanning views.
- Decorative layers (`Horizon`, the mirror, contact shadows) are `accessibilityHidden`. Labels, traits and combined
  elements from MOTION §1.5 are unchanged; severity always carries its word.
- Increase Contrast: surfaces get a 1pt primary stroke, `Horizon` loses its pool, `Sky`/`Bay` become the plain
  window. Reduce Transparency: no mirrors, materials go solid. Reduce Motion: MOTION §1.5 exactly.

## 4. Whydunit website: Daylight

### 4.1 Tokens (replace the two `:root` blocks in `site/static/styles.css`)

```css
:root {
  color-scheme: light dark;
  /* contrast(), light, worst of bg / bg-alt / card: text 16.4:1, text-2 5.34:1, accent 5.51:1;
     white on button 5.97:1, on hover 7.62:1. */
  --bg: #f4f6f9; --bg-alt: #eaeef3; --card: #ffffff;
  --text: #0a0f1c; --text-2: #586173; --accent: #1d54d4;
  --button: #2457e0; --button-hover: #1c48c2; --on-button: #ffffff;
  --line: #dde2ea; --header: rgb(255 255 255 / .72); --hi: rgb(255 255 255 / .9);
  --ink: 16 28 60;                                   /* navy: every shadow and hairline */
  --ok: #34c759; --warn: #ff9f0a; --bad: #ff3b30;
  /* The world, "iCloud dawn": deep cobalt sky, pale middle, one warm horizon glow (the key light), cloud banks. */
  --wp-1: #1a47c9; --wp-2: #3f82f2; --wp-3: #9cc8ff; --wp-4: #fbe3cf;
  --wp-hi: rgb(160 205 255 / .9); --wp-cloud: rgb(255 255 255 / .78); --wp-glow: rgb(255 214 170 / .7);
  --wp-ink: 6 24 80; --glass-lite: rgb(255 255 255 / .82); --menubar: rgb(255 255 255 / .22);
  --cap-top: #ffffff; --cap-bot: #f4f6fa;
  --cap: inset 0 1px 0 var(--hi), 0 0 0 .5px rgb(var(--ink) / .18), 0 1px 2px rgb(var(--ink) / .08), 0 4px 10px -4px rgb(var(--ink) / .12);
  --z1: 0 0 0 .5px rgb(var(--ink) / .12), 0 1px 2px rgb(var(--ink) / .05);
  --z2: inset 0 1px 0 var(--hi), 0 0 0 .5px rgb(var(--ink) / .12), 0 2px 4px rgb(var(--ink) / .04), 0 12px 28px -12px rgb(var(--ink) / .16);
  --shadow: 0 0 0 .5px rgb(var(--ink) / .22), 0 2px 4px rgb(var(--ink) / .06), 0 24px 48px -16px rgb(var(--ink) / .30), 0 64px 128px -32px rgb(var(--ink) / .34);
  --shadow-win: 0 0 0 .5px rgb(0 0 0 / .28), 0 2px 6px rgb(0 0 0 / .08), 0 28px 56px -12px rgb(var(--wp-ink) / .45), 0 72px 140px -24px rgb(var(--wp-ink) / .5);
  --glare: rgb(36 87 224 / .07);
  --grain: /* the existing inline feTurbulence SVG with the last matrix value .04 (4% on light) */;
  --font, --font-display, --font-mono: as §2.2;  --font-num: ui-rounded, var(--font);
  --r-s: 8px; --r-m: 12px; --r-l: 18px; --r-xl: 28px; --r-btn: 999px;
  /* motion tokens unchanged (MOTION §1.2) */
  /* Window replica, macOS 26 light (role="img", not measured). */
  --win-bg: #ffffff; --win-side: #f3f4f6; --win-group: #ffffff; --win-row-alt: #f7f8fa;
  --win-line: rgb(0 0 0 / .08); --win-sel: #2457e0;
}
@media (prefers-color-scheme: dark) {
  :root {
    /* worst: text 15.8:1, text-2 6.84:1, accent 7.7:1; white on button 5.09:1, on hover 6.23:1 */
    --bg: #0b0d12; --bg-alt: #111419; --card: #171a21;       /* graphite, not navy: crafted, not "SaaS dark" */
    --text: #f2f4f8; --text-2: #9aa3b2; --accent: #86abff;
    --button: #3563ea; --button-hover: #2b55d6;
    --line: #262b35; --header: rgb(17 20 25 / .72); --hi: rgb(255 255 255 / .06); --ink: 0 0 0;
    --ok: #30d158; --warn: #ff9f0a; --bad: #ff453a;
    /* The same sky at night: ink-blue, a violet horizon, faint cloud banks. */
    --wp-1: #04070f; --wp-2: #0b1a45; --wp-3: #1f3c8f; --wp-4: #3a2c6e;
    --wp-hi: rgb(90 130 255 / .35); --wp-cloud: rgb(150 170 255 / .14); --wp-glow: rgb(170 120 255 / .35);
    --wp-ink: 0 0 0; --glass-lite: rgb(40 42 48 / .82); --menubar: rgb(0 0 0 / .28);
    --cap-top: #1d212a; --cap-bot: #171a22;
    --cap: inset 0 1px 0 rgb(255 255 255 / .07), 0 0 0 1px rgb(255 255 255 / .09), 0 6px 16px -8px rgb(0 0 0 / .7);
    --z1: 0 0 0 1px rgb(255 255 255 / .07), 0 1px 2px rgb(0 0 0 / .5);
    --z2: inset 0 1px 0 var(--hi), 0 0 0 1px rgb(255 255 255 / .08), 0 12px 28px -12px rgb(0 0 0 / .7);
    --shadow: 0 0 0 1px rgb(255 255 255 / .1), 0 24px 48px -16px rgb(0 0 0 / .7), 0 64px 128px -32px rgb(0 0 0 / .8);
    --glare: rgb(255 255 255 / .08);
    --grain: /* 6% */;
    --win-bg: #1e1f22; --win-side: #26272b; --win-group: #2a2b2f; --win-row-alt: #232427;
    --win-line: rgb(255 255 255 / .08); --win-sel: #3563ea;
  }
}
```

`layout.html`: `theme-color` becomes `#f4f6f9` and `#0b0d12`; add the font preload (§2.2).

### 4.2 Home page, section by section (11 blocks, down from 13)

1. **Header pill** (§2.5): 22px icon and wordmark; How it works, Safety, FAQ at 14px/500 `--text-2`; a secondary
   key-cap "Source" and a 36px primary "Download".
2. **Hero** (§4.3): centered copy, then the desktop diorama.
3. **Proof strip**, hairlines only: "0 bytes · of file contents read", "SHA-256 · on every backup copy",
   "1 at a time · retries, each re-checked", "1 server · its update feed". Numerals in display 600.
4. **"Finder shows a status. Whydunit tells you why."** `.sec-head` left; right, a 320px-tall wallpaper tile
   (18px radius) holding a Finder list row (file glyph, name, dotted cloud, "Waiting to upload") with the Whydunit
   finding card overlapping it by −30px, 10% to the right, `--shadow`, `data-tilt` 7°.
5. **How it works.** Four key-cap numerals (44px, 12px radius, `--cap-top`/`--cap-bot`, `--cap`, display 600 17px)
   on a 1px hairline rail that fades at both ends. The coin-turn reveal stays (MOTION §2.4). Copy unchanged.
6. **Three fixes** (sticky stacking cards, tops 88/102/116px, the mechanism unchanged). Each card: white, 28px
   radius, 10px padding, `--z2`; media on 7 of 12 columns: a wallpaper well (§4.1 gradient, 18px radius, always the
   brand world) holding the existing `.sheet` replica with `--shadow-win`; text on 5 of 12: a mono index "01", the
   feature title in display, one paragraph, one 13px mono guarantee line with a green 6px dot ("Stops at the first
   SHA-256 mismatch", "One item at a time, backup first", "Only after you say yes"). The covered card dims to
   `opacity .6` through `animation-timeline: view()` only where supported and without reduced motion. Delete the
   icon wells in the text column.
7. **Safety: "Built to never lose a file."** Two columns, 5 and 7. Left: sticky head and lede, then a mono receipt
   card (`--bg-alt`, 12px radius): "CI fails any build whose code calls `removeItem`, `unlink`, `rmdir` or `rm`."
   (true: CI checks the first three safety rules; copy owner confirms wording). Right: the 6-rule `.rules` ledger,
   each with a trailing mono chip: `trashItem`, `read-only`, `SHA-256`, `1 feed`, `activity log`, `no telemetry`.
   This replaces the 6 icon cards and the "Free" card.
8. **Real screens.** The `.film` strip (§2.5, §2.6): Summary, a finding page, the Back Up sheet; `tabindex="0"`,
   `aria-label="Screenshots"`. Caption: "Real screens, captured by CI from the app with sample data."
9. **FAQ.** Sticky head left (5), the grouped `.faq-list` right (7). "Is it really free?" absorbs the old Free card.
10. **Finale.** A 28px-radius wallpaper panel, 72px top padding: the 128px icon with the floor reflection and the
    existing 12° pointer tilt, "See what's stuck. It's free." in display, the primary button and the trust line.
11. **Footer.** The `--bg-alt` slab, a 0.5px ink hairline on top, columns unchanged, the version in mono, and the
    official line: "The only official sources are <baseURL> and github.com/EverydayOpen/whydunit releases. Builds are
    Developer ID signed and notarized."

### 4.3 Hero: the desktop diorama (the 3D product scene)

**Copy stack** (nothing here moves, MOTION §1.1 rule 1): kicker pill; h1 (display ladder, second clause `.dim`,
copy unchanged); lede (max 34em); the CTA row (primary key-cap "Download free" with the download glyph and the
hairline `.sep`, secondary "View source"); trust line 13px: "Free · No account · macOS 15 or later · Apple silicon
and Intel · Signed and notarized".

**DOM.** `.stage.daylight` is up to 1240px wide, 28px radius, 48px below the trust line. The `.window` figure and
its `.win-*` markup stay; the cloud, docs, check and ghost are deleted; the menu bar, Finder and notification are
added. The replica copy is Demo.swift's sample (10 items, 2.1 GB, 4,213 checked, 4 need attention), as in the CI
capture.

```html
<div class="stage daylight" data-tilt>
  <p class="menubar" aria-hidden="true"><b>Whydunit</b> File Edit View Window Help <span>Tue 9:41</span></p>
  <div class="scene">
    <figure class="finder" aria-hidden="true">…a small Finder window: 4 rows, each with a dotted cloud and "Waiting to upload"…</figure>
    <figure class="window" role="img" aria-label="…unchanged…">…the Tahoe replica of Summary (§4.4)…</figure>
    <p class="note" aria-hidden="true"><img src="/icon.png" width="32" height="32" alt=""><b>Whydunit</b><time>now</time><span>10 copies verified with SHA-256</span></p>
  </div>
</div>
<p class="caption">Illustration with sample data</p>
```

**Planes**, back to front, in one `perspective: var(--persp-scene)` (MOTION §1.2):

| Plane | Z | What it is |
|---|---|---|
| Wallpaper | still, outside the scene | `::before` covers `inset: 0 0 16%`, so the window's lower 16% hangs off the wallpaper onto paper: the depth cue a flat frame can't give. The 28px `.menubar` (`--menubar`, white 13px/500, no Apple mark) sits on it. |
| Finder window | −120px | Left 2%, top 16%, 38% wide. The problem. |
| Whydunit window | 0 | The Tahoe replica, centered, `--shadow-win`. The diagnosis. |
| Notification | +110px | Top right, 340×72, 18px radius, `--glass-lite` with a rim and a top highlight, exactly where macOS puts banners. The safe fix. |

```css
.stage.daylight { position: relative; margin: 48px auto 0; max-width: 1240px; padding: 44px 5% 0; perspective: var(--persp-scene); perspective-origin: 50% 20%; }
.stage.daylight::before { content: ""; position: absolute; z-index: -2; inset: 0 0 16%; border-radius: var(--r-xl);
  background: var(--grain),
    radial-gradient(70% 45% at 50% 108%, var(--wp-glow), transparent 70%),        /* the key light: a dawn horizon */
    radial-gradient(38% 22% at 14% 96%, var(--wp-cloud), transparent 72%),
    radial-gradient(44% 26% at 52% 104%, var(--wp-cloud), transparent 72%),
    radial-gradient(34% 20% at 88% 98%, var(--wp-cloud), transparent 72%),
    radial-gradient(60% 50% at 82% -8%, var(--wp-hi), transparent 65%),
    linear-gradient(176deg, var(--wp-1), var(--wp-2) 42%, var(--wp-3) 74%, var(--wp-4));
  box-shadow: inset 0 0 0 .5px rgb(var(--ink) / .2), inset 0 1px 0 rgb(255 255 255 / .25); }
.menubar { position: absolute; inset: 0 0 auto; height: 28px; margin: 0; padding: 0 16px; display: flex; gap: 18px; align-items: center;
  border-radius: var(--r-xl) var(--r-xl) 0 0; background: var(--menubar); color: #fff; font: 500 13px/1 var(--font); }
.menubar span { margin-left: auto; }
.scene { position: relative; transform-style: preserve-3d; }
.finder { position: absolute; left: 2%; top: 16%; width: 38%; margin: 0; transform: translateZ(-120px); }
.note { position: absolute; right: 3%; top: 9%; width: 340px; display: grid; grid-template-columns: 32px 1fr auto; gap: 2px 10px;
  margin: 0; padding: 12px 14px; border-radius: 18px; background: var(--glass-lite); font-size: 13px; transform: translateZ(110px);
  box-shadow: inset 0 1px 0 var(--hi), 0 0 0 .5px rgb(var(--ink) / .18), 0 14px 32px -10px rgb(var(--wp-ink) / .4); }
.window { box-shadow: var(--shadow-win); }
@media (max-width: 720px) { .finder, .note, .menubar { display: none; } .stage.daylight::before { inset: 0; } }
@media (prefers-reduced-motion: no-preference) {
  .window { animation: surface var(--t-hero) var(--ease-out) .1s backwards; }          /* existing keyframes, MOTION §2.3 */
  .finder { animation: drift .9s var(--ease-out) .3s backwards; }
  .note   { animation: notify .7s var(--ease-spring) 1.3s backwards; }
}
@keyframes drift  { from { opacity: 0; transform: translate3d(-40px, 20px, -160px); } }
@keyframes notify { from { opacity: 0; transform: translate3d(60px, 0, 110px); } }
```

**Scaling.** At 720px and wider the stage scales with stepped `zoom` so replica text rescales sharply instead of
blurring: `.stage { zoom: .86 }` below 1180px, `.72` below 1000px, `.6` below 860px (VERIFY `zoom` with
`perspective` in Safari and Firefox 126+). Below 720px keep today's one-column collapse (sidebar hidden, zoom 1).

**Sequence** (2.0 s, once, then still; replaces MOTION §2.1):

| t (s) | What happens | Element | Easing |
|---|---|---|---|
| 0.10–1.20 | The window rises from `translate3d(0, 60px, -120px) rotateX(24deg)` and settles flat | `.window` | `--ease-out` |
| 0.30–1.20 | Finder drifts in from back-left | `.finder` | `--ease-out` |
| 1.30–2.00 | The notification slides in from the right, as a macOS banner does | `.note` | `--ease-spring` |

After 2.0 s the scene is still. Pointer tilt up to 5° (`data-tilt`, MOTION §1.3); phones settle on scroll. The rest
state is the final state, so Reduce Motion, print and no-JS show exactly it. The tagline stays the LCP.

**Delete:** `.sky`, `.cloud`, `.cloud-ok`, `.doc`, `.ghost`, `.chip*`, the `upload` keyframes and the cloud
`<symbol>`s.

### 4.4 The window replica (the Mac object in the diorama and the fixes wells)

Drawn at 1:1 point size for macOS 26 proportions, from the existing `.win-*` markup restyled through the `--win-*`
tokens: a 1040px-wide window with an 18px radius; the sidebar as an inset panel (8px margin, 12px radius) with the
traffic lights inside it; a toolbar with no fill (15px/600 title, 11px subtitle, trailing icon buttons in one 32px
capsule); 13px system text; sidebar rows with a category symbol (no filled tiles, §5.2) and a trailing count;
`.tag`s as they are; the verdict plate and the findings list as §5.2 draws them. **Acceptance:** it must match the
CI capture of the redesigned Summary side by side.

### 4.5 Sub-pages

Download, guides, changelog, support, privacy, terms and 404 inherit the tokens, type and header.

- **Download:** the finale panel (`.mini`, 240px tall) with the icon on the floor reflection, the h1, the button,
  the requirements line, three key-cap steps (Open the DMG · Drag to Applications · Open the app) and the official
  line.
- **Changelog:** release cards (`.card`) with a 2px accent rail on the left and the version in a mono tag.
- **Guides, support, privacy, terms:** the reading layout (`.read`, prose 17px/1.6) on paper. They stay still.
- **404:** the finale panel with one Finder-style file glyph on the wallpaper and "This page isn't here. Nothing
  was lost." (copy owner to confirm).

## 5. Whydunit app (macOS 15). Written, not compiled.

### 5.1 Window, chrome and the wash

- `NavigationSplitView`, the unified toolbar (Scan Again, Inspector, the finding page's `Back Up…`), the inspector,
  sheets and Settings are unchanged (BUILD_PLAN §6).
- `DetailView` adds `.toolbarBackground(.hidden, for: .windowToolbar)` so `Sky` runs under the toolbar, as in Music
  and Photos (VERIFY on macOS 15; on 26 the SDK's scroll-edge effect keeps the title legible).
- **`Sky`** (`Tokens.swift`, existing) grows: the wash to 320pt, plus a top-center sun:

```swift
if contrast != .increased {
    LinearGradient(colors: [Color.accentColor.opacity(scheme == .dark ? 0.16 : 0.09), .clear], startPoint: .top, endPoint: .bottom).frame(height: 320)
    RadialGradient(colors: [.white.opacity(scheme == .dark ? 0.06 : 0.6), .clear], center: .top, startRadius: 0, endRadius: 420)
}
```

- **Sidebar, the end of the orange wall.** Rows show a category SF Symbol, not a filled tile: `.orange` or `.red`
  only for warning and critical findings, `.secondary` for info, Summary is `icloud` in the accent. Keep the native
  `.badge(count)`. The row's accessibility label leads with the severity word. `extension RuleID { var symbol:
  String }` in `Tokens.swift` (VERIFY each in the SF Symbols app for macOS 15):

  | RuleID | Symbol | RuleID | Symbol |
  |---|---|---|---|
  | `onlyOnThisMac` | `laptopcomputer` | `storageDebt` | `internaldrive` |
  | `syncStalled` | `clock.badge.exclamationmark` | `developerFolders` | `hammer` |
  | `storageFull` | `externaldrive.badge.exclamationmark` | `relocatedFiles` | `folder.badge.questionmark` |
  | `serverUnreachable` | `icloud.slash` | `excludedByDesign` | `minus.circle` |
  | `uploadRejected` | `exclamationmark.icloud` | `unreadableFolders` | `folder.badge.minus` |
  | `stuckItems` | `icloud.and.arrow.up` | `permissionDenied` | `lock.shield` |
  | `lockFlags` | `lock.doc` | `tooLarge` | `scalemass` |
  | `conflicts` | `doc.on.doc` | History: Backups `clock.arrow.circlepath`, Activity `list.bullet.rectangle`, both `.secondary` |

- **No empty sidebar.** `NavigationSplitView(columnVisibility:)` with view `@State` in `MainView`: `.detailOnly`
  until the first diagnosis arrives, then `.all` with `Motion.spring`. Not in `AppStore`.

### 5.2 Screens

**Welcome.** A 480pt column centered at 45% height over the taller `Sky`:
1. `OnFloor(height: 128) { Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 128, height: 128) }`
   with MOTION §3.2's entrance and `HoverTilt(max: 8, glare: true)` on the whole `OnFloor`, so the reflection
   follows the tilt.
2. The headline at 30pt semibold, `tracking(-0.6)` (copy unchanged).
3. The privacy line, `.callout` secondary, max 440pt.
4. "Scan iCloud Drive": `.borderedProminent`, `.buttonBorderShape(.capsule)`, `.controlSize(.extraLarge)`.
5. The three trust `Label`s in `.caption.weight(.medium)` secondary, as now.

**First scan.** `ScanGlyph` (the only loop, MOTION §3.3) over `Sky` at 72pt, hierarchical `.tint`; the linear
`ProgressView` 280pt wide; the count in `.system(.callout, design: .rounded).monospacedDigit()`.

**Summary.** The `Form` becomes `ScrollView { VStack(spacing: Space.l) }` at `frame(maxWidth: 760)`, on `Sky`.
1. **Verdict plate** (`.surface(18)`, the one lifted object; `flipIn` as MOTION §3.4): top row
   `SeverityIcon(tile: true, size: 52)`, the title at 22pt semibold `tracking(-0.3)`, the meta line in secondary
   `monospacedDigit`, Copy Diagnosis trailing as `.bordered` small; a 0.5pt hairline; then a 3-column row of
   `Metric`s separated by vertical hairlines: `Metric("Checked", "4,213")`, `Metric("Need attention", "4", dot:
   .orange)`, `Metric("Only on this Mac", "2.1", unit: "GB")`. Values always `.primary`.
2. **Findings in two surfaces:** small-caps headers "Needs attention" (warning and critical) and "Good to know"
   (info). View-level grouping; the data flow is unchanged. Rows (≥ 52pt) separated by 0.5pt hairlines inset 56pt:
   a 28pt neutral `well` with the rule's symbol in the severity tint; the title 13pt semibold; the explanation 12pt
   secondary with `lineLimit(2)` and `.fixedSize(horizontal: false, vertical: true)`, never cut mid-word (copy
   owner: first sentence under 2 lines at 700pt); trailing `Tag(count, tint: severity.color)` and a chevron.
   `FindingRow`'s hover and flip-in are unchanged.
3. **iCloud Drive facts** as one more `.surface(16)` of `LabeledContent` rows, values `.monospacedDigit()`.

**Finding page.** Header over `Sky`: a 44pt symbol `well`, the title at 22pt semibold, the explanation (max 620pt),
"What to try" as numbered rows (20pt accent-tinted circles, text primary), then the action row: one
`.borderedProminent` capsule, the rest `.bordered` capsules. The `Table` stays untouched (MOTION §3.6) apart from the
Status column's `Tag` and mono Size and Modified. `Back Up…` stays in the toolbar with its shortcut.

**Inspector.** Native. Section headers small-caps with a trailing borderless Copy; values
`.system(.callout, design: .monospaced)`, selectable.

**Sheets** (Back Up, Retry Upload, Restart iCloud Sync). Keep `SheetHeader` and `cardSwap`. `ItemList` keeps its
`List` but gets `.listStyle(.plain)`, `.scrollContentBackground(.hidden)` and `.surface(12)`; each row gains a 20pt
file-type icon from `NSWorkspace.shared.icon(for: UTType(filenameExtension: ext) ?? .data)`, which never touches
the file. The preflight block: green `checkmark.circle.fill` rows with mono facts on `Color.primary.opacity(0.04)`
at 12pt radius. Capsule buttons, step dots top right, Done shows `checkmark.seal.fill` 40pt with one bounce (none
under Reduce Motion) and `Tag("SHA-256", tint: .green)`.

**Backups.** A native list; rows: folder glyph, the date in mono, `Tag("Verified · 14 items", tint: .green)`, Show
in Finder.

**Activity.** A timeline in a `LazyVStack`: a 64pt mono time column, a 1pt `.separator` rail, an 8pt dot per event
kind, the text; days grouped under small-caps headers.

**Empty and error states.** `ContentUnavailableView` over `Sky`: a hierarchical `.tint` symbol, one sentence, one
capsule action. Settings stays stock.

**Dark mode.** `Sky` at 16%; surfaces white .055 with a white .10 rim; shadows black .5; sidebar symbols keep their
tints. Increase Contrast gives the plain window and 1pt primary strokes.

## 6. Icon and social image (release owner: `tools/make_icon.py`, `tools/make_og.py`, stdlib SDF renderers)

- **Icon: unchanged for now.** The blue squircle with the frosted cloud and lens reads correctly at every size in
  the CI captures. Later, on a Mac: a macOS 26 Icon Composer `.icon` with three layers (blue, cloud, lens) and
  specular on the cloud (VERIFY).
- **OG image (1200×630):** the diorama's wallpaper edge to edge, the icon at 280px standing on the dawn horizon
  with its reflection on the floor, and the wordmark under it. No sentence in the image; `og:title` carries it.

## 7. What to delete from the current look

- The sky-in-a-box hero: `.sky`, `.cloud`, `.cloud-ok`, `.doc`, `.ghost`, `.chip*`, the `upload` keyframes, the
  pale flat gradient (`--sky-*`, `--cloud`, `--haze`, `--orb-*`).
- Weight 700 on every heading; the flat blue step orbs; the pale accent icon wells on marketing cards; the 6-card
  safety grid; the pricing-style "Free" card; the boxed proof strip; the stack of FAQ cards; the two-tone h2 on
  every single section.
- The untinted grey shadow; the banded sections and `section:not(.band) .card`.
- In the app: the filled orange tiles on every sidebar and finding row; the empty Welcome sidebar; the grey grouped
  `Form` cells; explanations cut mid-sentence; the icon floating in a blue blur.

## 8. Acceptance and budgets

**Looks premium (a judge checks light and dark captures at 1440 and 390px against `refs/`):**

- [ ] Headlines render in Inter Display on Windows Chromium with no shift when it arrives; weight 600, tight tracking.
- [ ] The hero diorama: the wallpaper has a deep top, a dawn horizon and clouds; the window stands out with a soft
      tinted shadow and hangs off the wallpaper onto paper; Finder is behind, the notification in front; the menu bar
      reads as macOS; everything is still after 2 s; the copy matches the CI capture side by side.
- [ ] No section uses a pale accent icon well; the safety section is a ledger; the FAQ is one grouped panel.
- [ ] Every raised surface shows a lit top edge, a 0.5px hairline (1px rim in dark) and an ink-tinted shadow.
- [ ] Real screens appear only at ≤ 50% of their pixel width, in a strip that scrolls inside itself; no horizontal
      page scroll at 360px (`scrollWidth === 360`).
- [ ] The finale icon stands on a reflection (Chrome and Safari).
- [ ] With Reduce Motion, no JS and print, the page shows the final state; print is dark text on white (§2.7 fix).
- [ ] `python tools/build_site.py --check` passes with exactly two `:root` blocks and no `style=""`.
- [ ] App, from CI captures: no orange wall in the sidebar or findings; no truncated explanation; Welcome has no
      empty sidebar; no grey grouped cell on the wash; the verdict plate is one porcelain object; the icon stands on
      a floor; VoiceOver labels and traits are unchanged.

**Budgets:**

| Item | Cap |
|---|---|
| `styles.css` | 40 KB (checker cap; 38 KB today: the deletions in §7 pay for the additions; VERIFY with `wc -c`) |
| `motion.js` | unchanged, ≤ 5 KB, byte-identical in both repos |
| Font | one woff2 ≤ 32 KB, byte-identical in both repos |
| Home HTML (built) | ≤ 36 KB (the replica adds markup) |
| First load (HTML + CSS + JS + font + icon + favicon) | ≤ 150 KB |
| Lazy screenshots | ≤ 110 KB each, 3 per scheme, only the active scheme loads |
| Third-party requests, CDNs, trackers | 0 |
| Hero sequence | ≤ 2.0 s, once; ≤ 4 planes |
| CLS / LCP | 0 / the h1 text |
| App CPU after entrance | 0% within 2 s; `HoverTilt` ≤ 8 on screen; new assets or dependencies: none |

**Security.** Nothing here touches the safety rules, `Process`, the entitlements, the Sparkle feed or the data
flow. The CSP stays as it is (same-origin fonts are already allowed). Glass and materials are system APIs.

## 9. Changes for other owners, decisions for the lead, VERIFY list

**By owner (proposed, not made):**

- **Site owner (`site/**`):** §2 and §4, the font file plus `OFL.txt`, the `layout.html` preload and theme-color,
  the §2.7 `html[lang]` fix.
- **App-views owner (`App/DesignSystem`, `App/Views`, `App/Sheets`):** §3 and §5. `columnVisibility` lives in
  `MainView`. Nothing touches `AppStore`, the safety rules or the copy.
- **Tools owner (`tools/build_site.py`):** rewrite and link-check `srcset="/`; add size caps to `--check` for
  `styles.css` (40 KB), `motion.js` (5 KB), `fonts/*.woff2` (32 KB) and `shots/*` (110 KB).
- **CI owner (`screens.yml`):** a `-o` no-shadow capture per screen plus `sips` conversion into `shots/`.
- **Release owner:** the OG image (§6).
- **Copy owner:** the trust line, the CI receipt wording, finding explanations under 2 lines, the notification and
  404 text.
- **BUILD_PLAN §6:** amend "No custom glass. No card backgrounds on content." to "Content sits on opaque porcelain
  surfaces (DESIGN.md §3.1); glass only where the macOS 26 SDK draws it."
- **MOTION.md:** record §2.8's table (the diorama sequence replaces §2.1; the notification and key-cap sink are new).

**Decisions for the lead:** (1) confirm the webfont (reverses "zero bytes"); (2) confirm real screenshots on the
site; (3) confirm porcelain content surfaces as the BUILD_PLAN amendment above.

**VERIFY (on a Mac or in Safari):** `toolbarBackground(.hidden, for: .windowToolbar)`; `.controlSize(.extraLarge)`
on macOS 15; every SF Symbol in §5.1; `Font.smallCaps()` with SF; `OnFloor`'s shadow offset and the reflection;
`HoverTilt` signs; CSS `zoom` with `perspective` in Safari and Firefox 126+; `-webkit-box-reflect` inside a 3D
parent; `sips formatOptions` syntax and WebP support on the runner; `screencapture -o -l`; the JPEG corner radius
at half scale; the Inter Display subset size; `font-display: optional` with preload in Safari; the diorama's plane
sorting in real Safari.
