#!/bin/bash
# Sourced, not run: defines release_base_url, which sets BASE_URL to the API
# base URL a staging or production build is compiled with, or refuses.
#
#   . scripts/ci/release_base_url.sh
#   release_base_url "$ENVIRONMENT" "$EXPLICIT_URL" || exit 1
#   flutter build ... --dart-define=BASE_URL="$BASE_URL"
#
# The second argument is an explicit URL (a workflow input, say) and wins when
# it is not empty. Otherwise the URL comes from the environment variable named
# after the build's environment:
#
#   BASE_URL_STAGING      for staging
#   BASE_URL_PRODUCTION   for production
#
# There is no fallback. These builds used to fall back to
# https://api.example.com (or api-staging), so a build run without a URL
# produced an app pointing at a placeholder host, and nothing at startup
# refuses that. The Fastlane lanes refuse it (fastlane/release_environment.rb);
# this is the same rule for the shell builds:
#
#   - the URL must be set;
#   - it must be an absolute https URL, because a staging or production
#     release refuses any other scheme at startup (lib/main.dart);
#   - its host must not be example.com or a subdomain of it;
#   - it must not contain whitespace, "%" or a backslash, which could spell
#     that host in a form this check does not read.
#
# Works on bash 3.2.

release_base_url() {
  local environment="$1"
  local source
  case "$environment" in
    staging) source=BASE_URL_STAGING ;;
    production) source=BASE_URL_PRODUCTION ;;
    *)
      echo "Error: '$environment' is not a release environment." >&2
      echo "Use staging or production." >&2
      return 1
      ;;
  esac

  local url="${2:-}"
  if [ -z "$url" ]; then
    # Indirect expansion; empty when the variable is unset.
    eval "url=\"\${$source:-}\""
  fi
  # Trim the ends, as the app trims the define.
  url="${url#"${url%%[![:space:]]*}"}"
  url="${url%"${url##*[![:space:]]}"}"

  if [ -z "$url" ]; then
    echo "Error: no API base URL for $environment. Set $source to your API" >&2
    echo "(https://...): there is no placeholder fallback." >&2
    return 1
  fi

  # Dart reads %61 as "a" and a backslash as "/", so either could spell the
  # placeholder host past the check below; whitespace is never part of a URL.
  case "$url" in
    *%*|*\\*|*[[:space:]]*)
      echo "Error: base URL '$url' contains whitespace, '%' or a" >&2
      echo "backslash. Write the host and path literally." >&2
      return 1
      ;;
  esac

  local lower
  lower=$(printf '%s' "$url" | tr '[:upper:]' '[:lower:]')
  case "$lower" in
    https://?*) ;;
    *)
      echo "Error: base URL '$url' is not an absolute https URL. A" >&2
      echo "$environment release refuses any other scheme at startup." >&2
      return 1
      ;;
  esac

  # Authority, without userinfo and port; a trailing dot names the same host.
  local host="${lower#https://}"
  host="${host%%[/?#]*}"
  host="${host##*@}"
  case "$host" in
    \[*) ;; # an IPv6 literal: its colons are not a port separator
    *) host="${host%%:*}" ;;
  esac
  while [ "${host%.}" != "$host" ]; do host="${host%.}"; done
  if [ -z "$host" ]; then
    echo "Error: base URL '$url' has no host." >&2
    return 1
  fi
  case "$host" in
    example.com|*.example.com)
      echo "Error: base URL '$url' is the starter's placeholder host. Pass" >&2
      echo "the URL of your API, or set $source to it." >&2
      return 1
      ;;
  esac

  # Read by the script that sourced this file.
  # shellcheck disable=SC2034
  BASE_URL="$url"
}
