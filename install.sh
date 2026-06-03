#!/bin/bash
# install_colab.sh - Tối ưu cho Google Colab (Ubuntu 22.04 Jammy)

set -e

# Xác định thư mục
REPO_DIR=$(pwd)
# Trong Colab, REPO_DIR thường là /content/drive/MyDrive/AutoVSF/autovsf-colab
PARENT_DIR=$(dirname "$REPO_DIR")
VSF_DIR="$PARENT_DIR/VideoSubFinder"
LIBS_DIR="$VSF_DIR/legacy_libs"

echo "🌍 Môi trường: Google Colab (Ubuntu 22.04 Jammy)"
echo "📂 Thư mục làm việc: $REPO_DIR"

echo "🚀 [1/4] Cài đặt công cụ hệ thống (Bắt buộc mỗi lần chạy)..."
sudo apt-get update -y || true
sudo apt-get install -y xvfb libxss1 libnss3 ffmpeg libxtst6 libxrender1 libxcomposite1 libasound2 libdbus-glib-1-2 libnuma1

# Xử lý thư viện cũ (VSF build cho Ubuntu 20.04 cần các bản lib cũ hơn)
echo "🚀 [2/4] Kiểm tra và vá lỗi thư viện cũ (Legacy Libs)..."
mkdir -p "$LIBS_DIR"
cd "$LIBS_DIR"

# Danh sách các thư viện thiếu hụt trên Ubuntu 22.04
declare -A DEBS=(
    ["libaom0"]="https://archive.ubuntu.com/ubuntu/pool/universe/a/aom/libaom0_1.0.0.errata1-3build1_amd64.deb"
    ["libvpx6"]="http://azure.archive.ubuntu.com/ubuntu/pool/main/libv/libvpx/libvpx6_1.8.2-1ubuntu0.4_amd64.deb"
    ["libx264-155"]="https://old-releases.ubuntu.com/ubuntu/pool/universe/x/x264/libx264-155_0.155.2917+git0a84d98-2_amd64.deb"
    ["libx265-179"]="http://ftp.ubuntu.com/ubuntu/ubuntu/pool/universe/x/x265/libx265-179_3.2.1-1build1_amd64.deb"
    ["libflite1"]="https://old-releases.ubuntu.com/ubuntu/pool/universe/f/flite/libflite1_2.1-release-3_amd64.deb"
    ["libwavpack1"]="http://azure.archive.ubuntu.com/ubuntu/pool/main/w/wavpack/libwavpack1_5.2.0-1ubuntu0.1_amd64.deb"
)

for pkg in "${!DEBS[@]}"; do
    if [ ! -f "${pkg}.so" ]; then
        echo "📥 Đang tải $pkg..."
        curl -L -o "$pkg.deb" "${DEBS[$pkg]}"
        dpkg -x "$pkg.deb" .
        # Tìm và đưa các file .so ra thư mục gốc libs
        find usr/lib/x86_64-linux-gnu/ -name "*.so*" -exec mv {} . \; || true
        rm -rf usr/ "$pkg.deb"
    else
        echo "✅ $pkg đã tồn tại trên Drive, bỏ qua."
    fi
done

cd "$REPO_DIR"

echo "🚀 [3/4] Cài đặt thư viện Python..."
pip install watchdog google-api-python-client google-auth-oauthlib google-auth httplib2 opencv-python psutil Pillow

echo "🚀 [4/4] Kiểm tra VideoSubFinder..."
VSF_LINK="https://github.com/lionc2240/autovsf-codespaces/releases/download/VideoSubFinder_6.10_ubu20.04.tar.xz/VideoSubFinder_6.10_ubu20.04.tar.xz"
VSF_FILE="VideoSubFinder_6.10_ubu20.04.tar.xz"

if [ ! -f "$VSF_DIR/VideoSubFinderWXW" ]; then
    echo "📥 Đang tải VideoSubFinder (500MB)..."
    curl -L -o "$PARENT_DIR/$VSF_FILE" "$VSF_LINK"
    tar -xf "$PARENT_DIR/$VSF_FILE" -C "$PARENT_DIR/"
    rm "$PARENT_DIR/$VSF_FILE"
    echo "✅ Đã tải xong VSF."
else
    echo "✅ VideoSubFinder đã tồn tại trên Drive, bỏ qua bước tải."
fi

# Cấu hình file .run (Tự động nhận diện đường dẫn lib trên Drive)
cat <<EOF > "$VSF_DIR/VideoSubFinderWXW.run"
#!/bin/sh
# Wrapper để nạp thư viện cũ từ Drive
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
echo "🎉 CÀI ĐẶT HOÀN TẤT CHO COLAB!"
echo "🚀 Bây giờ bạn có thể chạy VideoSubFinder trên Google Drive."
echo "==========================================================="
