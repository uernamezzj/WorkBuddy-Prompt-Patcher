#!/bin/bash
# ==============================================================================
#  macOS 重签名工具 (WorkBuddy Prompt Patcher 专用)
# ==============================================================================
#  为什么需要它：
#    /Applications/WorkBuddy.app 是 Apple 公证过的 Developer ID 签名包。
#    一旦在 app.asar.unpacked 里改写 .tpl 模板，CodeResources 的资源哈希
#    就不再匹配 → codesign --verify 报 "a sealed resource is missing or invalid"，
#    spctl --assess 直接判定不可信，后续 macOS 版本可能拒绝启动。
#
#  本脚本把整个 bundle 按「由内到外」顺序 ad-hoc 重签一遍：
#    1) 先签所有「叶子」组件：
#       - framework 内部的裸可执行文件（如 Electron Framework.framework 的
#         Helpers/chrome_crashpad_handler）
#       - 所有嵌套 bundle：.framework / .app / .appex / .xpc
#       顺序按路径深度倒序，保证「内层先签、外层后签」——
#       外层 CodeResources 要记录到内层签完之后的正确哈希
#    2) 最后签外层 bundle
#    3) 保留每个组件原有的 entitlements（allow-jit / disable-library-validation 等）
#       —— Electron 靠这些跑 V8 JIT，丢了会白屏起不来
#
#  用法: ./macos_resign.sh ["/Applications/WorkBuddy.app"]
# ==============================================================================

APP="${1:-/Applications/WorkBuddy.app}"

if [ ! -d "$APP" ]; then
  echo "[!] 找不到应用包: $APP"
  exit 1
fi

if ! command -v codesign >/dev/null 2>&1; then
  echo "[!] 系统未提供 codesign，无法重签。"
  exit 1
fi

echo "==> 目标: $APP"

sign_one() {
  local target="$1"
  codesign --force --sign - \
    --preserve-metadata=entitlements,flags \
    --timestamp=none "$target" >/dev/null 2>&1
}

# --- 1. 收集叶子：framework 内部的裸可执行文件 ---
#     (它们被 framework 的 CodeResources 封章，不签就报 "file modified")
LEAVES="$(find "$APP" -type d -name 'Helpers' 2>/dev/null | while read -r hd; do
  find "$hd" -maxdepth 2 -type f -perm -u+x 2>/dev/null
done)"

# --- 2. 收集嵌套 bundle ---
BUNDLES="$(find "$APP" \
  \( -name '*.app' -o -name '*.framework' -o -name '*.appex' -o -name '*.xpc' \) \
  -type d 2>/dev/null | grep -v "^${APP}$" | sort)"

# --- 3. 先签叶子（最内层） ---
LC=0
while IFS= read -r bin; do
  [ -z "$bin" ] && continue
  if sign_one "$bin"; then LC=$((LC + 1)); fi
done <<< "$LEAVES"

# --- 4. 再签嵌套 bundle，深度倒序（内层先、外层后） ---
SORTED="$(printf '%s\n' "$BUNDLES" | awk '{print length($0)"\t"$0}' | sort -rn | cut -f2-)"
BC=0
while IFS= read -r item; do
  [ -z "$item" ] && continue
  if sign_one "$item"; then BC=$((BC + 1)); fi
done <<< "$SORTED"

echo "==> 已重签: $BC 个嵌套 bundle + $LC 个 framework 内二进制"

# --- 5. 最后签外层 bundle ---
if sign_one "$APP"; then
  echo "==> 已重签外层 bundle"
else
  echo "[!] 外层 bundle 重签失败"
  exit 1
fi

# --- 6. 校验 ---
echo "==> 校验签名完整性..."
VERIFY_OUT="$(codesign --verify --deep --strict "$APP" 2>&1)"
if [ -z "$VERIFY_OUT" ]; then
  echo "    [OK] codesign --verify --deep --strict 通过"
else
  echo "    [!!] 仍有告警:"
  echo "$VERIFY_OUT" | head -6
fi

exit 0
