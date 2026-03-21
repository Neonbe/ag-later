import pty
import os
import sys
import time

prompt = sys.argv[1]
output_file = sys.argv[2]
cwd = sys.argv[3]

pid, fd = pty.fork()
if pid == 0:
    os.chdir(cwd)
    os.execv('/opt/homebrew/bin/codex', ['codex', '-a', 'never', '--no-alt-screen', prompt])
else:
    with open(output_file + '.cli.log', 'wb') as f:
        while True:
            try:
                data = os.read(fd, 1024)
                if not data: break
                f.write(data)
                f.flush()
                # "›" UTF-8 or standard TUI prompts
                if b'\xe2\x80\xba' in data or b'Explain this codebase' in data:
                    time.sleep(0.5)
                    os.write(fd, b'\x04') # Ctrl-D (EOF) to exit cleanly
            except OSError:
                break
