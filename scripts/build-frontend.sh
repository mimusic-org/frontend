#!/bin/bash

# MiMusic Flutter 前端构建脚本
# 用法：./scripts/build-frontend.sh <platform> [output_dir]
# 平台：web | web-embedded | linux | windows | macos | android | ios | all
#
# 示例：
#   ./scripts/build-frontend.sh web
#   ./scripts/build-frontend.sh linux /tmp/mimusic-build
#   ./scripts/build-frontend.sh all ./frontend-build

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 获取脚本所在目录（脚本位于 frontend/scripts/ 下）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$FRONTEND_DIR")"

# 参数解析
PLATFORM="${1:-}"
OUTPUT_DIR="${2:-$(pwd)/frontend-build}"

# 帮助信息
show_help() {
    echo -e "${BLUE}MiMusic Flutter 前端构建工具${NC}"
    echo ""
    echo "用法：$0 <platform> [output_dir]"
    echo ""
    echo "平台参数："
    echo "  web            构建 Web 独立部署版（standalone）"
    echo "  web-embedded   构建 Web 嵌入版（embedded，用于 Go 后端嵌入）"
    echo "  linux          构建 Linux 桌面版"
    echo "  windows        构建 Windows 桌面版"
    echo "  macos          构建 macOS 桌面版"
    echo "  android        构建 Android 版（APK + AAB）"
    echo "  ios            构建 iOS 版（仅 macOS 可用）"
    echo "  all            构建当前系统支持的所有平台"
    echo ""
    echo "可选参数："
    echo "  output_dir     输出目录（默认：\$(pwd)/frontend-build）"
    echo ""
    echo "示例："
    echo "  $0 web"
    echo "  $0 linux /tmp/mimusic-build"
    echo "  $0 all ./frontend-build"
}

# 校验参数
if [ -z "$PLATFORM" ]; then
    show_help
    exit 1
fi

# 日志目录
LOG_DIR="$OUTPUT_DIR/.build_logs"

# 检查 Flutter 是否安装
check_flutter() {
    if ! command -v flutter &>/dev/null; then
        echo -e "${RED}错误：未检测到 Flutter，请先安装 Flutter SDK${NC}"
        exit 1
    fi
}

# 准备构建环境
prepare() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}MiMusic Flutter 前端构建工具${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "${BLUE}构建平台:${NC} $PLATFORM"
    echo -e "${BLUE}输出目录:${NC} $OUTPUT_DIR"
    echo -e "${BLUE}前端目录:${NC} $FRONTEND_DIR"
    echo ""

    check_flutter

    echo -e "${BLUE}Flutter 版本:${NC}"
    flutter --version
    echo ""

    mkdir -p "$OUTPUT_DIR"
    mkdir -p "$LOG_DIR"

    echo -e "${BLUE}[准备阶段]${NC} 安装 Flutter 依赖..."
    cd "$FRONTEND_DIR"
    flutter pub get
    echo -e "${GREEN}✓${NC} 依赖安装完成"
    echo ""
}

# 构建函数
build_web() {
    local mode="${1:-standalone}"
    local output_name="web-${mode}"
    local output="$OUTPUT_DIR/$output_name"
    local log_file="$LOG_DIR/${output_name}.log"

    echo -e "${BLUE}[Web]${NC} 开始构建 Web ${mode} 版..."
    cd "$FRONTEND_DIR"
    flutter build web --no-web-resources-cdn --dart-define=DEPLOY_MODE=${mode} --output="$output" 2>&1 | tee -a "$log_file"
    echo -e "${GREEN}✓ [Web]${NC} Web ${mode} 构建完成 → $output"
}

build_linux() {
    local output="$OUTPUT_DIR/linux"
    local log_file="$LOG_DIR/linux.log"

    echo -e "${BLUE}[Linux]${NC} 开始构建 Linux 版本..."
    cd "$FRONTEND_DIR"
    flutter build linux --release 2>&1 | tee -a "$log_file"
    cp -r build/linux/x64/release/bundle "$output"
    echo -e "${GREEN}✓ [Linux]${NC} Linux 构建完成 → $output"
}

build_windows() {
    local output="$OUTPUT_DIR/windows"
    local log_file="$LOG_DIR/windows.log"

    echo -e "${BLUE}[Windows]${NC} 开始构建 Windows 版本..."
    cd "$FRONTEND_DIR"
    flutter build windows --release 2>&1 | tee -a "$log_file"
    cp -r build/windows/x64/runner/Release "$output"
    echo -e "${GREEN}✓ [Windows]${NC} Windows 构建完成 → $output"
}

