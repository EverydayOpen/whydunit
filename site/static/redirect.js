// The JS half of a redirect page (BUILD_PLAN §9.2): the <meta http-equiv="refresh"> does the same without JS.
// A file, not an inline script, so the Content-Security-Policy can forbid inline code.
const go = document.querySelector('meta[http-equiv="refresh"]');
if (go) location.replace(go.content.slice(go.content.indexOf('url=') + 4));
