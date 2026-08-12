$ErrorActionPreference = 'Stop'
$adb = "C:\Users\meanc\AppData\Local\Android\sdk\platform-tools\adb.exe"
$ui = "$env:TEMP\pawpal-ui.xml"

function Dump-Ui {
  & $adb shell uiautomator dump /sdcard/ui.xml | Out-Null
  & $adb pull /sdcard/ui.xml $ui | Out-Null
  return [xml](Get-Content $ui -Raw)
}

function Get-Center([string]$bounds) {
  if ($bounds -match '\[(\d+),(\d+)\]\[(\d+),(\d+)\]') {
    return @{
      X = [int](([int]$Matches[1] + [int]$Matches[3]) / 2)
      Y = [int](([int]$Matches[2] + [int]$Matches[4]) / 2)
    }
  }
  throw "Bad bounds: $bounds"
}

function Tap-Bounds([string]$bounds) {
  $c = Get-Center $bounds
  & $adb shell input tap $c.X $c.Y
  Start-Sleep -Milliseconds 600
}

function Type-Text([string]$text) {
  & $adb shell input text $text
  Start-Sleep -Milliseconds 350
}

function Find-Nodes([xml]$xml, [string]$xpath) {
  $hits = Select-Xml -Xml $xml -XPath $xpath
  $list = New-Object System.Collections.Generic.List[System.Xml.XmlElement]
  foreach ($h in @($hits)) {
    [void]$list.Add([System.Xml.XmlElement]$h.Node)
  }
  return ,$list.ToArray()
}

function Tap-Desc([string]$part, [switch]$Exact) {
  $xml = Dump-Ui
  $nodes = Find-Nodes $xml '//node[@content-desc]'
  foreach ($n in $nodes) {
    $cd = $n.GetAttribute('content-desc')
    $ok = if ($Exact) { $cd -eq $part } else { $cd.Contains($part) }
    if ($ok) {
      Tap-Bounds $n.GetAttribute('bounds')
      Write-Host ("tapped: " + ($cd -replace "`n", ' / '))
      return $true
    }
  }
  Write-Host "MISSING: $part"
  return $false
}

function Get-Edits {
  $xml = Dump-Ui
  return Find-Nodes $xml "//node[@class='android.widget.EditText']"
}

function Show-Descs {
  $xml = Dump-Ui
  $nodes = Find-Nodes $xml '//node[@content-desc]'
  foreach ($n in $nodes) {
    $cd = $n.GetAttribute('content-desc')
    if ($cd) { Write-Host ($cd -replace "`n", ' / ') }
  }
}

# Pets -> Add pet
[void](Tap-Desc "Pets`nTab 2 of 5" -Exact)
Start-Sleep -Milliseconds 800
[void](Tap-Desc 'Add pet')
Start-Sleep -Seconds 1

$eds = Get-Edits
Write-Host ("edit count=" + $eds.Length)
$vals = @('Bob', 'Dog', 'Golden%sRetriever', '6')
for ($i = 0; $i -lt [Math]::Min($vals.Length, $eds.Length); $i++) {
  Tap-Bounds $eds[$i].GetAttribute('bounds')
  Type-Text $vals[$i]
}

$xml = Dump-Ui
$sizeNodes = Find-Nodes $xml "//node[contains(@content-desc,'Size')]"
if ($sizeNodes.Length -gt 0) {
  Tap-Bounds $sizeNodes[0].GetAttribute('bounds')
  Start-Sleep -Milliseconds 800
  $xml = Dump-Ui
  $opt = Find-Nodes $xml "//node[contains(@content-desc,'Medium')]"
  if ($opt.Length -eq 0) { $opt = Find-Nodes $xml "//node[@text='Medium']" }
  if ($opt.Length -gt 0) {
    Tap-Bounds $opt[0].GetAttribute('bounds')
    Write-Host 'picked Medium'
  } else {
    Write-Host 'Medium missing'
  }
}

$eds = Get-Edits
Write-Host ("edits after size=" + $eds.Length)
if ($eds.Length -ge 5) {
  Tap-Bounds $eds[4].GetAttribute('bounds')
  Type-Text 'Long%scoat'
}

& $adb shell input swipe 540 1900 540 700 300
Start-Sleep -Milliseconds 800
$eds = Get-Edits
Write-Host ("edits after scroll=" + $eds.Length)
$notes = @('Needs%sallergy%smeds', 'Friendly%sbut%sjumpy', 'Walk%smorning%sonly')
for ($i = 0; $i -lt $notes.Length; $i++) {
  $idx = $eds.Length - $notes.Length + $i
  if ($idx -ge 0 -and $idx -lt $eds.Length) {
    Tap-Bounds $eds[$idx].GetAttribute('bounds')
    Type-Text $notes[$i]
  }
}

& $adb shell input swipe 540 1900 540 700 300
Start-Sleep -Milliseconds 800
$xml = Dump-Ui
$save = Find-Nodes $xml "//node[@content-desc='Add pet' and @class='android.widget.Button']"
if ($save.Length -eq 0) { $save = Find-Nodes $xml "//node[@content-desc='Add pet']" }
Write-Host ("save nodes=" + $save.Length)
if ($save.Length -gt 0) {
  Tap-Bounds $save[-1].GetAttribute('bounds')
}
Start-Sleep -Seconds 3
Write-Host '--- after save ---'
Show-Descs
