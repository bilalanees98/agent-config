# Backend security hunt checklist

Sections 1–6 are the hot spots: `effort=low` covers only these. `medium` and `high` cover every section. Each item is a question to answer from the code. The "Seen" notes are real patterns from past audits. They show one form of the bug, and there are others.

## Contents and OWASP mapping

Tag each finding with the OWASP API Security Top 10 (2023) category below. If none fits, use the general OWASP Top 10 category name (for example "Injection" or "Cryptographic Failures").

| # | Section | OWASP API Top 10 (2023) |
|---|---|---|
| 1 | Entry-point protection | API5 Broken Function Level Authorization, API9 Improper Inventory Management |
| 2 | Authentication and sessions | API2 Broken Authentication |
| 3 | Object and tenant authorization | API1 Broken Object Level Authorization |
| 4 | Data exposure | API3 Broken Object Property Level Authorization |
| 5 | Secrets and sensitive values | API8 Security Misconfiguration, Cryptographic Failures |
| 6 | Database abuse and injection | Injection (OWASP Top 10) |
| 7 | Input handling and mass assignment | API3, Injection |
| 8 | Identity binding and account lifecycle | API2, API6 Unrestricted Access to Sensitive Business Flows |
| 9 | Resource consumption and abuse | API4 Unrestricted Resource Consumption, API6 |
| 10 | Crypto and logging | Cryptographic Failures, Security Logging and Monitoring Failures |
| 11 | Outbound calls, third parties, and message consumers | API7 Server Side Request Forgery, API10 Unsafe Consumption of APIs |
| 12 | Files and shared resources | API8 Security Misconfiguration, Injection |
| 13 | Config, build, and dependencies | API8, Vulnerable and Outdated Components |
| 14 | Errors, legacy, and environment-gated code | API9, API8 |

## 1. Entry-point protection

- Is every new or changed entry point covered by an auth layer that **rejects** requests, rather than one that only annotates them?
  - Seen: an API-key middleware set a flag when the key matched and called `next()` either way. Every route excluded from login with no guard of its own was public.
- Do public-route lists, skip-auth decorators, or bypass globs pick up routes they shouldn't? Check path patterns and HTTP methods separately.
- Does a role or permission check pass when it has no rules or no user? A check that defaults to "allow" makes every route without rules public.
- Does an "internal" or "service-to-service" route rely on network placement alone? Check whether the deployment facts in `context` support that. If they aren't known, raise an open question.
- Are old routes still mounted next to their protected replacements (`/v1/x` next to `/v1/admin/x`)? Is there an undocumented or debug route?

## 2. Authentication and sessions

- Do token or session checks verify signature, expiry, audience, and revocation? Is there a fallback to a weaker credential when the strong one fails?
- For JWTs: is the algorithm pinned on verify, so `alg: none` and HS/RS key confusion (an RSA public key used as an HMAC secret) are rejected? Is a `kid` or `jku` header used to pick a key from a path, URL, or DB lookup the attacker controls?
  - Seen: a failed session-cookie check (revoked) fell back to a second token cookie that was checked without revocation.
- Do sensitive actions (password, email, MFA, recovery changes) re-check the current credential **on the server**?
- After a password change, logout, or revocation, are all cookies and tokens cleared or reissued? Can a stale one still pass any check?
- Are long-lived cookies or tokens sized to the risk? Compare lifetimes across environments.
- Is a signed or encrypted client-held snapshot (cookie, JWT claims) trusted without binding it to the live session's subject or reloading the user's current state?
  - Seen: a profile cookie had no subject ID, so cookies from different logins could be combined.
- Are API keys, reset tokens, OTPs, and invite tokens generated with a CSPRNG, compared in constant time, single-use, and given an expiry?

## 3. Object and tenant authorization

- Does every query that reads or writes owned data scope by the caller's tenant or user ID, taken from the session and never from the request?
- Are IDs in the path or body checked against the caller, or only validated for format? Can a caller swap in another user's or tenant's ID?
- Does a tenant-match check also check the caller's **role**? "Same tenant" is not "allowed".
  - Seen: any tenant user could create an invitation with admin roles.
- Are inactive, suspended, expired, or soft-deleted grants filtered out when permissions are computed?
  - Seen: a permission lookup loaded role grants without a status filter, so deactivated roles still granted access.
- Can a user act on themselves in a way only an admin should, such as unblocking, promoting, or approving themselves?
- Do bulk endpoints check authorization for **every** item, or only for the first item or the container?

## 4. Data exposure

Ask of every response, error, event, and log line: does this caller need every field?

- Does a handler return a raw model or ORM object, or a serializer with all fields, instead of an explicit allowlist? Check nested relations that get eager-loaded.
  - Seen: an unguarded "internal details" route returned the full account record, including metadata and every integration's settings.
