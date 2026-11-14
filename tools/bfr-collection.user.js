// ==UserScript==
// @name         Reborn Wiki - collection export
// @namespace    reborn-wiki
// @version      1.0
// @description  Adds a button to the Brave Frontier: Reborn unit list to copy your collection into Reborn Wiki. / Ajoute un bouton sur la liste d'unités pour copier ta collection dans Reborn Wiki.
// @match        https://rebornbf.com/*
// @grant        none
// @run-at       document-idle
// ==/UserScript==

(function () {
  'use strict';
  if (window.__rebornWikiExport) return;
  window.__rebornWikiExport = true;

  const fr = (navigator.language || '').toLowerCase().startsWith('fr');
  const T = fr
    ? { idle: 'Copier ma collection pour le wiki', reading: 'Lecture de la liste…', none: 'Aucune unité trouvée : ouvre « Toutes les unités »', done: (n) => `${n} lignes copiées : colle-les dans le wiki`, fail: 'Copie impossible : réessaie' }
    : { idle: 'Copy my collection for the wiki', reading: 'Reading the list…', none: 'No unit found: open "All Units"', done: (n) => `${n} lines copied: paste them into the wiki`, fail: 'Copy failed: try again' };

  // The list only renders visible rows, so it is scrolled to read every unit.
  // Each unit has a label such as "Water God, 5★, Lv.MAX, 16 copies".
  async function readCollection() {
    const links = () => [...document.querySelectorAll('a[href^="/units/"]')].filter((a) => a.getAttribute('aria-label'));
    const seen = new Map();
    const grab = () => links().forEach((a) => seen.set(a.getAttribute('href'), a.getAttribute('aria-label')));
    grab();
    let box = links()[0];
    while (box && !(box.scrollHeight > box.clientHeight + 20 && /(auto|scroll)/.test(getComputedStyle(box).overflowY))) {
      box = box.parentElement;
    }
    if (box) {
      const step = Math.max(100, box.clientHeight * 0.7);
      for (let y = 0; y <= box.scrollHeight; y += step) {
        box.scrollTop = y;
        await new Promise((r) => setTimeout(r, 120));
        grab();
      }
      box.scrollTop = 0;
    }
    return [...seen.values()];
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
    if (location.pathname !== '/units/list') {
      if (btn) btn.remove();
      btn = null;
      return;
    }
    if (btn && btn.isConnected) return;
    btn = document.createElement('button');
    btn.type = 'button';
    btn.textContent = T.idle;
    btn.style.cssText =
      'position:fixed;right:8px;bottom:8px;z-index:2147483647;padding:10px 14px;border-radius:10px;' +
      'background:#d6b25b;color:#1a1406;font:600 14px system-ui,sans-serif;border:0;cursor:pointer';
    btn.onclick = async () => {
      btn.disabled = true;
      btn.textContent = T.reading;
      const labels = await readCollection();
      if (!labels.length) {
        btn.textContent = T.none;
      } else {
        const ok = await copy('BFRCODEX1:' + JSON.stringify({ date: new Date().toISOString(), labels }));
        btn.textContent = ok ? T.done(labels.length) : T.fail;
      }
      setTimeout(() => {
        if (btn) {
          btn.disabled = false;
          btn.textContent = T.idle;
        }
      }, 6000);
    };
    document.body.appendChild(btn);
  }

  setInterval(ensureButton, 1000);
  ensureButton();
})();
