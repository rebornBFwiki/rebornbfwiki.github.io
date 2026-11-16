# Télécharge l'illustration de la meilleure forme de chaque unité jouable dans assets/art/<forme>.png,
# réduite à 280 px de large (fond transparent conservé).
$root = Split-Path -Parent $PSScriptRoot
$base = 'https://bfr-assets.cf-assets.workers.dev/assets/original/units'
Add-Type -AssemblyName System.Web.Extensions
Add-Type -AssemblyName System.Drawing
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$ser.MaxJsonLength = 2147483647
$units = $ser.DeserializeObject([IO.File]::ReadAllText("$root\data\units.json", [Text.Encoding]::UTF8))
$wc = New-Object System.Net.WebClient
$wc.Headers.Add('User-Agent', 'RebornWiki/1.0 (fan wiki)')
$tmp = Join-Path $env:TEMP 'rebornwiki-art'; New-Item -ItemType Directory -Force $tmp | Out-Null
New-Item -ItemType Directory -Force "$root\assets\art" | Out-Null
$ok = 0; $ko = @()
foreach ($u in $units) {
  $forms = @($u['forms'])
  if (-not ($forms | Where-Object { $_['leaderSkill'] })) { continue }
  $best = $forms[$forms.Count - 1]
  if ("$($u['name']) $($best['name'])" -match 'placeholder') { continue }
  $a = [string]$best['archiveId']; if (-not $a) { $ko += $best['id']; continue }
  $dest = "$root\assets\art\$($best['id']).png"
  if (Test-Path $dest) { $ok++; continue }
  $raw = Join-Path $tmp "$a.png"
  try { $wc.DownloadFile("$base/$a/unit_ills_full_$a.png", $raw) } catch { $ko += $best['id']; continue }
  $img = [System.Drawing.Image]::FromFile($raw)
  try {
    $w = 280; $h = [int]($img.Height * $w / $img.Width)
    $bmp = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.DrawImage($img, 0, 0, $w, $h)
    $bmp.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose(); $ok++
  } finally { $img.Dispose() }
}
"illustrations : $ok, échecs : " + $ko.Count + $(if ($ko.Count) { " (" + ($ko -join ', ') + ")" } else { "" })
"taille : " + [Math]::Round(((Get-ChildItem "$root\assets\art" -File | Measure-Object Length -Sum).Sum) / 1MB, 1) + " Mo"
