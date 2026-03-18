# ag-later

Antigravity Agent Manager 定时消息发送工具 — 通过自然语言调度，到时自动发送消息到当前对话窗口。

![Platform](https://img.shields.io/badge/platform-macOS-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## 功能

- 🕐 **自然语言调度**：对 AI 说「帮我 30 分钟后发送：检查构建状态」
- 📨 **自动发送**：到时间后 AppleScript 激活 Antigravity 窗口，模拟键盘粘贴并发送
- 🔒 **锁屏安全**：检测锁屏状态，等待解锁后重试（最多 10 分钟）
- 📋 **剪贴板保护**：发送前备份、完成后恢复剪贴板内容
- 📝 **完整日志**：所有操作记录到 `~/.ag-schedule/logs/send.log`
- 🔔 **macOS 通知**：发送成功/失败均弹出系统通知

## 原理

```
用户（自然语言）→ AI 解析意图 → 后台 sleep + ag-send.sh → 到时激活 Antigravity → Cmd+V 粘贴 → Enter 发送
```

短延迟（< 2h）使用 `sleep` 后台进程，长延迟（≥ 2h）自动切换 `launchd` 持久化调度（跨重启存活）。

## 安装

### 1. 复制核心脚本

```bash
mkdir -p ~/.ag-schedule/{bin,jobs,logs}
curl -sf https://raw.githubusercontent.com/Neonbe/ag-later/main/scripts/ag-send.sh -o ~/.ag-schedule/bin/ag-send.sh
chmod +x ~/.ag-schedule/bin/ag-send.sh
```

### 2. 安装 SKILL（Antigravity AI 集成）

```bash
mkdir -p ~/.gemini/antigravity/skills/ag-later
curl -sf https://raw.githubusercontent.com/Neonbe/ag-later/main/SKILL.md -o ~/.gemini/antigravity/skills/ag-later/SKILL.md
```

### 3. 授权辅助功能

系统设置 → 隐私与安全性 → 辅助功能 → 勾选 **Antigravity**

> 这是 macOS 安全模型的硬性要求。AppleScript 需要此权限才能模拟键盘操作。

## 使用

在 Antigravity 任意对话中对 AI 说：

```
帮我 30 分钟后发送：检查构建状态
帮我定个时，下午3点半发：开始发版流程
```

管理任务：

```
查看定时任务
取消定时任务 ag-20260318-153000
查看发送日志
```

## 已知限制

| 限制 | 原因 |
|------|------|
| 发送时抢占前台焦点（~2 秒） | AppleScript 必须激活窗口 |
| 消息进入当前激活的对话窗口 | 无法精确定位特定对话 |
| 短延迟任务不跨重启 | sleep 进程被关机杀死 |
| 剪贴板短暂占用 | 自动备份恢复纯文本 |

## 文件结构

```
~/.ag-schedule/
├── bin/
│   └── ag-send.sh          # 核心发送脚本
├── jobs/
│   ├── <job-id>.txt         # 消息内容
│   └── <job-id>.meta        # 任务元数据
└── logs/
    └── send.log             # 发送记录

~/.gemini/antigravity/skills/ag-later/
└── SKILL.md                 # AI SKILL 文件
```

## License

MIT — 随便用，不负责。

## Author

[@neonbe](https://github.com/Neonbe)
