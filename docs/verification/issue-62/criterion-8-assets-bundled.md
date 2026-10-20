# Criterion 8 - `assets/images/` and `assets/config/` are declared in `pubspec.yaml`

Declared as directory entries:

```yaml
  assets:
    - .env.example
    - assets/images/
    - assets/config/
```

Driven, not asserted: a real web release build, then the asset manifest it
produced.

```console
$ flutter build web --release
...
Compiling lib/main.dart for the Web...                            171.7s
Built build/web

$ ls build/web/assets/assets
config
images

$ python3 -c "import base64,json;print(base64.b64decode(json.load(open('build/web/assets/AssetManifest.bin.json'))))"
b'\r\x04\x07\x0c.env.example\x0c\x01\r\x01\x07\x05asset\x07\x0c.env.example
  \x07\x16assets/config/.gitkeep\x0c\x01\r\x01\x07\x05asset\x07\x16assets/config/.gitkeep
  \x07\x16assets/images/.gitkeep\x0c\x01\r\x01\x07\x05asset\x07\x16assets/images/.gitkeep
  \x072packages/cupertino_icons/assets/CupertinoIcons.ttf ...'
```

Both directories appear in the bundled manifest (via their tracked `.gitkeep`),
so anything dropped into either is now reachable through `rootBundle` instead of
404-ing at runtime. Before this change the whole `assets:` list was
`[.env.example]`.

Line-wrapping in the decoded manifest above is for readability only; it is a
single byte string.
