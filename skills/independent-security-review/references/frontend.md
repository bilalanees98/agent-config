# Frontend security hunt checklist

Sections 1–6 are the hot spots: `effort=low` covers only these. `medium` and `high` cover every section. Each item is a question to answer from the code.

The frontend runs on the attacker's machine. Anything it hides, checks, or computes, a user can change with devtools or a proxy. So a frontend finding is usually one of three things: the page runs someone else's input as code, the page leaks something to people or scripts that shouldn't have it, or the page enforces a rule that only the server can enforce.

Server code inside a frontend repo (Next.js API routes, route handlers and server actions, `getServerSideProps`, Remix and React Router loaders and actions, Nuxt `server/`, SvelteKit `+page.server.*` and `+server.*`, Angular SSR server files) is backend code. Review it with [backend.md](backend.md). This checklist covers what reaches the browser, including the data those server files serialize into the page (section 11).

## Contents and OWASP mapping

Tag each finding with the category below. Use the OWASP Top 10 (2021) ID, or the OWASP Top 10 Client-Side Security Risks ID (C1–C10) when it describes the issue better.

| # | Section | OWASP |
|---|---|---|
| 1 | Authorization enforced only in the UI | A01 Broken Access Control, C1 Broken Client-side Access Control |
| 2 | XSS and unsafe HTML | A03 Injection, C2 DOM-based XSS |
| 3 | DOM-based injection from URL and page data | A03 Injection, C2 DOM-based XSS |
| 4 | Tokens and personal data in browser storage | A07 Identification and Authentication Failures, C7 Sensitive Data Stored Client-side |
| 5 | Secrets and internal details in client bundles | A05 Security Misconfiguration, C10 Including Proprietary Information on the Client-Side |
| 6 | Trusting values the client sends back | A04 Insecure Design, C1 |
| 7 | Redirects and return URLs | A01 Broken Access Control (open redirect) |
| 8 | Cross-window messaging and web views | A03, A01, C2 |
| 9 | CSP, framing, and clickjacking | A05, C9 Not Using Standard Browser Security Controls |
| 10 | CSRF on cookie-authenticated calls | A01 Broken Access Control |
| 11 | SSR and hydration data leaks | A01, C3 Sensitive Data Leakage |
| 12 | Over-fetching | C3, API3 Broken Object Property Level Authorization |
| 13 | Third-party scripts and SRI | A08 Software and Data Integrity Failures, C5 Lack of Third-party Origin Control, C6 JavaScript Drift |
| 14 | Dependencies in the bundle | A06 Vulnerable and Outdated Components, C4 |
| 15 | Logs, analytics, and error reporting | A09 Security Logging and Monitoring Failures, C3, C8 |

## 1. Authorization enforced only in the UI

- For every route guard (React Router loaders or wrappers, Vue Router `beforeEach`, Angular `canActivate`, Next.js middleware, Svelte `load` redirects) and every role-gated button or menu, find the API call behind it. Does the server check the same rule? A hidden button or a client-side redirect is a UX choice, not a control.
- Does the client decide what a user may do from a decoded JWT, a cached profile, or a role flag in storage, and then call an API that trusts the client's decision?
- Are paid or admin features gated by client-side feature flags or plan checks with no server-side check?
- Is the admin UI shipped in the same bundle as the user UI, so its routes, API paths, and payload shapes are visible to everyone? That's fine only if every one of those APIs checks the role.
- When the backend isn't in scope, write each "server must enforce X" as an open question for the backend owner. Don't assume either way.

## 2. XSS and unsafe HTML

- Is untrusted data rendered as HTML? Sinks: React `dangerouslySetInnerHTML`, Vue `v-html`, Svelte `{@html}`, Angular `[innerHTML]` and `bypassSecurityTrustHtml/Url/ResourceUrl/Script/Style`, `innerHTML`, `outerHTML`, `insertAdjacentHTML`, `document.write`, jQuery `.html()`, `.append()` with strings, and `$(userString)`.
- Is a sanitizer used at each sink, and is it configured safely? Check DOMPurify options (`ADD_TAGS`, `ADD_ATTR`, `ALLOW_UNKNOWN_PROTOCOLS`), hand-written regex sanitizers, and whether the value is changed after sanitizing.
- Does markdown or rich-text rendering allow raw HTML? Look for `marked` without a sanitizer, `markdown-it` with `html: true`, `react-markdown` with `rehype-raw`, and WYSIWYG editors whose saved HTML is rendered elsewhere without sanitizing.
- Can a user-controlled URL reach `href`, `src`, `formaction`, `xlink:href`, or `window.open`? A `javascript:` or `data:` URL runs script even in frameworks that escape text.
- Is a string passed to `eval`, `new Function`, `setTimeout` or `setInterval`, or a template compiled at runtime (Vue runtime templates, Angular JIT, `v-bind` on user-built templates)?
- Is user content rendered as SVG, or uploaded files served from the app's origin so a crafted SVG or HTML file runs as the app?

