#!/bin/bash
# Sourced, not run: defines ssl_pinning_defines, which fills the array
# SSL_PINNING_DEFINES with the --dart-define arguments for certificate
# pinning, or refuses.
#
#   . scripts/ci/ssl_pinning_defines.sh
#   ssl_pinning_defines "$ENVIRONMENT" || exit 1
#   flutter build appbundle --release ... \
#     ${SSL_PINNING_DEFINES[@]+"${SSL_PINNING_DEFINES[@]}"}
#
# (That expansion form survives `set -u` on bash 3.2 when the array is empty,
# which it is for development with neither variable set.)
#
# Reads API_SSL_FINGERPRINTS and ENABLE_SSL_PINNING from the environment.
# Pinning is on by default in staging and production, and a release build
# with pinning on and no fingerprints refuses to start (lib/main.dart), so for
# those environments it refuses unless one of these is set:
#
#   API_SSL_FINGERPRINTS   the server's SHA-256 fingerprints, comma-separated
#   ENABLE_SSL_PINNING     false (or 0, no, off) to ship without pinning
#
# ENABLE_SSL_PINNING, when set, must be one of true/1/yes/on/false/0/no/off
# (any case): the app reads nothing else, and refuses a release that carries
# another value.
#
# The fingerprints are read the way AppConfig.apiSslFingerprints reads them -
# split on commas, colons and whitespace dropped, empty entries skipped - so a
# value like " " or "," counts as empty here too, as it does in the app. Each
# remaining entry must be 64 hex digits (a SHA-256): a mistyped fingerprint
# would build and then refuse every connection, so it is refused in any
# environment. Any other environment passes through whatever is set. Works on
# bash 3.2.

ssl_pinning_defines() {
  local environment="$1"
  # Trimmed and lowercased, as AppConfig.enableSslPinning reads it.
  local flag
  # Only the ends: "o n" must stay unrecognised, as it is in the app.
  flag=$(printf '%s' "${ENABLE_SSL_PINNING:-}" |
    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' |
    tr '[:upper:]' '[:lower:]')

  local count=0 entry
  local old_ifs="$IFS"
  IFS=','
  for entry in ${API_SSL_FINGERPRINTS:-}; do
    entry=$(printf '%s' "$entry" | tr -d ' \t:' | tr 'A-F' 'a-f')
    [ -z "$entry" ] && continue
    if ! printf '%s' "$entry" | grep -Eq '^[0-9a-f]{64}$'; then
      IFS="$old_ifs"
      echo "Error: API_SSL_FINGERPRINTS entry '$entry' is not a SHA-256" >&2
      echo "fingerprint (64 hex digits, colons optional)." >&2
      return 1
    fi
    count=$((count + 1))
  done
  IFS="$old_ifs"

  SSL_PINNING_DEFINES=()
  if [ "$count" -gt 0 ]; then
    SSL_PINNING_DEFINES+=("--dart-define=API_SSL_FINGERPRINTS=$API_SSL_FINGERPRINTS")
  fi
  if [ -n "${ENABLE_SSL_PINNING:-}" ]; then
    SSL_PINNING_DEFINES+=("--dart-define=ENABLE_SSL_PINNING=$ENABLE_SSL_PINNING")
  fi

  case "$environment" in
    staging|production) ;;
    *) return 0 ;;
  esac
  # The app reads only these spellings; a release carrying anything else
  # refuses to start, so refuse to build it.
  if [ -n "${ENABLE_SSL_PINNING:-}" ]; then
    case "$flag" in
      true|1|yes|on|false|0|no|off) ;;
      *)
        echo "Error: ENABLE_SSL_PINNING is '$ENABLE_SSL_PINNING', which is" >&2
        echo "neither on (true/1/yes/on) nor off (false/0/no/off)." >&2
        return 1
        ;;
    esac
  fi
  if [ "$count" -gt 0 ]; then
    return 0
  fi
  case "$flag" in
    false|0|no|off) return 0 ;;
  esac

  echo "Error: API_SSL_FINGERPRINTS is empty. Pinning is on in $environment," >&2
  echo "and a release built without fingerprints refuses to start." >&2
  echo "Set API_SSL_FINGERPRINTS, or ENABLE_SSL_PINNING=false to ship" >&2
  echo "without pinning." >&2
  return 1
}
