# Met à jour les données et les images du wiki depuis la Data API officielle de Brave Frontier: Reborn.
#   https://rebornbf.com/product/data : usage non commercial, crédit "Brave Frontier: Reborn (rebornbf.com)"
#   et "Brave Frontier © Alim/gumi", images uniquement depuis les packs officiels, hébergées ici.
# Écrit : data/units.json, spheres.json, items.json, banners.json, community.json (tier list et utilisation),
#         complète data/sources.json (drops des objets) et data/forge.json (matériaux, Karma, niveau),
#         data/images.json (vignettes), assets/item + assets/unit (icônes), assets/art (pose des unités).
# Les fichiers de l'API et les packs sont gardés en cache dans %TEMP%\rebornwiki-api : un fichier n'est
# téléchargé que si son nom (son hash) change, comme le demandent les règles.
# Usage : powershell -ExecutionPolicy Bypass -File build\api.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$cache = Join-Path $env:TEMP 'rebornwiki-api'
New-Item -ItemType Directory -Force "$cache\packs" | Out-Null
Add-Type -AssemblyName System.Web.Extensions
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$ser.MaxJsonLength = 2147483647
$utf8 = New-Object System.Text.UTF8Encoding $false
$wc = New-Object System.Net.WebClient
$wc.Headers.Add('User-Agent', 'RebornWiki/1.0 (fan wiki, rebornbfwiki.github.io)')
$wc.Encoding = [Text.Encoding]::UTF8

function Get-Cached($url, $file) {
  $dest = Join-Path $cache $file
  if (-not (Test-Path $dest)) { $wc.DownloadFile($url, "$dest.part"); Move-Item "$dest.part" $dest -Force }
  return $dest
}
function Read-Json($path) { return $ser.DeserializeObject([IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)) }
# PowerShell enveloppe parfois les valeurs (PSObject) : on les déballe avant la sérialisation.
Add-Type -ReferencedAssemblies ([psobject].Assembly.Location) -TypeDefinition @'
using System.Collections; using System.Collections.Generic; using System.Management.Automation;
public static class JsonPrep {
  public static object Unwrap(object o) {
    var p = o as PSObject; if (p != null) o = p.BaseObject;
    var d = o as IDictionary;
    if (d != null) { var r = new Dictionary<string, object>(); foreach (DictionaryEntry e in d) r[e.Key.ToString()] = Unwrap(e.Value); return r; }
    if (o is IEnumerable && !(o is string)) { var l = new List<object>(); foreach (var x in (IEnumerable)o) l.Add(Unwrap(x)); return l; }
    return o;
  }
}
'@
function Unwrap($o) { return , [JsonPrep]::Unwrap($o) }
function Write-Json($name, $obj) {
  try { $json = $ser.Serialize((Unwrap $obj)) } catch { throw "écriture de $name impossible : $_" }
  [IO.File]::WriteAllText("$root\data\$name", $json, $utf8)
}

# ---------- Données ----------
$manifest = $ser.DeserializeObject($wc.DownloadString('https://data.rebornbf.com/v1/manifest.json'))
$B = @{}
foreach ($f in $manifest['files']) { $B[$f['kind']] = Read-Json (Get-Cached "https://data.rebornbf.com$($f['path'])" (Split-Path $f['path'] -Leaf)) }
"données : version " + $manifest['contentVersion'] + " (" + $manifest['generatedAt'] + ")"
$art = $B['art']

# Unités : celles de l'API, plus les répliques d'invocation (absentes de l'API, gardées dans build/legacy-quotes.json).
$quotes = Read-Json "$PSScriptRoot\legacy-quotes.json"
$units = $B['units']['units']
foreach ($u in $units) { foreach ($f in $u['forms']) { if ($quotes.ContainsKey($f['id'])) { $f['quotes'] = $quotes[$f['id']] } } }
Write-Json 'units.json' $units

# Sphères et objets : l'icône est le chemin de l'image dans le pack, sans "original/".
$icon = @{}
foreach ($x in @($art['spheres']) + @($art['items'])) { $icon[$x['id']] = ($x['icon']['path'] -replace '^original/', '') }
foreach ($k in 'spheres', 'items') {
  $list = $B[$k][$k]
  foreach ($x in $list) { if ($icon.ContainsKey($x['id'])) { $x['icon'] = $icon[$x['id']] } }
  Write-Json "$k.json" $list
}
Write-Json 'banners.json' $B['banners']['banners']

