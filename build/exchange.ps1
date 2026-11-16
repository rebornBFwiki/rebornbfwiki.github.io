# Construit data/exchange.json à partir de build/exchange.json (Hall des échanges lu en jeu).
# Relie chaque article à une sphère, un objet ou une unité du wiki, d'après son nom anglais.
$root = Split-Path -Parent $PSScriptRoot
Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$ser.MaxJsonLength = 2147483647
$utf8 = New-Object System.Text.UTF8Encoding $false
function Read($p) { return $ser.DeserializeObject([IO.File]::ReadAllText($p, [Text.Encoding]::UTF8)) }
$ex = Read "$PSScriptRoot\exchange.json"
$spheres = Read "$root\data\spheres.json"; $items = Read "$root\data\items.json"; $units = Read "$root\data\units.json"
function Key($s) { $s = $s -replace 'Perserverance', 'Perseverance'; return (($s.ToLowerInvariant().Normalize([Text.NormalizationForm]::FormD) -replace '\p{Mn}', '') -replace '[^a-z0-9]', '') }
$sph = @{}; foreach ($s in $spheres) { $k = Key $s['name']; if (-not $sph.ContainsKey($k)) { $sph[$k] = $s['id'] } }
$itm = @{}; foreach ($i in $items) { $k = Key $i['name']; if (-not $itm.ContainsKey($k)) { $itm[$k] = $i['id'] } }
$uni = @{}
foreach ($u in $units) { $fs = @($u['forms']); for ($n = 0; $n -lt $fs.Count; $n++) { $k = Key $fs[$n]['name']; if (-not $uni.ContainsKey($k)) { $uni[$k] = @{ u = $u['id']; f = $n; fid = $fs[$n]['id'] } } }; $k = Key $u['name']; if (-not $uni.ContainsKey($k)) { $uni[$k] = @{ u = $u['id']; f = 0; fid = $fs[0]['id'] } } }
$miss = @()
function Build($src) {
  $o = [ordered]@{ spheres = @{}; items = @{}; units = @{}; other = @() }
  foreach ($e in $src['spheres']) { $k = Key $e[0]; if ($sph.ContainsKey($k)) { $o.spheres[$sph[$k]] = @{ pts = $e[1]; stock = $e[2] } } else { $script:miss += "sphère $($e[0])" } }
  foreach ($e in $src['units']) { $k = Key $e[0]; if ($uni.ContainsKey($k)) { $o.units[$uni[$k].fid] = @{ pts = $e[1]; stock = $e[2]; unit = $uni[$k].u; form = $uni[$k].f } } else { $script:miss += "unité $($e[0])" } }
  foreach ($e in $src['other']) {
    $k = Key $e[0]
    if ($itm.ContainsKey($k)) { $o.items[$itm[$k]] = @{ pts = $e[1]; stock = $e[2] } }
    elseif ($uni.ContainsKey($k)) { $o.units[$uni[$k].fid] = @{ pts = $e[1]; stock = $e[2]; unit = $uni[$k].u; form = $uni[$k].f } }
    else { $o.other += ,@{ name = $e[0]; pts = $e[1]; stock = $e[2] } }
  }
  return $o
}
$m = Build $ex
$g = Build $ex['guild']
$out = [ordered]@{ seen = $ex['seen']; spheres = $m.spheres; items = $m.items; units = $m.units; other = $m.other; guild = $g }
[IO.File]::WriteAllText("$root\data\exchange.json", ($out | ConvertTo-Json -Depth 6 -Compress), $utf8)
"mérite: " + $m.spheres.Count + " sphères, " + $m.units.Count + " unités, " + $m.items.Count + " objets · guilde: " + $g.spheres.Count + " sphères, " + $g.units.Count + " unités, " + $g.items.Count + " objets, autres: " + $g.other.Count
if ($miss.Count) { "introuvables: " + ($miss -join ', ') }
