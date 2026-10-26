#!/usr/bin/env bash
# Armor 安装脚本（Apple 芯片 macOS）
#   curl -fsSL https://raw.githubusercontent.com/hongqi-lgs/armor-release/main/install.sh | bash
# 选项（走环境变量，管道安装时也能用）：
#   ARMOR_DIR=~/Applications   安装目录（默认 /Applications）
#   ARMOR_VERSION=0.1.1        钉死版本：直接取 v0.1.1/ 目录，不读 latest.json
# 设计说明：载荷按版本号分目录存放（v<版本>/Armor.app.tar.gz），路径不可变，
# 所以只有 latest.json 会受 raw CDN 缓存（约 3–4 分钟）影响；钉版本安装完全绕开它。
#
# 三道关，顺序不能反（AGENTS.md R7：校验不可关、替换原子、失败保留旧版可启动）：
#   1. 下完先验哈希——在动旧版之前。不符就退出，旧版一根手指都没动
#   2. 把新版本写到目标目录里的临时名——写完才换，中途失败不会留下半截应用
#   3. mv 换名——同一目录内 rename 是原子的；换不进去就把旧版挪回原位
#
# 为什么用哈希而不是 codesign：构建产物是 linker-signed（没有资源封印），
# codesign --verify 既过不了也发现不了资源被改，验不出真伪。
# 哈希能防住"下载被截断 / CDN 发了旧载荷 / 解包前文件已损坏"——这三种都真实发生过。
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
# STAGE 在目标目录里（为了 rename 原子），中途退出也要清掉，否则会留下一个
# 隐藏的半个应用，人看着"装了两个 Armor"却不知道哪个能用。
cleanup() {
  rm -rf "$TMP"
  if [ -n "${STAGE:-}" ]; then rm -rf "$STAGE" 2>/dev/null || true; fi
}
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
HASH_URL="$BASE/v${VERSION}/Armor.app.tar.gz.sha256"
say "→ 下载安装包（v${VERSION}）"
curl -fL --retry 3 --progress-bar -o "$TMP/Armor.app.tar.gz" "$PAYLOAD" || die "下载失败：${PAYLOAD}"
[ -s "$TMP/Armor.app.tar.gz" ] || die "下载到的文件是空的"

# 第一道关：哈希。哈希文件与载荷同目录、路径同样不可变，所以它是这份发布的原件之一，
# 不会像 latest.json 那样被 CDN 先回源再更新。
# 0.1.3 及更早的版本目录里没有哈希文件（那时还没有这道关），取不到就只警告不拦——
# 否则钉版本回滚到旧版会装不上，回滚前提就断了。新版本一律有，见 release.sh。
if curl -fsL --max-time 15 --retry 3 -o "$TMP/payload.sha256" "$HASH_URL" 2>/dev/null; then
  EXPECTED="$(awk 'NR==1{print $1}' "$TMP/payload.sha256")"
  ACTUAL="$(shasum -a 256 "$TMP/Armor.app.tar.gz" | awk '{print $1}')"
  if [ "$EXPECTED" != "$ACTUAL" ]; then
    die "安装包校验失败（下载被截断、或该版本载荷已损坏）
  期望 ${EXPECTED}
  实际 ${ACTUAL}
旧版本没有改动，可以继续使用。"
  fi
  say "→ 哈希校验通过"
else
  say "→ 注意：v${VERSION} 没有发布哈希（0.1.3 及更早），跳过完整性校验"
fi

say "→ 解包"
tar -xzf "$TMP/Armor.app.tar.gz" -C "$TMP" || die "解包失败（包可能被截断）"
SRC="$TMP/$APP"
[ -d "$SRC" ] || die "安装包里找不到 $APP"

say "→ 退出正在运行的 Armor"
osascript -e 'quit app "Armor"' >/dev/null 2>&1 || true
sleep 1

say "→ 安装到 $DEST"
# 目标目录不存在时先自己建（新机器上 ~/Applications 往往没有）。
# 不建就直接测可写性，会被判成"不可写"而要求 sudo——说好的免 sudo 就失效了。
if [ ! -d "$DEST" ]; then
  mkdir -p "$DEST" 2>/dev/null || die "无法创建安装目录 ${DEST}（可用 ARMOR_DIR=~/Applications 换个位置）"
fi
SUDO=""
if [ ! -w "$DEST" ]; then SUDO="sudo"; fi

# 第二道关：先把新版本完整写进目标目录里的临时名。
# 写在目标目录而不是 /tmp，是为了后面 rename 落在同一个卷上——跨卷的 mv 是拷贝，
# 不是原子操作，那就白做了。
STAGE="$DEST/.${APP}.new.$$"
OLD="$DEST/.${APP}.old.$$"
$SUDO rm -rf "$STAGE" "$OLD"
$SUDO ditto "$SRC" "$STAGE" || die "写入新版本失败，旧版未动（常见原因是磁盘空间不足）"

# 第三道关：换入。任何一步失败都把旧版挪回原位。
# 绝不能在写成功之前 rm 旧版——那是之前版本的写法，ditto 一失败用户就没有 Armor 了。
if [ -d "$DEST/$APP" ] && ! $SUDO mv "$DEST/$APP" "$OLD"; then
  $SUDO rm -rf "$STAGE"
  die "无法移开旧版，未做任何改动"
fi
if $SUDO mv "$STAGE" "$DEST/$APP"; then
  $SUDO rm -rf "$OLD"
else
  if [ -d "$OLD" ]; then $SUDO mv "$OLD" "$DEST/$APP" || true; fi
  $SUDO rm -rf "$STAGE"
  die "替换失败，已回滚到旧版"
fi

# 未做 Apple 公证：去掉隔离标记，避免"已损坏"提示
$SUDO xattr -dr com.apple.quarantine "$DEST/$APP" 2>/dev/null || true

say "→ 完成：$DEST/$APP"
say "  数据存放在 ~/Library/Application Support/com.hongqi.armor（删应用不会删数据）"
open "$DEST/$APP" 2>/dev/null || say "  请手动打开 $DEST/$APP"

