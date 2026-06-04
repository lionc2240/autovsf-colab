# `install.sh` Explanation

## Overview

`install.sh` is an automated setup script designed specifically for **Google Colab** (Ubuntu 22.04 Jammy). It performs 4 main steps to prepare the environment for running VideoSubFinder.

## Directory Structure

Before diving into details, here is the directory structure the script assumes:

```
/content/drive/MyDrive/AutoVSF/          # PARENT_DIR
├── VideoSubFinder/                      # VSF_DIR
│   ├── VideoSubFinderWXW               # Main binary
│   ├── VideoSubFinderWXW.run           # Wrapper script
│   └── legacy_libs/                    # Legacy libraries (compatibility fix)
└── autovsf-colab/                       # REPO_DIR (current directory)
    ├── install.sh
    ├── headless.py
    ├── ocr.py
    └── config.py
```

`REPO_DIR` is the code directory (`autovsf-colab`), `PARENT_DIR` is the parent directory (`AutoVSF`), and `VSF_DIR` is the VideoSubFinder binary directory (`VideoSubFinder`).

---

## Step 1: Install system tools (lines 17-18)

```bash
sudo apt-get update -y || true
sudo apt-get install -y xvfb libxss1 libnss3 ffmpeg libxtst6 ...
```

### Purpose

Installs necessary system packages to run VideoSubFinder, a GUI application (WXWidgets) on a headless environment like Colab.

### Key packages

| Package | Role |
|---------|------|
| `xvfb` | **X Virtual Framebuffer** — emulates a virtual display to run GUI apps on a headless server |
| `ffmpeg` | Video processing, decoding various input formats |
| `libxss1`, `libnss3`, `libgtk-3-0` | GTK/WX libraries required by VideoSubFinder (built on WXWidgets) |
| `libxtst6`, `libxrender1`, `libxcomposite1` | X11 support libraries for virtual window rendering |

### Why run every time?

The comment `Required every run` is correct. On Google Colab, each runtime session is a new VM, so system packages do not persist across sessions.

---

## Step 2: Legacy library compatibility fix (lines 21-48)

### Problem

VideoSubFinder was built on **Ubuntu 20.04**, using older library versions. Google Colab runs **Ubuntu 22.04** with newer libraries that are not backward compatible. The script cannot install older libraries via `apt-get` because Ubuntu 22.04 no longer supports those packages in its official repository.

### Solution

The script downloads `.deb` files directly from Ubuntu 20.04 archives (old-releases, security, azure mirror), extracts them, and takes only the `.so*` (shared object / dynamic library) files. These files are placed in the `legacy_libs/` directory and loaded via the `LD_LIBRARY_PATH` environment variable.

### Patched libraries

| Library | Source .deb file | Notes |
|---------|-----------------|-------|
| `libaom0` | `aom_1.0.0.errata1-3build1_amd64.deb` | AV1 codec |
| `libvpx6` | `libvpx6_1.8.2-1ubuntu0.4_amd64.deb` | VP8/VP9 codec |
| `libx264-155` | `x264_0.155.2917+git0a84d98-2_amd64.deb` | H.264 codec |
| `libx265-179` | `x265_3.2.1-1build1_amd64.deb` | H.265 codec |
| `libflite1` | `flite_2.1-release-3_amd64.deb` | Text-to-speech (older ffmpeg dependency) |
| `libwavpack1` | `wavpack_5.2.0-1ubuntu0.1_amd64.deb` | Audio codec |
| `libwebp6` | `libwebp_0.6.1-2ubuntu0.20.04.3_amd64.deb` | WebP codec |
| `libcodec2-0.9` | `codec2_0.9.2-2_amd64.deb` | Codec2 codec |

### How it works (lines 37-48)

