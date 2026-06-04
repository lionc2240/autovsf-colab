# Giải thích file `install.sh`

## Tổng quan

File `install.sh` là script cài đặt tự động dành riêng cho môi trường **Google Colab** (Ubuntu 22.04 Jammy). Nó thực hiện 4 bước chính để chuẩn bị môi trường chạy VideoSubFinder.

## Kiến trúc thư mục

Trước khi đi vào chi tiết, cần hiểu cấu trúc thư mục mà script giả định:

```
/content/drive/MyDrive/AutoVSF/          # PARENT_DIR
├── VideoSubFinder/                      # VSF_DIR
│   ├── VideoSubFinderWXW               # Binary chính
│   ├── VideoSubFinderWXW.run           # Wrapper script
│   └── legacy_libs/                    # Thư viện cũ (vá lỗi)
└── autovsf-colab/                       # REPO_DIR (thư mục hiện tại)
    ├── install.sh
    ├── headless.py
    ├── ocr.py
    └── config.py
```

`REPO_DIR` là thư mục chứa code (`autovsf-colab`), `PARENT_DIR` là thư mục cha (`AutoVSF`), và `VSF_DIR` là thư mục chứa binary VideoSubFinder (`VideoSubFinder`).

---

## Bước 1: Cài đặt công cụ hệ thống (dòng 17-18)

```bash
sudo apt-get update -y || true
sudo apt-get install -y xvfb libxss1 libnss3 ffmpeg libxtst6 ...
```

### Mục đích

Cài đặt các gói hệ thống cần thiết để chạy VideoSubFinder, một ứng dụng GUI (WXWidgets) trên môi trường không có màn hình (headless) như Colab.

### Các gói quan trọng

| Gói | Vai trò |
|------|---------|
| `xvfb` | **X Virtual Framebuffer** — giả lập màn hình ảo để chạy ứng dụng GUI trên server không có màn hình |
| `ffmpeg` | Xử lý video, giải mã các định dạng đầu vào |
| `libxss1`, `libnss3`, `libgtk-3-0` | Thư viện GTK/WX cần thiết cho VideoSubFinder (dựng trên WXWidgets) |
| `libxtst6`, `libxrender1`, `libxcomposite1` | Thư viện X11 phụ trợ cho việc render cửa sổ ảo |

### Tại sao phải chạy lại mỗi lần?

Dòng comment `Bắt buộc mỗi lần chạy` là đúng. Trên Google Colab, mỗi runtime session là một VM mới, nên các gói hệ thống không tồn tại qua các phiên làm việc.

---

## Bước 2: Vá lỗi thư viện cũ — Legacy Libs (dòng 21-48)

### Vấn đề

VideoSubFinder được build trên **Ubuntu 20.04**, sử dụng các phiên bản thư viện cũ. Google Colab dùng **Ubuntu 22.04** có các thư viện mới hơn, không tương thích ngược. Script không thể cài các thư viện cũ qua `apt-get` vì Ubuntu 22.04 không còn hỗ trợ các gói đó trong repository chính thức.

### Giải pháp

Script tải trực tiếp các file `.deb` từ Ubuntu 20.04 archives (old-releases, security, azure mirror), giải nén chúng, và chỉ lấy các file `.so*` (shared object / thư viện động). Các file này được đặt vào thư mục `legacy_libs/` và sẽ được nạp qua biến môi trường `LD_LIBRARY_PATH`.

### Danh sách thư viện vá

| Thư viện | File .deb nguồn | Ghi chú |
|-----------|----------------|---------|
| `libaom0` | `aom_1.0.0.errata1-3build1_amd64.deb` | AV1 codec |
| `libvpx6` | `libvpx6_1.8.2-1ubuntu0.4_amd64.deb` | VP8/VP9 codec |
| `libx264-155` | `x264_0.155.2917+git0a84d98-2_amd64.deb` | H.264 codec |
| `libx265-179` | `x265_3.2.1-1build1_amd64.deb` | H.265 codec |
| `libflite1` | `flite_2.1-release-3_amd64.deb` | Text-to-speech (phụ thuộc của ffmpeg cũ) |
| `libwavpack1` | `wavpack_5.2.0-1ubuntu0.1_amd64.deb` | Audio codec |
| `libwebp6` | `libwebp_0.6.1-2ubuntu0.20.04.3_amd64.deb` | WebP codec |
| `libcodec2-0.9` | `codec2_0.9.2-2_amd64.deb` | Codec2 codec |

### Cách hoạt động (dòng 37-48)

