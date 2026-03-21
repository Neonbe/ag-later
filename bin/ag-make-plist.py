#!/usr/bin/env python3
"""
ag-make-plist.py — 为 ag-schedule launchd 任务生成 .plist 文件

用法:
    python3 ag-make-plist.py <job_id> <hour> <minute>

输出:
    写入 ~/Library/LaunchAgents/com.ag-schedule.<job_id>.plist
    打印 plist 文件绝对路径（供 shell 捕获）
"""
import sys
import os

def main():
    if len(sys.argv) != 4:
        print("用法: ag-make-plist.py <job_id> <hour> <minute>", file=sys.stderr)
        sys.exit(1)

    job_id = sys.argv[1]
    hour   = int(sys.argv[2])
    minute = int(sys.argv[3])
    home   = os.path.expanduser("~")

    plist_path = f"{home}/Library/LaunchAgents/com.ag-schedule.{job_id}.plist"
    send_sh    = f"{home}/.ag-schedule/bin/ag-send.sh"
    msg_file   = f"{home}/.ag-schedule/jobs/{job_id}.txt"
    log_file   = f"{home}/.ag-schedule/logs/{job_id}.out"

    content = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"'
        ' "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
        '<plist version="1.0">\n'
        '<dict>\n'
        '    <key>Label</key>\n'
        f'    <string>com.ag-schedule.{job_id}</string>\n'
        '    <key>ProgramArguments</key>\n'
        '    <array>\n'
        '        <string>/bin/bash</string>\n'
        f'        <string>{send_sh}</string>\n'
        '        <string>--file</string>\n'
        f'        <string>{msg_file}</string>\n'
        '        <string>--job-id</string>\n'
        f'        <string>{job_id}</string>\n'
        '    </array>\n'
        '    <key>StartCalendarInterval</key>\n'
        '    <dict>\n'
        '        <key>Hour</key>\n'
        f'        <integer>{hour}</integer>\n'
        '        <key>Minute</key>\n'
        f'        <integer>{minute}</integer>\n'
        '    </dict>\n'
        '    <key>StandardOutPath</key>\n'
        f'    <string>{log_file}</string>\n'
        '    <key>StandardErrorPath</key>\n'
        f'    <string>{log_file}</string>\n'
        '</dict>\n'
        '</plist>\n'
    )

    os.makedirs(os.path.dirname(plist_path), exist_ok=True)
    with open(plist_path, "w", encoding="utf-8") as f:
        f.write(content)

    # 输出路径供 shell 捕获：PLIST_PATH=$(python3 ag-make-plist.py ...)
    print(plist_path)

if __name__ == "__main__":
    main()
