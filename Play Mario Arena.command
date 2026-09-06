#!/bin/sh
set -eu
cd "$(dirname "$0")"
exec sh tools/run-arena-macos.sh host
