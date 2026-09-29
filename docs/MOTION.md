# Motion spec: Whydunit (website and app)

**Why:** the owner's requirement (2026-09-28): a modern UI with 3D animation that stays lightweight, for the website
and the app, in both EverydayOpen apps.
**Authority:** this file is authoritative for motion. It overrides BUILD_PLAN §6's "No pulsing" and UI_SPEC §2.8's
motion table where they conflict. Everything else in BUILD_PLAN is unchanged: safety rules, copy, data flow, system
components, no glass, no card backgrounds on content.
**Shared system:** §1 is identical in the Tirekick repo's `docs/MOTION.md`; change both together. This file covers
§1, §2 (website), §3 (app) and §6 (budgets and acceptance). Tirekick's copy has §4 and §5.
**Status:**
- The website code (§1.7, §2) was prototype-tested in Chromium on Windows against a copy of `site/`:
  - `build_site.py --check` found 0 errors;
  - no horizontal scroll at 360px;
  - no layout shift from the page;
  - LCP is the static tagline.
- The website code hasn't been run in Safari or Firefox yet.
- The Swift (§1.8, §3) is written, not compiled.

## 1. The EverydayOpen motion language (shared, identical in both repos)

### 1.0 What makes 3D feel premium and still light (research, 2026-09-28)

- **Only the object moves.** Apple's product pages keep headlines, prices and buttons still. The product and the
  depth around it do the moving, and the hero plays once and then stops.
- **One camera, a few planes.** Linear and Raycast get depth from 2 to 4 flat layers at different Z, turned a few
  degrees in one perspective. They never build a full 3D model. Flat layers are cheap and keep text sharp.
- **Physical, damped, quick.** Things and Arc use short springs with a little overshoot for small objects and none
  for big surfaces. Nothing floats for more than about a second.
- **Light follows the pointer.** macOS Tahoe's Liquid Glass puts specular highlights where you move, and Reduce Motion
  turns that parallax off. Here that becomes glare under the pointer plus shadows that don't move.
- **The platform does the heavy lifting.** CSS 3D transforms and scroll-driven animations run on the compositor.
  Safari 26 shipped scroll-driven animations, and Safari 26.4 moved them to the compositor thread. Firefox stable
  still hides them behind a flag (mid-2026), so it gets a small IntersectionObserver fallback. In SwiftUI,
  `rotation3DEffect`, springs and transitions cover everything here without SceneKit or Metal.
- **Trust tools animate facts calmly.** Motion never makes a verdict look scarier or more cheerful than it is.

### 1.1 Principles (rules, not taste)

1. **Text never waits.** Hero headlines, taglines, verdicts, numbers and buttons render still, at once. Below the
   fold, a block can rise in as it enters the viewport, and it is done by the time 75% of it is visible.
2. **One hero moment per surface, then stillness.** Every sequence ends: at most 3.2 s on the web and 1 s in the
   apps. The only loops are a progress indicator that runs while real work runs (a scan, the checks).
3. **Motion never encodes severity.** A red "Walk away" arrives exactly like a green "Clean". Nothing shakes, flashes
   or pulses to alarm.
4. **Depth follows light.** A surface turns to face the pointer: the edge under the pointer recedes. The glare sits
   under the pointer. Shadows are fixed per layer and move only with their surface.
5. **Physical and quick.** Surfaces use springs with bounce ≤ 0.25. Small glyphs use ≤ 0.4. Nothing lasts longer
   than 1.1 s except the one-time hero sequence.
6. **Reduce Motion means no movement.** The end state is the same, reached by at most a 150–200 ms fade. No tilt, no
   parallax, no flip: a flip becomes a crossfade or an instant swap.
7. **Compositor only.** The web animates `transform`, `translate`, `rotate`, `scale` and `opacity`. The apps animate
   geometry effects and opacity, never frames or padding, during 3D motion.

### 1.2 Tokens

**Depth.** The web shares one real perspective per scene. SwiftUI has no shared 3D space, so each view gets its own
`perspective:` (1 is the default; lower is flatter). The table's mapping is approximate: VERIFY on a Mac and tune by
eye.

| Token | CSS | SwiftUI `perspective:` | Use |
|---|---|---|---|
| scene | `--persp-scene: 1600px` | 0.4–0.5 | hero scenes, grids, the report card, the laptop |
| card | `--persp-card: 900px` | 0.6 | cards, tiles, rows, FAQ answers |
| glyph | `perspective(400px)` inline | 1.0 (default) | icons, step numbers, keys |

| Z layer | CSS `translateZ` | SwiftUI stand-in | Shadow |
|---|---|---|---|
| back | −140 to −160px | smaller, behind in a ZStack | none |
| surface | 0 | the view itself | `--shadow` (z3) if it floats, none on a band |
| hug | +40 to +60px | offset ×1 of the tilt | `--z1`/`--z2` |
| float | +90px (max +140) | offset ×2 of the tilt | `--shadow` |

Use at most 4 layers in one scene.

**Easing and springs.**

| Token | CSS | SwiftUI (Whydunit, macOS 15) | SwiftUI (Tirekick, macOS 13) | Use |
|---|---|---|---|---|
| out | `--ease-out: cubic-bezier(.16, 1, .3, 1)` | `Motion.spring(_:)` = `.spring(duration: 0.45, bounce: 0.22)` | `.spring(response: 0.45, dampingFraction: 0.78)` | entrances, settling, tilt return, flips |
| hero | `--ease-out` over `--t-hero` | `Motion.hero` = `.spring(duration: 0.9, bounce: 0.2)` | `.spring(response: 0.9, dampingFraction: 0.8)` | one-time entrances (icon, lid) |
| spring | `--ease-spring: cubic-bezier(.34, 1.56, .64, 1)` | `Motion.pop` = `.spring(duration: 0.32, bounce: 0.38)` | `.spring(response: 0.32, dampingFraction: 0.62)` | chips, symbols, keys |
| follow | `var(--t-fast)` with `--ease-out` | `Motion.follow` = `.interactiveSpring(response: 0.25, dampingFraction: 0.86)` | same (macOS 10.15 API) | following the pointer |
| in-out | `--ease-in-out: cubic-bezier(.65, 0, .35, 1)` | `.easeInOut(duration:)` | same | beams, rising files |
| standard | none | `Motion.standard(_:)` (existing) | `Motion.standard(_:)` (existing) | plain state changes |