# Où trouver les objets : les 5 quêtes qui en donnent le plus par point d'énergie.
$frNames = @{}
foreach ($line in [IO.File]::ReadAllLines("$PSScriptRoot\fr-names.tsv", [Text.Encoding]::UTF8)) {
  $p = $line.Split("`t", 2); if ($p.Count -eq 2) { $frNames[$p[0]] = $p[1] -replace "'$", '' }
}
$mission = @{}
foreach ($m in $B['missions']['missions']) { $mission[[string]$m['archiveId']] = $m }
$sources = if (Test-Path "$root\data\sources.json") { Read-Json "$root\data\sources.json" } else { @{ spheres = @{}; missions = @{} } }
$drops = @{}
$craft = @{}
foreach ($it in $B['sources']['items']) {
  $list = New-Object System.Collections.ArrayList
  foreach ($s in $it['sources']) {
    if ($s['kind'] -eq 'drop') {
      $m = $mission[[string]$s['mission']]; $en = if ($m) { [int]$m['energy'] } else { 0 }
      [void]$list.Add([ordered]@{ m = $s['mission']; e = [Math]::Round([double]$s['perRun'], 3); en = $en })
    } elseif ($s['kind'] -eq 'craft' -and $s['facility'] -eq 'sphere-forge') { $craft[$it['id']] = $s }
  }
  if ($list.Count) { $drops[$it['id']] = @($list | Sort-Object { - ($_.e / [Math]::Max(1, $_.en)) }, { - $_.e } | Select-Object -First 5) }
}
$sources['items'] = $drops
$names = @{}; if ($sources['missions']) { foreach ($k in $sources['missions'].Keys) { $names[$k] = $sources['missions'][$k] } }
foreach ($l in $drops.Values) { foreach ($s in $l) {
  $id = [string]$s.m; $m = $mission[$id]
  if ($m -and -not $names.ContainsKey($id)) { $fr = if ($frNames.ContainsKey("mission.$id")) { $frNames["mission.$id"] } else { $m['name'] }; $names[$id] = @{ fr = $fr; en = $m['name'] } }
} }
$sources['missions'] = $names
Write-Json 'sources.json' $sources
"objets avec drop : " + $drops.Count

# Forge : matériaux, Karma et niveau de l'API ; "na" (pas encore disponible en jeu) vient de la lecture en jeu (forge.ps1).
$isSphere = @{}; foreach ($s in $B['spheres']['spheres']) { $isSphere[$s['id']] = 1 }
$forge = if (Test-Path "$root\data\forge.json") { Read-Json "$root\data\forge.json" } else { @{} }
foreach ($id in $craft.Keys) {
  $c = $craft[$id]
  $mats = @(foreach ($m in $c['materials']) { [ordered]@{ k = $(if ($isSphere.ContainsKey($m['id'])) { 'sphere' } else { 'item' }); id = $m['id']; n = $m['count'] } })
  $na = if ($forge.ContainsKey($id)) { $forge[$id]['na'] } else { 0 }
  $forge[$id] = [ordered]@{ karma = $c['karma']; level = $c['level']; na = $na; mats = $mats }
}
Write-Json 'forge.json' $forge
"recettes de forge : " + $forge.Count

# Tier list votée et utilisation des unités (statistiques du jour).
$stats = $ser.DeserializeObject($wc.DownloadString('https://data.rebornbf.com/v1/stats/latest.json'))
$day = $stats['days'][0]
$comm = [ordered]@{ date = $day['date'] }
foreach ($f in $day['files']) {
  if ($f['name'] -in 'tiers', 'usage') { $comm[$f['name']] = Read-Json (Get-Cached "https://data.rebornbf.com$($f['path'])" (Split-Path $f['path'] -Leaf)) }
}
Write-Json 'community.json' $comm
"statistiques du " + $day['date']

