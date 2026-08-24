$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add('http://localhost:4173/')

try {
    $listener.Start()
} catch {
    Write-Host 'Framewise is already running, or port 4173 is in use.'
    Start-Process 'http://localhost:4173/'
    exit
}

Start-Process 'http://localhost:4173/'
Write-Host 'Framewise is running at http://localhost:4173/'
Write-Host 'Keep this window open while you use the app.'

$types = @{'.html'='text/html; charset=utf-8';'.js'='text/javascript; charset=utf-8';'.css'='text/css; charset=utf-8';'.json'='application/json';'.png'='image/png';'.jpg'='image/jpeg';'.jpeg'='image/jpeg';'.svg'='image/svg+xml'}
while ($listener.IsListening) {
    $context = $listener.GetContext()
    $relative = [Uri]::UnescapeDataString($context.Request.Url.AbsolutePath.TrimStart('/'))
    if ([string]::IsNullOrWhiteSpace($relative)) { $relative = 'index.html' }
    $candidate = [IO.Path]::GetFullPath((Join-Path $root $relative))
    if (!$candidate.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -or !(Test-Path -LiteralPath $candidate -PathType Leaf)) {
        $context.Response.StatusCode = 404
        $context.Response.Close()
        continue
    }
    $extension = [IO.Path]::GetExtension($candidate).ToLowerInvariant()
    $context.Response.ContentType = if ($types.ContainsKey($extension)) { $types[$extension] } else { 'application/octet-stream' }
    $context.Response.Headers.Add('Cache-Control', 'no-store')
    $bytes = [IO.File]::ReadAllBytes($candidate)
    $context.Response.ContentLength64 = $bytes.Length
    $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $context.Response.Close()
}