`.spring(duration:bounce:)` is macOS 14. With bounce ≥ 0 its damping fraction is 1 − bounce, so the Tirekick column
is the same curve.

**Durations.** `--t-fast .16s` (hover, press), `--t-base .32s` (state change, FAQ), `--t-slow .7s` (reveal, tilt
settle), `--t-hero 1.1s` (hero plane). **Stagger:** 90 ms between cards and 80 ms between report rows on the web.
In the apps, Whydunit rows use `Motion.stagger = 0.045` and Tirekick check rows keep their existing 70 ms. The
stagger index is capped (6 on the web, 8 in the apps), so a long list never trickles.

### 1.3 Hover tilt, glare and sheen

| Surface | Max tilt | Lift | Glare |
|---|---|---|---|
| Hero scene (window, laptop and card together) | 5° | none (it already floats) | only the report card |
| Cards and tiles | 7° | `scale 1.02` (web), press `0.97` | web yes, app no |
| App icon (Whydunit Welcome) | 12° | none | yes, masked to the icon |
| Laptop drawing (Tirekick Welcome) | 8° | none | no |
| Reading surface with long text (report card in the app) | 4° | none | yes |
| Tables, forms, lists, sidebars, buttons, navigation, keys | 0° | press depth only | no |

- **Direction.** `px` and `py` run from −1 to 1, measured from the center. CSS uses
  `rotateX(py × −max) rotateY(px × max)`, which was checked in Chromium: the edge under the pointer recedes. SwiftUI
  starts from the same formula; VERIFY the signs on a Mac.
- **Follow fast, settle slow.** Follow the pointer over 160 ms. Return over 700 ms (web) or with `Motion.spring`
  (app).
- **Fine pointers only.** Tilt needs `(hover: hover) and (pointer: fine)`; a Mac always qualifies. Phones get
  scroll-driven depth instead (§1.7).
- **Hit areas never move.** The web reads the pointer on the element and caches the box when the pointer enters. The
  app gets `onContinuousHover` coordinates in the untransformed layout frame.
- **Glare** is a soft radial spot under the pointer, about 60% of the surface wide, fading in over 160 ms. White
  can't shine on white, so light mode uses a faint accent spotlight (`rgb(0 102 204 / .07)`). Dark mode uses white
  at .10, and the app uses white at .28. On the web it is a 200% layer moved with `transform` and clipped by the
  card, drawn between the card's fill and its text, so it never repaints and never lowers text contrast.
- **Sheen** is a single linear highlight sweep. It is used only for the Tirekick scan beam, once.

### 1.4 Shadows that sell depth

- `--z1: 0 1px 2px rgb(0 0 0 / .06), 0 4px 12px rgb(0 0 0 / .05)`: hug layers and guide boxes.
- `--z2: 0 2px 6px rgb(0 0 0 / .06), 0 12px 32px rgb(0 0 0 / .1)`: small floating badges.
- `--shadow` (existing, z3): floating surfaces and chips.
- **Dark mode:** black backgrounds swallow shadows, so each shadow is darker and carries a 1px light rim
  (`0 0 0 1px rgb(255 255 255 / .06–.12)`) that draws the edge.
- **Never animate `box-shadow` or `filter`.** A shadow belongs to its layer. Depth changes come from moving the
  surface, and the shadow moves with it.
- **App:** use `.compositingGroup().shadow(...)` on anything that contains text, so glyphs don't get shadows of
  their own.

### 1.5 Reduce Motion

| Effect | With Reduce Motion |
|---|---|
| Hero sequence (web) | Nothing plays. The page shows the final state: lid open, files uploaded, rows filled, chips gone. |
| Pointer tilt, glare, parallax | Off (flat). |
| Scroll reveal, steps coin, phone scroll lean | Off: content is simply there. |
| FAQ unfold, button press scale | Off. `<details>` opens instantly. |
| Report card flip (web) | Instant swap by `visibility`. The button still works. |
| App entrances (icon, lid, card deal-in) | Shown at rest immediately, or a `Motion.standard(true)` fade. |
| Row flip-ins, split-flap verdict, sheet card swaps | `.opacity` transitions. |
| Scan loops (cloud glyph, laptop beam) | Not drawn. The system `ProgressView` stays. |
| Symbol effects | Removed (`.symbolEffectsRemoved(reduceMotion)` in Whydunit; Tirekick never triggers them). |

The web puts every movement inside `@media (prefers-reduced-motion: no-preference)`, so Reduce Motion needs no
override rules except the flip. The apps read `@Environment(\.accessibilityReduceMotion)` in every view that moves,
or go through `Motion.*(reduceMotion)`. VoiceOver labels, traits and element grouping never change.

### 1.6 Performance rules

**Web**

- Animate `transform`, `translate`, `rotate`, `scale` and `opacity`, plus the custom properties `--px` and `--py`
  that feed them. Never animate `box-shadow`, `filter`, `background-position`, size or position.
- **Grouping properties flatten 3D.** Never put `opacity < 1`, a non-visible `overflow`, `filter`, `clip-path`,
  `mask`, `mix-blend-mode`, `isolation` or `contain: paint` on an element that has
  `transform-style: preserve-3d`. Fade its children or its parent instead. The prototype follows this.
- No `backdrop-filter` inside a 3D scene (Safari draws it flat), and no permanent `will-change`: it wastes GPU memory
  and blurs text in Safari.
- Use `translate`/`rotate`/`scale` (the individual properties) for reveals and `transform` for tilt, so both can
  run on one card without fighting.
- At most one `requestAnimationFrame` per frame. `pointermove` listeners are passive. The box is read once per
  element entered.
- No infinite animations on the web.
- **CSS stays in `styles.css`.** `motion.js` is byte-identical in both repos (2.7 KB; hard cap 5 KB) and loads with
  `defer` from `layout.html`.
- **Two `:root` blocks only.** `tools/build_site.py` `contrast()` unpacks exactly two `:root { }` blocks, light then
  dark; a third one crashes `--check`. New tokens go into the existing two blocks. Any other override uses `html`
  or a class.
- `data-theme` and `localStorage` fail `--check`. Dark and light come from `prefers-color-scheme` only.

**Apps**

- **Zero CPU when idle.** Springs settle and stop. `repeatForever`, a `phaseAnimator` without a trigger, and
  `TimelineView` appear only inside views that exist only while work runs: Whydunit's first-scan view and Tirekick's
  "Checking this Mac…" view.
