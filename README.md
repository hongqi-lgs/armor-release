# Armor

以 AI 为铠甲的桌面工作台。这个仓库只放**安装包与更新清单**，源码在私有仓。

## 安装（Apple 芯片 macOS）

```bash
curl -fsSL https://raw.githubusercontent.com/hongqi-lgs/armor-release/main/install.sh | bash
```

脚本会：读 `latest.json` 取版本号 → 下载 `v<版本>/Armor.app.tar.gz` → 解包 → 退出正在运行的 Armor → 装到 `/Applications` → 去掉隔离标记 → 启动。

- 装到用户目录（不需要 sudo）：`ARMOR_DIR=~/Applications curl -fsSL https://raw.githubusercontent.com/hongqi-lgs/armor-release/main/install.sh | bash`
- 钉版本安装（不读 `latest.json`，完全不受 CDN 缓存影响）：`curl -fsSL https://raw.githubusercontent.com/hongqi-lgs/armor-release/main/install.sh | ARMOR_VERSION=0.1.2 bash`
- 手动安装：下载 [`v0.1.2/Armor.app.tar.gz`](https://raw.githubusercontent.com/hongqi-lgs/armor-release/main/v0.1.2/Armor.app.tar.gz)，`tar -xzf Armor.app.tar.gz -C /Applications`；也可以解包后把 `Armor.app` 拖进「应用程序」。
- 当前版本见 [`latest.json`](https://raw.githubusercontent.com/hongqi-lgs/armor-release/main/latest.json)。

下载地址按版本号分目录（`v0.1.1/Armor.app.tar.gz`），路径一旦发布就不会变；升级到新版请再跑一次上面的命令，或等应用内自动更新。

## 第一次打开

安装包**没有做 Apple 公证**（未购买 Developer ID），系统可能提示"无法验证开发者"。两种解法：

1. 用上面的脚本安装——它会自动清掉隔离标记；
2. 手动安装时，在「应用程序」里右键 Armor → 打开 → 再点一次「打开」。

## 更新

应用启动时会检查 `latest.json`，有新版本会在标题下方出现提示条，点一下即可下载、验签、替换并重启。

更新包用 minisign 公钥验签，公钥固定在应用内，**不依赖 GitHub 的完整性**——即使发布仓被改成别的内容，签名不对也不会安装。

## 卸载

```bash
rm -rf /Applications/Armor.app
rm -rf ~/Library/Application\ Support/com.hongqi.armor   # 连同对话与配置一起删
```

密钥存在 macOS 钥匙串，条目名为 `armor`（账户 `provider.<id>`），可在「钥匙串访问」里手动删除。

## 当前版本能力

- 配置本地（Ollama 等）或远程（任意兼容 Chat Completions）模型
- 流式对话、会话列表、停止生成
- 自动更新

## 已知限制

- 只提供 arm64（Apple 芯片）包，Intel Mac 需要另打 x86_64 包
- 未公证：首次打开需要一次手动放行（见上）
- ad-hoc 签名：每次更新后，macOS 可能再问一次是否允许访问钥匙串，点「始终允许」即可
- 安装包直接存放在本仓的 `v<版本>/` 目录（不是 Releases），每版约占 4MB 仓体积；载荷路径不可变，只有根目录 `latest.json` 有 3–4 分钟 CDN 缓存，急用可 `ARMOR_VERSION=x.y.z` 钉版本安装
- 对话历史不做上下文压缩，长对话超过模型上下文会由服务端报错并原样显示