- Are secrets, hashes, tokens, internal IDs, other users' contact details, or audit fields (who, when, from which IP) in responses?
- Do list and search endpoints return fields or rows that the single-item endpoint would hide?
- Do error responses include stack traces, SQL, file paths, upstream responses, or validation messages that echo secrets?
- Can a caller enumerate accounts, emails, phone numbers, or IDs by comparing responses, status codes, or timing ("user not found" vs "wrong password")?
- Are IDs guessable (sequential, timestamps) where a guessed ID combined with a weak check in section 3 leaks data?
- Do webhooks, events, or messages sent to other services carry more data than the consumer uses?

## 5. Secrets and sensitive values

Cheap to check, expensive to miss. Grep the target for these at every effort level.

- **Hardcoded secrets.** Are API keys, passwords, tokens, signing keys, private keys, or credentialed connection strings in source, config, seeders, test fixtures, Dockerfiles, CI files, or committed env files? Useful patterns: `(api[_-]?key|secret|token|passw(or)?d|private[_-]?key|client[_-]?secret)\s*[:=]`, `-----BEGIN .*PRIVATE KEY`, `AKIA[0-9A-Z]{16}`, `sk_live_`, `ghp_`, `xox[abprs]-`, `://[^/\s:]+:[^@\s]+@`. Check that `.env*` and credential files are gitignored.
- **Secret fallbacks.** Does missing config fall back to a usable default instead of failing at startup? Look for `process.env.X || 'dev-secret'`, `os.getenv("X", "changeme")`, `${X:default}`, config schemas with a default, or `?? ''`. An empty signing key or a known default password is as bad as a hardcoded one. A secret should have no default, so the service refuses to start without it.
  - Seen: API docs basic auth fell back to built-in default credentials when the env vars were unset.
- **Keys and headers in responses.** Does any response, error, or debug route echo request headers (`Authorization`, `Cookie`, `x-api-key`), outbound request config (HTTP-client errors often carry the full request, auth header included), environment variables, or stored credentials?
  - Seen: a client secret used for end-user auth was stored in plaintext on a profile record and served by routes with no guard.
- **Keys in transit.** Are keys put in URLs or query strings (proxies and access logs record them), forwarded to a third party that doesn't need them (passing the caller's `Authorization` header on), or sent to clients through config or bootstrap endpoints?
- **Header disclosure.** Do responses leak versions or internals (`X-Powered-By`, `Server`, debug headers), or expose sensitive headers to browsers through `Access-Control-Expose-Headers`? These are usually `minor`.

## 6. Database abuse and injection

Anything that makes the database do something it shouldn't: run attacker text, touch another tenant's data, or do far more work than intended.

- **Raw SQL.** Is input concatenated or interpolated into SQL anywhere: raw query helpers, `literal()`, `sequelize.query`, `knex.raw`, `$queryRawUnsafe`, `cursor.execute(f"...")`, `fmt.Sprintf`, string-built stored procedure calls, or dynamic SQL inside the DB? Only bound parameters are safe.
- **Identifiers.** Are table, column, schema, `ORDER BY`, or sort-direction values taken from input? Parameters can't bind identifiers, so these need an allowlist.
  - Watch multi-tenant code that builds a schema name or `search_path` from a request value.
- **Operator and filter injection.** Is a request object passed straight into an ORM `where` or a NoSQL query (`{"$ne": null}`, `{"$where": ...}`, `{"gt": ...}`)? Can a caller filter on columns they shouldn't see, or turn an equality check into "match all"?
- **Pattern queries.** Are `LIKE`, `ILIKE`, regex, or full-text inputs escaped? Unescaped `%` and `_` widen matches. User-supplied regexes can cause ReDoS in the DB.
- **Second-order.** Is data stored safely but later used unsafely in a query, report, or migration?
- **Scope leaks.** Can a query run without its tenant or owner filter: a default scope turned off, a raw query that skips the ORM's tenant hook, or a join that crosses tenants?
- **Tenant context on pooled connections.** If tenancy is a per-connection setting (`SET search_path`, `SET ROLE`, a session variable used by row-level security), is it set inside the same transaction as the query, or reset before the connection goes back to the pool? If not, a later request can run with the previous request's tenant. Check for async-context loss too: a tenant ID kept in a request-scoped store that a background callback, queue handler, or `Promise` chain reads after the request has ended.
- **Unbounded work.** Can a caller trigger queries with no `LIMIT`, an unbounded page size, deep includes or joins, `COUNT(*)` on huge tables, or N calls in a loop?
- **Concurrency.** Do read-check-write sequences (balance, quota, single-use token, inventory) run without a transaction, row lock, or unique constraint, so that parallel requests double-spend?
- **Migrations.** Does a migration drop or relax a unique index, foreign key, check constraint, or row-level-security policy that an authorization or single-use check relies on? Does it grant broader DB privileges, or backfill data across tenants?
- **Destructive paths.** Can input reach a hard delete, cascade, `TRUNCATE`, or a migration-style statement? Does the app connect as a DB superuser or owner when it needs less?

## 7. Input handling and mass assignment

