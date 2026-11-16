# Construit data/forge.json à partir des recettes lues dans la Forge à sphères du jeu (build/forge-recipes-fr.json).
# Chaque recette : { karma, level (niveau de Forge requis, 0 si inconnu), na (1 = pas encore disponible), mats: [{ k: "sphere"|"item", id, n }] }
$root = Split-Path -Parent $PSScriptRoot
Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$ser.MaxJsonLength = 2147483647
$utf8 = New-Object System.Text.UTF8Encoding $false
$recipes = $ser.DeserializeObject([IO.File]::ReadAllText("$PSScriptRoot\forge-recipes-fr.json", [Text.Encoding]::UTF8))
$spheres = $ser.DeserializeObject([IO.File]::ReadAllText("$root\data\spheres.json", [Text.Encoding]::UTF8))
$items = $ser.DeserializeObject([IO.File]::ReadAllText("$root\data\items.json", [Text.Encoding]::UTF8))
$fr = $ser.DeserializeObject([IO.File]::ReadAllText("$root\data\i18n-fr.json", [Text.Encoding]::UTF8))

function Key($s) { return (($s.ToLowerInvariant().Normalize([Text.NormalizationForm]::FormD) -replace '\p{Mn}', '') -replace '[^a-z0-9]', '') }
$sph = @{}; $itm = @{}
function Add($map, $name, $id) { if (-not $name) { return }; $k = Key $name; if (-not $map.ContainsKey($k)) { $map[$k] = New-Object System.Collections.ArrayList }; if (-not $map[$k].Contains($id)) { [void]$map[$k].Add($id) } }
foreach ($s in $spheres) { Add $sph $s['name'] $s['id']; if ($fr['sphere'].ContainsKey($s['id'])) { Add $sph $fr['sphere'][$s['id']]['n'] $s['id'] } }
foreach ($i in $items) { Add $itm $i['name'] $i['id']; if ($fr['item'].ContainsKey($i['id'])) { Add $itm $fr['item'][$i['id']]['n'] $i['id'] } }

$out = @{}; $unmatchedOut = @(); $unmatchedMat = @{}
foreach ($name in $recipes.Keys) {
  $r = $recipes[$name]
  $ids = $sph[(Key $name)]
  if (-not $ids) { $unmatchedOut += $name; continue }
  $mats = @()
  foreach ($m in $r[3]) {
    $k = Key $m[0]
    if ($sph.ContainsKey($k)) { $mats += [ordered]@{ k = 'sphere'; id = $sph[$k][0]; n = $m[1] } }
    elseif ($itm.ContainsKey($k)) { $mats += [ordered]@{ k = 'item'; id = $itm[$k][0]; n = $m[1] } }
    else { $mats += [ordered]@{ k = '?'; name = $m[0]; n = $m[1] }; $unmatchedMat[$m[0]] = 1 }
  }
  $rec = [ordered]@{ karma = $r[0]; level = $r[1]; na = $r[2]; mats = $mats }
  foreach ($id in $ids) { $out[$id] = $rec }
}
[IO.File]::WriteAllText("$root\data\forge.json", ($out | ConvertTo-Json -Depth 6 -Compress), $utf8)
"recettes: " + $recipes.Count + " · sphères couvertes: " + $out.Count + " · sphères introuvables: " + $unmatchedOut.Count
if ($unmatchedOut.Count) { "  " + ($unmatchedOut -join ', ') }
"matériaux introuvables: " + $unmatchedMat.Count
if ($unmatchedMat.Count) { "  " + (($unmatchedMat.Keys | Sort-Object) -join ', ') }
