---
name: ag-later
description: Antigravity 定时发送消息。通过自然语言指示 AI 在指定时间自动向当前对话窗口发送消息。触发词：「定时发送」「延迟发送」「N分钟后发」「到X点帮我发」「ag-schedule」「ag-later」「帮我定个时」「scheduled send」「schedule message」。
---

# ag-later — Antigravity 定时消息发送

通过自然语言调度定时消息。到时间后，AppleScript 激活 Antigravity 窗口并模拟键盘输入完成发送。

**核心链路**：用户说「30 分钟后发送 X」→ AI 解析意图 → 后台 `sleep` + `ag-send.sh` → 到时激活 Antigravity → 粘贴 → Enter 发送。

---

## 前置条件

首次使用前确认环境就绪：

```bash
ls -la "$HOME/.ag-schedule/bin/ag-send.sh"
ls -d "$HOME/.ag-schedule"/{bin,jobs,logs}
```

脚本不存在时提示用户：「ag-schedule 核心脚本未安装，需要先运行安装流程。」

辅助功能权限也必须就位：系统设置 → 隐私与安全性 → 辅助功能 → 勾选 Antigravity。无此权限 AppleScript 无法模拟键盘，一切都不会工作。

---

## 调度消息

### 1. 解析用户意图

从自然语言中提取两个要素：

| 要素 | 用户说 | AI 转换 |
|------|--------|---------|
| 时间 | 「30分钟后」「半小时后」 | 1800 秒 |
| | 「1小时后」 | 3600 秒 |
| | 「今天 15:30」「下午3点半」 | 距当前时间的秒数 |
| | 「明天早上9点」 | 距当前时间的秒数 |
| 消息 | 「帮我检查构建状态」 | 原样保留 |

**时间校验**：
- 从系统元数据中获取当前本地时间来计算延迟秒数
- 若目标时间已过，告知用户并拒绝创建
- 延迟 < 7200 秒（2 小时）：使用 sleep 模式（简单后台进程）
- 延迟 ≥ 7200 秒：使用 launchd 模式（跨重启持久化）

### 2. 创建任务

#### Sleep 模式（延迟 < 2h）

sleep 模式将调度和发送统一到一个后台进程里——`ag-send.sh` 先 sleep 指定秒数，然后立即执行发送。整个过程只有一个进程，不需要外部调度器。

```bash
JOB_ID="ag-$(date +%Y%m%d-%H%M%S)"

cat > "$HOME/.ag-schedule/jobs/${JOB_ID}.txt" << 'MSGEOF'
<消息内容>
MSGEOF

cat > "$HOME/.ag-schedule/jobs/${JOB_ID}.meta" << METAEOF
job_id=$JOB_ID
created=$(date '+%Y-%m-%d %H:%M:%S')
target_time=<目标时间 HH:MM:SS>
delay_seconds=<延迟秒数>
mode=sleep
status=pending
message_preview=<消息前30字>
pid=
METAEOF

nohup bash "$HOME/.ag-schedule/bin/ag-send.sh" \
  --delay <延迟秒数> \
  --file "$HOME/.ag-schedule/jobs/${JOB_ID}.txt" \
  --job-id "$JOB_ID" \
  > "$HOME/.ag-schedule/logs/${JOB_ID}.out" 2>&1 &

AG_PID=$!
sed -i '' "s/pid=.*/pid=$AG_PID/" "$HOME/.ag-schedule/jobs/${JOB_ID}.meta"
```

#### Launchd 模式（延迟 ≥ 2h）

长延迟任务用 launchd 持久化，这样即使 Mac 重启，任务仍然会在目标时间触发。

```bash
JOB_ID="ag-$(date +%Y%m%d-%H%M%S)"

cat > "$HOME/.ag-schedule/jobs/${JOB_ID}.txt" << 'MSGEOF'
<消息内容>
MSGEOF

cat > "$HOME/.ag-schedule/jobs/${JOB_ID}.meta" << METAEOF
job_id=$JOB_ID
created=$(date '+%Y-%m-%d %H:%M:%S')
target_time=<目标时间 YYYY-MM-DD HH:MM:SS>
mode=launchd
status=pending
message_preview=<消息前30字>
METAEOF

cat > "$HOME/Library/LaunchAgents/com.ag-schedule.${JOB_ID}.plist" << PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ag-schedule.${JOB_ID}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${HOME}/.ag-schedule/bin/ag-send.sh</string>
        <string>--file</string>
        <string>${HOME}/.ag-schedule/jobs/${JOB_ID}.txt</string>
        <string>--job-id</string>
        <string>${JOB_ID}</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer><目标小时></integer>
        <key>Minute</key>
        <integer><目标分钟></integer>
    </dict>
    <key>StandardOutPath</key>
    <string>${HOME}/.ag-schedule/logs/${JOB_ID}.out</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/.ag-schedule/logs/${JOB_ID}.out</string>
</dict>
</plist>
PLISTEOF

launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.ag-schedule.${JOB_ID}.plist"
```

