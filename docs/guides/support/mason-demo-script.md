# Mason demo GIF/video script

Goal: produce a short clip (30–45s) that shows Mason generating a new feature in this starter.

## Output location

- Save as: `docs/assets/mason-generate-feature.gif` (or `.mp4`)
- Then embed in root `README.md`:

```md
![Mason demo](docs/assets/mason-generate-feature.gif)
```

## Recommended recording settings

- **Resolution**: 1280×720 (or 1440×900 if you prefer terminal readability)
- **Font**: 16–18px, high contrast theme
- **Cursor**: optional (helpful if you point at folders)
- **Speed**: normal typing; keep pauses short

## Script (30–45s)

### Scene 1 — terminal (10–15s)

Run from repo root:

```bash
mason --version
mason get
mason make feature_clean
```

When prompted, use a short feature name, e.g.:
- `feature_name`: `profile`

### Scene 2 — file tree (10–15s)

In the editor sidebar, briefly expand:
- `lib/features/profile/`
  - `data/`
  - `domain/`
  - `presentation/`

### Scene 3 — quick proof (10–15s)

Open one generated file (any one is fine), e.g.:
- `lib/features/profile/di/profile_providers.dart`

Show 1–2 seconds of the file, then end the recording.

## Suggested captions (optional)

If your recorder supports overlay text, keep it minimal:
- “mason get”
- “mason make feature_clean (profile)”
- “generated: lib/features/profile/*”

## Tools

Pick one:

- **Cross-platform (terminal capture)**: OBS Studio (record MP4; optionally convert to GIF)
- **Windows**: ShareX (GIF) or ScreenToGif
- **macOS**: Kap (GIF/MP4) or QuickTime (MP4)
- **Linux**: Peek (GIF) or OBS (MP4)

## GIF conversion (if you recorded MP4)

Example with `ffmpeg`:

```bash
ffmpeg -i input.mp4 -vf "fps=15,scale=1280:-1:flags=lanczos" -gifflags -transdiff -y docs/assets/mason-generate-feature.gif
```

