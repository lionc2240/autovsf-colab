# `install.sh` 说明

## 概述

`install.sh` 是一个自动设置脚本，专门为 **Google Colab**（Ubuntu 22.04 Jammy）设计。它执行 4 个主要步骤来为运行 VideoSubFinder 准备环境。

## 目录结构

在深入了解细节之前，以下是脚本假设的目录结构：

```
/content/drive/MyDrive/AutoVSF/          # PARENT_DIR
├── VideoSubFinder/                      # VSF_DIR
│   ├── VideoSubFinderWXW               # 主二进制文件
│   ├── VideoSubFinderWXW.run           # 封装脚本
│   └── legacy_libs/                    # 旧版库（兼容性修复）
└── autovsf-colab/                       # REPO_DIR（当前目录）
    ├── install.sh
    ├── headless.py
    ├── ocr.py
    └── config.py
```

`REPO_DIR` 是代码目录（`autovsf-colab`），`PARENT_DIR` 是父目录（`AutoVSF`），`VSF_DIR` 是 VideoSubFinder 二进制目录（`VideoSubFinder`）。

---

## 步骤 1：安装系统工具（第 17-18 行）

```bash
sudo apt-get update -y || true
sudo apt-get install -y xvfb libxss1 libnss3 ffmpeg libxtst6 ...
```

### 目的

安装必要的系统包以在无头环境（如 Colab）中运行 VideoSubFinder（一个 GUI 应用程序，使用 WXWidgets）。

### 关键包

| 包名 | 作用 |
|---------|------|
| `xvfb` | **X Virtual Framebuffer** — 模拟虚拟显示器以在无头服务器上运行 GUI 应用 |
| `ffmpeg` | 视频处理，解码各种输入格式 |
| `libxss1`, `libnss3`, `libgtk-3-0` | VideoSubFinder（基于 WXWidgets 构建）所需的 GTK/WX 库 |
| `libxtst6`, `libxrender1`, `libxcomposite1` | 虚拟窗口渲染的 X11 支持库 |

### 为什么每次都要运行？

在 Google Colab 上，每个运行时会话都是一个全新的虚拟机，因此系统包不会跨会话持久化。

---

## 步骤 2：旧版库兼容性修复（第 21-48 行）

### 问题

VideoSubFinder 是使用旧库版本在 **Ubuntu 20.04** 上构建的。Google Colab 运行的是 **Ubuntu 22.04**，其库版本较新且不向后兼容。脚本无法通过 `apt-get` 安装旧库，因为 Ubuntu 22.04 的官方仓库不再支持这些包。

### 解决方案

脚本直接从 Ubuntu 20.04 存档（old-releases、security、azure mirror）下载 `.deb` 文件，解压它们，只提取 `.so*`（共享对象/动态库）文件。这些文件被放置在 `legacy_libs/` 目录中，并通过 `LD_LIBRARY_PATH` 环境变量加载。

### 修补的库

| 库名 | 来源 .deb 文件 | 说明 |
|---------|-----------------|-------|
| `libaom0` | `aom_1.0.0.errata1-3build1_amd64.deb` | AV1 编解码器 |
| `libvpx6` | `libvpx6_1.8.2-1ubuntu0.4_amd64.deb` | VP8/VP9 编解码器 |
| `libx264-155` | `x264_0.155.2917+git0a84d98-2_amd64.deb` | H.264 编解码器 |
| `libx265-179` | `x265_3.2.1-1build1_amd64.deb` | H.265 编解码器 |
| `libflite1` | `flite_2.1-release-3_amd64.deb` | 文本转语音（旧版 ffmpeg 依赖） |
| `libwavpack1` | `wavpack_5.2.0-1ubuntu0.1_amd64.deb` | 音频编解码器 |
| `libwebp6` | `libwebp_0.6.1-2ubuntu0.20.04.3_amd64.deb` | WebP 编解码器 |
| `libcodec2-0.9` | `codec2_0.9.2-2_amd64.deb` | Codec2 编解码器 |

### 工作原理（第 37-48 行）

