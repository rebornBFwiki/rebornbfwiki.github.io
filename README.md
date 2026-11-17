# Reborn Wiki

**Site : https://rebornbfwiki.github.io** · [English below](#english)

Wiki de fan non officiel de **Brave Frontier: Reborn** : fiches des unités, type conseillé, sphères conseillées, team builder avec stats en combat, tier list calculée, défis et modes de jeu, boutique de mérite et conseils de farm. Disponible en français et en anglais.

## Ma collection

Le script [`tools/bfr-collection.user.js`](tools/bfr-collection.user.js) s'installe dans [Tampermonkey](https://www.tampermonkey.net/). Dans le jeu, il ajoute un bouton sur **Unité › Voir les unités** qui copie tes unités, tes sphères et tes objets (lecture seule, rien n'est modifié) ; colle le texte dans la page **Ma collection** du wiki. Tu y verras ce qui te manque, les sphères que tu peux forger et des équipes proposées avec tes unités. Tout reste dans ton navigateur.

## Mettre à jour le site

- `src/wiki.html` : la source unique du site.
- `build/api.ps1` : télécharge la [Data API officielle](https://rebornbf.com/product/data) (unités, sphères, objets, bannières, drops, recettes de forge, tier list votée et utilisation des unités) et les packs d'images officiels (vignettes, icônes, sprites de combat d'où viennent les poses des unités). Les fichiers sont gardés en cache et ne sont retéléchargés que si leur nom change.
- `build/build.ps1` : génère `index.html` (français) et `en/index.html` (anglais, d'après `build/en-*.tsv`).
- `build/challenges.ps1` : recalcule `data/challenges.json` et `data/challenges-en.json` à partir du fichier `world` public du jeu.
- `build/fights.ps1` : extrait le comportement des boss des défis (IA, compétences, passifs) dans `data/fights.json`, d'où le wiki tire le déroulé et le plan de bataille de chaque combat.
- `data/` : données du jeu (Data API, plus le guide, les noms français et le monde des quêtes, qui ne sont pas encore dans l'API). Les images de `assets/` viennent uniquement des packs officiels.

```powershell
powershell -ExecutionPolicy Bypass -File build\api.ps1
powershell -ExecutionPolicy Bypass -File build\build.ps1
```

---

## English

Unofficial fan wiki for **Brave Frontier: Reborn**: unit pages, recommended type and spheres, a team builder with in-battle stats, a computed tier list, challenges and game modes, the merit shop and farming tips. Available in French and English.

To see your own account, install [`tools/bfr-collection.user.js`](tools/bfr-collection.user.js) in Tampermonkey, open **Unit › View Units** in the game, click the new button (it reads your units, spheres and items without changing anything) and paste the result in **My collection**: you get what you are missing, the spheres you can forge and teams suggested from your units. Everything stays in your browser.

---

Data and images: [Brave Frontier: Reborn](https://rebornbf.com) (rebornbf.com), through its official Data API and art packs. Non-commercial fan project, not affiliated with Alim, gumi or the Brave Frontier: Reborn team.

**Brave Frontier © Alim/gumi**
