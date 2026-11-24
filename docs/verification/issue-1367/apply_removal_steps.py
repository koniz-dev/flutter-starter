"""Applies step 2 and step 3 of getting-started.md's demo removal to a clone.

Step 1 (deleting files) is done with `git rm` before this runs; see
removal-run.log. Run from the clone's root.
"""
import re

def edit(path, old, new, count=1):
    s = open(path).read()
    assert s.count(old) == count, (path, old[:60])
    open(path, 'w').write(s.replace(old, new))

# Step 2: auth_providers.dart - one import and one line.
p = 'lib/features/auth/di/auth_providers.dart'
edit(p, "import 'package:flutter_starter/features/auth/demo/demo_auth.dart';\n", '')
edit(p, "      if (DemoAuth.enabled) return DemoAuthRemoteDataSource();\n", '')

# login_screen.dart - two imports and the if (DemoAuth.enabled) block.
p = 'lib/features/auth/presentation/screens/login_screen.dart'
edit(p, "import 'package:flutter_starter/features/auth/demo/demo_auth.dart';\n", '')
edit(p, "import 'package:flutter_starter/features/auth/demo/demo_sign_in_card.dart';\n", '')
edit(p, """                if (DemoAuth.enabled) ...[
                  DemoSignInCard(
                    onFill: () {
                      _emailController.text = DemoAuth.email;
                      _passwordController.text = DemoAuth.password;
                    },
                  ),
                  const SizedBox(height: 16),
                ],
""", '')

# app_config.dart - hasBackend, hasBackendFor and the baseUrl comment.
p = 'lib/core/config/app_config.dart'
edit(p, """  /// - Development: `http://localhost:3000`, which only a profile or release
  ///   build ever contacts: without `BASE_URL` a development debug build has
  ///   no backend ([hasBackend]) and signs in offline instead
""", """  /// - Development: `http://localhost:3000`
""")
s = open(p).read()
s2 = re.sub(r"  /// Whether this build talks to a backend:.*?environment != 'development';\n\n",
            '', s, flags=re.S)
assert s2 != s
open(p, 'w').write(s2)

# docs/api/features/auth/providers.md - the same demo line.
edit('docs/api/features/auth/providers.md',
     "      if (DemoAuth.enabled) return DemoAuthRemoteDataSource();\n", '')

# docs/guides/configuration.md - the no-backend sentence.
edit('docs/guides/configuration.md', """- Development: `http://localhost:3000`, used only by profile and release
  builds. Leaving `BASE_URL` empty in development means *no backend*
  (`AppConfig.hasBackend` is false): a debug build then signs in with the
  offline demo account and sends no request at all. To use a server on your
  machine, set `BASE_URL=http://localhost:3000` explicitly.
""", """- Development: `http://localhost:3000`
""")

# README.md - the "how to remove it" link to the section.
edit('README.md', """- **Connect your backend** by setting `BASE_URL`, which also turns the demo
   sign-in off ([how to remove it](docs/guides/onboarding/getting-started.md#signing-in-before-you-have-a-backend)).
   Requests go to""", """- **Connect your backend** by setting `BASE_URL`.
   Requests go to""")

# Step 3: delete the section (heading up to the next ### heading).
p = 'docs/guides/onboarding/getting-started.md'
s = open(p).read()
s2 = re.sub(r"### Signing In Before You Have a Backend\n.*?(?=### Connecting Your Backend)",
            '', s, flags=re.S)
assert s2 != s
open(p, 'w').write(s2)
print('applied')
