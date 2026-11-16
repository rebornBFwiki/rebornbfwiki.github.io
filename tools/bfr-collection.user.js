// ==UserScript==
// @name         Reborn Wiki - account export
// @namespace    reborn-wiki
// @version      2.0
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
  // - unités : la copie que le jeu garde dans ton navigateur (IndexedDB « bfr-player ») ;
  // - sphères et objets : les mêmes lectures que les pages Objets du jeu, avec ta propre session.
  const SUPABASE = 'https://vdvgusidfpcnywclwrkh.supabase.co';
  const KEY = 'sb_publishable_SelxJqdvtb2vuRUVCz8OEA_3j';
  const fr = (navigator.language || '').toLowerCase().startsWith('fr');
  const T = fr
    ? { idle: 'Copier mon compte pour Reborn Wiki', reading: 'Lecture du compte…', none: 'Aucune unité trouvée : ouvre « Unité › Voir les unités » puis réessaie', done: (u, s, i) => `Copié : ${u} unités, ${s} sphères, ${i} objets. Colle-le dans le wiki`, fail: 'Copie impossible : réessaie' }
    : { idle: 'Copy my account for Reborn Wiki', reading: 'Reading your account…', none: 'No unit found: open Unit › View Units and try again', done: (u, s, i) => `Copied: ${u} units, ${s} spheres, ${i} items. Paste it into the wiki`, fail: 'Copy failed: try again' };
  const LABEL = T.idle;

  function readRoster() {
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
      if (i > 0) jar[part.slice(0, i)] = decodeURIComponent(part.slice(i + 1));
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
        const b = raw.slice(7).replace(/-/g, '+').replace(/_/g, '/');
        raw = new TextDecoder().decode(Uint8Array.from(atob(b), (c) => c.charCodeAt(0)));
      }
      const s = JSON.parse(raw);
      return s.access_token || (s.currentSession && s.currentSession.access_token) || null;
    } catch (e) { return null; }
  }

  async function readTable(table, cols) {
    const token = accessToken();
    if (!token) return null;
    try {
      const r = await fetch(`${SUPABASE}/rest/v1/${table}?select=${encodeURIComponent(cols)}`, {
        headers: { apikey: KEY, Authorization: 'Bearer ' + token },
      });
      return r.ok ? await r.json() : null;
    } catch (e) { return null; }
  }

  async function buildExport() {
    const roster = await readRoster();
    const [ownedSpheres, ownedItems] = await Promise.all([
      readTable('owned_spheres', 'id, sphere_id'),
      readTable('owned_items', 'item_id, count'),
    ]);
    const typeOf = (t) => (t && typeof t === 'object' ? t.type : t) || null;
    const units = [];
    if (roster) {
      for (const u of roster.units || []) {
        units.push({ unit: u.unit_id, form: u.form_id, level: u.level, type: typeOf(u.unit_type), slot2: u.second_sphere_slot === true, count: 1, key: u.id });
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
          ? T.done(data.units.length, nS, nI)
          : T.fail;
      }
      setTimeout(() => {
        if (btn) {
          btn.disabled = false;
          btn.textContent = LABEL;
        }
      }, 7000);
    };
    document.body.appendChild(btn);
  }

  setInterval(ensureButton, 1000);
  ensureButton();
})();