- Use only `.animation(_:value:)`, never unscoped `.animation`. Call `withAnimation` only in event handlers and
  `onAppear`.
- **3D on content only.** Never add 3D to a `Table` or `List` row container: AppKit owns the cell, its clipping and
  its selection.
- `ImageRenderer` paths get no effects inside the rendered view. Tirekick's `ReportCardView` is the PNG.
- No `drawingGroup()` over text: it rasterizes, and the text blurs at 3D angles.
- Hover state lives in the modifier (`@State`), never in `AppStore` or `AppModel`. Keep at most 8 `HoverTilt`
  views on screen at once; plain `onHover` rows are cheap and don't count.
- Written, not compiled: none of the Swift in this file has been built. Mark every API you can't confirm with
  `VERIFY`.

### 1.7 Shared web code (prototype-tested in Chromium on Windows, 2026-09-28)

**Tokens.** Append these to the **existing** light `:root` block:

```css
  /* Motion and depth (docs/MOTION.md §1). Only these two :root blocks: build_site.py contrast() reads exactly two. */
  --ease-out: cubic-bezier(.16, 1, .3, 1);
  --ease-spring: cubic-bezier(.34, 1.56, .64, 1);
  --ease-in-out: cubic-bezier(.65, 0, .35, 1);
  --t-fast: .16s;
  --t-base: .32s;
  --t-slow: .7s;
  --t-hero: 1.1s;
  --persp-scene: 1600px;
  --persp-card: 900px;
  --z1: 0 1px 2px rgb(0 0 0 / .06), 0 4px 12px rgb(0 0 0 / .05);
  --z2: 0 2px 6px rgb(0 0 0 / .06), 0 12px 32px rgb(0 0 0 / .1);
  --glare: rgb(0 102 204 / .07);   /* white can't shine on white: a faint accent spotlight instead */
```

Then append these to the existing dark `:root` block:

```css
    --z1: 0 0 0 1px rgb(255 255 255 / .06), 0 4px 12px rgb(0 0 0 / .5);
    --z2: 0 0 0 1px rgb(255 255 255 / .08), 0 12px 32px rgb(0 0 0 / .6);
    --glare: rgb(255 255 255 / .1);
```

**Shared rules.** Append these to `styles.css`, and delete the old
`@media (prefers-reduced-motion: no-preference) { .button { transition: background-color .2s; } }` line, which the
button rule below replaces. The block adds about 3 KB.

```css
/* Motion (docs/MOTION.md). Everything above is the finished, still page; movement only under no-preference.
   Animate transform, translate, rotate, scale and opacity only. Never opacity, overflow, filter or clip-path on a
   transform-style: preserve-3d element: they flatten its 3D. */
[data-tilt] { --px: 0; --py: 0; }
.stage { --tilt: 5deg; perspective: var(--persp-scene); }
.scene { position: relative; transform-style: preserve-3d; }
.grid { perspective: var(--persp-scene); }
.card[data-tilt] { --tilt: 7deg; position: relative; isolation: isolate; overflow: hidden; }
/* Glare: a 200% spotlight moved by transform (no repaint), between the card's fill and its text. */
.card[data-tilt]::after {
  content: ""; position: absolute; z-index: -1; inset: -50%; pointer-events: none; opacity: 0;
  background: radial-gradient(circle, var(--glare), transparent 30%);
  transform: translate(calc(var(--px) * 25%), calc(var(--py) * 25%));
}
@media (prefers-reduced-motion: no-preference) and (hover: hover) and (pointer: fine) {
  .scene, .card[data-tilt] {
    transform: rotateX(calc(var(--py) * var(--tilt) * -1)) rotateY(calc(var(--px) * var(--tilt)));
    transition: transform var(--t-slow) var(--ease-out), scale var(--t-base) var(--ease-out);
  }
  .tilting .scene, .card.tilting { transition-duration: var(--t-fast), var(--t-base); }   /* follow fast, settle slow */
  .card.tilting { scale: 1.02; }
  .card[data-tilt]::after { transition: opacity var(--t-base), transform var(--t-fast) linear; }
  .card.tilting::after { opacity: 1; }
}
/* Phones: no pointer, so the hero leans back and straightens as it scrolls into place. */
@media (prefers-reduced-motion: no-preference) and (hover: none) {
  @supports (animation-timeline: view()) {
    .scene { animation: settle linear both; animation-timeline: view(); animation-range: cover 0% cover 45%; }
  }
}
/* Reveal: scroll-driven where supported; motion.js adds .reveal-io and .in elsewhere. */
@media (prefers-reduced-motion: no-preference) {
  @supports (animation-timeline: view()) {
    .reveal { animation: rise linear both; animation-timeline: view(); animation-range: entry 0% entry 75%; }
  }
  .reveal-io .reveal:not(.in) { opacity: 0; }
  .reveal-io .reveal.in { animation: rise var(--t-slow) var(--ease-out) calc(var(--i, 0) * 90ms) backwards; }
  details[open] > p { animation: unfold var(--t-base) var(--ease-out); }
  summary::after { transition: rotate var(--t-base) var(--ease-out); }
  details[open] summary::after { rotate: 180deg; }
  .button { transition: background-color .2s, scale var(--t-fast) var(--ease-out); }
  .button:active { scale: .97; }
}
details { perspective: var(--persp-card); }
@keyframes settle { from { transform: rotateX(12deg) scale(.96); } }
@keyframes rise { from { opacity: 0; translate: 0 32px; rotate: x 10deg; } }
@keyframes unfold { from { opacity: 0; translate: 0 -6px; rotate: x -12deg; } }
@keyframes fade { from { opacity: 0; } }
@keyframes pop { from { opacity: 0; transform: translateZ(0) scale(.8); } }
```

**`site/static/motion.js`** is byte-identical in both repos and loads from `layout.html` right after the stylesheet
link: `<script src="/motion.js" defer></script>`. The build prefixes `src="/`, and `--check` confirms the file
exists. It has three jobs:

1. **Tilt.** Write `--px`/`--py` on the hovered `[data-tilt]` element and toggle `.tilting`. This happens only for
   a mouse, without Reduce Motion, throttled to one rAF per frame. It resets on scroll and when the pointer leaves
   the window.
