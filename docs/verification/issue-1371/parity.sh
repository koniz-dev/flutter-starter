#!/bin/bash
# For each URL: the Ruby lane verdict and the shell build verdict, then whether they agree.
. scripts/ci/release_base_url.sh
fail=0
while IFS= read -r u; do
  if ( release_base_url production "$u" ) >/dev/null 2>&1; then sh=accepted; else sh=refused; fi
  rb=$(ruby -e 'require File.expand_path("fastlane/release_environment"); begin; ReleaseEnvironment.for_environment("production", ARGV[0]); print "accepted"; rescue ArgumentError; print "refused"; end' "$u")
  [ "$sh" = "$rb" ] && m=same || { m=DIFFER; fail=1; }
  printf '%-42s shell=%-8s ruby=%-8s %s\n' "$u" "$sh" "$rb" "$m"
done <<'LIST'
https://example.com?x@acme.io
https://example.com#@acme.io
https://example.com..
https://api.example.com../x
HTTPS://API.EXAMPLE.COM/v1
https://user@pw@api.example.com:8443
https://acme.io?x@example.com
https://acme.io/v1#@example.com
https://user@acme.io:8443/v1
https://@/v1
http://api.myco.com
ftp://api.myco.com
https://api.myco.com /x
https://api.ex%61mple.com
https://api.example.com\@good.com
https://api.myco.com
LIST
exit $fail
