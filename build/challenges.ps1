param([string]$World, [string]$FrNames = "", [string]$OutFile)
# Construit le fichier des défis (data/challenges.json en français, data/challenges-en.json en anglais) : un résumé de chaque quête pour la section Défis du Codex.
Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$ser.MaxJsonLength = 2147483647
$w = $ser.DeserializeObject([IO.File]::ReadAllText($World))

$fr = @{}
if ($FrNames) { foreach ($line in [IO.File]::ReadAllLines($FrNames, [Text.Encoding]::UTF8)) {
  $p = $line.Split("`t", 2); if ($p.Count -eq 2) { $fr[$p[0]] = $p[1] -replace "'$", '' }
} }
$enemies = @{}; foreach ($e in $w['enemies']) { $enemies[[string]$e['archiveId']] = $e }
$dungeons = @{}; foreach ($d in $w['dungeons']) { $dungeons[[string]$d['archiveId']] = $d }
$areas = @{}; foreach ($a in $w['areas']) { $areas[[string]$a['archiveId']] = $a }

function NameOf($kind, $id, $fallback) { $k = "$kind.$id"; if ($fr.ContainsKey($k)) { return $fr[$k] } return $fallback }

$out = New-Object System.Collections.ArrayList
foreach ($m in $w['missions']) {
  $d = $dungeons[[string]$m['dungeon']]; $a = if ($d) { $areas[[string]$d['area']] } else { $null }
  $bosses = @{}; $els = @{}; $ail = @{}; $mech = @{}; $maxAtk = 0; $sumHp = 0; $immune = @{}
  foreach ($wave in $m['waves']) {
    $opts = if ($wave['pool']) { $wave['pool'] } else { @($wave) }
    $waveHp = 0
    foreach ($o in $opts) {
      $optHp = 0
      foreach ($en in $o['enemies']) {
        $E = $enemies[[string]$en['enemy']]; if (-not $E) { continue }
        $v = $E['variants'][[string]$en['variant']]; if (-not $v) { $v = @($E['variants'].Values)[0] }
        $hp = [double]$v['stats']['hp']; $atk = [double]$v['stats']['atk']
        $optHp += $hp
        if ($atk -gt $maxAtk) { $maxAtk = $atk }
        if ($v['element']) { $els[$v['element']] = 1 }
        foreach ($sk in $v['skills']) {
          foreach ($x in $sk['effects']) {
            $id = [string]$x['id']
            if ($id -like 'ailment.inflict.*') { $ail[$id.Split('.')[2]] = 1 }
            elseif ($id -eq 'bb.drain') { $mech['bbDrain'] = 1 }
            elseif ($id -eq 'buff_removal') { $mech['buffRemoval'] = 1 }
            elseif ($id -like 'heal.*' -and $x['target'] -eq 'self') { $mech['selfHeal'] = 1 }
            elseif ($id -like 'debuff.*') { $mech['statDown'] = 1 }
            if ($x['hpDamage']) { $mech['hpPercent'] = 1 }
            if ($id -like 'attack.*' -and [double]$x['value'] -ge 3) { $mech['nuke'] = 1 }
          }
        }
        if ($v['resists']) { foreach ($r in $v['resists'].Keys) { $immune[$r] = 1 } }
        if ($en['boss'] -or $hp -ge 100000) {
          $key = [string]$E['name']
          if (-not $bosses.ContainsKey($key) -or $bosses[$key].hp -lt $hp) {
            $bosses[$key] = [ordered]@{ name = $key; element = $v['element']; hp = $hp; atk = $atk; def = [double]$v['stats']['def'] }
          }
        }
      }
      if ($optHp -gt $waveHp) { $waveHp = $optHp }
    }
    $sumHp += $waveHp
  }
  $bossList = @($bosses.Values | Sort-Object { -$_.hp } | Select-Object -First 4)
  $topHp = if ($bossList.Count) { $bossList[0].hp } else { 0 }
  # Note de difficulté : PV totaux, attaque maximale et mécaniques dangereuses.
  $score = [Math]::Log10([Math]::Max(10, $sumHp)) * 10 + [Math]::Log10([Math]::Max(10, $maxAtk)) * 6 + $ail.Count * 1.5 + $mech.Count * 2
  if ($m['continues'] -eq $false) { $score += 6 }
  [void]$out.Add([ordered]@{
    id = $m['archiveId']; name = (NameOf 'mission' $m['archiveId'] $m['name'])
    dungeon = (NameOf 'dungeon' $m['dungeon'] ($d['name'])); area = $(if ($a) { NameOf 'area' $a['archiveId'] $a['name'] } else { '' })
    areaType = $(if ($a) { $a['type'] } else { '' }); dungeonId = $m['dungeon']; areaId = $(if ($d) { $d['area'] } else { 0 }); battles = $m['battles']; energy = $m['energy']
    continues = $m['continues']; itemSlots = $m['itemSlots']; totalHp = $sumHp; maxAtk = $maxAtk; topHp = $topHp
    bosses = @($bossList | ForEach-Object { [pscustomobject]$_ }); elements = [string[]]@($els.Keys); ailments = [string[]]@($ail.Keys); mechanics = [string[]]@($mech.Keys); immune = [string[]]@($immune.Keys)
    score = [Math]::Round($score, 1)
  })
}
$json = @($out | ForEach-Object { [pscustomobject]$_ }) | ConvertTo-Json -Depth 6 -Compress
[IO.File]::WriteAllText($OutFile, $json, (New-Object System.Text.UTF8Encoding $false))
"missions: " + $out.Count
"top 12:"
$out | Sort-Object { -$_.score } | Select-Object -First 12 | ForEach-Object { "{0} {1} [{2}] score={3} hp={4} atk={5} ail={6} mech={7}" -f $_.id, $_.name, $_.dungeon, $_.score, $_.totalHp, $_.maxAtk, ($_.ailments -join ','), ($_.mechanics -join ',') }
"resist keys sample: " + (($out | ForEach-Object { $_.immune } | Group-Object | ForEach-Object Name) -join ',')