#!/bin/sh
set -eu
cd "$(dirname "$0")"
printf 'Host IP address: '
IFS= read -r arena_address
[ -n "$arena_address" ] || exit 0
exec sh tools/run-arena-macos.sh client "$arena_address"
