$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$target = Join-Path $root "target"
$source = Join-Path $root "kernel\efi_stub.c"
$object = Join-Path $target "efi_stub.obj"
$efiOut = Join-Path $target "BOOTX64.EFI"
$kernelPayload = Join-Path $target "kernel.bin"
$espRoot = Join-Path $target "efi-media"
$espBoot = Join-Path $espRoot "EFI\BOOT"

New-Item -ItemType Directory -Force $target | Out-Null
New-Item -ItemType Directory -Force $espBoot | Out-Null
$env:Path += ";C:\Program Files\LLVM\bin"

if (-not (Test-Path $kernelPayload)) {
    throw "Build the kernel first; expected $kernelPayload."
}

if ($null -eq (Get-Command clang -ErrorAction SilentlyContinue)) {
    throw "clang is required to build the EFI stub."
}

clang --target=x86_64-pc-windows-msvc -fno-builtin-memcpy -c $source -o $object

if (Get-Command lld-link -ErrorAction SilentlyContinue) {
    lld-link /nologo /entry:efi_main /subsystem:efi_application /out:$efiOut $object
}
elseif (Get-Command ld.lld -ErrorAction SilentlyContinue) {
    ld.lld -flavor link /subsystem:efi_application /entry:efi_main /out:$efiOut $object
}
else {
    throw "lld-link or ld.lld is required to link the EFI stub."
}

Write-Host "EFI stub built to $efiOut"
Copy-Item $efiOut (Join-Path $espBoot "BOOTX64.EFI") -Force
Copy-Item $kernelPayload (Join-Path $espRoot "KRUMPYOS.BIN") -Force
Write-Host "EFI media tree staged to $espRoot"
