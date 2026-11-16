# Construit le site Reborn Wiki à partir de la source unique src/wiki.html.
#   index.html     : version française
#   en/index.html  : version anglaise (traduction par tables de remplacement, build/en-*.tsv)
# Usage : powershell -ExecutionPolicy Bypass -File build\build.ps1
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding $false
$src = [IO.File]::ReadAllText("$root\src\wiki.html", [Text.Encoding]::UTF8).Replace('__REPO__', 'rebornBFwiki/rebornbfwiki.github.io')

function Wrap($body, $lang, $title, $desc) {
  return "<!doctype html>`n<html lang=`"$lang`">`n<head>`n<meta charset=`"utf-8`">`n<meta name=`"viewport`" content=`"width=device-width, initial-scale=1, viewport-fit=cover`">`n<meta name=`"description`" content=`"$desc`">`n" + $body.Replace("</style>", "</style>`n</head>`n<body>") + "`n</body>`n</html>`n"
}
function ApplyMap($text, $file) {
  if (-not (Test-Path $file)) { return $text }
  foreach ($line in [IO.File]::ReadAllLines($file, [Text.Encoding]::UTF8)) {
    if (-not $line -or $line.StartsWith('#')) { continue }
    $p = $line -split '§§', 2
    if ($p.Count -eq 2) { $text = $text.Replace($p[0], $p[1]) }
  }
  return $text
}

# Français
$fr = $src.Replace('__DATA__', 'data/').Replace('__ASSETS__', 'assets/').Replace('__LANGLINK__', '<a class="lang" href="en/" hreflang="en">English</a>')
[IO.File]::WriteAllText("$root\index.html", (Wrap $fr 'fr' 'Reborn Wiki' 'Wiki de fan non officiel de Brave Frontier: Reborn : unités, types, sphères, team builder, tier list et défis.'), $utf8)

# Anglais : d'abord les phrases longues, puis les mots isolés.
$en = $src.Replace('__DATA__', '../data/').Replace('__ASSETS__', '../assets/').Replace('__LANGLINK__', '<a class="lang" href="../" hreflang="fr">Français</a>')
$en = ApplyMap $en "$PSScriptRoot\en-1-phrases.tsv"
$en = ApplyMap $en "$PSScriptRoot\en-2-words.tsv"
$en = $en.Replace('__REPO__', 'rebornBFwiki/rebornbfwiki.github.io').Replace('"banners", "challenges"]', '"banners", "challenges-en"]').Replace('"fr-FR"', '"en-US"')
New-Item -ItemType Directory -Force "$root\en" | Out-Null
[IO.File]::WriteAllText("$root\en\index.html", (Wrap $en 'en' 'Reborn Wiki' 'Unofficial fan wiki for Brave Frontier: Reborn: units, types, spheres, team builder, tier list and challenges.'), $utf8)
"OK"
