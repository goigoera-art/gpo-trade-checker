# Обновляет цены, названия и картинки с https://gpovalues.com/browse/
# Запуск: powershell -ExecutionPolicy Bypass -File update.ps1
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$log  = Join-Path $root "update.log"
function Write-Log($m) { $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $m"; Write-Host $line; Add-Content -Path $log -Value $line -Encoding utf8 }

try {
  $tmp = Join-Path $env:TEMP "gpovalues-browse.html"
  curl.exe -sfL -A "Mozilla/5.0" "https://gpovalues.com/browse/" -o $tmp
  if ($LASTEXITCODE -ne 0) { throw "не удалось скачать страницу (curl $LASTEXITCODE)" }
  $t = [IO.File]::ReadAllText($tmp, [Text.Encoding]::UTF8)

  $updated = [regex]::Match($t, '<time class="num" datetime="([^"]+)"').Groups[1].Value
  $parts = $t -split '(?=<tr data-slug=)' | Select-Object -Skip 1
  $imgDir = Join-Path $root "images"; New-Item -ItemType Directory -Force $imgDir | Out-Null

  # старые данные — чтобы перекачивать только изменившиеся картинки
  $old = @{}
  $verFile = Join-Path $imgDir "versions.json"
  if (Test-Path $verFile) { (Get-Content -Raw $verFile | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $old[$_.Name] = $_.Value } }
  $ver = @{}

  $items = foreach ($p in $parts) {
    $end = $p.IndexOf('</tr>'); if ($end -gt 0) { $p = $p.Substring(0, $end) }
    $a = @{}
    foreach ($m in [regex]::Matches(($p -replace '>.*', ''), 'data-([a-z-]+)="([^"]*)"')) { $a[$m.Groups[1].Value] = $m.Groups[2].Value }
    $src = [regex]::Match($p, '<img src="([^"]+)"').Groups[1].Value
    $img = ""
    if ($src) {
      $f = Join-Path $imgDir "$($a.slug).webp"
      if (-not (Test-Path $f) -or $old[$a.slug] -ne $src) {
        curl.exe -sfL -A "Mozilla/5.0" ("https://gpovalues.com" + $src) -o $f
        if ($LASTEXITCODE -ne 0) { Write-Log "картинка не скачалась: $($a.slug)" }
      }
      if (Test-Path $f) { $img = "images/$($a.slug).webp"; $ver[$a.slug] = $src }
    }
    [pscustomobject]@{ slug=$a.slug; name=[Net.WebUtility]::HtmlDecode($a.name); code=$a.shortcut; rarity=$a.rarity
                       value=[int64]$a.value; demand=$a.demand; type=$a.type; img=$img }
  }

  if ($items.Count -lt 50) { throw "нашлось всего $($items.Count) предметов — похоже, сайт поменял вёрстку, данные не трогаю" }

  $stamp = if ($updated) { ([datetime]$updated).ToUniversalTime().ToString("yyyy-MM-dd HH:mm") + " UTC" } else { (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm") + " UTC" }
  $js = "var ITEMS = " + ($items | ConvertTo-Json -Compress) + ";`nvar UPDATED = '$stamp';`n"
  [IO.File]::WriteAllText((Join-Path $root "items.js"), $js, (New-Object Text.UTF8Encoding $false))
  [IO.File]::WriteAllText($verFile, ($ver | ConvertTo-Json -Compress), (New-Object Text.UTF8Encoding $false))
  Write-Log "OK: $($items.Count) предметов, цены на $stamp"
} catch {
  Write-Log "ОШИБКА: $_"
  exit 1
}
