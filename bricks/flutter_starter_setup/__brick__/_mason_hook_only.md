# Mason hook-only brick

This file exists because Mason requires at least one file under `__brick__/`. All setup runs in `hooks/post_gen.dart`, which deletes this file when it finishes. If it is still in your project, the hook stopped before the end; see its output.
