#!/usr/bin/env sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
image="$root/target/krumpyos.img"
output="$root/target/qemu-smoke.log"

if [ ! -f "$image" ]; then
    echo "error: $image was not found; run scripts/build.sh first" >&2
    exit 1
fi
if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "error: qemu-system-x86_64 was not found; install QEMU and retry" >&2
    exit 1
fi
if ! command -v timeout >/dev/null 2>&1; then
    echo "error: timeout was not found; install coreutils and retry" >&2
    exit 1
fi

input="$root/target/qemu-smoke.in"
printf '\rhelp\recho smoke\rmem\rps\ryield\ruptime\r' > "$input"
rm -f "$output"
set +e
timeout 5s qemu-system-x86_64 \
    -drive "format=raw,file=$image" \
    -serial stdio \
    -display none \
    -monitor none \
    -no-reboot \
    -no-shutdown \
    < "$input" > "$output"
qemu_status=$?
set -e

serial=$(tr -d '\r' < "$output")
case "$serial" in
    *"KrumpyOS console ready"*"Commands:"*"smoke"*"Physical Memory Map:"*"Kernel Threads / Processes:"*"Yielded."*"uptime:"*"krumpy> "*) ;;
    *)
        echo "error: QEMU did not produce the expected console report" >&2
        cat "$output" >&2 2>/dev/null || true
        exit 1
        ;;
esac

if [ "$qemu_status" -ne 0 ] && [ "$qemu_status" -ne 124 ]; then
    echo "error: QEMU exited with status $qemu_status" >&2
    exit "$qemu_status"
fi

echo "QEMU smoke test passed: interactive serial console"
