#!/bin/bash
# install_colab.sh - Optimized for Google Colab (Ubuntu 22.04 Jammy)

set -e

# Define directories
REPO_DIR=$(pwd)
# In Colab, REPO_DIR is usually /content/drive/MyDrive/AutoVSF/autovsf-colab
PARENT_DIR=$(dirname "$REPO_DIR")
VSF_DIR="$PARENT_DIR/VideoSubFinder"
LIBS_DIR="$VSF_DIR/legacy_libs"

echo "🌍 Environment: Google Colab (Ubuntu 22.04 Jammy)"
echo "📂 Working directory: $REPO_DIR"

echo "🚀 [1/4] Installing system tools..."
if command -v xvfb-run >/dev/null 2>&1; then
    echo "✅ System tools already installed, skipping apt-get."
else
    sudo apt-get update -y || true
    sudo apt-get install -y xvfb libxss1 libnss3 ffmpeg libxtst6 libxrender1 libxcomposite1 libasound2 libdbus-glib-1-2 libnuma1 libgtk-3-0
fi

# Handle legacy libraries (VSF build for Ubuntu 20.04 requires older libs)
echo "🚀 [2/4] Checking and patching legacy libraries..."
mkdir -p "$LIBS_DIR"
cd "$LIBS_DIR"

if [ -f ".libs_ready" ]; then
    echo "✅ Legacy libraries already present and verified on Drive, skipping."
else
    # List of missing libraries on Ubuntu 22.04
    declare -A DEBS=(
        ["libaom0"]="https://archive.ubuntu.com/ubuntu/pool/universe/a/aom/libaom0_1.0.0.errata1-3build1_amd64.deb"
        ["libvpx6"]="http://azure.archive.ubuntu.com/ubuntu/pool/main/libv/libvpx/libvpx6_1.8.2-1ubuntu0.4_amd64.deb"
        ["libx264-155"]="https://old-releases.ubuntu.com/ubuntu/pool/universe/x/x264/libx264-155_0.155.2917+git0a84d98-2_amd64.deb"
        ["libx265-179"]="http://ftp.ubuntu.com/ubuntu/ubuntu/pool/universe/x/x265/libx265-179_3.2.1-1build1_amd64.deb"
        ["libflite1"]="https://old-releases.ubuntu.com/ubuntu/pool/universe/f/flite/libflite1_2.1-release-3_amd64.deb"
        ["libwavpack1"]="http://azure.archive.ubuntu.com/ubuntu/pool/main/w/wavpack/libwavpack1_5.2.0-1ubuntu0.1_amd64.deb"
        ["libwebp6"]="http://security.ubuntu.com/ubuntu/pool/main/libw/libwebp/libwebp6_0.6.1-2ubuntu0.20.04.3_amd64.deb"
        ["libcodec2-0.9"]="http://security.ubuntu.com/ubuntu/pool/universe/c/codec2/libcodec2-0.9_0.9.2-2_amd64.deb"
    )

    for pkg in "${!DEBS[@]}"; do
        echo "📥 Downloading and extracting $pkg..."
        curl -L -o "$pkg.deb" "${DEBS[$pkg]}"
        dpkg -x "$pkg.deb" .
        # Move .so files to libs root
        find usr/lib/x86_64-linux-gnu/ -name "*.so*" -exec mv {} . \; || true
        rm -rf usr/ "$pkg.deb"
    done
    touch .libs_ready
    echo "✅ Legacy libraries installation complete."
fi

cd "$REPO_DIR"

echo "🚀 [3/4] Installing Python libraries..."
pip install --quiet --no-cache-dir watchdog google-api-python-client google-auth-oauthlib google-auth httplib2 opencv-python psutil Pillow

echo "🚀 [4/4] Checking VideoSubFinder..."
VSF_LINK="https://github.com/lionc2240/autovsf-codespaces/releases/download/VideoSubFinder_6.10_ubu20.04.tar.xz/VideoSubFinder_6.10_ubu20.04.tar.xz"
VSF_FILE="VideoSubFinder_6.10_ubu20.04.tar.xz"

if [ ! -f "$VSF_DIR/VideoSubFinderWXW" ]; then
    echo "📥 Downloading VideoSubFinder (500MB)..."
    curl -L -o "$PARENT_DIR/$VSF_FILE" "$VSF_LINK"
    tar -xf "$PARENT_DIR/$VSF_FILE" -C "$PARENT_DIR/"
    rm "$PARENT_DIR/$VSF_FILE"
    echo "✅ VSF download complete."
else
    echo "✅ Already exists on Drive, skipping download."
fi

# Configure .run file (Automatically detect lib path on Drive)
cat <<EOF > "$VSF_DIR/VideoSubFinderWXW.run"
#!/bin/sh
# Wrapper to load legacy libraries from Drive
export LD_LIBRARY_PATH="$LIBS_DIR:\$PWD:\$LD_LIBRARY_PATH"
if [ -z "\$DISPLAY" ]; then
    xvfb-run -a ./VideoSubFinderWXW "\$@"
else
    ./VideoSubFinderWXW "\$@"
fi
EOF

chmod +x "$VSF_DIR/VideoSubFinderWXW" "$VSF_DIR/VideoSubFinderWXW.run"
chmod +x headless.py ocr.py

echo "==========================================================="
echo "🎉 INSTALLATION COMPLETE FOR COLAB!"
echo "🚀 You can now run VideoSubFinder on Google Drive."
echo "==========================================================="
