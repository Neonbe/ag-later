#!/usr/bin/env bash
# ag-send.sh — Antigravity 定时消息发送核心脚本
# 通过 AppleScript 激活 Antigravity 窗口并模拟键盘输入发送消息
set -euo pipefail

# ── 配置 ──────────────────────────────────────────────────────────────────────
AG_SCHEDULE_DIR="$HOME/.ag-schedule"
LOG_FILE="$AG_SCHEDULE_DIR/logs/send.log"
APP_NAME="Antigravity"
# 等待窗口就绪的时间（秒）
ACTIVATE_DELAY=0.8
# 粘贴后等待时间（秒）
PASTE_DELAY=0.3
# 锁屏时最大等待时间（秒）
LOCK_TIMEOUT=600
# 锁屏检查间隔（秒）
LOCK_CHECK_INTERVAL=10

# ── 工具函数 ──────────────────────────────────────────────────────────────────

log() {
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  local msg="[$timestamp] $1"
  echo "$msg" >> "$LOG_FILE"
  echo "$msg"
}

notify() {
  osascript -e "display notification \"$1\" with title \"ag-schedule\"" 2>/dev/null || true
}

is_screen_locked() {
  # CGSessionCopyCurrentDictionary 方式检测锁屏
  local locked
  locked=$(python3 -c "
import Quartz
d = Quartz.CGSessionCopyCurrentDictionary()
print(d.get('CGSSessionScreenIsLocked', 0) if d else 0)
" 2>/dev/null)
  [ "$locked" = "1" ]
}

is_app_running() {
  # 通过 macOS lsappinfo 查询 App 注册表（最可靠，不受子进程环境影响）
  lsappinfo info -only pid "$APP_NAME" 2>/dev/null | grep -q "pid"
}

# ── 参数解析 ──────────────────────────────────────────────────────────────────

# 支持两种调用方式：
#   ag-send.sh "消息内容"
#   ag-send.sh --file /path/to/message.txt
#   ag-send.sh --delay 60 "消息内容"        （内置延迟）
#   ag-send.sh --delay 60 --file /path.txt

DELAY=0
MESSAGE=""
MESSAGE_FILE=""
JOB_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --delay)
      DELAY="$2"
      shift 2
      ;;
    --file)
      MESSAGE_FILE="$2"
      shift 2
      ;;
    --job-id)
      JOB_ID="$2"
      shift 2
      ;;
    *)
      MESSAGE="$1"
      shift
      ;;
  esac
done

# 从文件读取消息
if [[ -n "$MESSAGE_FILE" && -f "$MESSAGE_FILE" ]]; then
  MESSAGE="$(cat "$MESSAGE_FILE")"
fi

if [[ -z "$MESSAGE" ]]; then
  echo "用法: ag-send.sh [--delay 秒] [--file 消息文件] [--job-id ID] \"消息内容\""
  exit 1
fi

# ── 延迟等待 ──────────────────────────────────────────────────────────────────

if [[ "$DELAY" -gt 0 ]]; then
  log "⏳ 等待 ${DELAY} 秒后发送..."
  sleep "$DELAY"
fi

# ── 消息摘要（日志用） ────────────────────────────────────────────────────────

MSG_PREVIEW="${MESSAGE:0:50}"
[[ ${#MESSAGE} -gt 50 ]] && MSG_PREVIEW="${MSG_PREVIEW}..."

# ── 前置检查 ──────────────────────────────────────────────────────────────────

# 1. 检查 App 是否运行
if ! is_app_running; then
  log "❌ 发送失败：$APP_NAME 未运行 | 消息: $MSG_PREVIEW"
  notify "$APP_NAME 未运行，定时消息发送失败"
  # 标记 job 为失败
  [[ -n "$JOB_ID" && -f "$AG_SCHEDULE_DIR/jobs/${JOB_ID}.meta" ]] && \
    sed -i '' 's/status=.*/status=failed/' "$AG_SCHEDULE_DIR/jobs/${JOB_ID}.meta" 2>/dev/null
  exit 1
fi

# 2. 检查锁屏状态
if is_screen_locked; then
  log "🔒 屏幕已锁定，等待解锁（最多 ${LOCK_TIMEOUT} 秒）..."
  waited=0
  while is_screen_locked && [[ $waited -lt $LOCK_TIMEOUT ]]; do
    sleep "$LOCK_CHECK_INTERVAL"
    waited=$((waited + LOCK_CHECK_INTERVAL))
  done
  if is_screen_locked; then
    log "❌ 发送失败：屏幕锁定超时 (${LOCK_TIMEOUT}s) | 消息: $MSG_PREVIEW"
    notify "屏幕锁定超时，定时消息发送失败"
    [[ -n "$JOB_ID" && -f "$AG_SCHEDULE_DIR/jobs/${JOB_ID}.meta" ]] && \
      sed -i '' 's/status=.*/status=failed/' "$AG_SCHEDULE_DIR/jobs/${JOB_ID}.meta" 2>/dev/null
    exit 1
  fi
  log "🔓 屏幕已解锁，继续发送"
fi

# ── 执行发送 ──────────────────────────────────────────────────────────────────

# 3. 备份剪贴板（仅纯文本）
PREV_CLIP=""
PREV_CLIP="$(pbpaste 2>/dev/null || true)"

# 4. 写入消息到剪贴板
echo -n "$MESSAGE" | pbcopy

# 5. AppleScript：激活窗口 → 全选输入框 → 粘贴 → 发送
osascript <<APPLESCRIPT
tell application "$APP_NAME" to activate
delay $ACTIVATE_DELAY

tell application "System Events"
    tell process "$APP_NAME"
        -- 全选输入框内容（覆盖可能的草稿）
        keystroke "a" using command down
        delay 0.1
        -- 粘贴消息
        keystroke "v" using command down
        delay $PASTE_DELAY
        -- Enter 发送
        key code 36
    end tell
end tell
APPLESCRIPT

SEND_EXIT=$?

# 6. 恢复剪贴板
sleep 0.3
if [[ -n "$PREV_CLIP" ]]; then
  echo -n "$PREV_CLIP" | pbcopy
fi

# ── 后处理 ────────────────────────────────────────────────────────────────────

if [[ $SEND_EXIT -eq 0 ]]; then
  log "✅ 已发送: $MSG_PREVIEW"
  notify "✅ 定时消息已发送"
  # 标记 job 完成
  if [[ -n "$JOB_ID" && -f "$AG_SCHEDULE_DIR/jobs/${JOB_ID}.meta" ]]; then
    sed -i '' 's/status=.*/status=done/' "$AG_SCHEDULE_DIR/jobs/${JOB_ID}.meta" 2>/dev/null
  fi
else
  log "❌ 发送失败 (exit=$SEND_EXIT): $MSG_PREVIEW"
  notify "❌ 定时消息发送失败"
  if [[ -n "$JOB_ID" && -f "$AG_SCHEDULE_DIR/jobs/${JOB_ID}.meta" ]]; then
    sed -i '' 's/status=.*/status=failed/' "$AG_SCHEDULE_DIR/jobs/${JOB_ID}.meta" 2>/dev/null
  fi
  exit 1
fi
