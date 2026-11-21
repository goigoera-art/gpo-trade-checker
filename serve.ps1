# Простой локальный сервер: powershell -ExecutionPolicy Bypass -File serve.ps1  → http://localhost:8765/
$root = $PSScriptRoot
$l = New-Object System.Net.HttpListener
$port = if ($env:PORT) { $env:PORT } else { 8765 }
$l.Prefixes.Add("http://localhost:$port/")
$l.Start()
Write-Host "Serving $root on http://localhost:$port/"
$types = @{ ".html"="text/html; charset=utf-8"; ".js"="application/javascript; charset=utf-8"; ".webp"="image/webp"; ".css"="text/css" }
while ($l.IsListening) {
  $c = $l.GetContext()
  try {
    $p = [Uri]::UnescapeDataString($c.Request.Url.AbsolutePath.TrimStart('/'))
    if ($p -eq "") { $p = "index.html" }
    $f = [IO.Path]::GetFullPath((Join-Path $root $p))
    $c.Response.Headers["Cache-Control"] = "no-cache"
    if ($f.StartsWith($root) -and (Test-Path $f -PathType Leaf)) {
      $b = [IO.File]::ReadAllBytes($f)
      $ct = $types[[IO.Path]::GetExtension($f)]; if ($ct) { $c.Response.ContentType = $ct }
      $c.Response.ContentLength64 = $b.Length
      if ($c.Request.HttpMethod -ne "HEAD") { $c.Response.OutputStream.Write($b, 0, $b.Length) }
    } else { $c.Response.StatusCode = 404 }
  } catch { }
  try { $c.Response.Close() } catch { }
}