2. **Reveal fallback.** Where `animation-timeline: view()` is unsupported (Firefox stable), add `.reveal-io` to
   `<html>` and give `.in` to each `.reveal` as it enters, staggered within each batch. Anything already on screen at
   load gets `.in` before the class goes on, so it never flashes.
3. **Flip.** Unhide each `[data-flip]` button and make it toggle `.flipped` on its `aria-controls` target, keeping
   `aria-pressed` in sync.

With no JS, the pages are complete and still. Hero sequences are pure CSS and need no JS.

```js
// Motion for the EverydayOpen sites (docs/MOTION.md). Every page is complete and static without it.
(() => {
  const root = document.documentElement;
  const calm = matchMedia('(prefers-reduced-motion: reduce)');
  const fine = matchMedia('(hover: hover) and (pointer: fine)');

  // Tilt: --px/--py (-1..1 from the center) on the hovered [data-tilt]; CSS turns them into rotation and glare.
  // The box is read once per element entered, so the tilt never feeds back into it.
  let el = null, box, x = 0, y = 0, frame = 0;
  const enter = (t) => {
    if (el) {
      el.classList.remove('tilting');
      el.style.removeProperty('--px');
      el.style.removeProperty('--py');
    }
    el = t;
    if (el) {
      el.classList.add('tilting');
      box = el.getBoundingClientRect();
    }
  };
  const unit = (v, start, size) => Math.max(-1, Math.min(1, (v - start) / size * 2 - 1)).toFixed(3);
  const draw = () => {
    frame = 0;
    if (!el) return;
    el.style.setProperty('--px', unit(x, box.left, box.width));
    el.style.setProperty('--py', unit(y, box.top, box.height));
  };
  addEventListener('pointermove', (e) => {
    if (e.pointerType !== 'mouse' || calm.matches || !fine.matches) return;
    const t = e.target.closest ? e.target.closest('[data-tilt]') : null;
    if (t !== el) enter(t);
    x = e.clientX;
    y = e.clientY;
    if (el && !frame) frame = requestAnimationFrame(draw);
  }, { passive: true });
  addEventListener('scroll', () => el && enter(null), { passive: true });
  root.addEventListener('pointerleave', () => enter(null));

  // Reveal, where CSS scroll-driven animations don't exist yet (Firefox): .in when it enters, staggered per batch.
  const items = document.querySelectorAll('.reveal');
  if (items.length && !calm.matches && !CSS.supports('animation-timeline: view()') && 'IntersectionObserver' in window) {
    const io = new IntersectionObserver((entries) => {
      entries.filter((e) => e.isIntersecting).forEach((e, n) => {
        e.target.style.setProperty('--i', Math.min(n, 6));
        e.target.classList.add('in');
        io.unobserve(e.target);
      });
    }, { rootMargin: '0px 0px -8% 0px' });
    items.forEach((e) => (e.getBoundingClientRect().top < innerHeight ? e.classList.add('in') : io.observe(e)));
    root.classList.add('reveal-io');
  }

  // Flip: a [data-flip] button turns the card named by aria-controls over and back.
  document.querySelectorAll('[data-flip]').forEach((b) => {
    const card = document.getElementById(b.getAttribute('aria-controls'));
    if (!card) return;
    b.hidden = false;
    b.addEventListener('click', () => b.setAttribute('aria-pressed', card.classList.toggle('flipped')));
  });
})();
```

### 1.8 Shared SwiftUI code (PROPOSAL, written, not compiled)

Both apps get the same pointer tilt, in `App/DesignSystem/Tokens.swift`. It uses only macOS 13 APIs:
`onContinuousHover` is macOS 13, and `rotation3DEffect`, `RadialGradient` and `mask` are older. **Whydunit** (macOS
15) replaces the `.background(GeometryReader …)` line with
`.onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }`, which avoids the one-argument `onChange`
that is deprecated from macOS 14.

```swift
/// Turns a surface to face the pointer (the edge under it recedes), at most `max` degrees, with an optional glare
/// masked to the content's own shape. Flat under Reduce Motion. The pointer is read in the layout frame, so the
/// tilt never moves hit areas.
struct HoverTilt: ViewModifier {
    var max = 7.0
    var glare = false
    @State private var size = CGSize.zero
    @State private var p = CGPoint.zero          // -1...1 from the center
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                if glare && hovering {
                    RadialGradient(colors: [.white.opacity(0.28), .clear], center: .center,
                                   startRadius: 0, endRadius: size.width * 0.6)
                        .offset(x: p.x * size.width / 2, y: p.y * size.height / 2)
                        .mask { content }            // VERIFY: content drawn twice; fine for an icon and one card
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            // VERIFY on a Mac: the edge under the pointer should recede; negate both angles if it rises instead.
            .rotation3DEffect(.degrees(-p.y * max), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .rotation3DEffect(.degrees(p.x * max), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .background(GeometryReader { g in
                Color.clear.onAppear { size = g.size }.onChange(of: g.size) { size = $0 }
            })
            .onContinuousHover { phase in
                guard !reduceMotion, size.width > 0, size.height > 0 else { return }
                switch phase {
                case .active(let at):
                    withAnimation(Motion.follow) {
                        hovering = true
                        p = CGPoint(x: at.x / size.width * 2 - 1, y: at.y / size.height * 2 - 1)
                    }
                case .ended:
                    withAnimation(Motion.spring(false)) {
                        hovering = false
                        p = .zero
                    }
                }
            }
    }
}
```

The `Motion` additions (`spring`, `hero`, `pop`, `follow`) are in each app's section, spelled for its deployment
target.

**Sources:** WebKit, "WebKit Features in Safari 26.0" (webkit.org/blog/17333) and "WebKit Features for Safari
26.4" (webkit.org/blog/17862); Firefox's `layout.css.scroll-driven-animations.enabled` flag status (mid-2026
developer guides); Apple docs for `onContinuousHover(coordinateSpace:perform:)` (macOS 13) and
`rotation3DEffect(_:axis:anchor:anchorZ:perspective:)`; SF Symbols 6 effects `wiggle`, `breathe` and `rotate`
(macOS 15; WWDC24 "What's new in SwiftUI"). `keyframeAnimator` is deliberately unused. Nobody has checked whether a
one-shot run rests on the last keyframe or on `initialValue`, and plain `@State` plus a spring does the same job on
every macOS version without that question.

## 2. Whydunit website

### 2.1 The story in 3 seconds

