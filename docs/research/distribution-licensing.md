# Distribution, signing, updates, payments and licensing: native macOS utility, India-based solo developer

*Research date: 2026-09-27. Scope: non-sandboxed SwiftUI utility sold as a one-time license and built on Windows with GitHub Actions macOS runners. Each claim links to its source. Anything marked **unverified** could not be confirmed against a primary source in this pass.*

---

## 0. Recommendation summary (the stack)

| Layer | Pick | Why |
|---|---|---|
| Apple account | Apple Developer Program, **Individual** enrollment, $99/yr (charged in local currency where available) | Developer ID signing and notarization need it. **In India, enrollment only works through the Apple Developer app**, so you need an iPhone, iPad or Mac to enroll ([Apple](https://developer.apple.com/help/account/membership/program-enrollment/)). |
| Project format | **XcodeGen** `project.yml` committed to the repo, `xcodegen generate` run in CI | Nobody edits a `.xcodeproj` on Windows. You still get the real `xcodebuild archive`/`-exportArchive` flow, which signs Sparkle's helpers correctly. A SwiftPM-only `.app` has sharp edges (see §3). |
| CI | GitHub Actions **`macos-26`** (GA, arm64, default Xcode 26.6) | `macos-latest` moved to macos-26 between 2026-06-15 and 2026-07-15. `xcode-27` (macOS 27) is still **public preview** ([runner-images](https://github.com/actions/runner-images), [changelog](https://github.blog/changelog/2026-09-10-xcode-27-runner-image-now-runs-on-macos-27/)). |
| Signing | Developer ID Application cert (.p12 in a secret), hardened runtime, `--timestamp` | Required for notarization ([Apple](https://developer.apple.com/documentation/security/resolving-common-notarization-issues)). |
| Notarization | `xcrun notarytool submit --key/--key-id/--issuer --wait`, then `xcrun stapler staple` | Uses an App Store Connect API key, so no Apple ID password or 2FA is involved in CI ([notarytool(1)](https://keith.github.io/xcode-man-pages/notarytool.1.html)). |
| Packaging | `hdiutil`-built DMG (ULFO/lzfse), signed, notarized and stapled | No extra dependency. `create-dmg` is optional if you want a styled window. |
| Updates | **Sparkle 2.10.0**. EdDSA key generated on Windows, `generate_appcast --ed-key-file -` in CI, DMGs on GitHub Releases of a **public** `*-releases` repo, `appcast.xml` on that repo's GitHub Pages | Sparkle 2.10.0 was released 2026-09-13 and requires macOS 12+ ([release](https://github.com/sparkle-project/Sparkle/releases/tag/2.10.0)). |
| Merchant of record | **Dodo Payments** (primary) or **Polar** (fallback) | Both are verified to pay Indian sellers, both include license keys, and both have license activate/validate endpoints that **need no API key**, so the app can call them directly with no server. Dodo has the lower fee: 4% + 40¢, plus 1.5% on international cards. Lemon Squeezy is in wind-down under Stripe. Stripe Managed Payments does not accept India-based businesses. |
| Licensing | **Phase 1:** MoR license key, activated online once, cached in Keychain, re-checked occasionally with a long offline grace period and **no lockout while diagnosing**. **Phase 2 (optional):** a small Worker that exchanges an activated MoR key for an **Ed25519-signed token** that CryptoKit verifies offline. | Phase 1 needs no server. Phase 2 removes MoR lock-in and works fully offline. Both designs are in §8. |
| Mac App Store | **Not for v1** | The sandbox and Guideline 2.4.5 rule out the core features: shelling out to `log`/`pmset`/`brctl`, reading `/Library`, and running recovery actions. At most, a later "viewer" SKU. See §10. |
| Price | **$24–29 one-time**, "lifetime" defined in writing. Optionally a higher tier that includes all future versions, and a technician tier. | Matches 2025–26 norms for Mac utilities (§11). |

---

## 1. Apple Developer Program: what an India-based Windows developer has to do

**Enrollment**
- Fee: "99 USD per membership year… listed in local currency during the enrollment process" ([Apple enroll](https://developer.apple.com/programs/enroll/)). A figure of about ₹9,500 from a third-party blog is **unverified**.
- "Enrollment in India is only available through the Apple Developer app." ([Apple help](https://developer.apple.com/help/account/membership/program-enrollment/)). You need an Apple device (iPhone or iPad is enough) to run the app. Individuals need no D-U-N-S number; organizations do.
- Enrolling as an individual makes you the Account Holder. Only the Account Holder can create Developer ID certificates. The limit is **5 Developer ID Application** and 5 Developer ID Installer certificates ([Apple](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/)).

**Creating the Developer ID Application certificate without a Mac (Git Bash on Windows has OpenSSL)**
```bash
openssl genrsa -out devid.key 2048
openssl req -new -key devid.key -out devid.csr -subj "/emailAddress=you@example.com/CN=Your Name/C=IN"
# Upload devid.csr: Certificates, IDs & Profiles > + > Developer ID > Developer ID Application. Download the .cer.
openssl x509 -inform DER -in developerID_application.cer -out devid.pem
# Legacy PKCS#12 algorithms so macOS `security import` accepts the file
openssl pkcs12 -export -inkey devid.key -in devid.pem -out devid.p12 \
  -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 -passout pass:CHANGE_ME
base64 -w0 devid.p12 > devid.p12.b64     # paste into the DEVELOPER_ID_P12_BASE64 secret
```
Why the legacy flags: OpenSSL 3 exports AES/SHA-256 PKCS#12 by default. macOS 14 fails to import that with `-25264 MAC verification failed`. Apple DTS says macOS 15 and later handle the modern algorithms, and recommends `-legacy` for older systems ([Apple forums 810723](https://developer.apple.com/forums/thread/810723)). The explicit `-keypbe/-certpbe/-macalg` form does the same job when the OpenSSL build has no legacy provider. That equivalence is widely reported but **unverified against an Apple source**. Keep `devid.key` and `devid.p12` backed up offline.

**App Store Connect API key for notarytool.** Create a **Team key** under App Store Connect > Users and Access > Keys (`https://appstoreconnect.apple.com/access/api`). The private key can be downloaded only once. `--issuer` is **required for Team keys** and must be **omitted for Individual keys**, otherwise you get a 401 ([notarytool(1)](https://keith.github.io/xcode-man-pages/notarytool.1.html)). Third-party guides use the "Developer" role ([electron-builder](https://www.electron.build/v26/docs/notarization/)). The minimum role is **unverified with Apple**.

**Notarization requirements to satisfy**, from [Resolving common notarization issues](https://developer.apple.com/documentation/security/resolving-common-notarization-issues):
- Sign with a **Developer ID Application** certificate. Any other certificate fails with "not signed with a valid Developer ID certificate".
- Include a **secure timestamp**: `--timestamp`, or `OTHER_CODE_SIGN_FLAGS=--timestamp`.
- Do not ship `com.apple.security.get-task-allow`. Archive and export strips it; `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` also works.
- Enable hardened runtime: `ENABLE_HARDENED_RUNTIME=YES`, or `codesign -o runtime`.
- Check the result with `codesign -vvv --deep --strict <app>`, `spctl -vvv --assess --type exec <app>` and `codesign -dvv <app>` (look for a `Timestamp=` line).
- The notary service accepts **UDIF DMGs, signed flat pkgs and ZIPs** only. You can't staple a ticket to a ZIP; staple the `.app` inside it, or the DMG ([Apple customizing workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)).

---

## 2. GitHub Actions macOS runners (as of 2026-09)

| Label | OS | Xcode | Status |
|---|---|---|---|
| `macos-26`, `macos-latest`, `macos-26-xlarge` (arm64) | macOS 26.6.2 | **26.6 (default)**, 26.5, 26.4.1, 26.3, 26.2, 26.1.1, 26.0.1 | GA since 2026-02-26 ([changelog](https://github.blog/changelog/2026-02-26-macos-26-is-now-generally-available-for-github-hosted-runners/), [readme](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md)) |
| `macos-26-intel`, `macos-26-large` (x64) | macOS 26 | 26.x | GA ([runner-images README](https://github.com/actions/runner-images)) |
| `macos-15`, `macos-15-xlarge` (arm64); `macos-15-intel` (x64) | macOS 15.7.9 | 16.4 (default), 16.0–16.3, 26.0.1–26.3 | Still supported ([readme](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-arm64-Readme.md)) |
| `macos-14*` | macOS 14 | — | **Deprecated** |
| `xcode-27`, `xcode-27-xlarge` (arm64 only) | **macOS 27.0** | 27.0 (default), 27.1, 27.2 beta | **Public preview**. From Xcode 27 on, images are named after the Xcode major version rather than the OS ([2026-07-16](https://github.blog/changelog/2026-07-16-xcode-27-runner-image-now-in-public-preview/), [2026-09-10](https://github.blog/changelog/2026-09-10-xcode-27-runner-image-now-runs-on-macos-27/), [readme](https://raw.githubusercontent.com/actions/runner-images/main/images/macos/xcode-27-arm64-Readme.md)) |

- `macos-latest` moved to `macos-26` between 2026-06-15 and 2026-07-15 ([issue #14167](https://github.com/actions/runner-images/issues/14167)).
- Pre-installed on the images: Fastlane, xcbeautify, `gh` CLI, Xcode CLT. **XcodeGen, create-dmg and Tuist are not pre-installed.** Use `brew install xcodegen`.
- **Recommendation:** build releases on `macos-26` with Xcode 26.x. Add a non-blocking `xcode-27` job to smoke-test on macOS 27. Sparkle notes that **Xcode 27 drops deployment targets below macOS 12** ([Sparkle 2.10.0 notes](https://github.com/sparkle-project/Sparkle/releases/tag/2.10.0)). Whether Xcode 27 still builds `x86_64` slices is **unverified**. Intel Macs top out at macOS 26, so ship a universal binary built with Xcode 26 for now. Release builds use `ARCHS_STANDARD` with `ONLY_ACTIVE_ARCH=NO`, which produces arm64 + x86_64.
- **Cost:** standard runners are **free for public repos**. For private repos, a macOS minute costs **$0.062** against $0.006 for Linux 2-core. GitHub Free includes 2,000 minutes a month ([GitHub billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions)). A 10–15 minute release run costs about $0.60–0.95 once included usage is gone.

---

## 3. Project format: XcodeGen vs SwiftPM-only vs Tuist

| Option | Pros | Cons |
|---|---|---|
| **XcodeGen** (2.46.0, 2026-07-16) | YAML spec that is easy to edit on Windows. `packages:` handles SPM dependencies such as Sparkle. Generates Info.plist and entitlements. The `.xcodeproj` never goes into git. Keeps the standard `xcodebuild archive` → `-exportArchive` path ([XcodeGen](https://github.com/yonaskolb/XcodeGen)). | One more tool (`brew install xcodegen`). |
| SwiftPM-only (`swift build` + hand-assembled `.app`) | No project file at all. | You assemble `Contents/{MacOS,Resources,Frameworks}` and Info.plist yourself, embed and **re-sign Sparkle's helpers manually** ([Sparkle code-signing](https://sparkle-project.org/documentation/sandboxing/)), and handle resource bundles. `swift build` only processes `.xcassets` declared as resources, and the generated `Bundle.module` accessor **crashes inside a CLI-assembled .app** because it doesn't look in `Contents/Resources` ([2026 example](https://github.com/CodeEditApp/CodeEditSymbols/issues/22)). |
| Tuist | Swift manifests. Active project. | More machinery than one app target needs. **Not evaluated in depth.** |

Minimal `project.yml` sketch. Validate it with `xcodegen generate` in CI; it has not been run here.
```yaml
name: MacMedic                       # placeholder
options:
  bundleIdPrefix: in.yourdomain
  deploymentTarget: { macOS: "14.0" }
packages:
  Sparkle: { url: https://github.com/sparkle-project/Sparkle, from: "2.10.0" }
targets:
  MacMedic:
    type: application
    platform: macOS
    sources: [Sources]
    dependencies: [{ package: Sparkle }]
    info:
      path: Sources/Info.plist
      properties:
        SUFeedURL: https://yourname.github.io/macmedic-releases/appcast.xml
        SUPublicEDKey: "<base64 32-byte public key>"
        LSApplicationCategoryType: public.app-category.utilities
    settings:
      base:
        DEVELOPMENT_TEAM: ABCDE12345           # Team ID is not secret
        CODE_SIGN_STYLE: Manual
        CODE_SIGN_IDENTITY: "Developer ID Application"
        ENABLE_HARDENED_RUNTIME: YES
        OTHER_CODE_SIGN_FLAGS: --timestamp
```
`ExportOptions.plist` (committed): `method` = `developer-id`, `signingStyle` = `manual`, `signingCertificate` = `Developer ID Application`, `teamID` = your Team ID. The key names are listed by `xcodebuild -help`; this pass confirmed them only through third-party examples.

Sparkle signing: when you **archive and export**, Xcode re-signs Sparkle's XPC services and helpers, keeps hardened runtime, and strips `get-task-allow`. No manual re-signing is needed ([Sparkle docs](https://sparkle-project.org/documentation/sandboxing/)). A non-sandboxed app doesn't need Sparkle's XPC installer service anyway. Do **not** add `--deep` to `OTHER_CODE_SIGN_FLAGS`.

---

## 4. Release workflow (tag `v1.2.3` → signed, notarized, stapled DMG, then GitHub Release and Sparkle appcast)

Not run here. Every command and flag comes from the cited sources.

```yaml
# .github/workflows/release.yml
name: release
on:
  push:
    tags: ["v*"]

jobs:
  release:
    runs-on: macos-26
    env:
      APP: MacMedic                                  # scheme / product name
      RELEASES_REPO: yourname/macmedic-releases      # PUBLIC repo: DMGs in Releases, appcast on gh-pages
    steps:
      - uses: actions/checkout@v7

      - name: Version
        run: echo "VERSION=${GITHUB_REF_NAME#v}" >> "$GITHUB_ENV"

      - name: Import Developer ID certificate          # commands from GitHub docs
        env:
          P12_BASE64: ${{ secrets.DEVELOPER_ID_P12_BASE64 }}
          P12_PASSWORD: ${{ secrets.DEVELOPER_ID_P12_PASSWORD }}
          KEYCHAIN_PASSWORD: ${{ secrets.KEYCHAIN_PASSWORD }}
        run: |
          KC="$RUNNER_TEMP/signing.keychain-db"
          echo -n "$P12_BASE64" | base64 --decode -o "$RUNNER_TEMP/cert.p12"
          security create-keychain -p "$KEYCHAIN_PASSWORD" "$KC"
          security set-keychain-settings -lut 21600 "$KC"
          security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KC"
          security import "$RUNNER_TEMP/cert.p12" -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k "$KC"
          security set-key-partition-list -S apple-tool:,apple: -k "$KEYCHAIN_PASSWORD" "$KC"
          security list-keychain -d user -s "$KC"

      - name: Archive + export (Developer ID, hardened runtime, universal)
        run: |
          brew install xcodegen
          xcodegen generate
          xcodebuild -project "$APP.xcodeproj" -scheme "$APP" -configuration Release \
            -destination 'generic/platform=macOS' -archivePath "build/$APP.xcarchive" \
            MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$GITHUB_RUN_NUMBER" archive
          xcodebuild -exportArchive -archivePath "build/$APP.xcarchive" \
            -exportOptionsPlist ExportOptions.plist -exportPath build/export
          codesign -vvv --deep --strict "build/export/$APP.app"

      - name: Notarize app, build DMG, notarize DMG
        env:
          ASC_KEY_P8_BASE64: ${{ secrets.ASC_KEY_P8_BASE64 }}
          ASC_KEY_ID: ${{ secrets.ASC_KEY_ID }}
          ASC_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}
        run: |
          echo -n "$ASC_KEY_P8_BASE64" | base64 --decode -o "$RUNNER_TEMP/AuthKey.p8"
          notarize() { xcrun notarytool submit "$1" --key "$RUNNER_TEMP/AuthKey.p8" \
                         --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID" --wait; }
          ditto -c -k --keepParent "build/export/$APP.app" "build/$APP.zip"
          notarize "build/$APP.zip"
          xcrun stapler staple "build/export/$APP.app"   # fails the job if no ticket (not Accepted)
          mkdir -p build/dmg && cp -R "build/export/$APP.app" build/dmg/
          ln -s /Applications build/dmg/Applications
          DMG="build/$APP-$VERSION.dmg"
          hdiutil create -volname "$APP" -srcfolder build/dmg -ov -format ULFO "$DMG"
          codesign --timestamp -s "Developer ID Application" "$DMG"
          notarize "$DMG"
          xcrun stapler staple "$DMG"
          spctl -vvv --assess --type exec "build/export/$APP.app"
          echo "DMG=$DMG" >> "$GITHUB_ENV"

      - name: GitHub Release + Sparkle appcast
        env:
          GH_TOKEN: ${{ secrets.RELEASES_REPO_TOKEN }}   # fine-grained PAT: contents:write on RELEASES_REPO
          SPARKLE_ED_PRIVATE_KEY: ${{ secrets.SPARKLE_ED_PRIVATE_KEY }}
        run: |
          curl -sL -o "$RUNNER_TEMP/sparkle.tar.xz" \
            https://github.com/sparkle-project/Sparkle/releases/download/2.10.0/Sparkle-2.10.0.tar.xz
          mkdir "$RUNNER_TEMP/sparkle" && tar -xf "$RUNNER_TEMP/sparkle.tar.xz" -C "$RUNNER_TEMP/sparkle"
          gh release create "$GITHUB_REF_NAME" "$DMG" -R "$RELEASES_REPO" --title "$APP $VERSION" --notes "Release $VERSION"
          git clone --depth 1 --branch gh-pages "https://x-access-token:$GH_TOKEN@github.com/$RELEASES_REPO.git" pages
          mkdir updates && cp "$DMG" updates/
          [ -f pages/appcast.xml ] && cp pages/appcast.xml updates/
          echo "$SPARKLE_ED_PRIVATE_KEY" | "$RUNNER_TEMP/sparkle/bin/generate_appcast" --ed-key-file - \
            --download-url-prefix "https://github.com/$RELEASES_REPO/releases/download/$GITHUB_REF_NAME/" updates/
          cp updates/appcast.xml pages/appcast.xml
          cd pages && git add appcast.xml \
            && git -c user.name=ci -c user.email=ci@users.noreply.github.com commit -m "appcast $VERSION" \
            && git push
```
Notes:
- Keychain commands follow [GitHub's Xcode signing guide](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications). The guide's cleanup step (`security delete-keychain`) matters only on self-hosted runners.
- The app is notarized twice: once as the stapled `.app`, then as the DMG. Apple's notary service also generates nested tickets for anything inside a submitted DMG ([Apple](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)), so submitting only the DMG also works. Stapling the `.app` too keeps offline first launch safe.
- For a styled DMG window, use `create-dmg` (v1.3.0) with `--skip-jenkins`, which skips the Finder AppleScript in headless environments. It also supports `--codesign`, `--notarize <keychain-profile>`, `--filesystem APFS` and `--format ULFO` ([create-dmg](https://github.com/create-dmg/create-dmg)).
- **Why a separate public releases repo:** if the source repo is private, its release assets aren't publicly downloadable. A public repo with no source code can host DMGs; GitHub allows files under 2 GiB each, 1,000 assets per release, and no bandwidth limit ([GitHub](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)). The same repo's `gh-pages` branch serves `appcast.xml`. Cloudflare R2 is an alternative (not evaluated).

**Secrets (9)**

| Secret | Content |
|---|---|
| `DEVELOPER_ID_P12_BASE64` / `DEVELOPER_ID_P12_PASSWORD` | Developer ID Application identity (§1) |
| `KEYCHAIN_PASSWORD` | Any random string |
| `ASC_KEY_P8_BASE64` / `ASC_KEY_ID` / `ASC_ISSUER_ID` | App Store Connect Team API key |
| `SPARKLE_ED_PRIVATE_KEY` | base64 of the 32-byte Ed25519 seed (§5) |
| `RELEASES_REPO_TOKEN` | Fine-grained PAT with contents:write on the releases repo |
| *(repo variable, not secret)* Team ID | Hard-coded in `project.yml` and `ExportOptions.plist` |

---

## 5. Sparkle 2 auto-updates

- **Version:** 2.10.0 "Golden Gate Bump" (2026-09-13). It requires macOS 12+ and drops CocoaPods. For hand-written appcasts, add `<sparkle:minimumSystemVersion>12.0</sparkle:minimumSystemVersion>` ([release](https://github.com/sparkle-project/Sparkle/releases/tag/2.10.0)). 2.9.5 and 2.9.6 (August 2026) fixed symlink/delta security issues, so don't pin anything older ([2.9.5](https://github.com/sparkle-project/Sparkle/releases/tag/2.9.5)).
- **Info.plist:** `SUFeedURL` and `SUPublicEDKey` ([docs](https://sparkle-project.org/documentation/)).
- **SwiftUI:** `SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)`. Bind a "Check for Updates…" button to `updater.checkForUpdates` and disable it using KVO on `canCheckForUpdates` ([programmatic setup](https://sparkle-project.org/documentation/programmatic-setup/)).
- **Keys without a Mac.** `generate_keys` exports new-format keys as "the base64 encoding of the private seed" (32 bytes), and `SUPublicEDKey` is the base64 32-byte public key ([generate_keys source](https://github.com/sparkle-project/Sparkle/blob/2.x/generate_keys/main.swift)). You can therefore generate an equivalent pair on Windows (`pip install cryptography`):
  ```python
  import base64
  from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
  from cryptography.hazmat.primitives import serialization as s
  k = Ed25519PrivateKey.generate()
  print("SPARKLE_ED_PRIVATE_KEY:", base64.b64encode(k.private_bytes(s.Encoding.Raw, s.PrivateFormat.Raw, s.NoEncryption())).decode())
  print("SUPublicEDKey:", base64.b64encode(k.public_key().public_bytes(s.Encoding.Raw, s.PublicFormat.Raw)).decode())
  ```
  The format matches Sparkle's source. Run `sign_update --verify <dmg> <sig>` once in CI to confirm the pair before the first public release. Alternatively, run `generate_keys` then `generate_keys -x file` on a runner once.
- **CI signing flags,** verified in source:
  - `generate_appcast`: `--ed-key-file -` (key on stdin), `--download-url-prefix`, `-o`, `--maximum-deltas`, `--channel`, `--major-version`, `--informational-update-versions` (with `--link`), `--critical-update-version`, `--phased-rollout-interval`.
  - `sign_update`: `-f/--ed-key-file`, `--verify`, `-p`.
  - `-s <key>` is deprecated ([generate_appcast](https://github.com/sparkle-project/Sparkle/blob/2.x/generate_appcast/main.swift), [sign_update](https://github.com/sparkle-project/Sparkle/blob/2.x/sign_update/main.swift)).
- **Archive formats:** DMG (Sparkle recommends APFS/lzfse), ZIP (`ditto -c -k --sequesterRsrc --keepParent`), tar.xz, or AAR (2.7+) ([publishing](https://sparkle-project.org/documentation/publishing/)).
- **Paid-upgrade plumbing:** use `--major-version` plus `--informational-update-versions` / `--link`. v1 users then see that v2 exists and get a link to the upgrade page, instead of silently auto-installing a version their license may not cover.

---

## 6. Merchant of record and payment options for a seller in India

**Why an MoR at all:** if you sell directly to consumers, you are the seller of record everywhere you sell. For example, non-EU sellers of e-services to EU consumers owe VAT from the first euro. The €10,000 threshold is only for EU-established suppliers; non-EU sellers use the non-Union OSS scheme ([EU OSS](https://vat-one-stop-shop.ec.europa.eu/one-stop-shop_en)). An MoR takes on that liability.

| Provider | Pays out to an India-based seller? | Fee (one-time sale) | License keys and client API | Status / notes |
|---|---|---|---|---|
| **Dodo Payments** | **Yes.** Built for Indian sellers. PAN required for individuals; GSTIN or business PAN for entities; unregistered individuals can onboard. **Payouts in USD/GBP/EUR** (INR is no longer a payout wallet). $50 minimum; bi-monthly on the 4th and 18th ([FAQ](https://docs.dodopayments.com/miscellaneous/faq)) | **4% + 40¢**, +1.5% international, +3% PayPal/BNPL, +0.5% subscriptions. Refund $1, dispute $30, **payouts under $1,000: $5**, USD SWIFT payout $25 ([pricing](https://dodopayments.com/pricing)) | Built in: activation limit, license length, auto or manual fulfillment. **Public endpoints, no API key:** `POST /licenses/activate` {`license_key`,`name`}, `POST /licenses/validate`, `POST /licenses/deactivate` {`license_key`,`license_key_instance_id`}. Base URL `https://live.dodopayments.com` (test: `https://test.dodopayments.com`). Activate returns 422 when the activation limit is reached ([license docs](https://docs.dodopayments.com/features/license-keys), [API](https://docs.dodopayments.com/api-reference/licenses/activate-license)) | Young company (founded 2023). The India fit is its main selling point. |
| **Polar** | **Yes**, via Stripe Connect Express, "even if Stripe standalone is invite-only there" ([Polar](https://polar.sh/docs/merchant-of-record/supported-countries)) | Starter **5% + 50¢**; Pro $20/mo at 3.8% + 40¢. +1.5% international cards. $15 per dispute. Payouts: $2 per active payout month, 0.25% + $0.25 per payout, FX 1% outside the EU ([fees](https://polar.sh/docs/merchant-of-record/fees)) | Built in: prefix, expiry, activation limit, usage quota. `POST https://api.polar.sh/v1/customer-portal/license-keys/{validate,activate,deactivate}` with `key` and `organization_id`. The docs say it "doesn't require authentication and can be safely used on a public client" ([validate](https://polar.sh/docs/api-reference/customer-portal/license-keys/validate), [benefit](https://polar.sh/docs/features/benefits/license-keys)) | Open source. Fees are higher than Dodo's. |
| **Creem** | **Yes**: "India" with local bank transfer. Payout fee is **7 USD/EUR or 1%, whichever is higher** ([Creem](https://docs.creem.io/merchant-of-record/supported-countries)) | **3.9% + 40¢**, "No international card fees" ([pricing](https://www.creem.io/pricing)) | activate/validate/deactivate at `/v1/licenses/*`, but they **require an `x-api-key` header**, and the docs say not to put keys in client code. **You need your own server proxy** ([docs](https://docs.creem.io/features/addons/licenses)) | Cheapest per transaction, but the server requirement costs you more work. |
| **Paddle** | Works with software businesses "anywhere in the world" except the listed unsupported countries; India isn't listed ([Paddle](https://www.paddle.com/help/start/intro-to-paddle/which-countries-are-supported-by-paddle)). SWIFT payouts in a different currency cost **$/€/£15**; Payoneer is available; FX margin up to 1.5% ([payout fees](https://www.paddle.com/help/manage/get-paid/is-there-a-fee-taken-for-payouts)) | **5% + 50¢**. "If you're selling products under $10… contact us" ([pricing](https://www.paddle.com/pricing)) | **Paddle Billing has no license keys.** The Mac licensing SDK belonged to Paddle Classic, which is being wound down ([Eternal Storms](https://blog.eternalstorms.at/2024/12/18/selling-outside-of-the-mac-app-store-part-ii-lets-meddle-with-paddle/), [Paddle help](https://www.paddle.com/help/start/intro-to-paddle/selling-a-mac-app-with-trials-and-licensing)). Pair it with Keygen (free Dev tier up to 100 active licensed users; flat pricing, no revenue share; CE self-host) ([Keygen](https://keygen.sh/pricing/)) or your own Ed25519 keys (§8) | Solid and established, but you'd build the licensing yourself. |
| **Lemon Squeezy** | Stripe payouts have been invite-only for India since May 2024, so **PayPal payouts** apply: international PayPal payouts cost **3%, capped at $30** ([LS countries](https://docs.lemonsqueezy.com/help/getting-started/supported-countries), [fees](https://docs.lemonsqueezy.com/help/getting-started/fees)) | **5% + 50¢**, +1.5% international, +1.5% PayPal | Public License API: `POST https://api.lemonsqueezy.com/v1/licenses/{activate,validate,deactivate}` (`license_key`, `instance_name` / `instance_id`), limited to 60 requests/minute. Validate needs no API key. Always check `meta.store_id`/`product_id`/`variant_id`, or keys from other LS stores will unlock your app ([API](https://docs.lemonsqueezy.com/api/license-api), [guide](https://docs.lemonsqueezy.com/guides/tutorials/license-keys)) | **Avoid for a new product.** Stripe acquired it on 2024-07-26. On 2026-01-28 the CEO said support is slower and updates fewer, and that the goal is migration to Stripe Managed Payments ([2026 update](https://www.lemonsqueezy.com/blog/2026-update)). As of 2026-09-27 its register page opens a Stripe questionnaire ("Find the right setup for your business"). |
| **Stripe Managed Payments** | **No.** India is not among the supported business locations (CA, US, 31 European countries, AU, HK, JP, SG) ([eligibility](https://docs.stripe.com/payments/managed-payments/eligibility)) | — | — | Not an option. |
| **Gumroad** | MoR since 2025-01-01. In Gumroad's open-source code, **India is the only entry in `NEW_ACCOUNT_CREATION_BLOCKED_COUNTRIES` for Stripe Connect**, so new Indian creators use PayPal as the payout rail ([source](https://github.com/antiwork/gumroad/blob/main/app/business/payments/merchant_registration/implementations/stripe/stripe_merchant_account_manager.rb), [PR #8012](https://github.com/antiwork/gumroad/pull/8012)) | **10% + 50¢** (30% through Discover) ([pricing](https://gumroad.com/pricing)) | `POST https://api.gumroad.com/v2/licenses/verify` needs no auth. Pass `product_id`, which is now mandatory for newer products. **`increment_uses_count` defaults to true**, so send `false` on routine checks. `enable`/`disable`/`decrement_uses_count`/`rotate` need OAuth `edit_products` ([controller](https://github.com/antiwork/gumroad/blob/main/app/controllers/api/v2/licenses_controller.rb), [routes](https://github.com/antiwork/gumroad/blob/main/config/routes.rb)) | Highest fee. Sindre Sorhus uses it for his non-App-Store apps. |
| **FastSpring** | **Unverified** | Quote-based. The 5.9% + $0.95 figure comes from third-party blogs (**unverified**) | Has license fulfillment (unverified detail) | Better suited to larger vendors. |
| **PayPro Global** | Unverified | Unverified | — | DriveDx sells through it ([BinaryFruit store](https://binaryfruit.com/store)). |
| **Razorpay** | Indian payment gateway, **not an MoR** | Domestic 2%. **International cards up to 3%**, plus 18% GST on the fee. International cards must be activated separately ([pricing](https://razorpay.com/pricing/)) | None | You would be the seller of record for EU, UK and other VAT/GST. Only suitable for INR sales to Indian buyers. |

**What you keep on a $29 sale with a non-US card** (fee arithmetic only; excludes payout, FX, and tax-inclusive bases):

| Provider | Fee | You keep |
|---|---|---|
| Creem | $1.53 | **$27.47** (needs a server for licensing) |
| Paddle | $1.95 | $27.05 (no license keys) |
| **Dodo** | $2.00 | **$27.01** |
| Polar Starter | $2.39 | $26.62 |
| Lemon Squeezy | $2.39 (+3% PayPal payout) | ~$25.8 |
| Gumroad | $3.40 | $25.60 |
| Mac App Store (Small Business Program 15%) | $4.35 | $24.65 before Apple's tax deductions ([Apple SBP](https://developer.apple.com/app-store/small-business-program/)) |

**India-side notes (not tax advice; confirm with a CA).** An MoR pays you as a foreign customer, so payouts are generally treated as export of services. Dodo's docs describe onboarding with PAN/GSTIN and automatic GST handling for Indian merchants. Whether you must register for GST, file an LUT, and collect FIRA/FIRC paperwork for bank inward remittances depends on your turnover and setup. Those specifics are **unverified here**.

---

## 7. How the licenses and APIs behave

- **LS/Polar/Dodo/Gumroad keys all validate against the MoR's servers.** The response is **not signed**, so a local proxy can fake `valid: true`. Patching the binary is easier still, though. Every client-side check can be defeated. For a utility in the $20–40 range, the aim is to keep honest people honest, not to beat crackers.
- **Always check the product.** Compare Dodo's `product.product_id`, LS's `meta.product_id`/`variant_id`, Polar's `organization_id` and Gumroad's `product_id` against constants compiled into the app. Otherwise any key from the same platform unlocks your app ([LS guide](https://docs.lemonsqueezy.com/guides/tutorials/license-keys)).
- **MoR lock-in.** Keys issued by one MoR stop validating if you migrate unless you keep that account alive. Owning an Ed25519 token (Phase 2) removes this dependency.

---

## 8. License design: online activation vs Ed25519 offline tokens

| | MoR online activation (Phase 1) | Self-signed Ed25519 token (Phase 2) |
|---|---|---|
| Server you run | None | One small function (for example a Cloudflare Worker) |
| Works offline | Only after the first activation, and only if you cache the result | Fully; verification is local |
| Device limit | Enforced by the MoR's `activation_limit` | Only if the token is bound to a machine hash |
| Revocation (refund/chargeback) | Next online check | Needs a revocation list or short-lived tokens |
| Forgery resistance | Weak (response is unsigned) | Strong (needs your private key) |
| Survives an MoR switch | No | Yes |
| Binary patching | Defeats it | Defeats it |

**Recommendation for this app.** People open a troubleshooting tool when something is broken, sometimes with no network (a dock is down, iCloud is stuck). Licensing must never block diagnosis.
1. **Phase 1 (launch):**
   - On purchase, the MoR emails the key.
   - The app calls `POST https://live.dodopayments.com/licenses/activate` with `{license_key, name: <Mac name>}` and stores the key and instance `id` in the Keychain.
   - The app re-validates at most every 30 days and allows a **≥60-day offline grace period**. If validation fails, show a banner; never lock a running session.
   - Set the activation limit to **3 Macs** (Sensei and DriveDx use 3; WhatPort uses 2). Add a "Deactivate this Mac" button that calls `/licenses/deactivate`.
2. **Phase 2 (only if needed):** the Worker's `/activate` calls the MoR, then returns an Ed25519-signed token containing `{order, email, product, maxMajor, machine: SHA256(IOPlatformUUID+salt)}`. The app stores the token and verifies it offline indefinitely. Tokens stay valid if you change MoR later.

**Tested issuer and verifier (Python; ran OK here: sign, verify, tamper detection):**
```python
# license = "<b64url(payload JSON)>.<b64url(Ed25519 signature)>"
import base64, json
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey, Ed25519PublicKey
b64 = lambda b: base64.urlsafe_b64encode(b).rstrip(b"=").decode()
unb64 = lambda t: base64.urlsafe_b64decode(t + "=" * (-len(t) % 4))
def issue(seed_b64, payload):
    body = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode()
    return b64(body) + "." + b64(Ed25519PrivateKey.from_private_bytes(base64.b64decode(seed_b64)).sign(body))
def verify(pub_b64, lic):
    body, sig = lic.split(".")
    Ed25519PublicKey.from_public_bytes(base64.b64decode(pub_b64)).verify(unb64(sig), unb64(body))  # raises if forged
    return json.loads(unb64(body))
```
**In-app verification (CryptoKit).** The API names were checked against Apple docs; the snippet was not compiled here. `Curve25519.Signing.PublicKey.init(rawRepresentation:)` and `isValidSignature(_:for:)` are available on macOS 10.15+ ([Apple](https://developer.apple.com/documentation/cryptokit/curve25519/signing/publickey)).
```swift
import CryptoKit, Foundation

struct LicensePayload: Decodable { let order: String; let email: String; let maxMajor: Int }

enum License {
    static let key = try! Curve25519.Signing.PublicKey(rawRepresentation: Data(base64Encoded: "<BASE64_32_BYTE_PUBKEY>")!)
    static func verify(_ text: String) -> LicensePayload? {
        let p = text.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".").map(String.init)
        guard p.count == 2, let body = Data(b64url: p[0]), let sig = Data(b64url: p[1]),
              key.isValidSignature(sig, for: body) else { return nil }
        return try? JSONDecoder().decode(LicensePayload.self, from: body)
    }
}
extension Data {
    init?(b64url s: String) {
        var t = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        t += String(repeating: "=", count: (4 - t.count % 4) % 4)
        self.init(base64Encoded: t)
    }
}
```
Machine binding, if you want it: read the `IOPlatformUUID` property with `IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))` and `IORegistryEntryCreateCFProperty(…, kIOPlatformUUIDKey as CFString, …)`. `kIOMainPortDefault` requires macOS 12+ ([Apple](https://developer.apple.com/documentation/iokit/kiomainportdefault), [kIOPlatformUUIDKey](https://developer.apple.com/documentation/iokit/kioplatformuuidkey)). Hash it before it leaves the machine. WhatPort's privacy note says its licensing sends the "licence key and Mac identifier" ([WhatPort](https://www.whatport.app/)), so disclose the same.

**Major versions.** Put `maxMajor` in the token, or use a separate MoR product per tier. The app compares it with its own major version. Point v1 users to the upgrade page with Sparkle's `--informational-update-versions`.

---

## 9. How established indie Mac developers handle licensing

| Developer / app | Price | Seats | "Lifetime" definition / upgrades | Source |
|---|---|---|---|---|
| Rogue Amoeba (SoundSource / Audio Hijack / Piezo) | $49 / $69 / $29. Upgrades: SoundSource $25, Audio Hijack $29 | **One user, any number of their Macs**; shared machines need one license each | Nearly all updates free. Paid upgrades when "substantial new functionality" arrives, with a "generous grace period" for recent buyers. Old versions keep working and upgrades are never forced | [store](https://rogueamoeba.com/store/), [SoundSource buy](https://rogueamoeba.com/soundsource/buy.php), [philosophy](https://rogueamoeba.com/support/knowledgebase/?showArticle=MiscUpgradePolicy) |
| Bjango iStat Menus 7 | $11.99 single / $14.99 family (5); upgrade from v6 $9.99 | Family pack for 5 people | Paid major upgrades. Also on Setapp ($9.99/mo) | [Bjango](https://bjango.com/mac/istatmenus/). Prices from [MacSales](https://eshop.macsales.com/blog/95542-istat-menus-7-is-the-latest-in-a-long-line-of-delightful-mac-monitoring-apps-from-bjango/) (price **unverified on bjango.com**; it loads dynamically) |
| Sindre Sorhus | Mostly Mac App Store. Some apps on Gumroad | Gumroad: "one user on unlimited computers" | No cross-licensing between App Store, Gumroad and Setapp | [FAQ](https://sindresorhus.com/apps/faq) |
| Cindori Sensei | $59 one-time **or** $29/yr | 3 Macs | The one-time license covers Sensei 1 **and** 2; "Version 3 and onwards may be a paid upgrade" | [store](https://cindori.com/store/sensei) |
| Panic Transmit 5 | $45 | Volume discounts | "Keep it forever" | [Panic](https://panic.com/transmit/) |
| CleanShot X | $35 | 1 Mac (transferable) | 1 year of updates, then an optional $19/yr renewal; "continue using the last version forever" | [pricing](https://cleanshot.com/pricing), [why updates expire](https://cleanshot.com/why-updates-expire) |
| Alfred Powerpack | £34 (v5 license, with free upgrade to v6) / **£59 Mega Supporter: free lifetime upgrades** | Single user | Two-tier "version vs forever" model | [Alfred](https://www.alfredapp.com/powerpack/buy/) |
| coconutBattery Plus | "Lifetime Edition: all future Plus updates" vs "coconutBattery 4 only: only updates for v4.x" (about $17.95 / $12.95, from a search snippet of the vendor page, **unverified**) | Unlimited devices | Two-tier model; direct sales only | [vendor](https://coconut-flavour.com/coconutbattery/) |
| DriveDx | $24.99 personal (3 computers), $49.99 family (6); **Consultant license $49.99**, the only license that allows diagnosing third-party Macs | — | Sold through PayPro Global | [store](https://binaryfruit.com/store) |
| WhatPort Pro (direct competitor, ports) | **£9.99 one-time** | **2 Macs**, key validated online | Core app free and MIT open source; Pro adds history, alerts, export. Stripe checkout; 14-day refund | [WhatPort](https://www.whatport.app/) |
| DaisyDisk | $9.99 | — | "Lifetime license… Minor updates & bug fixes included" | [DaisyDisk](https://daisydiskapp.com/buy) |
| TG Pro | $20 (on sale for $10), one-time | — | — | [Tunabelly](https://www.tunabellysoftware.com/tgpro/) |

**Patterns.**
1. "Lifetime" almost always means lifetime **use**. Updates are either bounded by major version (Rogue Amoeba, coconutBattery Standard, Alfred Single, Sensei covering two majors) or by time (CleanShot, 1 year). "Forever updates" is sold as a premium tier (Alfred Mega Supporter, coconutBattery Lifetime).
2. Seat norms: one user on their own Macs, or 2–3 activations.
3. Upgrade discounts run at roughly 40–60% of the full price.
4. None of the vendors checked publicly describes aggressive DRM.

---

## 10. Mac App Store alternative

**How it would work.** A free download with a **non-consumable IAP** "lifetime unlock", using StoreKit 2:
- `Product.products(for:)` loads the product.
- `product.purchase(options:)` buys it.
- `Transaction.currentEntitlements` checks the unlock at launch.
- `Transaction.updates` listens for transactions made elsewhere.
- `AppStore.sync()` backs the "Restore" button.

All verified in Apple docs ([products(for:)](https://developer.apple.com/documentation/storekit/product/products(for:)), [currentEntitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements), [sync()](https://developer.apple.com/documentation/storekit/appstore/sync())). Apple takes 15% under the Small Business Program while proceeds stay under $1M ([Apple](https://developer.apple.com/app-store/small-business-program/)). Apple handles tax. Paid-upgrade pricing is not natively supported (widely reported; **not re-verified here**).

**Guideline 2.4.5 blockers** ([App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)):
- (i) must be sandboxed;
- (iv) no downloading additional code;
- (v) **no root escalation**;
- (vi) **no license keys or custom copy protection**;
- (vii) **updates only through the Mac App Store**, so no Sparkle.

**What the sandbox would block for this app:**
- **Shelling out to `log`, `pmset`, `system_profiler`, `brctl`.** Child processes run inside the app's sandbox (inherited; **likely**, not re-verified per tool). Log access is also limited: `OSLogStore.local()` "must be run by an admin account and have the `com.apple.logging.local-store` entitlement" ([Apple](https://developer.apple.com/documentation/oslog/oslogstore/local())). There is no sign that entitlement is available to App Store apps (**unverified**).
- **Scanning `/Library`, `~/Library/Mobile Documents`, other apps' data.** Default access is the app's container plus user-selected files. Anything wider needs `com.apple.security.temporary-exception.files.absolute-path.read-only`, which has to be justified to App Review. On macOS 14+, touching another app's container triggers a consent prompt ([Apple file access](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox), [temporary exceptions](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/AppSandboxTemporaryExceptionEntitlements.html)).
- **IOKit.** Opening non-default `IOUserClient` classes (for example for SMC reads) needs `com.apple.security.temporary-exception.iokit-user-client-class`. Plain IORegistry property reads are generally fine. WhatPort says it reads IOKit/SMC unprivileged and carries only the outbound-network entitlement; whether WhatPort is sandboxed is **unverified**.
- **iCloud recovery actions** (killing or restarting `bird`, `brctl` operations) and **privileged helpers** are ruled out.

**Verdict.** Ship Developer ID with Sparkle. At most, add a Mac App Store "Monitor Lite" later as a discovery channel. Setapp is another optional channel (iStat Menus and Sindre Sorhus apps are there).

---

## 11. Pricing recommendation

- **2025–26 norms for one-time Mac utilities:**
  - Single-purpose monitors and tools: **$10–25** (DaisyDisk $9.99, WhatPort Pro £9.99, iStat Menus $11.99, coconutBattery Plus ~$13–18, TG Pro $20, DriveDx $24.99).
  - Deeper "fix-it" or power tools: **$29–69** (Piezo $29, CleanShot $35, Transmit $45, SoundSource $49, Sensei $59, Audio Hijack $69).
- **Suggested tiers for a diagnostic tool that also fixes things (iCloud recovery plus guided dock/port A/B diagnosis):**
  - Free: record and view (WhatPort's model).
  - **Standard $24–29: "yours forever, all 1.x and 2.x updates, 3 Macs".**
  - Optional **Lifetime $49: all future versions**.
  - Optional **Technician $79–99: use on client Macs** (DriveDx's consultant-license precedent).
- **Write the definition on the checkout page,** for example: "Lifetime license = use the version you buy forever; includes all updates through version 2.x; later major upgrades discounted; purchases within 90 days of a new major version upgrade free." That follows Rogue Amoeba's grace period and Sensei's two-major-versions coverage.

---

## 12. One-time setup checklist (from Windows)

1. Enroll as an Individual using the Apple Developer app on an iPhone or iPad.
2. OpenSSL CSR → Developer ID Application `.cer` → legacy-algorithm `.p12` → secrets (§1).
3. App Store Connect Team API key (`.p8`, Key ID, Issuer ID) → secrets.
4. `pip install cryptography`. Generate the Sparkle EdDSA pair and, if using Phase 2, a separate license-signing pair. Put the private seeds in secrets and the public keys in `project.yml` / source.
5. Create the public `*-releases` repo with a `gh-pages` branch and GitHub Pages enabled. Create a fine-grained PAT.
6. Open a Dodo Payments account (PAN, bank details for USD payouts) and create the product with a license key (activation limit 3, no expiry). Or use Polar.
7. Commit `project.yml`, `ExportOptions.plist` and `.github/workflows/release.yml`. Tag `v0.1.0` and download the DMG on a Mac to confirm Gatekeeper opens it cleanly.

---

## 13. Unverified / open items

- The India fee in INR (~₹9,500) and the exact App Store Connect API key role notarytool needs.
- Whether Xcode 27 still builds `x86_64`. This decides whether Intel Macs on macOS ≤ 26 can keep getting updates built with Xcode 27.
- FastSpring and PayPro Global fees, and whether they support Indian payouts.
- GST registration, LUT and FIRA specifics for an Indian individual receiving MoR payouts.
- Whether Dodo's manual fulfillment (`POST /grants/{id}/license-key`) accepts ~200-character strings. If it does, Dodo could deliver self-signed Ed25519 tokens directly with no Worker.
- Exact sandbox behavior of each CLI tool (`pmset -g log`, `log show`, `system_profiler`, `brctl`) when launched from a sandboxed app. Test before considering a Mac App Store SKU.
