import subprocess
import sys

SCRIPT_GEO = 'tell application "System Events" to tell process "Simulator" to return {position of window 1, size of window 1}'
SCRIPT_CLICK = 'tell application "System Events" to click at {%d, %d}'


def geometry():
    out = subprocess.run(['osascript', '-e', SCRIPT_GEO], capture_output=True, text=True)
    return out.stdout.strip(), out.stderr.strip()


def tap(x, y):
    out = subprocess.run(['osascript', '-e', SCRIPT_CLICK % (x, y)], capture_output=True, text=True)
    return out.stderr.strip() or 'ok'


if __name__ == '__main__':
    geo, err = geometry()
    print('geometry:', geo, '| err:', err)
    if len(sys.argv) > 2:
        print('tap:', tap(int(sys.argv[1]), int(sys.argv[2])))
