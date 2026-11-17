param([string]$World, [string]$Challenges = "$PSScriptRoot\..\data\challenges.json", [string]$OutFile = "$PSScriptRoot\..\data\fights.json", [double]$MinScore = 70)
# Extrait le comportement des boss (IA, compétences, passifs) pour écrire le déroulé des combats difficiles.
# Source : le fichier public « world » du jeu. Seules les vagues avec un boss ou un ennemi scripté sont gardées.
Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$ser.MaxJsonLength = 2147483647
$w = $ser.DeserializeObject([IO.File]::ReadAllText($World))
$ch = $ser.DeserializeObject([IO.File]::ReadAllText($Challenges, [Text.Encoding]::UTF8))
$keep = @{}; foreach ($c in $ch) { if ([double]$c['score'] -ge $MinScore -or ($c['areaType'] -ne 'story' -and [double]$c['score'] -ge 60)) { $keep[[string]$c['id']] = 1 } }
$enemies = @{}; foreach ($e in $w['enemies']) { $enemies[[string]$e['archiveId']] = $e }

function Effects($list) {
  $out = @()
  foreach ($x in $list) {
    $o = [ordered]@{ id = $x['id'] }
    foreach ($k in 'value', 'turns', 'target', 'element', 'stat', 'hpDamage', 'damageScale', 'flatAtk', 'uncleansable', 'unremovable', 'chance', 'hits', 'count', 'min', 'max', 'boosts') { if ($x.ContainsKey($k) -and $null -ne $x[$k]) { $o[$k] = $x[$k] } }
    if ($x['effects']) { $o['effects'] = @(Effects $x['effects']) }
    $out += [pscustomobject]$o
  }
  return $out
}
function Variant($E, $vid) {
  $v = $E['variants'][[string]$vid]; if (-not $v) { $v = @($E['variants'].Values)[0] }
  $used = @{}; foreach ($a in $v['ai']) { $used[[string]$a['skill']] = 1; foreach ($p in @($a['skillPool'])) { if ($p) { $used[[string]$p] = 1 } } }
  if ($v['entrySkill']) { $used[[string]$v['entrySkill']] = 1 }
  foreach ($r in @($v['reactions'])) { if ($r) { $used[[string]$r['skill']] = 1 } }
  $skills = [ordered]@{}
  foreach ($s in $v['skills']) {
    $hits = 0; foreach ($at in $s['attacks']) { $hits += @($at['hitFrames']).Count }
    $skills[$s['id']] = [ordered]@{ name = $s['name']; hits = $hits; effects = @(Effects $s['effects']) }
  }
  $ai = @(); foreach ($a in $v['ai']) {
    $o = [ordered]@{ when = $a['when']; skill = $a['skill']; target = $a['target'] }
    foreach ($k in 'chance', 'hpPercent', 'conditions', 'setFlags', 'n', 'skillPool', 'thenEndTurn', 'summon') { if ($a.ContainsKey($k) -and $null -ne $a[$k]) { $o[$k] = $a[$k] } }
    $ai += [pscustomobject]$o
  }
  return [ordered]@{
    name = $E['name']; element = $v['element']; stats = $v['stats']; acts = $v['acts']; resists = $v['resists']; debuffResists = $v['debuffResists']
    passives = $v['passives']; entry = $v['entrySkill']; ai = $ai; skills = $skills; reactions = $v['reactions']; turnLossCap = $v['turnLossCap']
  }
}

$out = [ordered]@{}; $n = 0
foreach ($m in $w['missions']) {
  $id = [string]$m['archiveId']; if (-not $keep.ContainsKey($id)) { continue }
  $waves = @(); $i = 0
  foreach ($wave in $m['waves']) {
    $i++
    $opt = if ($wave['pool']) { $wave['pool'][0] } else { $wave }
    $list = @()
    foreach ($en in $opt['enemies']) {
      $E = $enemies[[string]$en['enemy']]; if (-not $E) { continue }
      $v = $E['variants'][[string]$en['variant']]; if (-not $v) { continue }
      $scripted = @($v['ai'] | Where-Object { $_['when'] -ne 'default' }).Count
      if ($en['boss'] -or [double]$v['stats']['hp'] -ge 100000 -or $scripted -ge 3) {
        $x = Variant $E $en['variant']; $x['boss'] = [bool]$en['boss']; $list += [pscustomobject]$x
      }
    }
    if ($list.Count) { $waves += [pscustomobject]@{ wave = $i; enemies = $list } }
  }
  if ($waves.Count) {
    # On garde les deux dernières vagues intéressantes : en général le boss et ce qui le précède.
    $out[$id] = [pscustomobject]@{ waves = @($waves | Select-Object -Last 2); total = @($m['waves']).Count }
    $n++
  }
}
$json = [pscustomobject]$out | ConvertTo-Json -Depth 14 -Compress
[IO.File]::WriteAllText($OutFile, $json, (New-Object System.Text.UTF8Encoding $false))
"missions : $n · taille : " + [Math]::Round($json.Length / 1KB) + " Ko"