# ---------- Images (packs officiels) ----------
$packs = $ser.DeserializeObject($wc.DownloadString('https://packs.rebornbf.com/packs/manifest.json'))
$zips = @{}
foreach ($p in $packs['packs']) { $zips[$p['id']] = @(foreach ($part in $p['parts']) { Get-Cached "https://packs.rebornbf.com$($part['path'])" ("packs\" + (Split-Path $part['path'] -Leaf)) }) }
# Index : chemin dans le pack -> entrée du zip.
function Open-Pack($id) {
  $map = @{}
  foreach ($z in $zips[$id]) { $zip = [IO.Compression.ZipFile]::OpenRead($z); foreach ($e in $zip.Entries) { $map[$e.FullName] = $e } }
  return $map
}
function Read-Entry($e) { $s = $e.Open(); $ms = New-Object IO.MemoryStream; $s.CopyTo($ms); $s.Dispose(); return $ms.ToArray() }

# Icônes des sphères et des objets.
foreach ($d in 'item', 'unit') { if (Test-Path "$root\assets\$d") { Remove-Item -Recurse -Force "$root\assets\$d" } }
$n = 0
foreach ($pk in 'item-icons', 'sphere-icons') {
  $map = Open-Pack $pk
  foreach ($path in $map.Keys) {
    if ($map[$path].Length -eq 0) { continue }
    $dest = Join-Path "$root\assets" (($path -replace '^original/', '') -replace '/', '\')
    New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
    [IO.File]::WriteAllBytes($dest, (Read-Entry $map[$path])); $n++
  }
}
"icônes : $n"

# Vignettes des unités (data/images.json, en data URI comme avant).
$thumbs = Open-Pack 'unit-thumbnails'
$images = [ordered]@{}
foreach ($x in $art['units']) {
  $e = $thumbs[$x['thumbnail']['path']]; if (-not $e) { continue }
  $mime = if ($x['thumbnail']['path'] -like '*.webp') { 'image/webp' } else { 'image/png' }
  $images[$x['form']] = "data:$mime;base64," + [Convert]::ToBase64String((Read-Entry $e))
}
Write-Json 'images.json' $images
"vignettes : " + $images.Count

# Pose des unités jouables : première image de l'animation d'attente du sprite de combat, rognée.
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System; using System.Drawing; using System.Drawing.Imaging; using System.Runtime.InteropServices;
public static class SpriteCut {
  public static Bitmap Frame(Bitmap sheet, int x, int y, int w, int h) {
    var f = new Bitmap(w, h, PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(f)) g.DrawImage(sheet, new Rectangle(0, 0, w, h), new Rectangle(x, y, w, h), GraphicsUnit.Pixel);
    var d = f.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
    var px = new byte[d.Stride * h]; Marshal.Copy(d.Scan0, px, 0, px.Length); f.UnlockBits(d);
    int x0 = w, y0 = h, x1 = -1, y1 = -1;
    for (int j = 0; j < h; j++) for (int i = 0; i < w; i++) if (px[j * d.Stride + i * 4 + 3] > 8) { if (i < x0) x0 = i; if (i > x1) x1 = i; if (j < y0) y0 = j; if (j > y1) y1 = j; }
    if (x1 < 0) return f;
    var r = new Rectangle(x0, y0, x1 - x0 + 1, y1 - y0 + 1);
    var t = f.Clone(r, PixelFormat.Format32bppArgb); f.Dispose(); return t;
  }
  public static Bitmap Fit(Bitmap b, int max) {
    double s = Math.Min(1.0, (double)max / Math.Max(b.Width, b.Height));
    if (s >= 1.0) return b;
    int w = Math.Max(1, (int)Math.Round(b.Width * s)), h = Math.Max(1, (int)Math.Round(b.Height * s));
    var o = new Bitmap(w, h, PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(o)) { g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic; g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality; g.DrawImage(b, 0, 0, w, h); }
    b.Dispose(); return o;
  }
}
'@
$sprites = Open-Pack 'unit-sprites'
$artOf = @{}; foreach ($x in $art['units']) { if ($x['sprite']) { $artOf[$x['form']] = $x['sprite'] } }
if (Test-Path "$root\assets\art") { Remove-Item -Recurse -Force "$root\assets\art" }
New-Item -ItemType Directory -Force "$root\assets\art" | Out-Null
$ok = 0; $ko = @()
foreach ($u in $units) {
  $forms = @($u['forms'])
  if (-not ($forms | Where-Object { $_['leaderSkill'] })) { continue }
  $best = $forms[$forms.Count - 1]
  if ("$($u['name']) $($best['name'])" -match 'placeholder') { continue }
  $sp = $artOf[$best['id']]
  if (-not $sp -or -not $sprites[$sp['path']] -or -not $sprites[$sp['json']]) { $ko += $best['id']; continue }
  $meta = $ser.DeserializeObject([Text.Encoding]::UTF8.GetString((Read-Entry $sprites[$sp['json']])))
  $first = $null
  foreach ($k in $meta['frames'].Keys) { if ($k -match ' idle 0$') { $first = $meta['frames'][$k]['frame']; break } }
  if (-not $first) { $first = @{ x = 0; y = 0; w = $sp['frameWidth']; h = $sp['frameHeight'] } }
  $ms = New-Object IO.MemoryStream (, (Read-Entry $sprites[$sp['path']]))
  $sheet = New-Object System.Drawing.Bitmap $ms
  try {
    $img = [SpriteCut]::Fit([SpriteCut]::Frame($sheet, $first['x'], $first['y'], $first['w'], $first['h']), 320)
    $img.Save("$root\assets\art\$($best['id']).png", [System.Drawing.Imaging.ImageFormat]::Png); $img.Dispose(); $ok++
  } finally { $sheet.Dispose(); $ms.Dispose() }
}
"poses : $ok, sans sprite : " + $ko.Count
if ($ko.Count) { "  " + ($ko -join ', ') }