```bash
for pkg in "${!DEBS[@]}"; do
    if [ ! -f "${pkg}.so" ]; then
        # Tải .deb từ URL
        curl -L -o "$pkg.deb" "${DEBS[$pkg]}"
        # Giải nén .deb (không cài đặt, chỉ giải nén)
        dpkg -x "$pkg.deb" .
        # Tìm file .so và đưa ra thư mục gốc libs
        find usr/lib/x86_64-linux-gnu/ -name "*.so*" -exec mv {} . \;
        rm -rf usr/ "$pkg.deb"
    else
        echo "✅ $pkg đã tồn tại trên Drive, bỏ qua."
    fi
done
```

Mỗi lần chạy, script kiểm tra xem file `.so` đã tồn tại trong `legacy_libs/` chưa. Nếu có (do đã tải từ phiên trước và lưu trên Drive), nó bỏ qua bước tải. Điều này giúp **tiết kiệm thời gian và băng thông** ở các lần chạy sau.

---

## Bước 3: Cài đặt thư viện Python (dòng 53)

```bash
pip install watchdog google-api-python-client google-auth-oauthlib google-auth httplib2 opencv-python psutil Pillow
```

Các thư viện này phục vụ cho:

| Thư viện | Vai trò |
|-----------|---------|
| `watchdog` | Theo dõi thay đổi thư mục (tự động xử lý khi có video mới) |
| `google-api-python-client` | Gọi Google Drive API để lưu kết quả OCR |
| `google-auth-oauthlib`, `google-auth` | Xác thực với Google Drive thông qua OAuth2 |
| `httplib2` | HTTP client (phụ thuộc của Google API client) |
| `opencv-python` | Xử lý ảnh (OCR frame từ video) |
| `psutil` | Giám sát tài nguyên hệ thống (CPU, RAM) |
| `Pillow` | Thao tác với ảnh (PIL fork) |

---

## Bước 4: Kiểm tra và tải VideoSubFinder (dòng 55-67)

```bash
if [ ! -f "$VSF_DIR/VideoSubFinderWXW" ]; then
    curl -L -o "$PARENT_DIR/$VSF_FILE" "$VSF_LINK"
    tar -xf "$PARENT_DIR/$VSF_FILE" -C "$PARENT_DIR/"
    rm "$PARENT_DIR/$VSF_FILE"
fi
```

### Mục đích

VideoSubFinder là binary ~500MB (đã build sẵn), không thể đưa vào git repository. Script tải nó từ GitHub Releases về thư mục `VideoSubFinder/` bên cạnh thư mục `autovsf-colab/`.

### Cơ chế cache trên Drive

Script kiểm tra sự tồn tại của binary trước khi tải. Vì thư mục `VideoSubFinder/` nằm trên Google Drive (đã mount), **chỉ tải một lần duy nhất**, các phiên Colab sau sẽ dùng lại mà không cần tải lại.

---

## Bước 5: Tạo wrapper script (dòng 70-81)

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

### Tại sao cần wrapper?

Wrapper này giải quyết **2 vấn đề** cùng lúc:

1. **Vá thư viện cũ:** Thiết lập `LD_LIBRARY_PATH` trỏ tới `legacy_libs/` để nạp các thư viện Ubuntu 20.04 trước, cho phép VideoSubFinder tìm đúng phiên bản cũ khi khởi động.

2. **Chạy headless:** Nếu biến môi trường `$DISPLAY` không tồn tại (đúng như trên Colab — không có màn hình vật lý), nó tự động dùng `xvfb-run` để tạo màn hình ảo và chạy VideoSubFinder bên trong.

---

## Tổng kết luồng hoạt động

```
install.sh
│
├── [1] apt-get install → xvfb, ffmpeg, thư viện hệ thống
│
├── [2] Tải & giải nén legacy .deb → lấy file .so
│     (chỉ tải nếu chưa có trên Drive)
│
├── [3] pip install → thư viện Python
│
├── [4] Tải VideoSubFinder binary
│     (chỉ tải nếu chưa có trên Drive)
│
└── [5] Tạo VideoSubFinderWXW.run
      → wrapper: LD_LIBRARY_PATH + xvfb-run
```

## Tóm tắt

`install.sh` biến một Google Colab VM trần thành môi trường hoàn chỉnh để chạy VideoSubFinder, bằng cách:

- Cài đặt các gói hệ thống cần thiết (buộc phải làm lại mỗi phiên)
- Vá các thư viện cũ không tương thích giữa Ubuntu 20.04 (nơi VSF được build) và Ubuntu 22.04 (Colab)
- Tải và cấu hình binary VideoSubFinder (được cache trên Drive)
- Tạo wrapper tự động xử lý cả vấn đề thư viện và màn hình ảo
