# AutoVSF - Google Colab 版

> 🌐 **[Tiếng Việt](VIE_README.md)**

使用 VideoSubFinder 和 Google Drive OCR 自动提取硬字幕（hardsub）的工具。此版本专门优化以在 Google Drive 上持久运行。

🔗 **主版本 (Codespaces)：** [https://github.com/lionc2240/autovsf-codespaces](https://github.com/lionc2240/autovsf-codespaces)

---

## 🚀 快速开始

1. **打开 Notebook：** 用 Google Colab 打开 `AutoVSF_Colab_Edition.ipynb`。
2. **挂载 Drive：** 运行第一个单元格以连接到您的 Google Drive。
3. **配置：** 将您的 `credentials.json` 文件上传到 Drive 上的 `AutoVSF/autovsf-colab/` 文件夹。
4. **运行 Setup：** 执行设置单元格。脚本将自动修复 Ubuntu 22.04 的库兼容性问题。
5. **提取：** 输入视频路径并开始处理。

## 📸 截图

<p align="center">
  <img src="../images/autovsf-colab_ocr.jpg" width="55%" alt="AutoVSF Colab OCR">
</p>

## 🌟 Colab 版优势
- **数据不丢失：** 整个工具和所有结果都保存在 Drive 上。
- **节省时间：** VideoSubFinder 仅下载一次。
- **自动修复：** 全面处理新 Colab 环境中的缺失库问题。

## ⚠️ 注意事项
- 始终保护好您的 `credentials.json` 文件。
- 处理完成后，清理临时图像文件夹以避免占用 Drive 配额。

## 📚 文档
- [install.sh 说明](CN_install-explanation.md)
