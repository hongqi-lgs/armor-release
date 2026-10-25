#!/usr/bin/env bash
# Armor 安装脚本（Apple 芯片 macOS）
#   curl -fsSL https://raw.githubusercontent.com/hongqi-lgs/armor-release/main/install.sh | bash
# 选项（走环境变量，管道安装时也能用）：
#   ARMOR_DIR=~/Applications   安装目录（默认 /Applications）
#   ARMOR_VERSION=0.1.1        钉死版本：直接取 v0.1.1/ 目录，不读 latest.json
# 设计说明：载荷按版本号分目录存放（v<版本>/Armor.app.tar.gz），路径不可变，
# 所以只有 latest.json 会受 raw CDN 缓存（约 3–4 分钟）影响；钉版本安装完全绕开它。
set -euo pipefail

REPO="hongqi-lgs/armor-release"
BASE="${ARMOR_BASE:-https://raw.githubusercontent.com/$REPO/main}"
DEST="${ARMOR_DIR:-/Applications}"
APP="Armor.app"
VERSION="${ARMOR_VERSION:-}"

say() { printf '%s\n' "$*"; }
die() { printf '错误：%s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "只支持 macOS"
[ "$(uname -m)" = "arm64" ] || die "当前只提供 Apple 芯片（arm64）安装包"

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

if [ -z "$VERSION" ]; then
  VERSION="$(curl -fsL --max-time 15 --retry 3 "$BASE/latest.json" \
    | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1 || true)"
  [ -n "$VERSION" ] || die "读不到 latest.json 里的版本号（可改用 ARMOR_VERSION=x.y.z 钉版本安装）"
  say "→ 最新版本 v${VERSION}"
else
  say "→ 指定版本 v${VERSION}"
fi

# 版本号只允许数字和点，避免拼进 URL 后跑到别的路径
case "$VERSION" in
  *[!0-9.]*|"") die "版本号格式不对：$VERSION" ;;
esac

PAYLOAD="$BASE/v${VERSION}/Armor.app.tar.gz"
say "→ 下载安装包（v${VERSION}）"
curl -fL --retry 3 --progress-bar -o "$TMP/Armor.app.tar.gz" "$PAYLOAD" || die "下载失败：$PAYLOAD"
[ -s "$TMP/Armor.app.tar.gz" ] || die "下载到的文件是空的"

say "→ 解包"
tar -xzf "$TMP/Armor.app.tar.gz" -C "$TMP" || die "解包失败"
SRC="$TMP/$APP"
[ -d "$SRC" ] || die "安装包里找不到 $APP"

say "→ 退出正在运行的 Armor"
osascript -e 'quit app "Armor"' >/dev/null 2>&1 || true
sleep 1

say "→ 安装到 $DEST"
SUDO=""
if [ ! -w "$DEST" ]; then SUDO="sudo"; fi
$SUDO rm -rf "$DEST/$APP"
$SUDO ditto "$SRC" "$DEST/$APP"

# 未做 Apple 公证：去掉隔离标记，避免"已损坏"提示
$SUDO xattr -dr com.apple.quarantine "$DEST/$APP" 2>/dev/null || true

say "→ 完成：$DEST/$APP"
say "  数据存放在 ~/Library/Application Support/com.hongqi.armor（删应用不会删数据）"
open "$DEST/$APP" 2>/dev/null || say "  请手动打开 $DEST/$APP"