## 3. DOM-based injection from URL and page data

- Trace sources an attacker controls to the sinks in section 2 and to navigation: `location.search`, `location.hash`, `URLSearchParams`, route params, `document.referrer`, `window.name`, `postMessage` data (section 8), and storage values another page or script could have written.
- Does a query string or JSON get deep-merged into an object (`qs` with nested parsing, lodash `merge`, `$.extend(true, ...)`)? Client-side prototype pollution can turn into XSS through library gadgets.
- Is a URL or hash value used as a selector, an import path, a script `src`, or an API path segment without validation?

## 4. Tokens and personal data in browser storage

- Are access tokens, refresh tokens, API keys, or session IDs kept in `localStorage`, `sessionStorage`, IndexedDB, persisted state (`redux-persist`, `pinia-plugin-persistedstate`), or cookies set from JavaScript (no `HttpOnly`)? Any XSS on the origin can read them. Prefer `HttpOnly` cookies or in-memory tokens.
- Is personal data (profile, health, payment, location) persisted in storage or service-worker caches beyond the session? Is it cleared on logout and on account switch?
- Do service workers cache authenticated API responses where another user on the same device could read them?

## 5. Secrets and internal details in client bundles

- Do public env prefixes carry secrets? Check `NEXT_PUBLIC_*`, `VITE_*`, `REACT_APP_*`, `EXPO_PUBLIC_*`, `PUBLIC_*` (SvelteKit), Nuxt `runtimeConfig.public`, and Angular `environment*.ts`. Everything under them is shipped to every visitor. Only values safe to publish belong there (publishable payment keys, public analytics IDs).
- Are secret keys, service-account JSON, private API tokens, or admin keys imported into client code, even in a file meant for the server, when a bundler can pull it into the client graph? Check `"use client"` boundaries and props passed from server to client components.
- Are internal hostnames, staging or admin URLs, internal API paths, or feature-flag names for unreleased work in the bundle? These are usually `minor` unless they unlock something.
- Are source maps shipped to production? Check `productionBrowserSourceMaps` (Next.js), `build.sourcemap` (Vite), `GENERATE_SOURCEMAP` (CRA), `productionSourceMap` (Vue CLI), and Angular `sourceMap`. Uploading them to an error tracker is fine. Serving them publicly exposes the full source and its comments.
- Use the same grep patterns as the backend checklist's secrets section on the client source and any committed build output.

## 6. Trusting values the client sends back

- Does the client send a price, total, discount, currency, quantity limit, role, user ID, tenant ID, `isAdmin`, `verified`, or eligibility result that the server could use as-is? The server must recompute or look these up. Flag it here, and confirm on the server at `surface=fullstack`.
- Do hidden form fields, disabled inputs, or read-only fields carry values the server trusts?
- Is validation done only in the client (form schema, `maxlength`, `pattern`, file type checks), with no matching server check?
- Are CAPTCHA results, OTP checks, or "step completed" flags decided in the client and only reported to the server?

## 7. Redirects and return URLs

- Do `next`, `returnUrl`, `redirect`, `callback`, or `continue` params feed `window.location`, `router.push`, `<a href>`, or a server redirect without an allowlist?
- Is the check strong enough? `startsWith('/')` lets `//evil.com` and `/\evil.com` through. `includes('example.com')` lets `example.com.evil.com` through. Parse with `new URL()` and compare the full origin against an allowlist.
- Do OAuth or SSO flows handle `state` and `redirect_uri` safely, and are tokens kept out of URLs that get logged or sent as a `Referer`?

## 8. Cross-window messaging and web views

