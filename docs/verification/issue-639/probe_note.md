# Is "no request" a real signal?

The test "demo sign-in to home sends nothing over the network" records
requests with an interceptor inserted at index 0 of the API client's Dio, so
it sees every request before any other interceptor can delay or cancel it.

Probe (temporary test, not committed): same pump and interceptor, but
`DemoAuth.debugEnabledOverride = false` and the credentials typed into the
form, so the real `AuthRemoteDataSourceImpl` is used. Output:

    PROBE requests: [POST /auth/login]

So the recorder does see the real login request; on the demo path the list
stays empty. A first version recorded at the HTTP adapter instead and saw
nothing even on the real path (the request deadline cancelled it in fake
time before it reached the transport) - which is why the recorder sits at the
front of the interceptor chain.
