#!/usr/bin/env bash
# Armor 安装脚本（Apple 芯片 macOS）
#   curl -fsSL https://raw.githubusercontent.com/hongqi-lgs/armor-release/main/install.sh | bash
# 选项：
#   ARMOR_DIR=~/Applications   安装目录（默认 /Applications）
set -euo pipefail

REPO="hongqi-lgs/armor-release"
BASE="https://raw.githubusercontent.com/$REPO/main"
PAYLOAD="$BASE/Armor.app.tar.gz"
DEST="${ARMOR_DIR:-/Applications}"
APP="Armor.app"

say() { printf '%s\n' "$*"; }
die() { printf '错误：%s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "只支持 macOS"
[ "$(uname -m)" = "arm64" ] || die "当前只提供 Apple 芯片（arm64）安装包"

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

VERSION="$(curl -fsL --max-time 15 "$BASE/latest.json" \
  | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1 || true)"

if [ -n "$VERSION" ]; then
  say "→ 下载安装包（v$VERSION）"
else
  say "→ 下载安装包"
fi
curl -fL --retry 3 --progress-bar -o "$TMP/Armor.app.tar.gz" "$PAYLOAD" || die "下载失败"

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