The app window rises and settles in front of a soft iCloud cloud. Three stuck files sit on the window's top edge,
each with an orange dot. One by one they turn and rise into the cloud, and a check lands on it. Two chips float in
front of the window: "12 files haven't uploaded" on the left and "Backup verified with SHA-256" on the right. After
that the page is still, and moving the pointer turns the whole scene up to 5°. The headline, tagline and Download
button never move.

| t (s) | What happens | Element | Easing |
|---|---|---|---|
| 0.10–1.20 | Window rises from `translate3d(0, 60px, -120px) rotateX(24deg)` with a fade | `.window` | `--ease-out` |
| 0.35–1.25 | Cloud fades in | `.cloud` | `--ease-out` |
| 0.80 / 0.95 | Chips pop forward to Z +90 / +60 | `.chip-l`, `.chip-r` | `--ease-spring` |
| 0.80–3.10 | Files appear on the edge, hold, then turn 160° and rise into the cloud (0.25 s apart) | `.doc` | `--ease-in-out` |
| 2.70–3.20 | Check pops onto the cloud | `.cloud-ok` | `--ease-spring` |

### 2.2 DOM (replaces the hero's second `.wrap`; the window `<figure>` itself is unchanged)

Add one symbol to the page's sprite:

```html
<symbol id="i-cloud-fill" viewBox="0 0 24 24"><path d="M7.2 18.5h10.3a4 4 0 0 0 .5-8A6 6 0 0 0 6.5 9.3a4.6 4.6 0 0 0 .7 9.2z"/></symbol>
```

```html
<div class="wrap">
  <!-- ILLUSTRATION: CSS drawing of the app window in a 3D scene (MOTION.md §2). Replace the window with a real screenshot once the app runs on a Mac. -->
  <div class="stage" data-tilt>
    <div class="scene">
      <div class="sky" aria-hidden="true">
        <svg class="cloud"><use href="#i-cloud-fill"/></svg>
        <span class="doc" style="--i:0"></span><span class="doc" style="--i:1"></span><span class="doc" style="--i:2"></span>
        <span class="cloud-ok"><svg><use href="#i-check"/></svg></span>
      </div>
      <figure class="window" role="img" aria-label="…unchanged…"> …unchanged… </figure>
      <p class="chip chip-l" aria-hidden="true"><svg><use href="#i-warn"/></svg>12 files haven't uploaded</p>
      <p class="chip chip-r" aria-hidden="true"><svg><use href="#i-check"/></svg>Backup verified with SHA-256</p>
    </div>
  </div>
  <p class="small muted center">Illustration with sample data</p>
</div>
```

- `.stage` holds the perspective and receives the pointer. `.scene` is the one element that tilts. The window,
  chips and sky are flat planes at different Z.
- The chips repeat the sample data (`aria-hidden`), so VoiceOver still reads only the figure's label. Chips are hidden
  at ≤ 640px, where they would cover the one-column window.
- Other page edits:
  - Problem and safety cards: `<div class="card reveal" data-tilt>`.
  - Each `.steps li`: `class="reveal"`.
  - The Free section card: `class="card reveal"` (no tilt; it holds a list).
  - FAQ, CTA, guide and legal pages: no markup changes. They get FAQ unfold and button press from the shared CSS.
- `layout.html`: add `<script src="/motion.js" defer></script>` after the stylesheet link.

### 2.3 CSS (append after the shared block in §1.7; about 2.9 KB)

```css
/* Hero scene (MOTION.md §2): the window floats in front of a cloud; stuck files rise into it, then it's still. */
.scene { padding-top: clamp(96px, 16vw, 170px); }
.stage .window { margin-top: 0; }
.sky { position: absolute; left: 50%; top: 0; width: min(80%, 420px); aspect-ratio: 2; translate: -50% 0; transform: translateZ(-160px) scale(1.1); transform-style: preserve-3d; pointer-events: none; }
.cloud { position: absolute; inset: 0; width: 100%; height: 100%; fill: var(--glare); }
.cloud-ok { position: absolute; left: 50%; top: 45%; display: grid; place-items: center; width: 44px; height: 44px; margin: -22px; border-radius: 50%; background: var(--card); color: var(--accent); box-shadow: var(--z2); }
.cloud-ok svg { width: 22px; height: 22px; }
.doc { position: absolute; bottom: 30%; left: calc(38% + var(--i) * 10%); width: 22px; height: 28px; border-radius: 4px; background: var(--card); box-shadow: var(--z1); opacity: 0; }
.doc::after { content: ""; position: absolute; top: 5px; right: 5px; width: 6px; height: 6px; border-radius: 50%; background: #ff9f0a; }
.chip { position: absolute; z-index: 1; display: flex; gap: 8px; align-items: center; margin: 0; padding: 10px 14px; border-radius: 12px; background: var(--card); color: var(--text); font-size: 13px; font-weight: 600; letter-spacing: 0; white-space: nowrap; box-shadow: var(--shadow); transform: translateZ(var(--z)); }
.chip svg { flex: none; width: 18px; height: 18px; color: var(--accent); }
.chip-l { --z: 90px; left: -20px; top: 78%; }
.chip-r { --z: 60px; right: 6%; bottom: -22px; }
@media (max-width: 640px) { .chip { display: none; } }
.steps { perspective: var(--persp-scene); }
.steps li { view-timeline: --step; }
@media (prefers-reduced-motion: no-preference) {
  .stage .window { animation: surface var(--t-hero) var(--ease-out) .1s backwards; }
  .cloud { animation: fade .9s var(--ease-out) .35s backwards; }
  .chip { animation: pop .6s var(--ease-spring) .8s backwards; }
  .chip-r { animation-delay: .95s; }
  .doc { animation: upload 1.8s var(--ease-in-out) calc(.8s + var(--i) * .25s) both; }
  .cloud-ok { animation: pop .5s var(--ease-spring) 2.7s backwards; }
  @supports (animation-timeline: view()) {
    .steps li::before { animation: coin linear both; animation-timeline: --step; animation-range: entry 20% entry 100%; }
  }
  .reveal-io .steps li.in::before { animation: coin var(--t-slow) var(--ease-out) calc(var(--i, 0) * 90ms + .15s) backwards; }
}
@keyframes surface { from { opacity: 0; transform: translate3d(0, 60px, -120px) rotateX(24deg); } }
@keyframes upload {
  0% { opacity: 0; transform: translateY(10px); }
  15%, 40% { opacity: 1; transform: none; }
  100% { opacity: 0; transform: translate3d(0, -110px, -60px) rotateY(160deg) scale(.55); }
}
@keyframes coin { from { opacity: 0; transform: perspective(400px) rotateY(-90deg); } }
```

