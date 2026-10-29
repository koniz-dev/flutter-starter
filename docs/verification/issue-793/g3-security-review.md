# G3 security review of fd1b58c6af7 (#840)

Reviewed together with #839; full notes are in issue-792/g3-security-review.md. For this change:
- A refresh does not advance the generation. Only login, register, logout and `_logoutUser` do. So requests queued under the current session are still replayed after a successful refresh.
- Unstamped requests (foreign-origin, or never through `onRequest`) keep the previous behaviour.
- A caller-forged stamp in `extra` comes from app code, not a remote party, and can only fail the caller's own request.
- `onRequest` uses `putIfAbsent`, so `RetryInterceptor` re-sends keep the original stamp.
- Session-ended rejections go through `_reject` (`retryExtraKey = false`), so they are not re-sent.

No findings.