```bash
for pkg in "${!DEBS[@]}"; do
    if [ ! -f "${pkg}.so" ]; then
        # Download .deb from URL
        curl -L -o "$pkg.deb" "${DEBS[$pkg]}"
        # Extract .deb (do not install, just extract)
        dpkg -x "$pkg.deb" .
        # Find .so files and move to root libs directory
        find usr/lib/x86_64-linux-gnu/ -name "*.so*" -exec mv {} . \;
        rm -rf usr/ "$pkg.deb"
    else
        echo "✅ $pkg already exists on Drive, skipping."
    fi
done
```

Each run, the script checks whether the `.so` file already exists in `legacy_libs/`. If it does (saved from a previous session on Drive), it skips the download. This **saves time and bandwidth** on subsequent runs.

---

## Step 3: Install Python libraries (line 53)

```bash
pip install watchdog google-api-python-client google-auth-oauthlib google-auth httplib2 opencv-python psutil Pillow
```

These libraries serve the following purposes:

| Library | Role |
|---------|------|
| `watchdog` | Monitor directory changes (auto-process when new videos are added) |
| `google-api-python-client` | Call Google Drive API to save OCR results |
| `google-auth-oauthlib`, `google-auth` | Authenticate with Google Drive via OAuth2 |
| `httplib2` | HTTP client (Google API client dependency) |
| `opencv-python` | Image processing (OCR frames from video) |
| `psutil` | System resource monitoring (CPU, RAM) |
| `Pillow` | Image manipulation (PIL fork) |

---

## Step 4: Download and verify VideoSubFinder (lines 55-67)

```bash
if [ ! -f "$VSF_DIR/VideoSubFinderWXW" ]; then
    curl -L -o "$PARENT_DIR/$VSF_FILE" "$VSF_LINK"
    tar -xf "$PARENT_DIR/$VSF_FILE" -C "$PARENT_DIR/"
    rm "$PARENT_DIR/$VSF_FILE"
fi
```

### Purpose

VideoSubFinder is a ~500MB pre-built binary that cannot be included in the git repository. The script downloads it from GitHub Releases into the `VideoSubFinder/` directory next to `autovsf-colab/`.

### Drive caching mechanism

The script checks for the binary's existence before downloading. Since the `VideoSubFinder/` directory resides on Google Drive (mounted), **it is downloaded only once**; subsequent Colab sessions reuse it without re-downloading.

---

## Step 5: Create the wrapper script (lines 70-81)

```bash
cat <<EOF > "$VSF_DIR/VideoSubFinderWXW.run"
#!/bin/sh
export LD_LIBRARY_PATH="$LIBS_DIR:\$PWD:\$LD_LIBRARY_PATH"
if [ -z "\$DISPLAY" ]; then
    xvfb-run -a ./VideoSubFinderWXW "\$@"
else
    ./VideoSubFinderWXW "\$@"
fi
EOF
```

### Why a wrapper?

This wrapper solves **2 problems** simultaneously:

1. **Legacy library injection:** Sets `LD_LIBRARY_PATH` pointing to `legacy_libs/` to load Ubuntu 20.04 libraries first, allowing VideoSubFinder to find the correct older versions at startup.

2. **Headless execution:** If the `$DISPLAY` environment variable does not exist (as on Colab — no physical display), it automatically uses `xvfb-run` to create a virtual display and run VideoSubFinder inside it.

---

## Summary of the execution flow

```
install.sh
│
├── [1] apt-get install → xvfb, ffmpeg, system libraries
│
├── [2] Download & extract legacy .deb → get .so files
│     (only downloads if not already on Drive)
│
├── [3] pip install → Python libraries
│
├── [4] Download VideoSubFinder binary
│     (only downloads if not already on Drive)
│
└── [5] Create VideoSubFinderWXW.run
      → wrapper: LD_LIBRARY_PATH + xvfb-run
```

## Conclusion

`install.sh` transforms a bare Google Colab VM into a complete environment for running VideoSubFinder by:

- Installing necessary system packages (must be done every session)
- Patching incompatible legacy libraries between Ubuntu 20.04 (where VSF was built) and Ubuntu 22.04 (Colab)
- Downloading and configuring the VideoSubFinder binary (cached on Drive)
- Creating a wrapper that handles both library compatibility and virtual display