Notes from the prototype:

- **Keep the files high.** `perspective-origin` is the stage's center, far below the sky, so things at negative Z are
  drawn lower on screen. At `bottom: 10%` the files hid behind the window; at 30% they sit on its edge.
- **Keep the chips off content.** `top: 58%` covered the sidebar's History rows. The left chip now sits over the
  sidebar's empty bottom, and the right chip hangs off the bottom edge.
- **Rest state is the final state.** The files are gone (opacity 0), the check is on the cloud and the window is flat
  and sharp. Reduce Motion, print and no-JS all show exactly that.
- **Dark mode needs no extra rules.** The cloud uses `--glare` (a faint accent in light mode, white at .10 in dark),
  and the chips use `--card`/`--text`, which `--check` already measures.

### 2.4 Sections

| Section | Motion | Why |
|---|---|---|
| Hero text and Download | none | It's the LCP (the tagline, about 0.48 s locally), and it's the promise. |
| Hero scene | §2.1 once, then pointer tilt (fine pointers) or scroll lean (phones) | the product moment |
| Sound familiar? (3 cards) | reveal (rise 32px, rotate X 10° → 0) plus 7° tilt, glare and scale 1.02 | quotes feel like cards you can pick up |
| How it works (4 steps) | reveal; each number turns in like a coin (rotate Y −90° → 0) | four calm steps, one at a time |
| Built to never lose a file (6 cards) | as Sound familiar | |
| Free (checklist card) | reveal only | a list is read, not handled |
| Questions | answer unfolds (fade, 6px, rotate X −12° → 0); "+" turns 180° into "−" | quiet feedback |
| CTA and buttons | press `scale .97` | depth under the finger |
| Guide, changelog, legal, support | only FAQ and button rules apply | reading pages stay still |

## 3. Whydunit app (macOS 15, SwiftUI)

This is PROPOSAL code: written, not compiled. The owner is app-views (`App/DesignSystem/*`, `App/Views/*` and the
three sheets). It doesn't touch `AppStore`, safety rules, copy or data flow. It overrides BUILD_PLAN §6's "No
pulsing" only for the first-scan glyph (§3.3). "No custom glass" and "no card backgrounds on content" stay as they
are.

### 3.1 Tokens (`App/DesignSystem/Tokens.swift`)

```swift
enum Motion {
    static func standard(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.15) : .smooth(duration: 0.28)
    }
    /// Surfaces: flips, card swaps, a tilt settling back.
    static func spring(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.15) : .spring(duration: 0.45, bounce: 0.22)
    }
    /// One-time entrances.
    static let hero = Animation.spring(duration: 0.9, bounce: 0.2)
    /// Small things landing: symbols, chevrons.
    static let pop = Animation.spring(duration: 0.32, bounce: 0.38)
    /// Following the pointer: quick, no overshoot.
    static let follow = Animation.interactiveSpring(response: 0.25, dampingFraction: 0.86)
    /// Between rows that arrive together.
    static let stagger = 0.045
}

extension View {
    /// Rows that arrive together turn down into place from their top edge, one `Motion.stagger` apart (index capped
    /// at 8). Opacity only under Reduce Motion.
    func flipIn(_ shown: Bool, index: Int, reduceMotion: Bool) -> some View {
        // VERIFY sign on a Mac: the bottom edge should start toward the viewer.
        rotation3DEffect(.degrees(shown || reduceMotion ? 0 : 70), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.6)
            .opacity(shown ? 1 : 0)
            .animation(Motion.spring(reduceMotion).delay(Double(min(index, 8)) * Motion.stagger), value: shown)
    }
}

extension AnyTransition {
    /// A sheet's steps: the old step turns away to the left, the new one turns in from the right.
    static func cardSwap(_ reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .modifier(active: Turn(angle: -28, anchor: .trailing, x: 40, opacity: 0), identity: Turn(anchor: .trailing)),
            removal: .modifier(active: Turn(angle: 28, anchor: .leading, x: -40, opacity: 0), identity: Turn(anchor: .leading)))
    }
}

private struct Turn: ViewModifier {
    var angle = 0.0
    var anchor: UnitPoint
    var x: CGFloat = 0
    var opacity = 1.0

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), anchor: anchor, perspective: 0.5)
            .offset(x: x)
            .opacity(opacity)
    }
}
```

`HoverTilt` from §1.8 goes in the same file, with `onGeometryChange` in place of the `GeometryReader` background.
Every API here is on macOS 15, and `spring(duration:bounce:)` needs macOS 14.

### 3.2 Welcome: the icon arrives in 3D, then follows the pointer

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
@State private var shown = false
…
Image(nsImage: NSApp.applicationIconImage)
    .resizable()
    .frame(width: 96, height: 96)
    .modifier(HoverTilt(max: 12, glare: true))     // glare masked to the icon's own shape
    .rotation3DEffect(.degrees(shown || reduceMotion ? 0 : 35), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
    .scaleEffect(shown || reduceMotion ? 1 : 0.85)
    .offset(y: shown || reduceMotion ? 0 : 16)
    .opacity(shown ? 1 : 0)
    .accessibilityHidden(true)
    .onAppear { withAnimation(reduceMotion ? Motion.standard(true) : Motion.hero) { shown = true } }
```

- The sentence, the privacy line and **Scan iCloud Drive** don't move (principle 1).
- There's no extra shadow: macOS icon art already has one.

### 3.3 First scan: a file turns as it rises into the cloud (`DetailView.scanning`)

Put this above the existing `ProgressView`. The linear bar, phase text and count stay, because they are the
accessible progress.

```swift
/// While the first scan runs: a document turns as it rises into the cloud. It exists only in the first-scan view,
/// so the loop stops with the scan. A still cloud under Reduce Motion.
private struct ScanGlyph: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private enum Rise: CaseIterable { case below, middle, inside }

    var body: some View {
        ZStack {
            Image(systemName: "icloud")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.tint)
            if !reduceMotion {
                Image(systemName: "doc.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .phaseAnimator(Rise.allCases) { doc, phase in
                        doc
                            .rotation3DEffect(.degrees(phase == .below ? 0 : phase == .middle ? 180 : 360), axis: (x: 0, y: 1, z: 0))
                            .offset(y: phase == .below ? 40 : phase == .middle ? 18 : 4)
                            .scaleEffect(phase == .inside ? 0.6 : 1)
                            .opacity(phase == .middle ? 1 : 0)
                    } animation: { phase in
                        phase == .below ? nil : .easeInOut(duration: 0.8)   // the jump back is invisible
                    }
            }
        }
        .frame(height: 96)
        .accessibilityHidden(true)
    }
}
```

- `phaseAnimator(_:content:animation:)` without a trigger loops. That is allowed only because this view exists only
  while `scanState` is `.scanning` on a first scan.
- Rescans keep the toolbar's small circular `ProgressView`, with no glyph.

### 3.4 Summary: the hero lands and the findings flip in once per scan

```swift
/// The scan whose rows have flipped in; coming back to Summary shows them at rest.
@MainActor private var flippedScan: Date?

