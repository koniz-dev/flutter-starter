# G3 security review of e2becae05ef (#839)

A `security` subagent reviewed the change, read-only, with probes in a throwaway clone.

- **Finding (filed as koniz-dev/flutter-starter#841, P1).** `_targetsApiOrigin` judged `Uri.parse(options.path)`. dio joins a relative path to the base URL as strings, so with a base URL that has no path, `@evil.example/x` and `.evil.example/x` reached another host carrying the token. The shipped `/v1` base URL is not exploitable.
- **Checked and sound:**
  - an uppercase host, the `:443` default port, userinfo, backslash tricks, IDN hosts and scheme-relative URLs;
  - `https:evil` and the uppercase `HTTPS://` scheme;
  - `http://` to the API host (no token over cleartext);
  - a malformed URI does not leave a handler uncompleted, because dio 5.11.1 catches errors from async interceptor callbacks;
  - the replay path is reachable only after the origin check passes.
