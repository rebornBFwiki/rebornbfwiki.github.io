// ==UserScript==
// @name         Reborn Wiki - account export
// @namespace    reborn-wiki
// @version      2.3
// @description  Copies your Brave Frontier: Reborn units, spheres and items (read-only) to paste into Reborn Wiki. / Copie tes unités, sphères et objets (lecture seule) pour Reborn Wiki.
// @match        https://rebornbf.com/*
// @grant        none
// @run-at       document-idle
// ==/UserScript==

(function () {
  'use strict';
  if (window.__bfrExport) return;
  window.__bfrExport = true;

  // Lecture seule. Le script ne modifie rien sur ton compte :
  // - unités : la liste à jour du serveur (la même lecture « get_roster » que le jeu au chargement),
  //   ou, si elle échoue, la copie que le jeu garde dans ton navigateur (IndexedDB « bfr-player », parfois en retard) ;
  // - sphères et objets : les mêmes lectures que les pages Objets du jeu, avec ta propre session.
  const SUPABASE = 'https://vdvgusidfpcnywclwrkh.supabase.co';
  const KEY = 'sb_publishable_SelxJqdvtb2vuRUVCz8OEA_3jMEv7rC';
  const fr = (navigator.language || '').toLowerCase().startsWith('fr');
  const T = fr
    ? { idle: 'Copier mon compte pour Reborn Wiki', reading: 'Lecture du compte…', none: 'Aucune unité trouvée : ouvre « Unité › Voir les unités » puis réessaie', done: (u, s, i) => `Copié : ${u} unités, ${s} sphères, ${i} objets. Colle-le dans le wiki`, fail: 'Copie impossible : réessaie', partial: 'à vérifier : ' }
    : { idle: 'Copy my account for Reborn Wiki', reading: 'Reading your account…', none: 'No unit found: open Unit › View Units and try again', done: (u, s, i) => `Copied: ${u} units, ${s} spheres, ${i} items. Paste it into the wiki`, fail: 'Copy failed: try again', partial: 'to check: ' };
  const LABEL = T.idle;

  function readCachedRoster() {
    return new Promise((resolve) => {
      let req;
      try { req = indexedDB.open('bfr-player'); } catch (e) { return resolve(null); }
      req.onerror = () => resolve(null);
      req.onsuccess = () => {
        const db = req.result;
        if (!db.objectStoreNames.contains('roster')) { db.close(); return resolve(null); }
        const get = db.transaction('roster', 'readonly').objectStore('roster').get('roster');
        get.onsuccess = () => { db.close(); resolve(get.result && get.result.roster ? get.result.roster : null); };
        get.onerror = () => { db.close(); resolve(null); };
      };
    });
  }

  // Jeton de session : cookie « sb-…-auth-token », parfois découpé en .0, .1… et préfixé « base64- ».
  function accessToken() {
    const jar = {};
    for (const part of document.cookie.split('; ')) {
      const i = part.indexOf('=');
      if (i <= 0) continue;
      let v = part.slice(i + 1);
      try { v = decodeURIComponent(v); } catch (e) { /* valeur laissée telle quelle */ }
      jar[part.slice(0, i)] = v;
    }
    const name = Object.keys(jar).map((k) => k.replace(/\.\d+$/, '')).find((k) => /^sb-.*-auth-token$/.test(k));
    let raw = name ? jar[name] : null;
    if (name && raw == null) {
      raw = '';
      for (let n = 0; jar[name + '.' + n] != null; n++) raw += jar[name + '.' + n];
    }
    if (!raw) {
      const k = Object.keys(localStorage).find((x) => /^sb-.*-auth-token$/.test(x));
      raw = k ? localStorage.getItem(k) : null;
    }
    if (!raw) return null;
    try {
      if (raw.startsWith('base64-')) {
        let b = raw.slice(7).replace(/-/g, '+').replace(/_/g, '/');
        while (b.length % 4) b += '=';
        raw = new TextDecoder().decode(Uint8Array.from(atob(b), (c) => c.charCodeAt(0)));
      }
      const s = JSON.parse(raw);
      return s.access_token || (s.currentSession && s.currentSession.access_token) || null;
    } catch (e) { return null; }
  }

  const errors = [];
  async function readTable(table, cols) {
    const token = accessToken();
    if (!token) { errors.push('session'); return null; }
    try {
      const r = await fetch(`${SUPABASE}/rest/v1/${table}?select=${encodeURIComponent(cols)}`, {
        headers: { apikey: KEY, Authorization: 'Bearer ' + token },
      });
      if (!r.ok) { errors.push(table + ' ' + r.status); return null; }
      return await r.json();
    } catch (e) { errors.push(table + ' réseau'); return null; }
  }

  // Liste complète des unités, lue sur le serveur comme le fait le jeu (lecture seule).
  async function readServerRoster() {
    const token = accessToken();
    if (!token) return null;
    try {
      const r = await fetch(`${SUPABASE}/rest/v1/rpc/get_roster`, {
        method: 'POST',
        headers: { apikey: KEY, Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' },
        body: '{}',
      });
      if (!r.ok) { errors.push('get_roster ' + r.status); return null; }
      const j = await r.json();
      const ro = j && j.roster ? j.roster : j;
      return ro && Array.isArray(ro.units) && Array.isArray(ro.stacks) ? ro : null;
    } catch (e) { errors.push('get_roster réseau'); return null; }
  }

  async function buildExport() {
    errors.length = 0;
    const server = await readServerRoster();
    const roster = server || (await readCachedRoster());
    if (!server) errors.push(fr ? 'unités lues dans le cache' : 'units read from cache');
    const [ownedSpheres, ownedItems] = await Promise.all([
      readTable('owned_spheres', 'id, sphere_id'),
      readTable('owned_items', 'item_id, count'),
    ]);
    const typeOf = (t) => (t && typeof t === 'object' ? t.type : t) || null;
    const units = [];
    if (roster) {
      for (const u of roster.units || []) {
        // Niveaux de BB/SBB (1 à 10, il faut 10 pour les Enhancements) et lutins (bonus de stats, plafonnés par forme).
        const imps = u.imps && typeof u.imps === 'object' ? { hp: Number(u.imps.hp) || 0, atk: Number(u.imps.atk) || 0, def: Number(u.imps.def) || 0, rec: Number(u.imps.rec) || 0 } : null;
        units.push({ unit: u.unit_id, form: u.form_id, level: u.level, type: typeOf(u.unit_type), slot2: u.second_sphere_slot === true, count: 1, key: u.id || u.owned_unit_id, bb: Number(u.bb_level) || 1, sbb: Number(u.sbb_level) || 1, imps });
      }
      for (const s of roster.stacks || []) {
        units.push({ unit: s.unit_id, form: s.form_id, level: null, type: typeOf(s.unit_type), count: Number(s.count) || 1 });
      }
    }
    // Sphères : on compte les exemplaires et on note celles déjà équipées (et sur qui).
    const equippedOn = new Map();
    for (const e of (roster && roster.spheres) || []) equippedOn.set(e.owned_sphere_id, e.owned_unit_id);
    const spheres = {};
    for (const s of ownedSpheres || []) {
      const o = (spheres[s.sphere_id] = spheres[s.sphere_id] || { count: 0, on: [] });
      o.count++;
      if (equippedOn.has(s.id)) o.on.push(equippedOn.get(s.id));
    }
    const items = {};
    for (const i of ownedItems || []) if (Number(i.count) > 0) items[i.item_id] = Number(i.count);
    return {
      date: new Date().toISOString(),
      units,
      spheres,
      items,
      squads: ((roster && roster.squads) || []).map((q) => ({ slot: q.slot, units: q.unit_ids, leader: q.leader_index })),
      missing: [!roster && 'units', !ownedSpheres && 'spheres', !ownedItems && 'items'].filter(Boolean),
    };
  }

  async function copy(text) {
    try {
      await navigator.clipboard.writeText(text);
      return true;
    } catch (e) {
      const ta = document.createElement('textarea');
      ta.value = text;
      ta.style.cssText = 'position:fixed;left:0;top:0;width:1px;height:1px;opacity:0';
      document.body.appendChild(ta);
      ta.select();
      const ok = document.execCommand('copy');
      ta.remove();
      return ok;
    }
  }

  let btn;
  function ensureButton() {
    // Le bouton reste discret : seulement sur l'accueil, les unités et les objets, jamais en combat.
    const show = /^\/(home|units|items|town)(\/|$)/.test(location.pathname);
    if (!show) {
      if (btn) btn.remove();
      btn = null;
      return;
    }
    if (btn && btn.isConnected) return;
    btn = document.createElement('button');
    btn.type = 'button';
    btn.textContent = LABEL;
    btn.style.cssText =
      'position:fixed;right:8px;bottom:8px;z-index:2147483647;padding:10px 14px;border-radius:10px;' +
      'background:#d6b25b;color:#1a1406;font:600 14px system-ui,sans-serif;border:0;cursor:pointer';
    btn.onclick = async () => {
      btn.disabled = true;
      btn.textContent = T.reading;
      const data = await buildExport();
      if (!data.units.length) {
        btn.textContent = T.none;
      } else {
        const ok = await copy('BFRCODEX2:' + JSON.stringify(data));
        const nS = Object.values(data.spheres).reduce((a, s) => a + s.count, 0);
        const nI = Object.keys(data.items).length;
        btn.textContent = ok
          ? T.done(data.units.length, nS, nI) + (errors.length ? ' (' + T.partial + errors.join(', ') + ')' : '')
          : T.fail;
      }
      setTimeout(() => {
        if (btn) {
          btn.disabled = false;
          btn.textContent = LABEL;
        }
      }, errors.length ? 15000 : 7000);
    };
    document.body.appendChild(btn);
  }

  setInterval(ensureButton, 1000);
  ensureButton();
})();
