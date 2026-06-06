# AutoVSF - Phiên bản Google Colab

Công cụ trích xuất phụ đề cứng (Hardsub) tự động thông qua VideoSubFinder và Google Drive OCR. Phiên bản này được tối ưu hóa đặc biệt để chạy bền vững trên Google Drive.

🔗 **Phiên bản chính (Windows):** [![GitHub](https://img.shields.io/badge/GitHub-Xem_trên_GitHub-blue?logo=github)](https://github.com/lionc2240/autovsf)
🔗 **Phiên bản Codespaces:** [![GitHub](https://img.shields.io/badge/GitHub-Xem_trên_GitHub-blue?logo=github)](https://github.com/lionc2240/autovsf-codespaces)
🔗 **Phiên bản Colab:** [![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/lionc2240/autovsf-colab/blob/main/AutoVSF_Colab_Edition.ipynb?hl=vi)

---

## 🚀 Hướng dẫn sử dụng nhanh

1. **Mở file Notebook:** Mở `AutoVSF_Colab_Edition.ipynb` bằng Google Colab.
2. **Mount Drive:** Chạy Cell đầu tiên để kết nối với Google Drive.
3. **Cấu hình:** Tải file `credentials.json` của bạn lên thư mục `AutoVSF/autovsf-colab/` trên Drive.
4. **Chạy Setup:** Chạy Cell cài đặt. Script sẽ tự động vá lỗi thư viện cho Ubuntu 22.04.
5. **Trích xuất:** Nhập đường dẫn video và bắt đầu chạy.

## 📸 Ảnh chụp màn hình

<p align="center">
  <img src="../images/autovsf-colab_ocr.jpg" width="55%" alt="AutoVSF Colab OCR">
</p>

## 🌟 Ưu điểm của bản Colab
- **Không mất dữ liệu:** Toàn bộ tool và kết quả được lưu trên Drive.
- **Tiết kiệm thời gian:** Chỉ tải VideoSubFinder một lần duy nhất.
- **Tự động vá lỗi:** Xử lý triệt để các thư viện thiếu hụt trên môi trường Colab mới.

## ⚠️ Lưu ý
- Luôn giữ file `credentials.json` bảo mật.
- Sau khi chạy xong, hãy dọn dẹp thư mục ảnh tạm để tránh đầy dung lượng Drive.

## 📚 Tài liệu
- [Giải thích chi tiết install.sh](VIE_install-explanation.md)
