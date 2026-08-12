$ErrorActionPreference = 'Stop'
$adb = 'C:\Users\meanc\AppData\Local\Android\sdk\platform-tools\adb.exe'
$ui = Join-Path $env:TEMP 'pawpal-ui.xml'

function Dump {
  & $adb shell uiautomator dump /sdcard/ui.xml | Out-Null
  & $adb pull /sdcard/ui.xml $ui | Out-Null
  Get-Content $ui -Raw
}

function TapBounds([string]$b) {
  if ($b -match '\[(\d+),(\d+)\]\[(\d+),(\d+)\]') {
    $x = [int](([int]$Matches[1] + [int]$Matches[3]) / 2)
    $y = [int](([int]$Matches[2] + [int]$Matches[4]) / 2)
    & $adb shell input tap $x $y
    Start-Sleep -Milliseconds 400
  }
}

function ClearField {
  & $adb shell input keyevent KEYCODE_MOVE_END
  1..100 | ForEach-Object { & $adb shell input keyevent 67 }
}

function TypeEscaped([string]$t) {
  & $adb shell input text ($t -replace ' ', '%s')
}

# Open Profile quick action
$raw = Dump
$m = [regex]::Match($raw, 'content-desc="Profile[^"]*"[^>]*bounds="([^"]+)"')
if (-not $m.Success) { throw 'Profile not found' }
TapBounds $m.Groups[1].Value
Start-Sleep -Seconds 1

$fields = @(
  'T12B Sitter',
  'Carlton',
  '3053',
  'Experienced dog walker and sittings near Carlton suburb.',
  '35'
)

for ($i = 0; $i -lt $fields.Count; $i++) {
  $raw = Dump
  $ms = [regex]::Matches($raw, 'class="android.widget.EditText"[^>]*bounds="([^"]+)"')
  while ($ms.Count -le $i) {
    & $adb shell input swipe 540 1600 540 900 250
    Start-Sleep -Milliseconds 500
    $raw = Dump
    $ms = [regex]::Matches($raw, 'class="android.widget.EditText"[^>]*bounds="([^"]+)"')
    if ($ms.Count -eq 0) { throw "No EditText while filling index $i" }
  }
  # Prefer the EditText whose top is lowest among those still above keyboard; use index i if visible
  $target = $null
  if ($i -lt $ms.Count) { $target = $ms[$i].Groups[1].Value }
  else { $target = $ms[$ms.Count - 1].Groups[1].Value }

  # If field is too low, swipe up
  if ($target -match '\[(\d+),(\d+)\]\[(\d+),(\d+)\]' -and [int]$Matches[2] -gt 1650) {
    & $adb shell input swipe 540 1600 540 900 250
    Start-Sleep -Milliseconds 500
    $raw = Dump
    $ms = [regex]::Matches($raw, 'class="android.widget.EditText"[^>]*bounds="([^"]+)"')
    if ($i -lt $ms.Count) { $target = $ms[$i].Groups[1].Value }
    else { $target = $ms[$ms.Count - 1].Groups[1].Value }
  }

  TapBounds $target
  ClearField
  TypeEscaped $fields[$i]
  Write-Host "Filled $i"
  Start-Sleep -Milliseconds 300
}

# Swipe to reveal Save without tapping app bar
& $adb shell input swipe 540 1700 540 800 300
Start-Sleep -Milliseconds 500
$raw = Dump
$m = [regex]::Match($raw, 'content-desc="Save profile"[^>]*bounds="([^"]+)"')
if (-not $m.Success) { throw 'Save profile not found' }
TapBounds $m.Groups[1].Value
Start-Sleep -Seconds 3
$raw = Dump
Select-String -Path $ui -Pattern 'content-desc="[^"]+"' -AllMatches | ForEach-Object { $_.Matches.Value } | Select-Object -First 25