- Does every `message` listener check `event.origin` against an exact allowlist before using `event.data`? Weak checks like `indexOf`, `includes`, or `endsWith` without a leading dot can be bypassed. Is the data's shape validated before use?
- Does `postMessage` send tokens or personal data with `targetOrigin` set to `'*'`?
- Are `window.opener` references safe? Links with `target="_blank"` to untrusted URLs need `rel="noopener"` (modern browsers default to it, but `window.open` does not).
- Mobile web views: is a native bridge (`addJavascriptInterface`, `WKScriptMessageHandler`, React Native `onMessage`, Capacitor or Cordova plugins) exposed to every page the web view can load? Can deep links or in-app links load an arbitrary URL into a web view that has the bridge? Are file access and universal access from file URLs turned off?

## 9. CSP, framing, and clickjacking

- Is there a Content Security Policy for app pages? Where is it set: a server or framework config (`next.config` headers, middleware, Helmet), a `<meta>` tag, or the CDN? If it's set outside the repo, raise an open question for DevOps.
- Does the CSP allow `'unsafe-inline'` or `'unsafe-eval'` in `script-src`, wildcard hosts, or broad CDNs that serve user content? Are nonces random per response and never reused?
- Are sensitive pages (account settings, payments, admin actions) protected from framing with `frame-ancestors` or `X-Frame-Options`?
- Do embedded iframes of third-party or user content use `sandbox` with only the permissions they need?

## 10. CSRF on cookie-authenticated calls

- If the API uses cookies for auth, does every state-changing call send the CSRF token or custom header the backend expects? Are cookies `SameSite=Lax` or `Strict`?
- Do any GET requests, image loads, or link clicks change state?
- Does the client call APIs with `credentials: 'include'` or `withCredentials: true`, and does the backend's CORS policy allow that only for trusted origins? At `surface=frontend`, write the backend half as an open question.

## 11. SSR and hydration data leaks

- Does server-side data loading (`getServerSideProps`, `getStaticProps`, loaders, Nuxt `useAsyncData` or `useFetch`, SvelteKit `load`, Angular `TransferState`) return whole records that are then serialized into the page (`__NEXT_DATA__`, `window.__NUXT__`, loader JSON)? Everything serialized is visible in the page source, even fields the UI never shows.
- Are server-only values (API keys, DB rows with hashes, internal flags) passed as props to client components?
- Is state serialized into a `<script>` tag with plain `JSON.stringify`? Without escaping `<`, a value containing `</script>` breaks out and runs as HTML.
- Can a personalized page be cached and served to another user? Check `Cache-Control` on authenticated SSR responses, ISR or static generation of pages that read cookies, and CDN cache keys.

## 12. Over-fetching

- Does a component use a few fields from a response that carries many more, especially other users' contact details, internal IDs, roles, or audit data? The browser receives the whole response, and anyone can read it in devtools.
- Do GraphQL queries or fragments select sensitive fields the UI doesn't render?
- Do list views fetch full objects when they show a summary?
- The fix is usually on the server (an explicit response allowlist). Report it at the call site, and name the API that over-returns.

## 13. Third-party scripts and SRI

- Are scripts or styles loaded from CDNs without `integrity` and `crossorigin`? A compromised CDN then runs code as the app.
- Can a tag manager or a config value add scripts at runtime without code review? Who controls it?
- Do third-party widgets (chat, analytics, ads, payments) run in the app's origin with access to the DOM, storage, and forms? Are payment fields in the provider's iframe, not the app's DOM?
- Is any script URL built from user or config input?

## 14. Dependencies in the bundle

- Are new dependencies from the expected registry and scope, maintained, and free of known vulnerabilities? Watch for typosquats and packages with `postinstall` scripts.
- Did a lockfile entry change its `resolved` source or integrity hash without a version change?
- Are sanitizers, markdown renderers, and HTTP or auth libraries on versions with known bypasses?

## 15. Logs, analytics, and error reporting

- Do `console.log` calls, debug panels, or Redux devtools in production builds print tokens, full user objects, or API responses?
- Does error reporting (Sentry, Bugsnag, Datadog RUM) scrub tokens, auth headers, and personal data in `beforeSend` or the equivalent? Are request bodies and breadcrumbs captured?
- Does session replay (LogRocket, FullStory, Hotjar, PostHog) mask inputs, especially passwords, payment fields, and personal data?
- Do analytics events or page URLs carry emails, tokens, or IDs? Tokens in URLs also leak through the `Referer` header. Check `Referrer-Policy`.