### 3. 确认回复

任务创建成功后，回复用户：

```
✅ 已安排定时发送

📋 任务详情：
   Job ID:   <job-id>
   发送时间: <目标时间>
   消息内容: <完整消息>
   调度模式: sleep / launchd

⚠️ 消息将发送到届时 Antigravity 当前激活的对话窗口。
```

---

## 管理任务

用户可能会用自然语言表达管理意图。识别以下模式并执行对应操作。

### 查看任务列表

触发词：「查看定时任务」「有哪些定时消息」「list scheduled」

```bash
echo "=== ag-schedule 任务列表 ==="
for meta in "$HOME/.ag-schedule/jobs"/*.meta; do
  [ -f "$meta" ] || continue
  source "$meta"
  if [ "$mode" = "sleep" ] && [ "$status" = "pending" ]; then
    if [ -n "$pid" ] && ! ps -p "$pid" > /dev/null 2>&1; then
      status="lost"
    fi
  fi
  echo "  $job_id | $target_time | $mode | $status | $message_preview"
done
```

### 取消任务

触发词：「取消定时任务」「cancel scheduled」「别发了」

```bash
JOB_ID="<用户指定的 Job ID>"
META="$HOME/.ag-schedule/jobs/${JOB_ID}.meta"

if [ -f "$META" ]; then
  source "$META"
  if [ "$mode" = "sleep" ] && [ -n "$pid" ]; then
    # 验证 PID 确实属于 ag-send 进程，避免误杀
    if ps -p "$pid" -o command= 2>/dev/null | grep -q "ag-send"; then
      kill "$pid" 2>/dev/null && echo "✅ 已终止进程 $pid"
    fi
  elif [ "$mode" = "launchd" ]; then
    launchctl bootout "gui/$(id -u)/com.ag-schedule.${JOB_ID}" 2>/dev/null
    rm -f "$HOME/Library/LaunchAgents/com.ag-schedule.${JOB_ID}.plist"
    echo "✅ 已卸载 launchd 任务"
  fi
  sed -i '' 's/status=.*/status=cancelled/' "$META"
fi
```

### 查看日志

触发词：「发送日志」「send log」

```bash
tail -20 "$HOME/.ag-schedule/logs/send.log"
```

### 清理历史任务

触发词：「清理定时任务」「clean up」

```bash
for meta in "$HOME/.ag-schedule/jobs"/*.meta; do
  [ -f "$meta" ] || continue
  source "$meta"
  if [ "$status" = "done" ] || [ "$status" = "failed" ] || [ "$status" = "cancelled" ]; then
    rm -f "$meta" "${meta%.meta}.txt"
    rm -f "$HOME/Library/LaunchAgents/com.ag-schedule.${job_id}.plist" 2>/dev/null
  fi
done
echo "✅ 已清理完成/失败/取消的任务"
```

---

## 已知限制

发送时告知用户这些限制，帮助他们形成正确预期：

| 限制 | 原因 |
|------|------|
| 发送时抢占前台焦点（~2 秒） | AppleScript 必须激活窗口才能模拟键盘 |
| 消息进入当前激活的对话窗口 | 无法通过 AppleScript 精确定位特定对话 |
| 短延迟任务（< 2h）不跨重启存活 | sleep 进程被关机杀死；长延迟自动用 launchd |
| 发送瞬间占用剪贴板（~1 秒） | 通过 pbcopy/pbpaste 实现，脚本会自动备份恢复纯文本 |
| 输入框草稿会被覆盖 | 发送前 Cmd+A 全选再粘贴 |
| 首次需要辅助功能权限 | macOS 安全模型强制要求 |

---

## 故障排查

| 症状 | 诊断步骤 |
|------|---------|
| 消息没发出 | `tail ~/.ag-schedule/logs/send.log` 查日志 |
| 「Antigravity 未运行」 | 确认 Antigravity 窗口打开 |
| AppleScript 权限被拒 | 系统设置 → 辅助功能 → 勾选 Antigravity |
| 锁屏超时 | 脚本等 10 分钟后放弃，日志有记录 |
| launchd 任务未触发 | `launchctl list \| grep ag-schedule` |
| PID 进程不在了 | 查 `.meta` 文件的 status 字段 |
