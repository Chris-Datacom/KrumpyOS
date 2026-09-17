$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$image = Join-Path $root "target\krumpyos.img"
if (-not (Test-Path $image)) {
    throw "KrumpyOS image was not found. Run .\scripts\build.ps1 first."
}

$qemu = Get-Command qemu-system-x86_64 -ErrorAction SilentlyContinue
if ($null -ne $qemu) {
    & $qemu.Source -drive "format=raw,file=$image" -serial stdio -display none -no-reboot -no-shutdown
    exit $LASTEXITCODE
}

$drive = $root.Substring(0, 1).ToLower()
$rest = $root.Substring(2).Replace("\", "/")
$wslRoot = "/mnt/$drive$rest"
wsl.exe -d Arch sh -lc "cd '$wslRoot'; exec qemu-system-x86_64 -drive format=raw,file=target/krumpyos.img -serial stdio -display none -no-reboot -no-shutdown"
if ($LASTEXITCODE -ne 0) {
    throw "QEMU failed to run in Windows or Arch WSL."
}
