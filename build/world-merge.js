// Usage : node build/world-merge.js <dossier des fichiers de contenu du jeu> → <dossier>/world.merged.json, à passer à challenges.ps1, fights.ps1 et sources.ps1.
// Recompose l'ancien fichier « world » à partir du nouveau découpage du jeu (index + un fichier par zone).
// Les drops des vagues sont des numéros dans la table de la zone : on les remplace par leur contenu.
const fs = require('fs');
const dir = process.argv[2] || __dirname; // dossier où sont world-index.*.json et world-area-*.json
const files = fs.readdirSync(dir);
const read = (n) => JSON.parse(fs.readFileSync(dir + '/' + n, 'utf8'));
const idx = read(files.find((f) => f.startsWith('world-index')));
const missions = [], enemies = new Map();
for (const f of files.filter((f) => f.startsWith('world-area-'))) {
  const z = read(f);
  const table = z.dropTables || [];
  const fix = (e) => (typeof e.drops === 'number' ? { ...e, drops: table[e.drops] || null } : e);
  for (const m of z.missions || []) {
    for (const w of m.waves || []) {
      if (w.enemies) w.enemies = w.enemies.map(fix);
      if (w.pool) w.pool = w.pool.map((o) => (Array.isArray(o) ? o.map(fix) : { ...o, enemies: (o.enemies || []).map(fix) }));
    }
    missions.push(m);
  }
  // Un même ennemi apparaît dans plusieurs zones, chacune avec seulement ses variantes : on les fusionne.
  for (const e of z.enemies || []) {
    const k = String(e.archiveId), prev = enemies.get(k);
    enemies.set(k, prev ? { ...prev, variants: { ...prev.variants, ...e.variants } } : e);
  }
}
const world = { releases: idx.releases, lands: idx.lands, areas: idx.areas, dungeons: idx.dungeons, missions, enemies: [...enemies.values()] };
fs.writeFileSync(dir + '/world.merged.json', JSON.stringify(world));
console.log('quêtes', missions.length, 'ennemis', enemies.size, 'avec première victoire', missions.filter((m) => m.firstClear).length);
