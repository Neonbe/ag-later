#!/usr/bin/env bash
# ag-codex.sh — Antigravity 后台由 Codex 执行耗时任务（如长文评审）的辅助脚本
set -euo pipefail

# 确保日志目录存在
mkdir -p "$HOME/.ag-schedule/logs"
LOG_FILE="$HOME/.ag-schedule/logs/codex.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

notify() {
  osascript -e "display notification \"$1\" with title \"Auto Codex Task\" sound name \"Glass\"" 2>/dev/null || true
}

PROMPT=""
CWD=""
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pwd)
      CWD="$2"
      shift 2
      ;;
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    *)
      PROMPT="$1"
      shift
      ;;
  esac
done

if [[ -z "$CWD" ]]; then
  CWD="$PWD"
fi

if [[ -z "$PROMPT" ]] || [[ -z "$OUTPUT_FILE" ]]; then
  echo "用法: ag-codex.sh --pwd <工作目录> --output <预期落盘文件> \"提示词\""
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

log "⏳ 开始后台运行 Codex，工作区: ${CWD}，预期输出: ${OUTPUT_FILE}"

set +e
# 通过独立的 python 伪终端套壳执行 codex 以绕过无 TTY 的退出报错
python3 "$HOME/.ag-schedule/bin/ag-codex-wrapper.py" "$PROMPT" "${OUTPUT_FILE}" "${CWD}"
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -ne 0 ]]; then
  log "❌ Codex 运行出错 (代码 $EXIT_CODE)，日志位置: ${OUTPUT_FILE}.cli.log"
  notify "❌ 后台 Codex 任务出现异常，请查阅日志"
  exit 1
fi

if [[ -f "$OUTPUT_FILE" ]]; then
  log "✅ 任务顺利完成，已生成 $OUTPUT_FILE"
  notify "✅ Codex 评审已完成并落盘！"
  open "$OUTPUT_FILE" || true
else
  log "⚠️ 进程结束，但似乎没能按预期生成输出文件: $OUTPUT_FILE"
  notify "⚠️ Codex 任务结束，但未找到预期的结果文档"
fi
