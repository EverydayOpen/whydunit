# Releasing Whydunit

Pushing a `vX.Y.Z` tag (digits only; a tag like `v1.1.0-beta.1` starts no run) runs [.github/workflows/release.yml](../.github/workflows/release.yml) in three jobs:

1. **build** first runs a preflight that fails before any build time. The tag's version must have a `CHANGELOG.md`
   section; Sparkle must be declared in `project.yml`; `SUPublicEDKey` must be set and be the public half of
   `SPARKLE_ED_PRIVATE_KEY`; `OWNER` must be gone from `SUFeedURL`, `site/site.json`'s `baseURL` and
   `Links.website`, which must all agree (`bash tools/doctor.sh --ci`); `site/site.json`'s `releasesRepo` must equal
   the `RELEASES_REPO` variable and its `dmgName` must be `Whydunit.dmg`; `SUFeedURL` must be where the releases repo's
   `gh-pages` is served (`<owner>.github.io/<repo>`, or its `CNAME`'s domain); and `notarytool` must accept the App
   Store Connect key. The job then
   archives a universal (arm64 + x86_64) Developer ID build with the hardened runtime. It checks that
   `Sparkle.framework` is embedded and that both architectures are present, and launches the signed app on the
   arm64 runner (it must stay up for 10 seconds). Only then does it notarize and staple the app, and build, sign,
   notarize and staple the DMG.
2. **smoke-intel** launches the same signed app on an Intel runner (`macos-15-intel`, which also covers the macOS 15
   deployment target).
3. **publish** runs only when both launch tests passed. It creates the GitHub Release in the public releases repo
   with the changelog section as its notes, and uploads the DMG twice: `Whydunit-X.Y.Z.dmg` for the appcast and
   `Whydunit.dmg`, which the site's `/download/` link follows through `releases/latest/download/Whydunit.dmg`. It
   then pushes a Sparkle `appcast.xml` signed with EdDSA, with the same notes embedded as HTML.

Background and sources are in [research/distribution-licensing.md](research/distribution-licensing.md) §1–§5.
Everything around this (GitHub Pages, an optional custom domain, website, legal review) is in
[GO_LIVE.md](GO_LIVE.md). The app is free, so there is no payment or licence setup (BUILD_PLAN §10).

Everything below works from Windows (Git Bash has `openssl` and `base64`). You only need a Mac to check the result.

## One-time setup

Do all of this **outside the repo folder**. `.gitignore` blocks `*.p12`, `*.p8`, `*.key` and `*.pem`, but key
material should never be in the working tree at all. Keep an offline backup of `devid.key`, `devid.p12`, the
`.p8` file and the Sparkle private key (a password manager works).

### 1. Apple Developer Program

- Enroll as an **Individual** ($99/year). In India, enrollment only works through the **Apple Developer app** on
  an iPhone or iPad.
- Write down your **Team ID** (developer.apple.com › Account › Membership details). It becomes the
  `DEVELOPMENT_TEAM` secret.

### 2. Developer ID Application certificate (no Mac needed)

```sh
openssl genrsa -out devid.key 2048
# MSYS_NO_PATHCONV=1: Git Bash rewrites arguments starting with '/' into Windows paths, which breaks -subj
MSYS_NO_PATHCONV=1 openssl req -new -key devid.key -out devid.csr -subj "/emailAddress=you@example.com/CN=Your Name/C=IN"
```

Go to developer.apple.com › Certificates, IDs & Profiles › Certificates › **+** › **Developer ID Application**
(G2 Sub-CA), upload `devid.csr` and download `developerID_application.cer`. Then:

```sh
openssl x509 -inform DER -in developerID_application.cer -out devid.pem
# Legacy PKCS#12 algorithms so `security import` on the runner accepts the file
openssl pkcs12 -export -inkey devid.key -in devid.pem -out devid.p12 \
  -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 -passout pass:CHOOSE_A_PASSWORD
base64 -w0 devid.p12 > devid.p12.b64
```

Only the Account Holder can create Developer ID certificates, and each account can have at most 5.

### 3. App Store Connect API key (for notarytool)

Go to App Store Connect › Users and Access › Integrations › **Team Keys**, generate a key with the Developer role,
and download `AuthKey_XXXXXXXXXX.p8`. You can download it only once. Write down the **Key ID** and the
**Issuer ID** shown above the table, then run:

```sh
base64 -w0 AuthKey_XXXXXXXXXX.p8 > authkey.p8.b64
```

Use a Team key: `--issuer` is required for Team keys and is rejected for Individual keys.

### 4. Sparkle update keys

```sh
python tools/sparkle_keys.py        # needs `pip install cryptography`
```

- Paste each key exactly, with no spaces or line breaks around it. Stray whitespace in `Info.plist` fails the
  release preflight.
- Paste the **public** key into `App/Info.plist` › `SUPublicEDKey`, replacing `REPLACE_WITH_SPARKLE_PUBLIC_KEY`,
  and commit it.
- The **private** key becomes the `SPARKLE_ED_PRIVATE_KEY` secret. The script prints it and writes nothing.
- Never regenerate the pair after the first public release. Every installed copy trusts only this public key, so
  losing the private key means those copies can never update again.

### 5. Releases repo and appcast host

1. Create a **public** repo, for example `whydunit-releases`, with a README so that `main` has a commit. DMGs
   go in its Releases.
2. Create an empty `gh-pages` branch:
   ```sh
   git clone https://github.com/OWNER/whydunit-releases && cd whydunit-releases
   git switch --orphan gh-pages
   git commit --allow-empty -m "gh-pages"
   git push -u origin gh-pages
   ```
   Then go to Settings › Pages › Build and deployment › Deploy from a branch › `gh-pages` / `/ (root)` › Save.
   `appcast.xml` appears there after the first release.
3. Make sure `SUFeedURL` in `App/Info.plist` points at that file:
   `https://OWNER.github.io/whydunit-releases/appcast.xml` with your lower-case user or organization in place of
   `OWNER`, or `https://<domain>/appcast.xml` with a custom domain ([GO_LIVE.md](GO_LIVE.md) steps 2 and 3). Change
   it together with `site/site.json`'s `baseURL` and `Links.website` (`bash tools/doctor.sh` checks they agree).
   The workflow checks `SUFeedURL` against the `gh-pages` address, or its `CNAME` if there is one, before it builds.
   The release workflow only touches `appcast.xml` and the site workflow never touches `appcast.xml` or `CNAME`.
   Decide before the first public release, because the URL is baked into every copy you ship.
   Each GitHub Release also carries `appcast.xml` as an asset, as a backup.
4. Create a **fine-grained personal access token**. Set Repository access to *only* `whydunit-releases`, set
   Permissions › Contents to **Read and write**, and give it an expiry you will remember to renew. It becomes
   `RELEASES_REPO_TOKEN`.

### 6. GitHub environment, secrets and variable

Environment secrets, the `v*`/`main` rules and required reviewers need a public source repo, or GitHub Pro for a
private one (reviewers: public only; [GO_LIVE.md](GO_LIVE.md) step 2.1).

In the source repo, go to Settings › Environments › **New environment** `release`, then:

- Under Deployment branches and tags, choose *Selected* and add the tag rule `v*`.
- Optionally, add yourself as a required reviewer so every signing run waits for your approval.

Add these as **environment secrets** of `release`. With the GitHub CLI you can pipe files, for example
`gh secret set DEVELOPER_ID_P12_BASE64 --env release < devid.p12.b64`.

| Secret | Value |
|---|---|
| `DEVELOPER_ID_P12_BASE64` | contents of `devid.p12.b64` |
| `DEVELOPER_ID_P12_PASSWORD` | the `.p12` password from step 2 |
| `KEYCHAIN_PASSWORD` | any random string |
| `DEVELOPMENT_TEAM` | your 10-character Team ID |
| `ASC_KEY_P8_BASE64` | contents of `authkey.p8.b64` |
| `ASC_KEY_ID` | Key ID from step 3 |
| `ASC_ISSUER_ID` | Issuer ID from step 3 |
| `SPARKLE_ED_PRIVATE_KEY` | private key from step 4 |
| `RELEASES_REPO_TOKEN` | the fine-grained PAT from step 5 |

Open the **`site`** environment (the first push to `main` already created it through `site.yml`; create it if it is
missing) for the website deploy (`.github/workflows/site.yml`, which runs on pushes to `main`, so the `release`
environment's `v*` rule would block it). Under Deployment branches and tags, choose
*Selected* and add the branch `main`. Add one secret, `RELEASES_REPO_TOKEN`, with the same PAT as above:
`gh secret set RELEASES_REPO_TOKEN --env site`. No reviewer: the site only needs the token to push to `gh-pages`.

Then go to Settings › Secrets and variables › Actions › **Variables** and add `RELEASES_REPO` = `OWNER/whydunit-releases`.

`ExportOptions.plist` keeps `REPLACE_WITH_TEAM_ID`. The workflow fills in the real Team ID from the secret.

## Cutting a release

1. Make sure `main` is green in the **ci** workflow and `bash tools/doctor.sh` shows no `ERROR`.
2. Rename `## Unreleased` in `CHANGELOG.md` to `## X.Y.Z — YYYY-MM-DD` (em dash, today's ISO date), check that the
   notes are written for users, and commit it, but don't push `main` yet. The section becomes the GitHub release
   notes, the Sparkle update notes and the site's changelog (`## Unreleased` is never published).
   Check it with `python tools/changelog.py notes X.Y.Z --format html`. The workflow refuses a tag without a
   section.
3. Tag that commit and push only the tag. The tag sets the version (`MARKETING_VERSION`), and the workflow run number
   sets the build number (`CURRENT_PROJECT_VERSION`, which Sparkle compares). Don't edit the versions in `project.yml`.
   ```sh
   git tag v1.0.0
   git push origin v1.0.0
   ```
4. Open Actions › **release**, approve the environment if you added a reviewer, and wait about 20 minutes. The
   **build** and **publish** jobs both use the `release` environment, so a reviewer approves twice: once to build
   and once to publish after both launch tests have passed. If a launch test fails, the job prints the newest
   crash report. If notarization fails, it prints Apple's notary log.
5. **Push `main` once publish has succeeded** (`git push origin main`). That push deploys the site with the new
   changelog entry; pushed earlier, the site would list a release that doesn't exist yet. Before 1.0 has a released
   section on `main`, `/download/` shows "Coming soon". If `main` moved meanwhile, `git pull --no-rebase`
   first: a rebase would leave the tagged commit off `main`.
6. **Verify on a Mac.** Download `Whydunit-1.0.0.dmg` from the releases repo, then:
   ```sh
   xcrun stapler validate Whydunit-1.0.0.dmg
   spctl -a -vvv -t open --context context:primary-signature Whydunit-1.0.0.dmg   # accepted, source=Notarized Developer ID
   ```
   Open the DMG, drag the app to Applications and launch it. There should be no Gatekeeper warning. Then check:
   ```sh
   spctl -a -vvv /Applications/Whydunit.app
   codesign -dvv /Applications/Whydunit.app      # Authority=Developer ID Application, Timestamp=, flags=0x10000(runtime)
   lipo -archs /Applications/Whydunit.app/Contents/MacOS/Whydunit   # x86_64 arm64
   ```
7. **Check the update path.** Fetch `SUFeedURL`: the new `<item>` has a `sparkle:edSignature` and a
   `<description>` with the release notes. In the previous version, choose Whydunit › Check for Updates…; it
   should show the notes, then download and install the new build. Check that
   `https://github.com/OWNER/whydunit-releases/releases/latest/download/Whydunit.dmg` downloads this version.

**Before the first public release,** tag a throwaway `v0.0.1`, install it, then tag `v0.0.2` and update to it via
Sparkle. This proves that the certificate, notarization and the Sparkle key pair work end to end. Each tag needs a `CHANGELOG.md` section: commit them on a throwaway branch,
not `main`, so the website never lists them. Remove the releases and appcast items afterwards
([GO_LIVE.md](GO_LIVE.md) step 8).

If a release is broken, don't reuse its version, because Sparkle clients may already have seen it. Remove it from
the releases repo (`gh release delete vX.Y.Z -R OWNER/whydunit-releases --cleanup-tag`), revert its item in
`appcast.xml` on `gh-pages`, fix the problem and tag the next patch version.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `security import` fails with `-25264 MAC verification failed` | Re-export the `.p12` with the legacy flags in step 2. |
| codesign: "unable to build chain to self-signed root" | Import Apple's Developer ID G2 intermediate (`https://www.apple.com/certificateauthority/DeveloperIDG2CA.cer`) into the CI keychain in the import step. |
| Notary log: "not signed with a valid Developer ID certificate" or "no secure timestamp" | Check that the identity is *Developer ID Application*, not Apple Development, and that `OTHER_CODE_SIGN_FLAGS=--timestamp` is set. |
| notarytool returns 401 | A Team key needs `--issuer`. Check `ASC_ISSUER_ID` and that the key wasn't revoked. |
| Sparkle: "update is improperly signed" | `SUPublicEDKey` in the shipped app doesn't match `SPARKLE_ED_PRIVATE_KEY`. |
| Preflight: "CHANGELOG.md needs a '## X.Y.Z — …' section" | Add the section (em dash, ISO date, at least one line of notes), commit, delete the tag and push it again. |
| Preflight: "SUPublicEDKey … is not the public key of SPARKLE_ED_PRIVATE_KEY" | Paste the public key that `tools/sparkle_keys.py` printed with the private key, or set the secret to the matching private key. Never regenerate the pair after a public release. |
| "Sparkle.framework is missing" or "is not universal" | Check the Sparkle package and dependency in `project.yml`, and that the archive ran with `ARCHS="arm64 x86_64"`. |
| Launch smoke test: "quit within 10 s of launch" | Read the crash report printed below the error. Crashes that happen only on the Intel job usually mean an arm64-only binary, or an API newer than macOS 15. |
