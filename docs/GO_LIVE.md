# Going live: from zero to the first public release

Whydunit is free (BUILD_PLAN §10): there are no payments, taxes, refunds or licence keys to set up. Do the steps in
order; each one unblocks the next. `bash tools/doctor.sh` shows what's configured and what's still open. Signing,
notarization and Sparkle details live in [RELEASING.md](RELEASING.md); this file covers everything around them.
Anything marked **VERIFY** wasn't confirmed against the provider's docs, so check it there when you get to it.

`OWNER` below is your GitHub user or organization name. Until you replace it, the site's address is the placeholder
`https://OWNER.github.io/whydunit-releases`.

## 1. Name check (before anything goes public)

"Whydunit" is a working name (BUILD_PLAN §1). A knockout search is a quick screen for obvious conflicts, not a
legal clearance.

- Search "Whydunit" and close variants ("Whydunnit", "Whodunit") for software in Nice classes **9**
  (downloadable software) and **42** (software services):
  - USPTO: https://tmsearch.uspto.gov/
  - WIPO Global Brand Database (many national registers): https://branddb.wipo.int/
  - EU and member-state offices via TMview: https://www.tmdn.org/tmview/
  - India, IP India public search: https://tmrsearch.ipindia.gov.in/tmrpublicsearch/ (**VERIFY** the address)
  - The Mac App Store, Setapp, and a web search for "Whydunit app" and "Whydunit Mac".
- If a live mark or a shipping app uses the same or a confusingly similar name for software, pick another name
  now. It appears in only a few places (BUILD_PLAN §1), plus the releases repo's name if you change that too. If you
  want to register the mark, ask a trademark attorney.

## 2. GitHub account, releases repo and GitHub Pages

