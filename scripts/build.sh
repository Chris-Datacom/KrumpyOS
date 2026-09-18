#!/usr/bin/env sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
k_root=$(CDPATH= cd -- "$root/../k" && pwd)
target="$root/target"
asm_flags=""

if [ "${KRUMPYOS_TEST_DIVZERO:-0}" = "1" ]; then
    asm_flags="-DTEST_DIVZERO=1"
fi

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "error: required command '$1' was not found; install LLVM and QEMU" >&2
        exit 1
    }
}

require_command cargo
require_command clang
require_command ld.lld
require_command llvm-objcopy

mkdir -p "$target"
cargo run --manifest-path "$k_root/Cargo.toml" -- compile "$root/kernel/kernel.k" "$target/kernel.s" x86_64-krumpyos
clang --target=x86_64-unknown-elf -c "$target/kernel.s" -o "$target/kernel.o"
clang --target=x86_64-unknown-elf -c "$root/kernel/interrupts.s" -o "$target/interrupts.o"
ld.lld -m elf_x86_64 -nostdlib -T "$root/kernel/linker.ld" -o "$target/kernel.elf" "$target/kernel.o" "$target/interrupts.o"
llvm-objcopy -O binary "$target/kernel.elf" "$target/kernel.bin"

kernel_size=$(wc -c < "$target/kernel.bin")
if [ "$kernel_size" -gt 32768 ]; then
    echo "error: kernel payload exceeds the 64-sector boot limit" >&2
    exit 1
fi

clang -x assembler-with-cpp --target=i386-unknown-elf $asm_flags -c "$root/kernel/boot.s" -o "$target/boot.o"
ld.lld -m elf_i386 -nostdlib -T "$root/kernel/boot.ld" -o "$target/boot.elf" "$target/boot.o"
llvm-objcopy -O binary "$target/boot.elf" "$target/boot.bin"

boot_size=$(wc -c < "$target/boot.bin")
if [ "$boot_size" -ne 512 ]; then
    echo "error: boot sector is not exactly 512 bytes" >&2
    exit 1
fi

dd if=/dev/zero of="$target/kernel.padded" bs=512 count=64 status=none
dd if="$target/kernel.bin" of="$target/kernel.padded" conv=notrunc status=none
cat "$target/boot.bin" "$target/kernel.padded" > "$target/krumpyos.img"
echo "Built $target/krumpyos.img"
