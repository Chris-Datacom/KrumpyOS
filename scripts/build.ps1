$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$kRoot = (Resolve-Path (Join-Path $root "..\k")).Path
$drive = $root.Substring(0, 1).ToLower()
$rest = $root.Substring(2).Replace("\", "/")
$wslRoot = "/mnt/$drive$rest"
$wslKRoot = "/mnt/" + $kRoot.Substring(0, 1).ToLower() + $kRoot.Substring(2).Replace("\", "/")

New-Item -ItemType Directory -Force (Join-Path $root "target") | Out-Null
cargo run --manifest-path (Join-Path $kRoot "Cargo.toml") -- compile (Join-Path $root "kernel\kernel.k") (Join-Path $root "target\kernel.s")
wsl.exe sh -lc "set -eu; cd '$wslRoot'; as --64 -o target/kernel.o target/kernel.s; as --32 -o target/boot.o kernel/boot.s; ld -nostdlib -T kernel/linker.ld -o target/kernel.elf target/kernel.o; objcopy -O binary target/kernel.elf target/kernel.bin; ld -nostdlib -T kernel/boot.ld -o target/boot.elf target/boot.o; objcopy -O binary target/boot.elf target/boot.bin; test \`$(wc -c < target/boot.bin) -eq 512; dd if=/dev/zero of=target/kernel.padded bs=512 count=64 status=none; dd if=target/kernel.bin of=target/kernel.padded conv=notrunc status=none; cat target/boot.bin target/kernel.padded > target/krumpyos.img"
Write-Host "Built $root\target\krumpyos.img"