- Is a request body spread into a create or update (`...dto`, `Object.assign`, `update(params)`, `Model(**data)`, `permit!`)? Can the caller set `status`, `role`, `tenantId`, `isAdmin`, `ownerId`, or other privileged fields?
  - Seen: a member PATCH spread the request DTO, which included `status`, so a blocked member could unblock themselves.
- Do create-or-restore and upsert paths revive deleted or blocked records with caller-chosen fields?
- Is untrusted input used in shell commands, template rendering, XML parsing (XXE), deserialization (pickle, Java/YAML object loading), redirects, or file paths?
- Does validation run on every entry point (global pipe, schema, serializer), and does it reject unknown fields and wrong types?

## 8. Identity binding and account lifecycle

- When an account is found by phone, email, or an external ID, has the caller **proven** in this request that they own that identifier?
  - Seen: a signup found an existing identity-provider user by phone number with no ownership check, then linked it to a new member.
- Can a shared external identity (one IdP account used across tenants) be deleted or changed by one tenant's cleanup?
- Do merge, link, and invite-accept flows check that the invite or link belongs to the acting identity?
- Are password-reset, invite, magic-link, or verification URLs built from the request's `Host`, `X-Forwarded-Host`, or `Origin` header? An attacker who sets that header gets the victim's token sent to a host they control. Links should come from configured base URLs.
- Can sensitive business flows (signup, checkout, voucher redemption, referral) be automated or replayed in ways that harm the business?

## 9. Resource consumption and abuse

- Do login, OTP, password reset, signup, lookup, and costly endpoints (SMS, email, payments, AI calls) have rate limits keyed on something an attacker can't rotate?
- Is the client IP taken from `X-Forwarded-For` (first entry) or similar without a trusted-proxy setting? Then rate limits and IP allowlists can be spoofed.
  - Seen: a rate-limit guard used the first `X-Forwarded-For` entry. A TODO in the code admitted that it could be spoofed.
- Are request body size, page size, batch size, upload size, and query complexity (GraphQL depth) capped?
- Can one caller start unbounded background work, such as large exports, fan-out jobs, or retries that never stop?

## 10. Crypto and logging

- Do logs, events, or analytics receive request bodies, headers, full payloads, tokens, passwords, or personal data? Follow interceptors and "log the event" helpers to their sinks.
  - Seen: a logging interceptor sent every request body, passwords included, to a log topic, and a messaging helper printed full payloads to stdout.
- Are passwords hashed with a slow KDF (bcrypt, scrypt, argon2)? Is anything protected with a weak algorithm, a static IV, or `Math.random`?
- Are TLS checks disabled (`rejectUnauthorized: false`, `verify=False`) for databases, caches, or outbound calls?
- Are security events (failed logins, permission denials, admin actions) logged with enough detail to investigate, but without the secrets themselves?

## 11. Outbound calls, third parties, and message consumers

- Can input control a URL, host, or path that the server fetches (webhooks, image fetch, import-from-URL)? Is there an allowlist that blocks internal addresses and cloud metadata endpoints, after redirects too?
- Are incoming webhooks verified by signature and timestamp before they are trusted?
- Do queue, event, and Pub/Sub consumers trust a tenant ID, user ID, or role in the message payload without checking it against the publisher? Who can publish to that topic? Do push endpoints (Pub/Sub push, SNS, Cloud Tasks) verify the provider's signed token and its audience, or are they reachable by anyone who knows the URL?
- Are responses from third-party APIs validated before they are stored or acted on, with timeouts and size limits on the calls?

## 12. Files and shared resources

- Are temp or storage paths built from user-supplied file names? Look for collisions between tenants or requests, path traversal, and overwrites.
  - Seen: uploads were written to `tmpdir/<original filename>`, so two tenants uploading files with the same name at the same time could read each other's rows.
- Are upload type, size, and count limited? Are files parsed safely (zip bombs, CSV formula injection on export)?
- Are cache keys, queue names, and storage buckets scoped by tenant?

## 13. Config, build, and dependencies

- Are CORS origins, cookie flags (`Secure`, `HttpOnly`, `SameSite`, `Domain`), and CSRF defenses right for cookie-authenticated changes?
- Are debug modes, API docs, admin consoles, or default credentials exposed in production config?
- Does the container build copy credentials into the image (`COPY . .` with gaps in `.dockerignore`)?
- Do CI workflows triggered by pull requests get cloud credentials, OIDC `id-token: write`, or secrets?
- Are new dependencies from the expected registry and namespace, maintained, and free of known vulnerabilities? Are images and actions pinned?

## 14. Errors, legacy, and environment-gated code

- Is a dangerous endpoint (delete-any, impersonate, seed, debug) gated only by an environment string, domain check, or flag that a deploy mistake could flip?
- Are test-only or migration-era endpoints still mounted? Report them with their environment scope. Owners often accept the risk, and that decision belongs to them, not to the reviewer.
- Does a failure fail open? Look for a `catch` that grants access, skips a check, or continues with partial state.
- Does a comment like "remove after X" or "temporary" point at code that is still reachable?
