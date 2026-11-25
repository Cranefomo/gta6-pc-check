<#
gta6-pc-check  (github.com/Cranefomo/gta6-pc-check)

Checks your PC against the requirements in the README of VIctory (github.com/Marvisak/VIctory),
the open source attempt at running GTA VI on PC. Read-only: downloads nothing, changes nothing,
needs no admin rights and no game files.

one line:   irm https://raw.githubusercontent.com/Cranefomo/gta6-pc-check/main/check.ps1 | iex
from file:  powershell -ExecutionPolicy Bypass -File check.ps1 [-DxDiagFile report.xml]
#>
param(
  [string]$DxDiagFile   # use a dxdiag /x report you already have (skips the 20 s scan)
)
$ErrorActionPreference = 'Stop'
$isWin = [Environment]::OSVersion.Platform -eq 'Win32NT'

function Line($k, $v, $c = 'Gray') { Write-Host ('  {0,-14}' -f $k) -NoNewline -ForegroundColor DarkGray; Write-Host $v -ForegroundColor $c }
function Mark($ok) { if ($ok -eq $true) { 'OK  ' } elseif ($ok -eq $false) { 'NO  ' } else { '??  ' } }
function Col($ok) { if ($ok -eq $true) { 'Green' } elseif ($ok -eq $false) { 'Red' } else { 'Yellow' } }

Write-Host ''
Write-Host '  gta6-pc-check' -ForegroundColor Cyan
Write-Host '  can this PC run VIctory, the GTA VI on PC project? read-only, nothing is downloaded' -ForegroundColor DarkGray
Write-Host ''

# ---------- collect ----------
$r = [ordered]@{}

# OS
$build = if ($isWin) { [Environment]::OSVersion.Version.Build } else { 0 }
$x64 = [Environment]::Is64BitOperatingSystem
$r.os = @{ ok = ($isWin -and $x64 -and $build -ge 10240); text = $(if (-not $isWin) { 'not Windows' } elseif ($build -ge 22000) { "Windows 11 x64 (build $build)" } else { "Windows 10 x64 (build $build)" }) }

# CPU + AVX2
$cpuName = 'unknown'; $avx2 = $null
if ($isWin) {
  $cpuName = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name.Trim()
  try {
    Add-Type -Namespace G6 -Name Cpu -MemberDefinition '[DllImport("kernel32.dll")] public static extern bool IsProcessorFeaturePresent(uint f);' -ErrorAction Stop
    $avx2 = [G6.Cpu]::IsProcessorFeaturePresent(40)   # PF_AVX2_INSTRUCTIONS_AVAILABLE
  } catch { $avx2 = $null }
}
$r.cpu = @{ ok = $avx2; text = "$cpuName, AVX2 $(if ($avx2 -eq $true) { 'yes' } elseif ($avx2 -eq $false) { 'no' } else { 'unknown' })" }

# RAM and commit
$ramGB = $null; $commitGB = $null; $freeCommitGB = $null
if ($isWin) {
  $cs = Get-CimInstance Win32_ComputerSystem; $os = Get-CimInstance Win32_OperatingSystem
  $ramGB = [math]::Round($cs.TotalPhysicalMemory / 1GB)
  $commitGB = [math]::Round($os.TotalVirtualMemorySize / 1MB)
  $freeCommitGB = [math]::Round($os.FreeVirtualMemory / 1MB)
}

