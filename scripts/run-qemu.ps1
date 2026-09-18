$env:Path += ";C:\Program Files\qemu"

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$image = Join-Path $root "target\krumpyos.img"
if (-not (Test-Path $image)) {
    throw "KrumpyOS image was not found. Run .\scripts\build.ps1 first."
}

$qemu = Get-Command qemu-system-x86_64 -ErrorAction SilentlyContinue
if ($null -eq $qemu) {
    throw "qemu-system-x86_64 was not found. Install QEMU and retry."
}

& $qemu.Source -drive "format=raw,file=$image" -serial stdio -display none -no-reboot -no-shutdown
exit $LASTEXITCODE
