# Reborn Wiki

**Site : https://rebornbfwiki.github.io** · [English below](#english)

Wiki de fan non officiel de **Brave Frontier: Reborn** : fiches des unités, type conseillé, sphères conseillées, team builder avec stats en combat, tier list calculée, défis et modes de jeu, boutique de mérite et conseils de farm. Disponible en français et en anglais.

## Ma collection

Le script [`tools/bfr-collection.user.js`](tools/bfr-collection.user.js) s'installe dans [Tampermonkey](https://www.tampermonkey.net/). Dans le jeu, il ajoute un bouton sur **Unité › Voir les unités** qui copie tes unités, tes sphères et tes objets (lecture seule, rien n'est modifié) ; colle le texte dans la page **Ma collection** du wiki. Tu y verras ce qui te manque, les sphères que tu peux forger et des équipes proposées avec tes unités. Tout reste dans ton navigateur.

## Mettre à jour le site

- `src/wiki.html` : la source unique du site.
- `build/build.ps1` : génère `index.html` (français) et `en/index.html` (anglais, d'après `build/en-*.tsv`).
- `build/challenges.ps1` : recalcule `data/challenges.json` et `data/challenges-en.json` à partir du fichier `world` public du jeu.
- `data/` : fichiers publics du jeu (unités, guide, objets, sphères, bannières) et vignettes.

```powershell
powershell -ExecutionPolicy Bypass -File build\build.ps1
```

---

## English

Unofficial fan wiki for **Brave Frontier: Reborn**: unit pages, recommended type and spheres, a team builder with in-battle stats, a computed tier list, challenges and game modes, the merit shop and farming tips. Available in French and English.

To see your own account, install [`tools/bfr-collection.user.js`](tools/bfr-collection.user.js) in Tampermonkey, open **Unit › View Units** in the game, click the new button (it reads your units, spheres and items without changing anything) and paste the result in **My collection**: you get what you are missing, the spheres you can forge and teams suggested from your units. Everything stays in your browser.

---

Brave Frontier, its characters, art and trademarks belong to their rights holders (Alim, gumi). This project is not affiliated with them or with the Brave Frontier: Reborn team. Game data and thumbnails come from the game's public files.
