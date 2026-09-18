$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$image = Join-Path $root "target\krumpyos.img"
$output = Join-Path $root "target\qemu-smoke.log"

if (-not (Test-Path $image)) {
    throw "KrumpyOS image was not found. Run .\scripts\build.ps1 first."
}

$qemu = Get-Command qemu-system-x86_64 -ErrorAction SilentlyContinue
if ($null -eq $qemu) {
    throw "qemu-system-x86_64 was not found. Install QEMU and retry."
}

if (Test-Path $output) {
    Remove-Item $output
}

$arguments = @(
    "-drive", "format=raw,file=$image",
    "-serial", "file:$output",
    "-display", "none",
    "-monitor", "none",
    "-no-reboot",
    "-no-shutdown"
)
$process = Start-Process -FilePath $qemu.Source -ArgumentList $arguments -PassThru
$timedOut = $false
try {
    if (-not $process.WaitForExit(5000)) {
        $timedOut = $true
        Stop-Process -Id $process.Id
        $process.WaitForExit()
    }
}
finally {
    if (-not $process.HasExited) {
        Stop-Process -Id $process.Id
        $process.WaitForExit()
    }
}

$serial = if (Test-Path $output) {
    ((Get-Content -Raw $output) -replace "`r", "").TrimEnd("`n")
}
else {
    ""
}
if ($serial -notmatch "Hello, World!.*exception=3") {
    throw "QEMU did not produce the expected ABI report."
}
if (-not $timedOut -and $process.ExitCode -ne 0) {
    throw "QEMU exited with status $($process.ExitCode)."
}

Write-Host "QEMU smoke test passed: Hello, World! -> exception=3"
