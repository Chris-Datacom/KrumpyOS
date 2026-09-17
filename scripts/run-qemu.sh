#!/usr/bin/env sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
image="$root/target/krumpyos.img"

if [ ! -f "$image" ]; then
    echo "error: $image was not found; run scripts/build.sh first" >&2
    exit 1
fi
if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "error: qemu-system-x86_64 was not found; install QEMU and retry" >&2
    exit 1
fi

exec qemu-system-x86_64 \
    -drive "format=raw,file=$image" \
    -serial stdio \
    -display none \
    -no-reboot \
    -no-shutdown
