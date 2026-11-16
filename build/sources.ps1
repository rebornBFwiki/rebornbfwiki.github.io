param([string]$Content, [string]$FrChunk)
# Construit data/sources.json (où obtenir sphères et objets) et data/i18n-fr.json (noms français officiels).
#   -Content : dossier des fichiers publics du jeu (world.*.json, spheres.*.json, frontierLadder.*.json, frontierQuests.*.json)
#   -FrChunk : script du jeu qui contient la traduction française (clés "sphere.<id>.name", "item.<id>.name")
$root = Split-Path -Parent $PSScriptRoot
Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$ser.MaxJsonLength = 2147483647
function Load($pattern) { $f = Get-ChildItem $Content -Filter $pattern | Select-Object -First 1; return $ser.DeserializeObject([IO.File]::ReadAllText($f.FullName)) }
$world = Load 'world.*.json'
$ladder = Load 'frontierLadder.*.json'
$quests = Load 'frontierQuests.*.json'

$frNames = @{}
foreach ($line in [IO.File]::ReadAllLines("$PSScriptRoot\fr-names.tsv", [Text.Encoding]::UTF8)) {
  $p = $line.Split("`t", 2); if ($p.Count -eq 2) { $frNames[$p[0]] = $p[1] -replace "'$", '' }
}
$missionName = @{}
foreach ($m in $world['missions']) {
  $id = [string]$m['archiveId']
  $fr = if ($frNames.ContainsKey("mission.$id")) { $frNames["mission.$id"] } else { $m['name'] }
  $missionName[$id] = @{ fr = $fr; en = $m['name'] }
}
foreach ($q in $quests) { $missionName[[string]$q['archiveId']] = @{ fr = $q['name']; en = $q['name'] } }

$sph = @{}
function AddSphere($id, $src) { if (-not $id) { return }; if (-not $sph.ContainsKey($id)) { $sph[$id] = New-Object System.Collections.ArrayList }; [void]$sph[$id].Add($src) }

# Premières victoires (dans les quêtes et dans les sorties de contenu).
foreach ($m in $world['missions']) {
  $fc = $m['firstClear']; if ($fc -and $fc['spheres']) { foreach ($s in $fc['spheres']) { AddSphere $s['sphere'] ([ordered]@{ k = 'first-clear'; m = $m['archiveId'] }) } }
}
foreach ($r in $world['releases']) {
  foreach ($fc in @($r['firstClears'])) { if ($fc -and $fc['reward'] -and $fc['reward']['spheres']) { foreach ($s in $fc['reward']['spheres']) { AddSphere $s['sphere'] ([ordered]@{ k = 'first-clear'; m = $fc['mission'] }) } } }
}
# Rangs de chasseur (Frontier Hunter).
foreach ($h in $ladder['hunterRanks']) { $rw = $h['reward']; if ($rw -and $rw['kind'] -eq 'sphere') { AddSphere $rw['content'] ([ordered]@{ k = 'hunter-rank'; rank = $h['rank'] }) } }
# Autres récompenses du classement et des quêtes Frontier : toute récompense de type sphère.
function Walk($o, $ctx) {
  if ($o -is [System.Collections.IDictionary]) {
    if ($o['kind'] -eq 'sphere' -and $o['content']) { AddSphere $o['content'] $ctx }
    foreach ($k in @($o.Keys)) { if ($k -ne 'hunterRanks') { Walk $o[$k] $ctx } }
  } elseif ($o -is [System.Collections.IEnumerable] -and -not ($o -is [string])) { foreach ($x in $o) { Walk $x $ctx } }
}
foreach ($q in $quests) { Walk $q ([ordered]@{ k = 'frontier-quest'; m = $q['archiveId'] }) }
foreach ($k in @($ladder.Keys)) { if ($k -ne 'hunterRanks') { Walk $ladder[$k] ([ordered]@{ k = 'frontier-ladder' }) } }

# Objets : où ils tombent, avec le nombre moyen par tour.
$items = @{}
foreach ($m in $world['missions']) {
  $per = @{}
  foreach ($w in $m['waves']) {
    $opts = if ($w['pool']) { $w['pool'] } else { @($w) }
    foreach ($o in $opts) { foreach ($e in $o['enemies']) {
      $d = $e['drops']; if (-not $d) { continue }
      foreach ($it in @($d['items'])) { if ($it) { $per[$it['item']] = [double]$per[$it['item']] + ([double]$it['rate'] / 100) / $opts.Count } }
      if ($d['chest']) { foreach ($c in $d['chest']['contents']) { if ($c['kind'] -eq 'item') { $per[$c['item']] = [double]$per[$c['item']] + ([double]$d['chest']['rate'] / 100) * ([double]$c['chance'] / 100) / $opts.Count } } }
    } }
  }
  foreach ($k in $per.Keys) {
    if (-not $items.ContainsKey($k)) { $items[$k] = New-Object System.Collections.ArrayList }
    [void]$items[$k].Add([ordered]@{ m = $m['archiveId']; e = [Math]::Round($per[$k], 3); en = $m['energy'] })
  }
}
$itemOut = @{}
foreach ($k in $items.Keys) {
  # Les 5 meilleures quêtes : le plus d'exemplaires par point d'énergie.
  $itemOut[$k] = @($items[$k] | Sort-Object { - ($_.e / [Math]::Max(1, $_.en)) }, { - $_.e } | Select-Object -First 5)
}
$used = New-Object System.Collections.Generic.HashSet[string]
foreach ($l in $sph.Values) { foreach ($s in $l) { if ($s.m) { [void]$used.Add([string]$s.m) } } }
foreach ($l in $itemOut.Values) { foreach ($s in $l) { [void]$used.Add([string]$s.m) } }
$names = @{}; foreach ($id in $used) { if ($missionName.ContainsKey($id)) { $names[$id] = $missionName[$id] } }

$out = [ordered]@{ spheres = $sph; items = $itemOut; missions = $names }
$utf8 = New-Object System.Text.UTF8Encoding $false
[IO.File]::WriteAllText("$root\data\sources.json", ($out | ConvertTo-Json -Depth 8 -Compress), $utf8)

# Noms et descriptions français officiels des sphères et des objets.
$js = [IO.File]::ReadAllText($FrChunk, [Text.Encoding]::UTF8)
$fr = @{ sphere = @{}; item = @{} }
foreach ($m in [regex]::Matches($js, '"(sphere|item)\.([^"]+)\.(name|description)":"((?:[^"\\]|\\.)*)"')) {
  $kind = $m.Groups[1].Value; $id = $m.Groups[2].Value; $field = if ($m.Groups[3].Value -eq 'name') { 'n' } else { 'd' }
  $val = $m.Groups[4].Value -replace "\\'", "'" -replace '\\"', '"'
  if (-not $fr[$kind].ContainsKey($id)) { $fr[$kind][$id] = @{} }
  $fr[$kind][$id][$field] = $val
}
[IO.File]::WriteAllText("$root\data\i18n-fr.json", $ser.Serialize($fr), $utf8)
"spheres avec source: " + $sph.Count + " · objets avec drop: " + $itemOut.Count + " · quêtes citées: " + $names.Count + " · FR sphères: " + $fr.sphere.Count + " · FR objets: " + $fr.item.Count