struct SummaryView: View {
    …
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Bool

    init(diagnosis: Diagnosis) {
        self.diagnosis = diagnosis
        _shown = State(initialValue: flippedScan == diagnosis.scannedAt)
    }
    // Hero section content:
    //   HStack { SeverityIcon(severity: diagnosis.verdict, size: 28)
    //              .contentTransition(.symbolEffect(.replace))            // verdict changed on a rescan
    //              .symbolEffect(.bounce, value: diagnosis.scannedAt)     // a new result landed
    //              .symbolEffectsRemoved(reduceMotion)
    //            … } .flipIn(shown, index: 0, reduceMotion: reduceMotion)
    // Findings section:
    //   ForEach(Array(diagnosis.findings.enumerated()), id: \.element.id) { i, finding in
    //       Button { store.route = .finding(finding.rule) } label: { FindingRow(finding: finding) }
    //           .buttonStyle(.plain)
    //           .flipIn(shown, index: i + 1, reduceMotion: reduceMotion)
    //   }
    // On the Form:
    //   .onAppear { flippedScan = diagnosis.scannedAt; shown = true }
}
```

- The rows flip once, the first time a result is shown. Navigating back to Summary shows them at rest. A rescan while
  Summary is open keeps the rows still (BUILD_PLAN: rescans keep old results visible) and bounces the hero symbol once.
- The flip moves only the row's **content**; the `Form` row container is never transformed. VERIFY on a Mac that
  cells don't clip the first 70° badly. If they do, drop the angle to 40°.
- The "iCloud Drive" section (`LabeledContent`) doesn't move. It's reference data.

Hover depth on finding rows replaces "table row hover depth". The chevron slides and the icon lifts:

```swift
private struct FindingRow: View {
    let finding: Finding
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let lift = hovering && !reduceMotion
        HStack(spacing: Space.s) {
            SeverityIcon(severity: finding.severity, showsWord: false)
                .scaleEffect(lift ? 1.12 : 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(finding.title)
                Text(finding.explanation).font(.callout).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: Space.xs)
            Image(systemName: "chevron.right")
                .foregroundStyle(hovering ? .secondary : .tertiary)
                .offset(x: lift ? 3 : 0)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .onHover { h in withAnimation(Motion.follow) { hovering = h } }
    }
}
```

### 3.5 Sheets: steps swap like cards (Back Up, Retry Upload, Restart iCloud Sync)

Each step becomes one container, so it turns as a whole. The old and new steps overlap in a `ZStack`, so the sheet
doesn't grow during the swap:

```swift
var body: some View {
    ZStack(alignment: .topLeading) {
        switch phase {
        case .review: step { review }
        case .running: step { running }
        case .done(let manifest): step { done(manifest) }
        }
    }
    .padding(Space.l)
    .frame(width: 560, alignment: .leading)
    .animation(Motion.spring(reduceMotion), value: phase)     // was Motion.standard
    .interactiveDismissDisabled(phase == .running)
    …
}

/// One step as one card, so the swap turns it as a whole.
private func step<C: View>(@ViewBuilder _ content: () -> C) -> some View {
    VStack(alignment: .leading, spacing: Space.m, content: content)
        .transition(.cardSwap(reduceMotion))
}
```

- **RetryUploadSheet** does the same with `review`/`running`/`done`.
- **RestartSyncSheet** swaps on `result == nil`. It moves its `Text(title)` into both branches and adds
  `@Environment(\.accessibilityReduceMotion)`.
- Per-item rows inside a running step don't animate. Keyboard shortcuts, default and cancel actions, and
  `interactiveDismissDisabled` don't change.

### 3.6 What doesn't move, and why

- **Finding `Table` rows.** They're NSTableView-backed: AppKit owns the row, its clipping and its selection, and a
  finding can hold thousands of rows. Motion there would cost performance and fight native selection. The hover
  depth lives on Summary's finding rows instead (§3.4).
- **Sidebar, inspector, toolbar, Settings and Activity.** They stay system parts with system motion.
- **Scanned-ago text and counts.** They already use `.contentTransition` where UI_SPEC says so.
- **Not doing** (each is more code for little gain):
  - a `matchedGeometryEffect` from the Welcome icon to the scan glyph;
  - glass;
  - confetti on "No problems found".

## 6. Budgets and acceptance (Whydunit)

### 6.1 Budgets

| Website item | Hard cap | Before | Prototype | Measure |
|---|---|---|---|---|
| `site/static/styles.css` | 40 KB | 12.5 KB | 19.2 KB | `wc -c site/static/styles.css` |
| `site/static/motion.js` | 5 KB | none | 2.7 KB | `wc -c site/static/motion.js` |
| Home HTML (built) | 26 KB | 16.8 KB | 18.0 KB | `wc -c site/_dist/index.html` |
| Home first load, uncompressed (HTML + CSS + JS + icon + favicon) | 100 KB | 58.5 KB | 69.1 KB | sum of the above plus `icon.png` and `favicon.png` |
| New image assets, fonts, CDNs, third-party requests | 0 | 0 | 0 | `git diff --stat site/static` shows only `motion.js`; no `http` in `src=` |
| Hero sequence | ≤ 3.2 s, once | none | 3.2 s | §2.1 table |
| CLS | 0 | 0 | 0 | the snippet in §6.3 |
| LCP element | static text | tagline | tagline, about 0.48 s local | the snippet in §6.3 |

| App item | Budget |
|---|---|
| CPU after the entrance settles (Welcome, Summary, finding, sheets) | 0% in Activity Monitor within 2 s |
| Loops | only `ScanGlyph`, only in the first-scan view |
| Entrance lengths | icon ≤ 1 s; row flips ≤ 0.45 s + 8 × 0.045 s; card swap ≤ 0.5 s |
| `HoverTilt` views on screen | ≤ 8 |
| New files, assets, dependencies | none (all in `Tokens.swift`, the views and the sheets) |

### 6.2 Acceptance checklist

**Website, all pages**

- [ ] `python tools/build_site.py --check` passes. It covers links, including `/motion.js`, one `<h1>`, alt text,
  contrast with exactly two `:root` blocks, and no `data-theme`/`localStorage`.
- [ ] With DevTools › Rendering › `prefers-reduced-motion: reduce`, nothing moves and the page shows the final
  state: files gone, check on the cloud, chips in place, content visible.
- [ ] With JavaScript off, the page is complete and still. Cards are visible, and nothing is stuck at opacity 0.
- [ ] Light and dark (Rendering › `prefers-color-scheme`) look right: cloud, chips, glare and the dark shadow rims.
- [ ] At 360×740: no horizontal scroll (`document.documentElement.scrollWidth === 360`), chips hidden, the scene
  leans and straightens on scroll (Chromium/Safari).
- [ ] Firefox on Windows shows the fallback path. `html` gets `reveal-io`, cards rise as they enter, and nothing
  flashes on a `/#faq` deep link.
