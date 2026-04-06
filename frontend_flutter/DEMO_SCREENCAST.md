# Screencast / Recording Instructions

Use this guide to record a short demo screencast (2–4 minutes) on Windows. Two options: `ffmpeg` (quick CLI) or `OBS` (recommended for quality/control).

Quick FFmpeg (one-shot full-screen)
- Install ffmpeg and ensure `ffmpeg` is on PATH.
- Record the full desktop at 30 fps (1080p):

```powershell
ffmpeg -f gdigrab -framerate 30 -i desktop -video_size 1920x1080 -vcodec libx264 -crf 18 -preset veryfast demo.mp4
```

- Stop recording with `q` in the ffmpeg console.

Record a specific window (Chrome) by window title (may need the exact title):

```powershell
ffmpeg -f gdigrab -framerate 30 -i title="Chrome" -video_size 1920x1080 -vcodec libx264 demo_chrome.mp4
```

OBS (recommended)
- Install OBS Studio.
- Create a Scene, add a Source: 'Window Capture' or 'Display Capture'.
- Set Recording format (MP4/MP3), bitrate, and start/stop with the UI or hotkeys.

Tips for a tight 2–3 minute video
- Use the Demo Script (`DEMO_SCRIPT.md`) and practice once.
- Keep each section short: intro (15s), dashboard (30s), CTA + approvals (45s), analytics (30s), close (15s).
- Highlight the browser address bar briefly to show query args passed by CTAs.

Upload
- After recording, optionally trim with `ffmpeg`:

```powershell
ffmpeg -i demo.mp4 -ss 00:00:10 -to 00:02:40 -c copy demo_trimmed.mp4
```
