# apply-vulkan-patch.ps1
# Patches an installed OpenWhispr app with the Vulkan whisper-server binary.
# Run after each OpenWhispr update until Vulkan support is in the official release.
#
# Usage: powershell -ExecutionPolicy Bypass -File apply-vulkan-patch.ps1

$ErrorActionPreference = "Stop"

$installDir = "$env:LOCALAPPDATA\Programs\OpenWhispr"
$binDir = "$installDir\resources\bin"
$asarPath = "$installDir\resources\app.asar"

if (-not (Test-Path $binDir)) {
    Write-Error "OpenWhispr not found at $installDir"
    exit 1
}

# --- Download Vulkan binary + DLLs ---

Write-Host "Fetching latest release from jonasthilo/whisper.cpp..."
$release = Invoke-RestMethod "https://api.github.com/repos/jonasthilo/whisper.cpp/releases/latest" `
    -Headers @{ "User-Agent" = "apply-vulkan-patch" }

$asset = $release.assets | Where-Object { $_.name -eq "whisper-vulkan-bin-x64.zip" }
if (-not $asset) {
    Write-Error "Asset whisper-vulkan-bin-x64.zip not found in release $($release.tag_name)"
    exit 1
}

Write-Host "Downloading $($asset.name) ($([math]::Round($asset.size/1MB, 1)) MB)..."
$zipPath = "$env:TEMP\whisper-vulkan-bin-x64.zip"
Invoke-WebRequest $asset.browser_download_url -OutFile $zipPath

$extractDir = "$env:TEMP\whisper-vulkan-extract"
if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
Expand-Archive $zipPath $extractDir

# Copy binary under both names:
# - whisper-server-win32-x64-vulkan.exe  (used by new app code with vulkanGpuDetector)
# - whisper-server-win32-x64.exe         (used by older app code without GPU detection)
$serverExe = Get-ChildItem $extractDir -Recurse -Filter "whisper-server.exe" | Select-Object -First 1
if (-not $serverExe) {
    Write-Error "whisper-server.exe not found in archive"
    exit 1
}
Copy-Item $serverExe.FullName "$binDir\whisper-server-win32-x64-vulkan.exe" -Force
Copy-Item $serverExe.FullName "$binDir\whisper-server-win32-x64.exe" -Force
Write-Host "  Copied whisper-server-win32-x64-vulkan.exe"
Write-Host "  Copied whisper-server-win32-x64.exe"

$dlls = @("ggml-vulkan.dll", "ggml.dll", "ggml-base.dll", "ggml-cpu.dll", "whisper.dll")
foreach ($dll in $dlls) {
    $src = Get-ChildItem $extractDir -Recurse -Filter $dll | Select-Object -First 1
    if ($src) {
        Copy-Item $src.FullName "$binDir\$dll" -Force
        Write-Host "  Copied $dll"
    } else {
        Write-Warning "  $dll not found in archive"
    }
}

# --- Patch ASAR if --no-flash-attn not already present ---

$asarBytes = [System.IO.File]::ReadAllBytes($asarPath)
$asarText = [System.Text.Encoding]::UTF8.GetString($asarBytes)

if ($asarText -match "no-flash-attn") {
    Write-Host "`nASAR already contains --no-flash-attn, skipping patch."
} else {
    Write-Host "`nPatching ASAR to add --no-flash-attn..."
    $patched = $asarText -replace `
        '(args\.push\("--language"[^\n]+\n)', `
        "`$1    args.push(`"--no-flash-attn`");`n"
    $patchedBytes = [System.Text.Encoding]::UTF8.GetBytes($patched)
    [System.IO.File]::WriteAllBytes($asarPath, $patchedBytes)
    Write-Host "  ASAR patched."
}

# --- Cleanup ---
Remove-Item $zipPath -Force
Remove-Item $extractDir -Recurse -Force

Write-Host "`nDone. Restart OpenWhispr to apply changes."
