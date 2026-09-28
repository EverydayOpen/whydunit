#!/usr/bin/env bash
# What's configured and what's next before go-live (docs/GO_LIVE.md). Runs in Git Bash on Windows and on macOS.
#   bash tools/doctor.sh        ok/todo lines; also checks the live site and GitHub secrets when it can. Exits 0.
#   bash tools/doctor.sh --ci   offline; exits 1 only on an error (base URLs that disagree, update signing checks off).
# Placeholders (REPLACE_…, OWNER) are todos, not errors: they are expected until go-live.
cd "$(dirname "$0")/.." || exit 1
CI_MODE=; [ "${1:-}" = --ci ] && CI_MODE=1
errors=0 todos=0 BASE=
ok()   { printf 'ok     %s\n' "$*"; }
todo() { printf 'todo   %s\n' "$*"; todos=$((todos + 1)); }
err()  { printf 'ERROR  %s\n' "$*"; errors=$((errors + 1)); }
placeholder() { case "$1" in "" | *REPLACE* | *OWNER*) return 0 ;; *) return 1 ;; esac; }
json() { [ -f site/site.json ] && sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" site/site.json | head -1; }
plist() { grep -A1 "<key>$1</key>" App/Info.plist 2>/dev/null | sed -n 's#.*<string>\(.*\)</string>.*#\1#p'; }

# 1. One base URL everywhere (BUILD_PLAN §10.2). The first real one found is the reference.
base() {  # file, what, URL without the trailing slash
    if [ ! -f "$1" ]; then todo "$1: missing (BUILD_PLAN §10.2)"
    elif [ -z "$3" ]; then todo "$1: couldn't read $2; expected https://OWNER.github.io/whydunit or https://<domain> (BUILD_PLAN §10.2)"
    elif placeholder "$3"; then todo "$1: $2 $3 is a placeholder; put your GitHub user in place of OWNER (docs/GO_LIVE.md step 2)"
    elif [ -z "$BASE" ] || [ "$3" = "$BASE" ]; then BASE=$3; ok "$1: $2 $3"
    else err "$1: $2 is $3 but the other files say $BASE (BUILD_PLAN §10.2: one base URL everywhere)"
    fi
}
FEED=$(plist SUFeedURL)
WEB=$(grep -m1 'let website' App/Links.swift 2>/dev/null | grep -o 'https://[^"]*')
base site/site.json baseURL "$(json baseURL)"
base App/Links.swift Links.website "${WEB%/}"
base App/Info.plist "SUFeedURL minus /appcast.xml" "${FEED%/appcast.xml}"
[ "$FEED" = "${FEED%/appcast.xml}" ] && [ -n "$FEED" ] && err "App/Info.plist: SUFeedURL $FEED must end in /appcast.xml"

# 2. Placeholders.
for K in SUVerifyUpdateBeforeExtraction SURequireSignedFeed; do   # updates must be EdDSA-checked before they're opened
    if grep -A1 "<key>$K</key>" App/Info.plist 2>/dev/null | grep -q '<true/>'; then ok "App/Info.plist: $K on"
    else err "App/Info.plist: $K must be <true/> (Sparkle checks the update's and the feed's EdDSA signatures)"; fi
done
KEY=$(plist SUPublicEDKey)
if [[ $KEY =~ ^[A-Za-z0-9+/]{43}=$ ]]; then ok "App/Info.plist: SUPublicEDKey set"
else todo "App/Info.plist: SUPublicEDKey isn't a Sparkle public key; run python tools/sparkle_keys.py (docs/RELEASING.md step 4)"; fi
while IFS= read -r hit; do
    case "$hit" in
        *'"owner"'* | *governingLaw*) next="your legal name and governing law, from the legal review (docs/GO_LIVE.md step 6)" ;;
        *OWNER*) next="your GitHub user or organization in place of OWNER (docs/GO_LIVE.md step 2)" ;;
        *) next="see docs/GO_LIVE.md" ;;
    esac
    todo "${hit%%:*}: placeholder on line $(echo "$hit" | cut -d: -f2); set $next"
done < <(grep -rnIE 'REPLACE_|OWNER' App Sources site/site.json 2>/dev/null \
         | grep -vE '^App/Info.plist:|"baseURL"|let website|^[^:]+:[0-9]+:[[:space:]]*//')   # section 1 covers those

# 3. Go-live: the first release's changelog row (project.yml's version stays 1.0.0; release.yml's preflight checks every tag's row).
VER=$(sed -n 's/.*MARKETING_VERSION:[[:space:]]*"\([^"]*\)".*/\1/p' project.yml)
if grep -q "^## $VER — [0-9]" CHANGELOG.md 2>/dev/null; then ok "CHANGELOG.md: has a $VER section"
else todo "CHANGELOG.md: on release day rename '## Unreleased' to '## $VER — <that day>' (release.yml refuses the tag without it)"; fi

