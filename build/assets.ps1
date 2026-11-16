param([string]$Content)
# Télécharge les images du site depuis les fichiers publics du jeu :
#   assets/item/...       icônes des sphères et des objets (chemin "icon" des données)
#   assets/dungeon/<id>.jpg  fond de chaque donjon, réduit à 400 px de large
#   assets/area/<id>.jpg     plaque de chaque terre de l'histoire
$root = Split-Path -Parent $PSScriptRoot
$base = 'https://bfr-assets.cf-assets.workers.dev/assets/original'
Add-Type -AssemblyName System.Web.Extensions
Add-Type -AssemblyName System.Drawing
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$ser.MaxJsonLength = 2147483647
function Load($pattern) { $f = Get-ChildItem $Content -Filter $pattern | Select-Object -First 1; return $ser.DeserializeObject([IO.File]::ReadAllText($f.FullName)) }
$wc = New-Object System.Net.WebClient
$wc.Headers.Add('User-Agent', 'RebornWiki/1.0 (fan wiki)')

function Fetch($rel, $dest) {
  if (Test-Path $dest) { return $true }
  New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
  try { $wc.DownloadFile("$base/$rel", $dest); return $true } catch { return $false }
}
function Shrink($src, $dest, $width) {
  $img = [System.Drawing.Image]::FromFile($src)
  try {
    $h = [int]($img.Height * $width / $img.Width)
    $bmp = New-Object System.Drawing.Bitmap $width, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($img, 0, 0, $width, $h)
    $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
    $p = New-Object System.Drawing.Imaging.EncoderParameters 1
    $p.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), 72L
    $bmp.Save($dest, $codec, $p)
    $g.Dispose(); $bmp.Dispose()
  } finally { $img.Dispose() }
}

$ok = 0; $ko = @()
$icons = New-Object System.Collections.Generic.HashSet[string]
foreach ($s in (Load 'spheres.*.json')) { if ($s['icon']) { [void]$icons.Add($s['icon']) } }
foreach ($i in (Load 'items.*.json')) { if ($i['icon']) { [void]$icons.Add($i['icon']) } }
foreach ($ic in $icons) { if (Fetch $ic "$root\assets\$($ic -replace '/', '\')") { $ok++ } else { $ko += $ic } }
"icônes : $ok, échecs : " + $ko.Count

$world = Load 'world.*.json'
$tmp = Join-Path $env:TEMP 'rebornwiki-img'; New-Item -ItemType Directory -Force $tmp | Out-Null
$d = 0
foreach ($dg in $world['dungeons']) {
  if (-not $dg['background']) { continue }
  $dest = "$root\assets\dungeon\$($dg['archiveId']).jpg"
  if (Test-Path $dest) { $d++; continue }
  $raw = Join-Path $tmp $dg['background']
  if (Fetch "dungeon/$($dg['background'])" $raw) { New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null; Shrink $raw $dest 400; $d++ }
}
"donjons : $d"
$a = 0
foreach ($ar in $world['areas']) {
  if (-not $ar['plate']) { continue }
  $raw = Join-Path $tmp $ar['plate']; $dest = "$root\assets\area\$($ar['archiveId']).png"
  if (Fetch "area/$($ar['plate'])" $raw) { New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null; Copy-Item $raw $dest -Force; $a++ }
}
"terres : $a"