```bash
for pkg in "${!DEBS[@]}"; do
    if [ ! -f "${pkg}.so" ]; then
        # 从 URL 下载 .deb
        curl -L -o "$pkg.deb" "${DEBS[$pkg]}"
        # 解压 .deb（不安装，仅解压）
        dpkg -x "$pkg.deb" .
        # 查找 .so 文件并移动到 libs 根目录
        find usr/lib/x86_64-linux-gnu/ -name "*.so*" -exec mv {} . \;
        rm -rf usr/ "$pkg.deb"
    else
        echo "✅ $pkg 已存在于 Drive 上，跳过。"
    fi
done
```

每次运行时，脚本检查 `.so` 文件是否已存在于 `legacy_libs/` 中。如果存在（从之前的会话保存在 Drive 上），则跳过下载。这在后续运行中**节省了时间和带宽**。

---

## 步骤 3：安装 Python 库（第 53 行）

```bash
pip install watchdog google-api-python-client google-auth-oauthlib google-auth httplib2 opencv-python psutil Pillow
```

这些库的作用如下：

| 库名 | 作用 |
|---------|------|
| `watchdog` | 监控目录变化（添加新视频时自动处理） |
| `google-api-python-client` | 调用 Google Drive API 保存 OCR 结果 |
| `google-auth-oauthlib`, `google-auth` | 通过 OAuth2 与 Google Drive 认证 |
| `httplib2` | HTTP 客户端（Google API 客户端依赖） |
| `opencv-python` | 图像处理（从视频中提取 OCR 帧） |
| `psutil` | 系统资源监控（CPU、RAM） |
| `Pillow` | 图像处理（PIL 分支） |

---

## 步骤 4：下载并验证 VideoSubFinder（第 55-67 行）

```bash
if [ ! -f "$VSF_DIR/VideoSubFinderWXW" ]; then
    curl -L -o "$PARENT_DIR/$VSF_FILE" "$VSF_LINK"
    tar -xf "$PARENT_DIR/$VSF_FILE" -C "$PARENT_DIR/"
    rm "$PARENT_DIR/$VSF_FILE"
fi
```

### 目的

VideoSubFinder 是一个约 500MB 的预构建二进制文件，无法包含在 git 仓库中。脚本从 GitHub Releases 将其下载到 `autovsf-colab/` 旁边的 `VideoSubFinder/` 目录。

### Drive 缓存机制

脚本在下载前检查二进制文件是否存在。由于 `VideoSubFinder/` 目录位于 Google Drive（已挂载）上，**它只被下载一次**；后续 Colab 会话无需重新下载即可重复使用。

---

## 步骤 5：创建封装脚本（第 70-81 行）

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

### 为什么需要封装？

这个封装同时解决了 **2 个问题**：

1. **旧库注入：** 设置 `LD_LIBRARY_PATH` 指向 `legacy_libs/`，首先加载 Ubuntu 20.04 库，使 VideoSubFinder 在启动时能找到正确的旧版本。

2. **无头执行：** 如果 `$DISPLAY` 环境变量不存在（Colab 上正是如此 — 没有物理显示器），它会自动使用 `xvfb-run` 创建虚拟显示器并在其中运行 VideoSubFinder。

---

## 执行流程总结

```
install.sh
│
├── [1] apt-get install → xvfb, ffmpeg, 系统库
│
├── [2] 下载并解压旧 .deb → 获取 .so 文件
│     （仅在 Drive 上不存在时下载）
│
├── [3] pip install → Python 库
│
├── [4] 下载 VideoSubFinder 二进制文件
│     （仅在 Drive 上不存在时下载）
│
└── [5] 创建 VideoSubFinderWXW.run
      → 封装: LD_LIBRARY_PATH + xvfb-run
```

## 结论

`install.sh` 通过以下方式将裸机的 Google Colab VM 转换为完整的 VideoSubFinder 运行环境：

- 安装必要的系统包（每次会话都必须执行）
- 修补 VideoSubFinder 构建环境（Ubuntu 20.04）与 Colab（Ubuntu 22.04）之间不兼容的旧版库
- 下载并配置 VideoSubFinder 二进制文件（缓存在 Drive 上）
- 创建同时处理库兼容性和虚拟显示问题的封装脚本