# 4. Legal pages reviewed by a person (site/site.json "legalReviewed": true).
if grep -qE '"legalReviewed"[[:space:]]*:[[:space:]]*true' site/site.json 2>/dev/null; then ok "site/site.json: legal pages reviewed"
else todo "site/site.json: have the terms and privacy pages reviewed, then set \"legalReviewed\": true (docs/GO_LIVE.md step 6)"; fi

# 5. Live checks: the site on GitHub Pages and the release secrets. Skipped in CI (no network or token needed there).
if [ -z "$CI_MODE" ]; then
    if [ -z "$BASE" ]; then todo "the live site can't be checked until the base URL is set (docs/GO_LIVE.md step 2)"
    elif curl -fsS --max-time 10 -o /dev/null "$BASE/" 2>/dev/null; then ok "$BASE/ is live"
    else todo "$BASE/ doesn't load: enable Pages on this repo (Settings › Pages › Deploy from a branch › gh-pages / root) and push main to deploy the site (docs/GO_LIVE.md steps 2 and 6)"; fi
    if gh repo view --json name > /dev/null 2>&1; then
        # Admin-only repo settings (docs/RELEASING.md step 6). on PATH JQ: the API's answer is exactly true.
        on() { [ "$(gh api "repos/{owner}/{repo}/$1" --jq "$2" 2>/dev/null)" = true ]; }
        on environments/release/deployment-branch-policies '[.branch_policies[] | .type + " " + .name] == ["tag v*"]' \
            && on environments/release 'any(.protection_rules[]; .type == "required_reviewers")' \
            && ok "GitHub env release: v* tags only, required reviewer" \
            || todo "GitHub env release: needs Selected tag v* and a required reviewer, before any secret goes in (docs/RELEASING.md step 6)"
        on environments/site/deployment-branch-policies '[.branch_policies[] | .type + " " + .name] == ["branch main"]' \
            && ok "GitHub env site: main only" || todo "GitHub env site: set Deployment branches to Selected, branch main (docs/RELEASING.md step 6)"
        on rules/branches/main 'map(.type) | contains(["deletion", "non_fast_forward"])' && ok "GitHub: main can't be force-pushed or deleted" \
            || todo "GitHub: add a branch ruleset on main that blocks force pushes and deletion (docs/RELEASING.md step 6)"
        on immutable-releases .enabled && ok "GitHub: immutable releases on" \
            || todo "GitHub: turn on immutable releases (docs/RELEASING.md step 6)"
        on private-vulnerability-reporting .enabled && ok "GitHub: private vulnerability reporting on" \
            || todo "GitHub: turn on private vulnerability reporting, SECURITY.md sends reports there (docs/RELEASING.md step 6)"
        on code-scanning/default-setup '.state == "configured"' && ok "GitHub: CodeQL default setup on" \
            || todo "GitHub: turn on CodeQL default setup (docs/RELEASING.md step 6)"
    fi
    if SECRETS=$(gh secret list --env release 2>/dev/null); then
        # A PAT only for a separate releases repo: publishing to this repo uses the workflows' own github.token.
        SEP=; [ "$(json releasesRepo)" = "$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)" ] || SEP=1
        for s in DEVELOPER_ID_P12_BASE64 DEVELOPER_ID_P12_PASSWORD KEYCHAIN_PASSWORD DEVELOPMENT_TEAM ASC_KEY_P8_BASE64 \
                 ASC_KEY_ID ASC_ISSUER_ID SPARKLE_ED_PRIVATE_KEY ${SEP:+RELEASES_REPO_TOKEN}; do
            echo "$SECRETS" | cut -f1 | grep -qx "$s" && ok "GitHub env release: secret $s" \
                || todo "GitHub env release: add secret $s (docs/RELEASING.md step 6)"
        done
        if [ -n "$SEP" ]; then
            gh secret list --env site 2>/dev/null | cut -f1 | grep -qx RELEASES_REPO_TOKEN && ok "GitHub env site: secret RELEASES_REPO_TOKEN" \
                || todo "GitHub env site: add secret RELEASES_REPO_TOKEN, site.yml deploys with it (header of .github/workflows/release.yml)"
            gh variable list 2>/dev/null | cut -f1 | grep -qx RELEASES_REPO && ok "GitHub: variable RELEASES_REPO" \
                || todo "GitHub: add variable RELEASES_REPO (header of .github/workflows/release.yml)"
        fi
    else
        todo "GitHub secrets not checked (needs gh, gh auth login, a GitHub remote and the release environment); see docs/RELEASING.md step 6"
    fi
fi

echo "$todos todo, $errors error(s)"
[ -n "$CI_MODE" ] && [ "$errors" -gt 0 ] && exit 1
exit 0