# GPU via dxdiag XML report (tags are English on every Windows language)
# feature level 12_2 = DirectX 12 Ultimate = mesh shaders
$gpus = @()
$tmpReport = $false
if (-not $DxDiagFile -and $isWin) {
  $DxDiagFile = Join-Path $env:TEMP 'gta6-pc-check-dxdiag.xml'; $tmpReport = $true
  Write-Host '  reading graphics info with dxdiag, about 20 seconds...' -ForegroundColor DarkGray
  if (Test-Path $DxDiagFile) { Remove-Item $DxDiagFile -Force }
  Start-Process dxdiag -ArgumentList "/x `"$DxDiagFile`"" -Wait -WindowStyle Hidden
  for ($i = 0; $i -lt 30 -and -not (Test-Path $DxDiagFile); $i++) { Start-Sleep 1 }
}
if ($DxDiagFile -and (Test-Path $DxDiagFile)) {
  [xml]$x = Get-Content $DxDiagFile -Raw
  foreach ($d in $x.DxDiag.DisplayDevices.DisplayDevice) {
    $mb = 0; if ("$($d.DedicatedMemory)" -match '([\d.]+)') { $mb = [double]$Matches[1] }
    $gpus += @{ name = "$($d.CardName)".Trim(); fl = "$($d.FeatureLevels)".Trim(); vramMB = $mb; driver = "$($d.DriverVersion)".Trim() }
  }
  if ($tmpReport) { Remove-Item $DxDiagFile -Force -ErrorAction SilentlyContinue }
}
$gpu = $gpus | Sort-Object { $_.vramMB } -Descending | Select-Object -First 1

$dx12 = $null; $ultimate = $null; $vramGB = $null
if ($gpu) {
  $dx12 = $gpu.fl -match '12_[012]'
  $ultimate = $gpu.fl -match '12_2'
  $vramGB = [math]::Round($gpu.vramMB / 1024)
}
$r.gpu = @{ ok = $dx12; text = $(if ($gpu) { "$($gpu.name), $vramGB GB" } else { 'not found' }) }

# ---------- print ----------
Write-Host ''
Write-Host '  YOUR PC' -ForegroundColor Cyan
Line 'windows' $r.os.text (Col $r.os.ok)
Line 'cpu' $r.cpu.text (Col $r.cpu.ok)
Line 'gpu' $r.gpu.text
if ($gpu) { Line 'dx feature' $(if ($gpu.fl) { $gpu.fl } else { 'unknown' }) }
Line 'ram' $(if ($ramGB) { "$ramGB GB" } else { 'unknown' })
Line 'commit' $(if ($commitGB) { "$commitGB GB limit, $freeCommitGB GB free (RAM + page file)" } else { 'unknown' })

# stage 1: boot and menus  (README: Win10/11 x64, AVX2, D3D12 GPU with SM 6.6)
$s1 = @($r.os.ok, $avx2, $dx12)
$boot = if ($s1 -contains $false) { $false } elseif ($s1 -contains $null) { $null } else { $true }
# stage 2: reach the world (README: mesh shaders; fork: ~22 GB RAM, >16 GB VRAM, ~33 GB commit)
$s2 = @($boot, $ultimate, ($ramGB -ge 32), ($vramGB -ge 16), ($commitGB -ge 40))
if (-not $ramGB) { $s2[2] = $null }; if ($null -eq $vramGB) { $s2[3] = $null }; if (-not $commitGB) { $s2[4] = $null }
$world = if ($s2 -contains $false) { $false } elseif ($s2 -contains $null) { $null } else { $true }

Write-Host ''
Write-Host '  VERDICT' -ForegroundColor Cyan
Line "$(Mark $boot)boot" 'menus and intro (Windows 10/11 x64, AVX2 CPU, DirectX 12 GPU)' (Col $boot)
Line "$(Mark $world)world" 'load into the open world (DX12 Ultimate, 32 GB RAM, 16 GB VRAM, 40 GB commit)' (Col $world)
Line 'NO  play' 'nobody can yet: 3 to 5 fps on an RX 9070 XT with 64 GB RAM (Nov 25)' Red

# why not
$why = @()
if ($r.os.ok -eq $false) { $why += 'needs 64-bit Windows 10 or 11' }
if ($avx2 -eq $false) { $why += 'your CPU has no AVX2 (roughly anything older than 2013 Intel / 2015 AMD)' }
if ($dx12 -eq $false) { $why += 'your GPU has no DirectX 12 feature level' }
if ($ultimate -eq $false) { $why += 'your GPU is not DirectX 12 Ultimate (no mesh shaders). minimum class: GeForce RTX 20, Radeon RX 6000, Intel Arc' }
if ($ramGB -and $ramGB -lt 32) { $why += "$ramGB GB RAM, the AMD fork used about 22 GB on its own" }
if ($null -ne $vramGB -and $vramGB -lt 16) { $why += "$vramGB GB VRAM, the game wanted more than a 16 GB card has" }
if ($commitGB -and $commitGB -lt 40) { $why += "commit limit $commitGB GB, raise the page file (System > About > Advanced > Performance > Virtual memory)" }
if ($why) { Write-Host ''; Write-Host '  WHY' -ForegroundColor Cyan; $why | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow } }

Write-Host ''
Write-Host '  VIctory: github.com/Marvisak/VIctory  (GPL-3.0, ships no game files)' -ForegroundColor DarkGray
Write-Host '  never run a "GTA VI PC port" exe from a post or a video. that is where the malware is' -ForegroundColor DarkGray
Write-Host ''