build_macos() {
    local output="$OUTPUT_DIR/macos"
    local log_file="$LOG_DIR/macos.log"

    if [[ "$(uname)" != "Darwin" ]]; then
        echo -e "${RED}✗ [macOS]${NC} macOS 构建仅在 macOS 系统上支持"
        return 1
    fi

    echo -e "${BLUE}[macOS]${NC} 开始构建 macOS 版本..."
    cd "$FRONTEND_DIR"
    flutter build macos --release 2>&1 | tee -a "$log_file"
    cp -r build/macos/Build/Products/Release/*.app "$output/"
    echo -e "${GREEN}✓ [macOS]${NC} macOS 构建完成 → $output"
}

build_android() {
    local output="$OUTPUT_DIR/android"
    local log_file="$LOG_DIR/android.log"

    echo -e "${BLUE}[Android]${NC} 开始构建 Android 版本..."
    cd "$FRONTEND_DIR"
    mkdir -p "$output"

    # 构建 APK（split-per-abi 生成多架构包）
    flutter build apk --release --split-per-abi 2>&1 | tee -a "$log_file"
    # 复制 APK 产物到输出目录
    if [ -d "build/app/outputs/flutter-apk" ]; then
        cp -r build/app/outputs/flutter-apk "$output/apk"
        echo -e "${GREEN}✓ [Android]${NC} APK 构建完成"
    fi

    # 构建 AAB（App Bundle）
    flutter build appbundle --release 2>&1 | tee -a "$log_file"
    # 复制 AAB 产物到输出目录
    if [ -d "build/app/outputs/bundle/release" ]; then
        mkdir -p "$output/bundle"
        cp build/app/outputs/bundle/release/*.aab "$output/bundle/"
        echo -e "${GREEN}✓ [Android]${NC} AAB 构建完成"
    fi

    echo -e "${GREEN}✓ [Android]${NC} Android 构建完成 → $output"
}

build_ios() {
    local output="$OUTPUT_DIR/ios"
    local log_file="$LOG_DIR/ios.log"

    if [[ "$(uname)" != "Darwin" ]]; then
        echo -e "${RED}✗ [iOS]${NC} iOS 构建仅在 macOS 系统上支持"
        return 1
    fi

    echo -e "${BLUE}[iOS]${NC} 开始构建 iOS 版本..."
    cd "$FRONTEND_DIR"
    flutter build ios --release --no-codesign 2>&1 | tee -a "$log_file"
    cp -r build/ios/iphoneos/*.app "$output/" 2>/dev/null || true
    echo -e "${GREEN}✓ [iOS]${NC} iOS 构建完成 → $output"
}

build_all() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}[并行构建] 启动所有平台构建...${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    PIDS=()
    PLATFORMS_LAUNCHED=()

    # Web
    echo -e "${YELLOW}→ 启动 Web 构建${NC}"
    (build_web standalone) &
    PIDS+=($!)
    PLATFORMS_LAUNCHED+=("web")

    # Linux
    echo -e "${YELLOW}→ 启动 Linux 构建${NC}"
    (build_linux) &
    PIDS+=($!)
    PLATFORMS_LAUNCHED+=("linux")

    # Windows（仅 Windows 系统）
    if [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == CYGWIN* ]] || [[ "$(uname -s)" == MSYS* ]]; then
        echo -e "${YELLOW}→ 启动 Windows 构建${NC}"
        (build_windows) &
        PIDS+=($!)
        PLATFORMS_LAUNCHED+=("windows")
    else
        echo -e "${YELLOW}⚠ 跳过 Windows 构建（需要 Windows 系统）${NC}"
    fi

    # macOS（仅 macOS 系统）
    if [[ "$(uname)" == "Darwin" ]]; then
        echo -e "${YELLOW}→ 启动 macOS 构建${NC}"
        (build_macos) &
        PIDS+=($!)
        PLATFORMS_LAUNCHED+=("macos")

        echo -e "${YELLOW}→ 启动 iOS 构建${NC}"
        (build_ios) &
        PIDS+=($!)
        PLATFORMS_LAUNCHED+=("ios")
    else
        echo -e "${YELLOW}⚠ 跳过 macOS/iOS 构建（需要 macOS 系统）${NC}"
    fi

    # Android（需要 Android SDK）
    if command -v sdkmanager &>/dev/null || [ -n "$ANDROID_HOME" ] || [ -n "$ANDROID_SDK_ROOT" ]; then
        echo -e "${YELLOW}→ 启动 Android 构建${NC}"
        (build_android) &
        PIDS+=($!)
        PLATFORMS_LAUNCHED+=("android")
    else
        echo -e "${YELLOW}⚠ 跳过 Android 构建（未检测到 Android SDK）${NC}"
    fi

    echo ""
    echo -e "${BLUE}等待所有构建进程完成...${NC}"
    echo ""

    FAILED=0
    for pid in "${PIDS[@]}"; do
        if ! wait "$pid"; then
            FAILED=1
        fi
    done

    if [ $FAILED -eq 1 ]; then
        echo -e "${RED}========================================${NC}"
        echo -e "${RED}✗ 部分平台构建失败${NC}"
        echo -e "${RED}========================================${NC}"
        echo ""
        echo -e "${YELLOW}查看各平台构建日志:${NC}"
        for log_file in "$LOG_DIR"/*.log; do
            if [ -s "$log_file" ]; then
                echo "  - $(basename "$log_file" .log): $log_file"
            fi
        done
        exit 1
    fi
}

# 显示构建结果
show_result() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ 构建完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${BLUE}输出目录:${NC} $OUTPUT_DIR"
    echo ""

    # 列出产物
    for dir in "$OUTPUT_DIR"/*/; do
        if [ -d "$dir" ] && [ "$(basename "$dir")" != ".build_logs" ]; then
            local platform_name
            platform_name=$(basename "$dir")
            local size
            size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            echo "  ${platform_name}: ${size}"
        fi
    done
    echo ""
}

# 主流程
prepare

case "$PLATFORM" in
    web)
        build_web standalone
        ;;
    web-embedded)
        build_web embedded
        ;;
    linux)
        build_linux
        ;;
    windows)
        build_windows
        ;;
    macos)
        build_macos
        ;;
    android)
        build_android
        ;;
    ios)
        build_ios
        ;;
    all)
        build_all
        ;;
    *)
        echo -e "${RED}错误：未知平台 '$PLATFORM'${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac

show_result
