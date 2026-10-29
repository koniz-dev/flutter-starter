# G3 security review of f1e3b1a3394 (#843) and cc71fcc2a57 (#842)

A `security` subagent reviewed both commits, read-only, with probes in a throwaway clone. It found **no security findings.**

**#843 (this issue)**
- 276 combinations of a real `AuthInterceptor` with a recording adapter, none of which put `Authorization` on a host other than the API's:
  - 6 base URLs: origin-only, `/v1`, `/v1/`, uppercase, userinfo, explicit `:443`;
  - times 23 paths: `@`, `.`, `HTTPS://`, `//`, backslashes, `https:evil`, `%40`, ports, `/../../@`, a trailing dot, leading whitespace;
  - each with and without a query parameter.
- A bad `baseUrl` cannot reach the interceptor, because dio's setter parses it.
- In 27 base/path pairs, the 401 replay went to exactly the URI that had been judged.
- Not findings:
  - a per-request `baseUrl` through the raw `ApiClient.dio` escape hatch, which is documented as not for requests;
  - a bare `Dio` with no base URL, which counts every request as the API's by design.

**#842 (koniz-dev/flutter-starter#794)**
- The release refusal holds across:
  - ENVIRONMENT case and whitespace (the value is trimmed and lowercased);
  - dart-define vs `.env` precedence (a bundled `.env` wins only in the safe direction);
  - web, since `flutter build web` is release mode.
- Pinning that turns on because fingerprints are set changes nothing on web (`!kIsWeb` guards).
- `.env.production` and `.env.staging` are git-ignored; `check_env_assets` flags any `.env.*` asset.
- Not security, filed as koniz-dev/flutter-starter#844: `build.yml` defaults its manual input to `development` and builds a release, so a default dispatch now yields artifacts that refuse to start. `build_all.sh development` has the same problem.
