# G3 security review of 08f3f3f1482 (#883) and 9c45817ee84 (#884)

A read-only `security` subagent found **no security findings**.
- #883: no half-written state. Both token writes come after parsing and after the generation check, so a `TypeError` from `fromJson` lands before any write. It creates no new forced-logout vector: a malformed body already ended the session through the interceptor's catch-all, and a server can always answer 400/401/403. It never returns `Success` on failure. The caught object is discarded and never logged. One improvement: the generation is now checked before logging out.
- #884: the only `AppException` carried in the chain today is `REQUEST_BODY_NOT_REPLAYABLE`, whose message holds a runtime type and no URL or token. A server cannot choose the exception, because dio's transformer throws `FormatException`. No carried `AuthException` or 401 `ServerException` exists, so session behaviour is unchanged.
- A behaviour edge with an adopter's custom token store was filed separately.
