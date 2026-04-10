#!/bin/bash

# 下载 CanvasKit 字体 fallback 所需的字体文件
# 包括：
# - NotoSansSC-Regular.otf：通过 pubspec.yaml 绑定的完整中文字体
# - Noto Sans SC 分片 woff2：CanvasKit fallback 按需加载的中文字体分片（编号 4-119）
# - Roboto：英文字体（CanvasKit fallback 机制使用）
#
# CanvasKit 渲染引擎在遇到绑定字体未覆盖的字符时，会从 fontFallbackBaseUrl 按需加载
# Google Fonts 的分片 woff2 文件。embedded 模式下需要预下载这些分片到本地。

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="$(dirname "$SCRIPT_DIR")"
FONTS_DIR="$FRONTEND_DIR/web/fonts"
PUBSPEC_FONTS_DIR="$FRONTEND_DIR/fonts"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}下载 CanvasKit 字体文件${NC}"
echo -e "${BLUE}========================================${NC}"

# 创建目录结构
mkdir -p "$FONTS_DIR/roboto/v32"
mkdir -p "$FONTS_DIR/notosanssc/v37"
mkdir -p "$PUBSPEC_FONTS_DIR"

# ========================================
# 下载 NotoSansSC-Regular.otf（pubspec.yaml 绑定字体）
# ========================================
echo -e "${BLUE}[1/3] 下载 NotoSansSC-Regular.otf...${NC}"

NOTO_OTF_FILE="$PUBSPEC_FONTS_DIR/NotoSansSC-Regular.otf"
if [ -f "$NOTO_OTF_FILE" ]; then
    echo -e "  [跳过] NotoSansSC-Regular.otf (已存在)"
else
    NOTO_OTF_URL="https://github.com/notofonts/noto-cjk/raw/main/Sans/SubsetOTF/SC/NotoSansSC-Regular.otf"
    echo -e "  [下载] NotoSansSC-Regular.otf"
    if curl -s -f -L -o "$NOTO_OTF_FILE" "$NOTO_OTF_URL" 2>/dev/null; then
        echo -e "    ${GREEN}\u2713${NC} 成功"
    else
        rm -f "$NOTO_OTF_FILE"
        echo -e "    ${RED}\u2717${NC} 下载失败"
    fi
fi

# ========================================
# 下载 Noto Sans SC 分片 woff2（CanvasKit fallback 字体）
# ========================================
echo -e "${BLUE}[2/3] 下载 Noto Sans SC 分片 woff2 (CanvasKit fallback)...${NC}"

# CanvasKit 使用 Google Fonts 的分片 woff2 文件，按 Unicode 范围分片
# Noto Sans SC v37 共有编号 4-119 的分片文件
NOTO_SC_BASE_URL="https://fonts.gstatic.com/s/notosanssc/v37"
NOTO_SC_FILENAME_PREFIX="k3kCo84MPvpLmixcA63oeAL7Iqp5IZJF9bmaG9_FnYkldv7JjxkkgFsFSSOPMOkySAZ73y9ViAt3acb8NexQ2w"
NOTO_SC_SHARD_START=4
NOTO_SC_SHARD_END=119
NOTO_SC_OUTPUT_DIR="$FONTS_DIR/notosanssc/v37"

noto_sc_downloaded=0
noto_sc_skipped=0
noto_sc_failed=0

for i in $(seq $NOTO_SC_SHARD_START $NOTO_SC_SHARD_END); do
    filename="${NOTO_SC_FILENAME_PREFIX}.${i}.woff2"
    OUTPUT_FILE="$NOTO_SC_OUTPUT_DIR/$filename"
    if [ -f "$OUTPUT_FILE" ]; then
        noto_sc_skipped=$((noto_sc_skipped + 1))
    else
        URL="${NOTO_SC_BASE_URL}/${filename}"
        if curl -s -f -o "$OUTPUT_FILE" "$URL" 2>/dev/null; then
            noto_sc_downloaded=$((noto_sc_downloaded + 1))
        else
            rm -f "$OUTPUT_FILE"
            noto_sc_failed=$((noto_sc_failed + 1))
        fi
    fi
done

noto_sc_total=$((NOTO_SC_SHARD_END - NOTO_SC_SHARD_START + 1))
echo -e "  ${GREEN}✓${NC} Noto Sans SC 分片: 共 ${noto_sc_total} 个, 新下载 ${noto_sc_downloaded}, 已存在 ${noto_sc_skipped}, 失败 ${noto_sc_failed}"
if [ "$noto_sc_failed" -gt 0 ]; then
    echo -e "  ${YELLOW}⚠${NC} 部分分片下载失败，大屏模式下可能仍有中文显示为方框"
fi

# ========================================
# 下载 Roboto 字体
# ========================================
echo -e "${BLUE}[3/3] 下载 Roboto 字体...${NC}"

ROBOTO_FILES=(
    "KFOmCnqEu92Fr1Me4GZLCzYlKw.woff2"
)

for filename in "${ROBOTO_FILES[@]}"; do
    OUTPUT_FILE="$FONTS_DIR/roboto/v32/$filename"
    if [ -f "$OUTPUT_FILE" ]; then
        echo -e "  [跳过] $filename (已存在)"
    else
        URL="https://fonts.gstatic.com/s/roboto/v32/$filename"
        echo -e "  [下载] $filename"
        if curl -s -f -o "$OUTPUT_FILE" "$URL" 2>/dev/null; then
            echo -e "    ${GREEN}✓${NC} 成功"
        else
            rm -f "$OUTPUT_FILE"
            echo -e "    ${RED}✗${NC} 下载失败"
        fi
    fi
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ 字体下载完成！${NC}"
echo -e "${GREEN}========================================${NC}"
