#!/bin/bash
# Usage: evidence.sh <scratch dir> <evidence dir>
S=$1; E=$2
awk '/^#!\/bin\/bash$/{c=1} c&&/^# scripts\/ci\/build_release.sh/{f=1} c&&!f{buf=$0; next} f&&/^```$/{exit} f{if(buf!=""){print buf; buf=""} print}' docs/guides/security/implementation.md > "$S/build_release.sh"
{
echo "## Criterion 1"
echo '$ grep -rn "CERTIFICATE_FINGERPRINTS" docs README.md .github lib .env.example | grep -v docs/verification'
grep -rn "CERTIFICATE_FINGERPRINTS" docs README.md .github lib .env.example | grep -v docs/verification
echo "pipeline exit: ${PIPESTATUS[1]} (1 = grep -v printed nothing, i.e. no match outside docs/verification)"
echo; echo '$ grep -n "dart-define=.*FINGERPRINTS" docs/guides/security/implementation.md'
grep -n "dart-define=.*FINGERPRINTS" docs/guides/security/implementation.md
} > "$E/criterion1-grep.txt" 2>&1
{
echo "## Criterion 3: the guide's build_release.sh, extracted verbatim from"
echo "## docs/guides/security/implementation.md, run under bash with a stub"
echo "## 'flutter' on PATH that prints its argv one bracketed argument at a time."
echo; echo '$ head -3 build_release.sh'; head -3 "$S/build_release.sh"
echo; echo '$ shellcheck -s bash build_release.sh'
shellcheck -s bash "$S/build_release.sh"; echo "shellcheck exit: $?"
run() { echo; echo "\$ $1 build_release.sh $2"; env -u API_SSL_FINGERPRINTS -u BASE_URL $1 PATH="$S/bin:$PATH" bash "$S/build_release.sh" $2; echo "exit: $?"; }
run "API_SSL_FINGERPRINTS=aa:bb,cc:dd" "production apk"
run "API_SSL_FINGERPRINTS=aa:bb,cc:dd" "staging appbundle"
run "API_SSL_FINGERPRINTS=aa:bb,cc:dd" "staging ios"
run "BASE_URL=https://api.custom.test API_SSL_FINGERPRINTS=aa:bb" "staging apk"
run "" "production apk"
run "API_SSL_FINGERPRINTS=aa" "prod apk"
run "API_SSL_FINGERPRINTS=aa" "staging web"
} > "$E/criterion3-build-script-run.txt" 2>&1
{
echo "## Criterion 2: every --dart-define key in the 'Code Obfuscation' section"
echo "## of docs/guides/security/implementation.md, checked against the keys of"
echo "## DartDefines.values in lib/core/config/dart_defines.dart."
known=$(sed -n '/static const Map<String, String> values/,/^  };/p' lib/core/config/dart_defines.dart | grep -oE "^    '[A-Z0-9_]+'" | tr -d " '" | sort -u)
echo; echo "DartDefines.values keys:"; echo "$known" | sed 's/^/  /'
section=$(awk '/^### 2\. Code Obfuscation/{f=1} /^### 3\./{f=0} f' docs/guides/security/implementation.md)
echo; echo "--dart-define occurrences in the section:"
echo "$section" | grep -nE -- '--dart-define=' | sed 's/^/  /'
fail=0
for k in $(echo "$section" | grep -oE -- '--dart-define=[A-Z0-9_]+' | cut -d= -f2 | sort -u); do
  if echo "$known" | grep -qx "$k"; then echo "  OK      $k"; else echo "  UNKNOWN $k"; fail=1; fi
done
echo; echo "result: $([ $fail = 0 ] && echo PASS || echo FAIL)"
echo; echo "## Control: the same check on the section as it was on origin/main"
fail=0
for k in $(git show origin/main:docs/guides/security/implementation.md | awk '/^### 2\. Code Obfuscation/{f=1} /^### 3\./{f=0} f' | grep -oE -- '--dart-define=[A-Z0-9_]+' | cut -d= -f2 | sort -u); do
  if echo "$known" | grep -qx "$k"; then echo "  OK      $k"; else echo "  UNKNOWN $k"; fail=1; fi
done
echo; echo "control result: $([ $fail = 0 ] && echo PASS || echo FAIL) (expected FAIL)"
} > "$E/criterion2-define-keys.txt" 2>&1
{
echo "## Criterion 4"
grep -n -A3 '#### Step 3: Update Documentation' docs/guides/security/implementation.md
echo; echo '$ ls docs/deployment/android-deployment.md docs/deployment/ios-deployment.md'
ls docs/deployment/android-deployment.md docs/deployment/ios-deployment.md; echo "exit: $?"
echo; echo '$ grep -rn "build-and-deploy.md" docs README.md | grep -v docs/verification'
grep -rn "build-and-deploy.md" docs README.md | grep -v docs/verification
echo "pipeline exit: ${PIPESTATUS[1]} (1 = no remaining reference)"
} > "$E/criterion4-step3-link.txt" 2>&1
