# Acceptance evidence - issue #182

`docs: contracts-map.md documents a tasks controller provider that does not
exist and an authControllerProvider nothing reads` (title paraphrased - the dead
identifier is never spelled out in this directory, see criterion 1)

Fix merged as `1507cd9` (PR #194), plus one wording correction carried by the
evidence PR - see criterion 1 below for why it was needed.

Verified against `main` @ `ffa4615`. The documents themselves are anchored to
`48ba708`, the commit their line numbers were re-derived from; `main` moved three
times during this issue (#191 renumbered `api_client.dart`, #195 added two
`IKeyValueStore` consumers), and every citation was re-resolved after each move -
see `criterion-2-citations.log`.

No golden was run (`--no-goldens`). A golden renders text with the Ahem font, so
every glyph is an opaque block: it cannot show a word of prose, and every
criterion here is about prose. The directory therefore contains no PNG, and no
verdict below rests on a screenshot.

## Result

| Criterion | Result | Evidence |
|---|---|---|
| 1. `grep -rn "<the dead identifier>" .` returns no hit outside `.git/` | PASS | `criterion-1-phantom-provider.log` |
| 2. Every symbol in a "Default implementation" / "Wired in" / "Consumed by" cell exists in `lib/` | PASS | `criterion-2-symbols.log` (36 symbols, 0 with zero hits) and `criterion-2-citations.log` (48 `file:line` citations, 0 unresolvable) |
| 3. The map distinguishes three states per contract | PASS | `criterion-3-status-column.log` |
| 4. The `AppDesignTokens` row states `AppTheme` binds the concrete class | PASS | `criterion-4-design-tokens.log` |
| 5. ADR 0005 does not assert `ITasksController` is implemented | PASS | `criterion-5-adr-0005.log` |
| 6. `git diff --name-only origin/main` lists only paths under `docs/` | PASS | `criterion-6-diff-scope.log` |

Supporting gates from `./scripts/test/run_acceptance.sh 182 --no-goldens`:
`format.log`, `analyze.log`, `tests.log` - all PASS. Those prove the repository
is healthy, not that any criterion above holds; the criterion evidence is the
per-criterion logs.

## Notes per criterion

### Criterion 1 - and the trap in it

The first draft of the fix ended the swap map with a line reading "Until #182
this table named a `<dead identifier>` that has never existed in the tree".
That sentence is accurate and useful, and it **fails criterion 1**: the grep the
criterion specifies is repository-wide, so a historical note that spells the dead
identifier out is itself a hit. The note now describes the identifier without
naming it, and says so explicitly, which keeps the grep a clean test forever.

The same trap applies to this evidence directory, so
`criterion-1-phantom-provider.log` substitutes `$NEEDLE` for the identifier and
never writes it. The generator was:

```bash
NEEDLE="tasksController""Provider"      # split so the script is not a hit either

echo '$ grep -rn "$NEEDLE" . --exclude-dir=.git'
hits=$(grep -rn "$NEEDLE" . --exclude-dir=.git)
status=$?
printf '%s' "$hits"
echo "exit=$status   (1 = no match anywhere outside .git/ = PASS)"
echo "matching lines: $(printf '%s' "$hits" | grep -c . )"
```

### Criterion 2 - two checks, not one

`criterion-2-symbols.log` answers the criterion as written: for every symbol the
map names, `grep -rn "<symbol>" lib` returns at least one line. 36 symbols, none
with zero hits.

That is necessary but weak - it would pass a map that cites the right symbol at
the wrong place. `criterion-2-citations.log` is the stronger check: it extracts
every `` `path.dart:NN` `` citation from both edited documents (and every bare
`` `:NN` `` that follows one, which inherits the preceding path), opens the file,
and prints the line it lands on. 48 citations, 0 unresolvable, and each printed
line is the construct the prose claims. Generator:

```python
import re, pathlib, sys

docs = ['docs/architecture/contracts-map.md',
        'docs/architecture/adr/0005-state-boundary.md']
bad = total = 0
for d in docs:
    print(f'--- {d} ---')
    last = None
    for m in re.finditer(r'`((?:lib|test)/[A-Za-z0-9_/]+\.dart):(\d+)`|`:(\d+)`',
                         pathlib.Path(d).read_text()):
        if m.group(1):
            last, line = m.group(1), int(m.group(2))
        else:
            line = int(m.group(3))
        total += 1
        src = pathlib.Path(last).read_text().split('\n')
        if line > len(src):
            print(f'  OUT OF RANGE {last}:{line}'); bad += 1
        else:
            print(f'  {last}:{line}: {src[line - 1].strip()[:100]}')
print(f'\nchecked {total} citation(s); {bad} unresolvable')
sys.exit(1 if bad else 0)
```

This is a script, not a `.dart` file, and it lives in this README rather than as
a committed source file on purpose: `analysis_options.yaml` does not exclude
`docs/`, so a `.dart` probe under `docs/verification/` is analyzed like any other
source and fails the tasks-stripping CI variants with `uri_does_not_exist`
(koniz-dev/flutter-starter#187).

### Criterion 3 - the states, and the one the criterion did not name

The criterion asks for three states. The map uses exactly three - **Live**,
**No production consumer**, **No implementor** - with a legend table directly
above the swap map defining each. Six rows are Live, three are No production
consumer, one is No implementor.

`AppDesignTokens` sits in "No production consumer" alongside `AppNavigator` and
`IAuthController`, but it is not the same shape of dead: the other two have a
provider binding the contract that nobody reads, while `AppDesignTokens` has no
provider at all. The row says so in its own cells rather than inventing a fourth
status value.

### Criterion 5 - what was and was not changed in ADR 0005

ADR 0005's Decision section is intent ("Introduce controller contracts...", "Use
Riverpod notifiers as adapter implementations"), and a reader could easily take
it for a description of the shipped tree. It now carries an **Implementation
status** section recording that `ITasksController` has no implementor and that
`authControllerProvider` has no readers.

The ADR's Status stays **Proposed** and no decision was added or reversed.
Deciding which of these contracts to wire up or delete is
koniz-dev/flutter-starter#183, deliberately sequenced after this one.

## Live-versus-dead status established for each contract

Every row re-derived by hand for this issue; `file:line` in
`criterion-2-citations.log`.

| Contract | Status | Proof |
|---|---|---|
| `INetworkClient` | Live | `api_client.dart:138` field typed on it, bound at `:54`, every verb routes through `_send` (`:259`) calling `_networkClient.send` (`:263`) |
| `IHttpResponseCache` | Live | `api_client.dart:160`, `auth_interceptor.dart:118`, `auth_repository_impl.dart:34`, wired `auth_providers.dart:63` |
| `IKeyValueStore` | Live | `providers.dart:23`; consumed in all three feature slices since #195 |
| `ITokenStore` | Live | `providers.dart:28`, `auth_interceptor.dart:52`, `auth_local_datasource.dart:57` |
| `ISessionTerminationSink` | Live | `auth_interceptor.dart:87`, invoked `:534`, wired `auth_providers.dart:93` |
| `AppNavigator` | No production consumer | `navigation_providers.dart:7`; only reader is `test/core/routing/navigation_providers_test.dart:25` |
| `AppDesignTokens` | No production consumer | `app_theme.dart:7` binds `const DefaultDesignTokens()`; `grep -rn "AppDesignTokens" lib` returns only the declaration and `implements` |
| `IAuthController` | No production consumer | `auth_provider.dart:284`; zero readers in `lib/` and `test/` |
| `ITasksController` | No implementor | `grep -rn "implements ITasksController" lib` exits 1 |

## Mechanical guard - deliberately not added here

Criterion 6 confines this change to `docs/`, so the guard that would stop this
class of drift could not land with it. What it should be, in one line: a
`<!-- symbol: <source path> <Identifier> -->` directive, sibling to #89's
`<!-- signature: ... -->` in `tool/doc_signatures.dart`, asserting that
`<Identifier>` is declared in `<source path>` - wired into `tool/check_docs.dart`
and `test/docs/`, so both the Docs check (fires on markdown) and the Quality gate
(fires on `lib/`) catch it. Had it existed, the phantom provider would have failed
CI the day it was written.

Filed as koniz-dev/flutter-starter#206.

Until that lands, what stops the next drift is weaker and worth naming honestly:
the instruction now printed in the swap map itself ("If you add or edit a row,
`grep -rn "<symbol>" lib` every symbol you put in it"), and a reviewer reading it.
That is a convention, not a gate.
