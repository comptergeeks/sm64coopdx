#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
game='./build/us_pc/Mario FPS.app/Contents/MacOS/sm64coopdx'
if [ ! -x "$game" ]; then
    echo 'Build first: sh tools/build-fps-macos.sh' >&2
    exit 1
fi
mode="${1:-host}"
if [ "$#" -gt 0 ]; then shift; fi
case "$mode" in
    host)
        exec "$game" --savepath ./build/us_pc/fps-host --server 7777 \
            --enable-mod first-person-arena --skip-intro --skip-update-check --windowed "$@"
        ;;
    client)
        address="${1:-127.0.0.1}"
        if [ "$#" -gt 0 ]; then shift; fi
        exec "$game" --savepath ./build/us_pc/fps-client --client "$address" 7777 \
            --skip-intro --skip-update-check --windowed "$@"
        ;;
    *) echo 'Usage: sh tools/run-fps-macos.sh host | client [host-ip]' >&2; exit 1 ;;
esac