1. **GitHub account.** The free plan is enough if both repos are public. The releases repo must be public. On
   GitHub Free the source repo (this one) must be public too: in a private repo, the `release` and `site`
   environments, their secrets and their `v*`/`main` rules need GitHub Pro or higher
   ([environments](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments)),
   and required reviewers work only in a public repo on Free, Pro and Team
   ([reviewers](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments)).
   A public repo also runs standard GitHub-hosted runners, macOS included, for free. A private one spends its plan's
   included minutes, macOS at a higher rate, and `ci.yml` runs two macOS jobs (the Xcode 26 build and a non-blocking
   Xcode 27 early-warning build) on every push to main and every pull request; deleting the `xcode-27` job halves
   that (**VERIFY** current Actions pricing in GitHub's billing docs).
2. **Source repo.** The push below makes this folder public. From this folder, with `gh` logged in, first run
   `git init -b main && git add -A && git status --ignored`. Every file staged to commit becomes public, so check
   that no key material or secrets are among them (RELEASING.md keeps them outside the repo), and check the ignored
   files too. Then:
   `git commit -m "Initial commit" && gh repo create whydunit --public --source . --push`.
   Keep `-b main`: `ci.yml` and `site.yml` run only on `main`. This push starts `ci.yml`'s first macOS run, and a
   `site.yml` run that fails its `site/site.json` checks until steps 2.5, 5 and 6.1 are done; that failure is
   expected.
3. **Releases repo.** Create the public repo `OWNER/whydunit-releases` and its empty `gh-pages` branch (RELEASING.md
   step 5). Its Releases hold the DMGs; its `gh-pages` branch holds the website (`site.yml`) and `appcast.xml`
   (`release.yml`). Leave **Issues** turned on (Settings › General › Features): the site's support page, which the app's
   Help menu opens, sends people there.
4. **Turn on Pages.** In the releases repo, open Settings › Pages › Build and deployment › Source: **Deploy from a
   branch**, then Branch: `gh-pages`, folder `/ (root)`, and **Save**. The site is then served at
   `https://OWNER.github.io/whydunit-releases/`.
5. **Replace `OWNER`** in the base URL in these three places, in lower case (`release.yml` compares the URLs as text
   with the lower-case Pages address), then run `bash tools/doctor.sh`. It must show no `ERROR` lines:
   - `site/site.json` › `baseURL` = `https://OWNER.github.io/whydunit-releases` (no trailing slash), and
     `releasesRepo` = `OWNER/whydunit-releases`;
   - `App/Links.swift` › `Links.website` = the same URL;
   - `App/Info.plist` › `SUFeedURL` = the same URL followed by `/appcast.xml`.

   `SUFeedURL` is baked into every copy you ship, so settle it, and whether you want a custom domain (step 3), before
   the first public release.
   `release.yml` refuses to build while `OWNER` remains in `SUFeedURL`, `baseURL` or `Links.website`, and checks
   that `SUFeedURL` is where `gh-pages` is served.

## 3. Optional: a custom domain

Skip this unless you want your own domain; `OWNER.github.io` works as is.

1. Buy the domain. A `.app` domain is HSTS-preloaded, so browsers load it only over HTTPS: the site stays
   unreachable until GitHub Pages has issued its certificate.
2. Verify the domain for your GitHub account first (your profile's Settings › Pages › **Add a domain**; GitHub shows
   a TXT record to add). This stops anyone else from taking the domain over on GitHub Pages.
3. Add these records at your DNS host:

   | Type | Name | Value |
   |---|---|---|
   | A | `@` | `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153` (four records) |
   | AAAA | `@` | `2606:50c0:8000::153`, `2606:50c0:8001::153`, `2606:50c0:8002::153`, `2606:50c0:8003::153` |
   | CNAME | `www` | `OWNER.github.io` |

   Don't add wildcard (`*`) records that point at GitHub Pages.
4. In the releases repo, open Settings › Pages › Custom domain, enter the domain and save. GitHub commits a `CNAME`
   file to `gh-pages`, which `release.yml` and `site.yml` never overwrite. Tick **Enforce HTTPS** when it becomes
   available, which can take up to 24 hours.
5. Change the base URL in the three places from step 2.5 to `https://<domain>` (no path) and run
   `bash tools/doctor.sh`. With a `CNAME` on `gh-pages`, `release.yml` expects `SUFeedURL` =
   `https://<domain>/appcast.xml`.

Adding a domain after the first public release: GitHub redirects the `github.io` address to the custom domain, so
older copies should still find their updates, but **VERIFY** with an installed older build that Sparkle follows the
redirect before you rely on it. If you ever publish a support email address on the domain, set up SPF, DKIM and
DMARC for it with your mail host (one SPF record per domain; start DMARC at `p=none`).

## 4. Apple Developer Program, certificates and Sparkle keys

Still needed for a free app: without a Developer ID signature and Apple's notarization, macOS Gatekeeper refuses to
open a downloaded app without a trip to System Settings. Follow RELEASING.md steps 1 to 4: enrollment (Individual,
$99 a year; in India only through the Apple Developer app), the Developer ID Application certificate, the App Store
Connect Team API key, and the Sparkle key pair (the public key goes into `App/Info.plist` › `SUPublicEDKey`).
Enrollment approval isn't instant, so start it alongside steps 1 to 3.

## 5. GitHub secrets and variable

Follow RELEASING.md step 6: the `release` environment and its nine secrets, the `site` environment and its copy of
`RELEASES_REPO_TOKEN`, and the `RELEASES_REPO` variable (`OWNER/whydunit-releases`, the same as `site/site.json` ›
`releasesRepo`). With `gh` logged in, `bash tools/doctor.sh` lists any secret that's still missing.

## 6. Website live and legal review

1. Fill in `site/site.json` (`owner` and `governingLaw` are named on the legal pages; `site.yml` refuses to deploy
   until they're set), run `python tools/build_site.py --check`, and push `main`: `site.yml` publishes the site to
   `gh-pages`. `/download/` shows "Coming soon" until `CHANGELOG.md` on `main` has a released section (step 8.2).
   `bash tools/doctor.sh` then reports the site as live.
2. **Legal review.** The terms and privacy pages are drafts written by an AI, not a lawyer. Have a lawyer check them
   against:
   - the terms for free software: provided as is, no warranty, limitation of liability, use on any number of Macs,
     no redistribution of modified builds. Consumer law in your country and your main users' countries may not
     allow excluding all liability, even for something given away;
   - what the app actually does: no telemetry and no account; a scan reads file status only, while Back Up reads the
     files it copies; the app goes online only for update checks (the appcast on GitHub Pages, DMGs from GitHub
     Releases) and a 1 MB test upload to the user's own iCloud Drive during each scan (CHANGELOG.md);
   - GitHub as host of the site, the downloads and the update feed: it sees visitors' IP addresses (GitHub's privacy
     statement; **VERIFY** what it logs for Pages and release downloads);
   - the contact route for privacy requests: GitHub Issues are public, so ask whether you also need a private one.
3. When the review is done, set `"legalReviewed": true` in `site/site.json` and push `main` to redeploy.

## 7. Placeholders

Run `bash tools/doctor.sh` until it reports no `todo` lines, or only ones you have decided to accept. `release.yml`
refuses to build while `SUPublicEDKey` is still the placeholder, while `OWNER` remains in `SUFeedURL`, `baseURL` or
`Links.website`, while the three base URLs disagree, while `SUFeedURL` isn't where `gh-pages` is served, or while
`site/site.json`'s `releasesRepo` isn't the `RELEASES_REPO` variable.

## 8. First release

1. **Rehearse** as RELEASING.md describes under "Before the first public release": tag `v0.0.1`, install it, then
   tag `v0.0.2` and update to it with Sparkle. Each tag needs its own `CHANGELOG.md` section, or the preflight
   refuses it; commit those sections on a throwaway branch, not `main`, so the website (deployed from `main`) never
   lists them. Afterwards, delete both releases (`gh release delete vX.Y.Z -R OWNER/whydunit-releases --cleanup-tag`)
   and remove their items from `appcast.xml` on `gh-pages`.
2. On release day, rename `## Unreleased` in `CHANGELOG.md` to `## 1.0.0 — <that day>` and commit it, then tag and
   push only `v1.0.0`. Push `main` once the release is published (RELEASING.md "Cutting a release"): that push
   deploys the site, and `/download/` stops showing "Coming soon".

## 9. Post-release checks

- `<baseURL>/download/` downloads the new DMG
  (`https://github.com/OWNER/whydunit-releases/releases/latest/download/Whydunit.dmg`). It opens and the app
  launches without a Gatekeeper warning. The release workflow already launched it on Apple silicon and Intel.
- `<baseURL>/appcast.xml` has the new item with a `sparkle:edSignature` and its release notes. An older copy
  finds the update through Check for Updates….
- `/changelog/` and `/feed.xml` show the release. Every page's footer links terms, privacy and support, and the
  support page leads to the releases repo's Issues.
- In the app, the Help menu's links open the right pages under the base URL, and every action (Back Up, Retry
  Upload, Restart iCloud Sync) works without any licence prompt.
- For the first weeks, watch the releases repo's Issues and the Actions runs.