- [ ] Performance panel: no long task from `motion.js`, no layout or paint while the pointer tilts a card (compositor
  only), and the hero shows ≤ 10 layers.

**Website, hero**

- [ ] The window rises, the files hold at the edge and then rise into the cloud, and the check lands. After about
  3.2 s the page is still.
- [ ] The pointer tilts the scene at most 5°, with the edge under the pointer receding. It settles back when the
  pointer leaves or the page scrolls.
- [ ] The headline, tagline and Download button never move.

**Website, sections**

- [ ] Cards rise in once and tilt at most 7°. The glare sits under the pointer and text contrast never drops.
- [ ] Step numbers turn in like coins, and FAQ answers unfold.

**App** (on a Mac, or in CI once it compiles)

- [ ] Welcome: the icon turns up into place once, follows the pointer up to 12°, and the glare stays inside the icon.
- [ ] First scan: the cloud glyph loops while the scan runs and is gone after it. The bar, phase text and count still
  read in VoiceOver.
- [ ] Summary: the hero and rows flip in once per new result, and don't replay on navigating back. On a rescan the
  hero symbol bounces once, and replaces itself if the verdict changed.
- [ ] Finding rows: the chevron slides 3pt and the icon lifts on hover. The `Table` is untouched.
- [ ] Sheets: steps swap as cards without the sheet growing mid-swap. Return, Esc and dismiss-disabled behave exactly
  as before.
- [ ] With Reduce Motion on: no rotation anywhere, fades only, no glyph loop, no symbol effects.
- [ ] VoiceOver: labels, traits and the combined hero element are unchanged.

### 6.3 How to verify without a Mac

```sh
python tools/build_site.py --check                     # site contract, contrast, links (incl. /motion.js)
wc -c site/static/styles.css site/static/motion.js     # budgets
python tools/build_site.py                             # then preview with the project path prefix:
mkdir -p <scratchpad>/pages/whydunit && cp -r site/_dist/. <scratchpad>/pages/whydunit/
python -m http.server 8766 --directory <scratchpad>/pages   # open http://localhost:8766/whydunit/
```

- **Chromium (Chrome or Edge):**
  - DevTools › Rendering covers reduced motion, dark mode and paint flashing. Performance covers long tasks, and
    Layers shows the hero's layer count.
  - The device toolbar at 360×740 emulates touch, which exercises the `(hover: none)` scroll lean.
  - In the console,
    `new PerformanceObserver(l => l.getEntries().forEach(e => console.log(e.hadRecentInput, e.value, e.sources))).observe({type: 'layout-shift', buffered: true})`
    lists layout shifts. Entries with `hadRecentInput: true` come from resizing the viewport and don't count.
  - `largest-contentful-paint` in the same observer names the LCP element.
- **Stepping through the hero:** `document.getAnimations().filter(a => a.timeline === document.timeline)`, then
  `pause()` each and set `currentTime` (ms) to screenshot any moment. Query right after load: animations that have
  finished are dropped from the list.
- **Firefox on Windows** covers the IntersectionObserver fallback: stable Firefox has no `animation-timeline`.
- **Safari:** WebKit behavior (3D sorting, `backface-visibility`, scroll timelines) needs a real Safari on the owner's
  Mac or iPhone. Playwright's WebKit build on Windows is a rough proxy only; it isn't part of the repo.
- **App, by review until CI compiles it:**

```sh
grep -rn "repeatForever\|phaseAnimator\|TimelineView" App/                  # only DetailView.swift (ScanGlyph)
grep -rn "\.animation(" App/ | grep -v "value:"                              # nothing
grep -rln "rotation3DEffect\|flipIn\|HoverTilt\|cardSwap" App/ | xargs grep -L "accessibilityReduceMotion"   # nothing
git diff -U0 App/ | grep "^-.*accessibility"                                # nothing removed
```

- Then the macOS CI job (`xcodebuild`) is the first compile. Until it's green, call the app code "written, not
  compiled".

### 6.4 Proposals for other owners (not made here)

- **tools** (`build_site.py` `check()`): add size caps so the budget can't drift:

  ```python
  for name, cap in (("styles.css", 40_000), ("motion.js", 5_000)):
      if (out / name).exists() and (out / name).stat().st_size > cap:
          errors.append(f"{name}: {(out / name).stat().st_size} bytes, over the {cap} byte motion budget")
  ```

- **CI** (`.github/workflows/ci.yml`): run the first two app greps above as failures, beside the existing safety
  greps.
- **BUILD_PLAN §6:** change "No confetti. No pulsing." to "No confetti. Motion follows docs/MOTION.md (one loop: the
  first-scan glyph)". **AGENTS.md:** add "Motion: docs/MOTION.md".
- **site owner:** apply §1.7 and §2 to `site/`, and copy `motion.js` byte-for-byte from the Tirekick repo, or the
  other way round.
