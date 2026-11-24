#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
pkill -x Linkord 2>/dev/null || true
bash scripts/check.sh
bash scripts/package.sh
open -n "$PWD/dist/Linkord.app"
case "${1:-run}" in
    --verify) sleep 1; pgrep -x Linkord >/dev/null ;;
    --logs) /usr/bin/log stream --info --predicate 'process == "Linkord"' ;;
    --telemetry) /usr/bin/log stream --info --predicate 'subsystem == "com.arkatov.linkord"' ;;
    --debug) lldb -n Linkord ;;
    run) ;;
    *) echo 'Usage: script/build_and_run.sh [--verify|--logs|--telemetry|--debug]' >&2; exit 2 ;;
esac
