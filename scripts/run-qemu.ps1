$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (-not (Get-Command qemu-system-x86_64 -ErrorAction SilentlyContinue)) {
    throw "qemu-system-x86_64 was not found on PATH."
}
& qemu-system-x86_64 -drive "format=raw,file=$(Join-Path $root 'target\krumpyos.img')" -serial stdio -display none
