$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$kRoot = (Resolve-Path (Join-Path $root "..\k")).Path
$asmFlags = @()
if ($env:KRUMPYOS_TEST_DIVZERO -eq "1") {
    $asmFlags += "-DTEST_DIVZERO=1"
}

function Require-Command([string]$name) {
    if ($null -eq (Get-Command $name -ErrorAction SilentlyContinue)) {
        throw "Required command '$name' was not found. Install LLVM and QEMU, then retry."
    }
}

Require-Command "cargo"
Require-Command "clang"
Require-Command "ld.lld"
Require-Command "llvm-objcopy"

New-Item -ItemType Directory -Force (Join-Path $root "target") | Out-Null
cargo run --manifest-path (Join-Path $kRoot "Cargo.toml") -- compile (Join-Path $root "kernel\kernel.k") (Join-Path $root "target\kernel.s") x86_64-krumpyos
if ($LASTEXITCODE -ne 0) {
    throw "K compiler failed; refusing to link stale kernel.s."
}
clang --target=x86_64-unknown-elf -c (Join-Path $root "target\kernel.s") -o (Join-Path $root "target\kernel.o")
if ($LASTEXITCODE -ne 0) {
    throw "Kernel assembly failed."
}
clang --target=x86_64-unknown-elf -c (Join-Path $root "kernel\interrupts.s") -o (Join-Path $root "target\interrupts.o")
if ($LASTEXITCODE -ne 0) {
    throw "Interrupt assembly failed."
}
ld.lld -m elf_x86_64 -nostdlib -T (Join-Path $root "kernel\linker.ld") -o (Join-Path $root "target\kernel.elf") (Join-Path $root "target\kernel.o") (Join-Path $root "target\interrupts.o")
if ($LASTEXITCODE -ne 0) {
    throw "Kernel link failed."
}
llvm-objcopy -O binary (Join-Path $root "target\kernel.elf") (Join-Path $root "target\kernel.bin")
if ((Get-Item (Join-Path $root "target\kernel.bin")).Length -gt 32768) {
    throw "Kernel payload exceeds the 64-sector boot limit."
}
clang -x assembler-with-cpp --target=i386-unknown-elf $asmFlags -c (Join-Path $root "kernel\boot.s") -o (Join-Path $root "target\boot.o")
ld.lld -m elf_i386 -nostdlib -T (Join-Path $root "kernel\boot.ld") -o (Join-Path $root "target\boot.elf") (Join-Path $root "target\boot.o")
llvm-objcopy -O binary (Join-Path $root "target\boot.elf") (Join-Path $root "target\boot.bin")
if ((Get-Item (Join-Path $root "target\boot.bin")).Length -ne 512) {
    throw "Boot sector is not exactly 512 bytes."
}
$kernelPadded = Join-Path $root "target\kernel.padded"
$image = Join-Path $root "target\krumpyos.img"
$padding = New-Object byte[] 32768
[IO.File]::WriteAllBytes($kernelPadded, $padding)
$kernelBytes = [IO.File]::ReadAllBytes((Join-Path $root "target\kernel.bin"))
[Array]::Copy($kernelBytes, 0, $padding, 0, $kernelBytes.Length)
[IO.File]::WriteAllBytes($kernelPadded, $padding)
$bootBytes = [IO.File]::ReadAllBytes((Join-Path $root "target\boot.bin"))
$imageBytes = New-Object byte[] ($bootBytes.Length + $padding.Length)
[Array]::Copy($bootBytes, 0, $imageBytes, 0, $bootBytes.Length)
[Array]::Copy($padding, 0, $imageBytes, $bootBytes.Length, $padding.Length)
[IO.File]::WriteAllBytes($image, $imageBytes)
Write-Host "Built $image"
