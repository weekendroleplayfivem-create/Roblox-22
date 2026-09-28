/* ============================================================
   nijmegen-cinematics  |  NUI
   ============================================================ */

const IS_FIVEM = typeof GetParentResourceName === 'function';
const RESOURCE = IS_FIVEM ? GetParentResourceName() : 'nijmegen-cinematics';
const DRAFT_KEY = 'nijmegen-cinematics:draft';

const $ = (s, root = document) => root.querySelector(s);
const $$ = (s, root = document) => [...root.querySelectorAll(s)];
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

/* ------------------------------------------------------------
   Vertalingen
   ------------------------------------------------------------ */

const LANG = {
    nl: {
        cameraMode: 'Cameramodus', kMove: 'bewegen', kUpDown: 'omlaag / omhoog', kLook: 'rondkijken', kZoom: 'zoom (FOV)',
        kSpeed: 'snel / langzaam', kBaseSpeed: 'basissnelheid', kRoll: 'kantelen / recht', kAdd: 'keyframe toevoegen',
        kRemove: 'laatste verwijderen', kPlay: 'afspelen', kMenu: 'menu gebruiken',
        lockText: 'Je bestuurt de camera. Druk op TAB om het menu te gebruiken.', scenePh: 'Naam van de scène',
        tabPoints: 'Keyframes', tabEffects: 'Effecten', tabScenes: 'Scènes', addPoint: 'Keyframe', play: 'Afspelen', playFrom: 'Vanaf #',
        totalTime: 'Totale duur', emptyPoints: 'Nog geen keyframes. Vlieg naar een plek en druk op Spatie (of + Keyframe).',
        gLook: 'Beeld', bars: 'Filmbalken', filter: 'Filter', strength: 'Sterkte filter', gCamera: 'Camera', shake: 'Beweging',
        shakeAmp: 'Sterkte beweging', smooth: 'Vloeiend pad (spline)', loop: 'Herhalen (loop)', fade: 'In- en uitfaden',
        gWorld: 'Wereld (alleen voor jou)', time: 'Tijd', weather: 'Weer', gOther: 'Overig', hideHud: 'HUD verbergen',
        hidePlayer: 'Eigen personage verbergen', previewBars: 'Balken tonen tijdens bewerken', save: 'Opslaan', new: 'Nieuw',
        broadcast: 'Voor iedereen', export: 'Gebruiken in een ander script', copy: 'Kopiëren', stop: 'stoppen',
        cancel: 'Annuleren', confirm: 'Ja', dur: 'Duur', hold: 'Wacht', fov: 'FOV', ease: 'Curve',
        easeLinear: 'Lineair', easeIn: 'Optrekken', easeOut: 'Afremmen', easeInOut: 'Soepel',
        goto: 'Camera hierheen', update: 'Huidige camera opslaan in dit punt', up: 'Omhoog', down: 'Omlaag', remove: 'Verwijderen',
        load: 'Laden', server: 'Server', points: 'punten', noScenes: 'Nog geen opgeslagen scènes',
        needName: 'Geef de scène eerst een naam', needPoints: 'Je hebt minimaal 2 keyframes nodig', copied: 'Gekopieerd',
        newTitle: 'Nieuwe scène?', newText: 'Niet opgeslagen keyframes gaan verloren.', delTitle: 'Scène verwijderen?',
        bcTitle: 'Voor iedereen afspelen?', bcText: 'Alle spelers op de server zien deze cinematic.', pointUpdated: 'Punt bijgewerkt',
        selectFirst: 'Selecteer eerst een keyframe', exportServer: '-- Server: opgeslagen scène afspelen voor een speler',
        exportClient: '-- Client: direct afspelen zonder opslaan', closeTitle: 'Editor sluiten?',
    },
    en: {
        cameraMode: 'Camera mode', kMove: 'move', kUpDown: 'down / up', kLook: 'look around', kZoom: 'zoom (FOV)',
        kSpeed: 'fast / slow', kBaseSpeed: 'base speed', kRoll: 'roll / reset', kAdd: 'add keyframe',
        kRemove: 'remove last', kPlay: 'play', kMenu: 'use the menu',
        lockText: 'You are controlling the camera. Press TAB to use the menu.', scenePh: 'Scene name',
        tabPoints: 'Keyframes', tabEffects: 'Effects', tabScenes: 'Scenes', addPoint: 'Keyframe', play: 'Play', playFrom: 'From #',
        totalTime: 'Total duration', emptyPoints: 'No keyframes yet. Fly somewhere and press Space (or + Keyframe).',
        gLook: 'Look', bars: 'Letterbox', filter: 'Filter', strength: 'Filter strength', gCamera: 'Camera', shake: 'Shake',
        shakeAmp: 'Shake strength', smooth: 'Smooth path (spline)', loop: 'Loop', fade: 'Fade in and out',
        gWorld: 'World (only for you)', time: 'Time', weather: 'Weather', gOther: 'Other', hideHud: 'Hide HUD',
        hidePlayer: 'Hide own character', previewBars: 'Show bars while editing', save: 'Save', new: 'New',
        broadcast: 'For everyone', export: 'Use in another script', copy: 'Copy', stop: 'stop',
        cancel: 'Cancel', confirm: 'Yes', dur: 'Time', hold: 'Hold', fov: 'FOV', ease: 'Curve',
        easeLinear: 'Linear', easeIn: 'Ease in', easeOut: 'Ease out', easeInOut: 'Smooth',
        goto: 'Move camera here', update: 'Store current camera in this point', up: 'Up', down: 'Down', remove: 'Remove',
        load: 'Load', server: 'Server', points: 'points', noScenes: 'No saved scenes yet',
        needName: 'Give the scene a name first', needPoints: 'You need at least 2 keyframes', copied: 'Copied',
        newTitle: 'New scene?', newText: 'Unsaved keyframes will be lost.', delTitle: 'Delete scene?',
        bcTitle: 'Play for everyone?', bcText: 'All players on the server will see this cinematic.', pointUpdated: 'Point updated',
        selectFirst: 'Select a keyframe first', exportServer: '-- Server: play a saved scene for a player',
        exportClient: '-- Client: play directly without saving', closeTitle: 'Close editor?',
    },
};

let T = LANG.nl;

function applyLang(code) {
    T = LANG[code] || LANG.nl;
    document.documentElement.lang = code === 'en' ? 'en' : 'nl';
    $$('[data-i18n]').forEach((el) => { if (T[el.dataset.i18n]) el.textContent = T[el.dataset.i18n]; });
    $$('[data-i18n-ph]').forEach((el) => { if (T[el.dataset.i18nPh]) el.placeholder = T[el.dataset.i18nPh]; });
}

/* ------------------------------------------------------------
   State
   ------------------------------------------------------------ */

const DEFAULT_SETTINGS = {
    bars: 0.12, filter: '', strength: 1, shake: '', shakeAmp: 0, smooth: true, loop: false,
    fade: true, hideHud: true, hidePlayer: false, time: -1, weather: '', previewBars: true,
};

const state = {
    open: false,
    mode: 'camera',
    scene: { name: '', points: [], settings: { ...DEFAULT_SETTINGS } },
    selected: null,
    defaults: { dur: 4, ease: 'inout' },
    broadcast: false,
    scenes: [],
    playing: false,
};

/* ------------------------------------------------------------
   Communicatie
   ------------------------------------------------------------ */

async function post(name, data = {}) {
    if (!IS_FIVEM) return preview.handle(name, data);
    try {
        const r = await fetch(`https://${RESOURCE}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data),
        });
        return await r.json();
    } catch (e) {
        return null;
    }
}

async function serverCall(name, data) {
    const res = (await post('call', { name, data })) || {};
    if (res.msg) toast(res.msg, res.ok ? 'success' : 'error');
    return res;
}

function toast(msg, kind = 'info', duration = 2800) {
    const el = document.createElement('div');
    el.className = `toast ${kind}`;
    el.textContent = msg;
    $('#toasts').appendChild(el);
    setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 260); }, duration);
}

let modalResolve = null;
function confirmBox(title, text) {
    $('#modal-title').textContent = title;
    $('#modal-text').textContent = text || '';
    $('#modal').classList.remove('hidden');
    return new Promise((r) => { modalResolve = r; });
}
function closeModal(v) {
    $('#modal').classList.add('hidden');
    if (modalResolve) modalResolve(v);
    modalResolve = null;
}
$('#modal-yes').addEventListener('click', () => closeModal(true));
$('#modal-no').addEventListener('click', () => closeModal(false));

/* ------------------------------------------------------------
   Concept bewaren (lokaal, per speler)
   ------------------------------------------------------------ */

function saveDraft() {
    try { localStorage.setItem(DRAFT_KEY, JSON.stringify(state.scene)); } catch (e) { /* geen opslag */ }
}
function loadDraft() {
    try {
        const d = JSON.parse(localStorage.getItem(DRAFT_KEY) || 'null');
        if (d && Array.isArray(d.points)) {
            state.scene = { name: d.name || '', points: d.points, settings: { ...DEFAULT_SETTINGS, ...(d.settings || {}) } };
        }
    } catch (e) { /* negeren */ }
}

/* ------------------------------------------------------------
   Modus (camera / menu)
   ------------------------------------------------------------ */

function setMode(m) {
    state.mode = m;
    document.body.classList.toggle('camera', m === 'camera');
    $('#mode-badge').textContent = m === 'camera' ? 'CAMERA' : 'MENU';
    $('#hint').classList.toggle('hidden', !(state.open && m === 'camera' && !state.playing));
    if (m === 'camera' && document.activeElement) document.activeElement.blur();
}

document.addEventListener('keydown', (e) => {
    if (!state.open || state.mode !== 'mouse') return;
    if (!$('#modal').classList.contains('hidden')) {
        if (e.key === 'Escape') closeModal(false);
        return;
    }
    if (e.key === 'Tab' || e.key === 'Escape') {
        e.preventDefault();
        setMode('camera');
        post('mode', { mode: 'camera' });
    }
});

/* ------------------------------------------------------------
   Tabs
   ------------------------------------------------------------ */

$$('.tab-btn').forEach((b) => b.addEventListener('click', () => {
    $$('.tab-btn').forEach((x) => x.classList.toggle('active', x === b));
    $$('.tab').forEach((t) => t.classList.toggle('active', t.dataset.tab === b.dataset.tab));
    if (b.dataset.tab === 'scenes') refreshScenes();
}));

/* ------------------------------------------------------------
   Keyframes
   ------------------------------------------------------------ */

const ICON = {
    eye: '<svg viewBox="0 0 24 24"><path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/></svg>',
    cam: '<svg viewBox="0 0 24 24"><path d="M3 7h13v10H3zM16 10l5-3v10l-5-3"/></svg>',
    up: '<svg viewBox="0 0 24 24"><path d="M12 19V5M5 12l7-7 7 7"/></svg>',
    down: '<svg viewBox="0 0 24 24"><path d="M12 5v14M5 12l7 7 7-7"/></svg>',
    del: '<svg viewBox="0 0 24 24"><path d="M4 7h16M10 11v6M14 11v6M5 7l1 13h12l1-13M9 7V4h6v3"/></svg>',
};

function totalTime() {
    const pts = state.scene.points;
    if (pts.length < 2) return 0;
    let t = 0;
    const segs = state.scene.settings.loop ? pts.length : pts.length - 1;
    for (let i = 0; i < segs; i++) t += (+pts[i].hold || 0) + (+pts[i].dur || 0);
    if (!state.scene.settings.loop) t += +pts[pts.length - 1].hold || 0;
    return t;
}

function renderPoints() {
    const pts = state.scene.points;
    $('#point-count').textContent = pts.length;
    $('#points-empty').classList.toggle('off', pts.length > 0);
    $('#total-time').textContent = `${totalTime().toFixed(1)} s`;
    $('#btn-play-from').querySelector('span').textContent = state.selected !== null ? `${T.playFrom.replace('#', '')}#${state.selected + 1}` : T.playFrom;

    $('#points').innerHTML = pts.map((p, i) => `
        <div class="point${i === state.selected ? ' sel' : ''}${i === pts.length - 1 && !state.scene.settings.loop ? ' last' : ''}" data-i="${i}">
            <div class="point-head" data-act="select">
                <span class="point-num">${i + 1}</span>
                <span class="point-pos">${p.x.toFixed(1)}, ${p.y.toFixed(1)}, ${p.z.toFixed(1)}</span>
                <div class="point-actions">
                    <button class="icon-btn accent" data-act="goto" title="${T.goto}">${ICON.eye}</button>
                    <button class="icon-btn accent" data-act="update" title="${T.update}">${ICON.cam}</button>
                    <button class="icon-btn" data-act="up" title="${T.up}" ${i === 0 ? 'disabled' : ''}>${ICON.up}</button>
                    <button class="icon-btn" data-act="down" title="${T.down}" ${i === pts.length - 1 ? 'disabled' : ''}>${ICON.down}</button>
                    <button class="icon-btn danger" data-act="remove" title="${T.remove}">${ICON.del}</button>
                </div>
            </div>
            <div class="point-fields">
                <label class="dur-field">${T.dur} (s)<input type="number" step="0.1" min="0.1" data-f="dur" value="${p.dur}"></label>
                <label>${T.hold} (s)<input type="number" step="0.1" min="0" data-f="hold" value="${p.hold || 0}"></label>
                <label>${T.fov}<input type="number" step="1" min="5" max="130" data-f="fov" value="${Math.round(p.fov)}"></label>
                <label>${T.ease}<select data-f="ease">
                    ${[['inout', T.easeInOut], ['linear', T.easeLinear], ['in', T.easeIn], ['out', T.easeOut]]
                        .map(([v, l]) => `<option value="${v}"${p.ease === v ? ' selected' : ''}>${l}</option>`).join('')}
                </select></label>
            </div>
        </div>`).join('');
    renderExport();
}

$('#points').addEventListener('click', async (e) => {
    const card = e.target.closest('.point');
    if (!card) return;
    const i = +card.dataset.i;
    const act = e.target.closest('[data-act]')?.dataset.act;
    const pts = state.scene.points;
    if (!act) return;
    if (act === 'select') {
        state.selected = state.selected === i ? null : i;
    } else if (act === 'goto') {
        state.selected = i;
        post('goto', pts[i]);
    } else if (act === 'update') {
        const c = await post('capture');
        if (c && c.x !== undefined) {
            Object.assign(pts[i], { x: c.x, y: c.y, z: c.z, rx: c.rx, ry: c.ry, rz: c.rz, fov: c.fov });
            toast(T.pointUpdated, 'success');
        }
    } else if (act === 'up' && i > 0) {
        [pts[i - 1], pts[i]] = [pts[i], pts[i - 1]];
        state.selected = i - 1;
    } else if (act === 'down' && i < pts.length - 1) {
        [pts[i + 1], pts[i]] = [pts[i], pts[i + 1]];
        state.selected = i + 1;
    } else if (act === 'remove') {
        pts.splice(i, 1);
        state.selected = null;
    }
    saveDraft();
    renderPoints();
});

$('#points').addEventListener('change', (e) => {
    const f = e.target.dataset.f;
    const card = e.target.closest('.point');
    if (!f || !card) return;
    const p = state.scene.points[+card.dataset.i];
    p[f] = f === 'ease' ? e.target.value : Math.max(f === 'dur' ? 0.1 : 0, parseFloat(e.target.value) || 0);
    saveDraft();
    renderPoints();
});

function addPoint(p) {
    const point = {
        x: p.x, y: p.y, z: p.z, rx: p.rx, ry: p.ry || 0, rz: p.rz, fov: p.fov,
        dur: p.dur ?? state.defaults.dur, hold: p.hold ?? 0, ease: p.ease || state.defaults.ease,
    };
    if (state.selected !== null && state.selected < state.scene.points.length - 1) {
        state.scene.points.splice(state.selected + 1, 0, point);
        state.selected += 1;
    } else {
        state.scene.points.push(point);
        state.selected = null;
    }
    saveDraft();
    renderPoints();
    const list = $('#points');
    list.parentElement.scrollTop = list.parentElement.scrollHeight;
}

$('#btn-add').addEventListener('click', async () => {
    const c = await post('capture');
    if (c && c.x !== undefined) addPoint(c);
});

function play(from) {
    if (state.scene.points.length < 2) return toast(T.needPoints, 'error');
    post('play', { scene: sceneForExport(), from: from ? from + 1 : 1 });
}
$('#btn-play').addEventListener('click', () => play(0));
$('#btn-play-from').addEventListener('click', () => {
    if (state.selected === null) return toast(T.selectFirst, 'error');
    play(state.selected);
});

/* ------------------------------------------------------------
   Effecten
   ------------------------------------------------------------ */

function fillSelect(el, list) {
    el.innerHTML = (list || []).map((o) => `<option value="${esc(o.id)}">${esc(o.label)}</option>`).join('');
}

function renderSettings() {
    const s = state.scene.settings;
    $('#s-bars').value = Math.round(s.bars * 100);
    $('#v-bars').textContent = `${Math.round(s.bars * 100)}%`;
    $('#s-filter').value = s.filter;
    $('#s-strength').value = Math.round(s.strength * 100);
    $('#v-strength').textContent = `${Math.round(s.strength * 100)}%`;
    $('#s-shake').value = s.shake;
    $('#s-shakeAmp').value = Math.round(s.shakeAmp * 10);
    $('#v-shakeAmp').textContent = s.shakeAmp.toFixed(1);
    $('#s-time').value = s.time;
    $('#v-time').textContent = s.time < 0 ? T.server : `${String(s.time).padStart(2, '0')}:00`;
    $('#s-weather').value = s.weather;
    ['smooth', 'loop', 'fade', 'hideHud', 'hidePlayer', 'previewBars'].forEach((k) => { $(`#s-${k}`).checked = !!s[k]; });
    updateBars();
}

function updateBars() {
    const s = state.scene.settings;
    const show = state.playing ? state.playBars : (state.open && s.previewBars ? s.bars : 0);
    document.documentElement.style.setProperty('--bars', show || 0);
}

let previewTimer;
function pushPreview() {
    clearTimeout(previewTimer);
    previewTimer = setTimeout(() => post('preview', state.scene.settings), 120);
}

const SETTING_INPUTS = {
    bars: (v) => v / 100, strength: (v) => v / 100, shakeAmp: (v) => v / 10, time: (v) => parseInt(v, 10),
    filter: (v) => v, shake: (v) => v, weather: (v) => v,
};
Object.entries(SETTING_INPUTS).forEach(([k, conv]) => {
    $(`#s-${k}`).addEventListener('input', (e) => {
        state.scene.settings[k] = conv(e.target.value);
        renderSettings();
        saveDraft();
        renderExport();
        pushPreview();
    });
});
['smooth', 'loop', 'fade', 'hideHud', 'hidePlayer', 'previewBars'].forEach((k) => {
    $(`#s-${k}`).addEventListener('change', (e) => {
        state.scene.settings[k] = e.target.checked;
        saveDraft();
        renderSettings();
        renderPoints();
    });
});

/* ------------------------------------------------------------
   Scènes
   ------------------------------------------------------------ */

function sceneForExport() {
    const round = (n, d = 3) => Math.round(n * 10 ** d) / 10 ** d;
    return {
        name: state.scene.name || 'scene',
        points: state.scene.points.map((p) => ({
            x: round(p.x), y: round(p.y), z: round(p.z), rx: round(p.rx, 2), ry: round(p.ry || 0, 2), rz: round(p.rz, 2),
            fov: round(p.fov, 1), dur: +p.dur, hold: +p.hold || 0, ease: p.ease,
        })),
        settings: { ...state.scene.settings },
    };
}

function renderExport() {
    const s = sceneForExport();
    delete s.settings.previewBars;
    $('#export').value = `${T.exportServer}\nexports['nijmegen-cinematics']:PlayScene(source, '${(state.scene.name || 'naam').replace(/'/g, '')}')\n\n${T.exportClient}\nexports['nijmegen-cinematics']:Play(json.decode([[${JSON.stringify(s)}]]))`;
}

async function refreshScenes() {
    const res = await post('call', { name: 'list' });
    state.scenes = res?.scenes || [];
    $('#scene-list').innerHTML = state.scenes.map((s) => `
        <div class="scene${s.name === state.scene.name ? ' current' : ''}">
            <div class="scene-info"><b>${esc(s.name)}</b><small>${s.points} ${T.points} · ${esc(s.by || '')} · ${esc(s.date || '')}</small></div>
            <button class="btn soft" data-load="${esc(s.name)}">${T.load}</button>
            <button class="icon-btn danger" data-del="${esc(s.name)}">${ICON.del}</button>
        </div>`).join('') || `<div class="empty">${T.noScenes}</div>`;
}

$('#scene-list').addEventListener('click', async (e) => {
    const load = e.target.closest('[data-load]')?.dataset.load;
    const del = e.target.closest('[data-del]')?.dataset.del;
    if (load) {
        const res = await serverCall('load', { name: load });
        if (res.ok) {
            state.scene = { name: res.scene.name, points: res.scene.points, settings: { ...DEFAULT_SETTINGS, ...res.scene.settings } };
            state.selected = null;
            saveDraft();
            $('#scene-name').value = state.scene.name;
            renderPoints();
            renderSettings();
            pushPreview();
            refreshScenes();
            if (state.scene.points[0]) post('goto', state.scene.points[0]);
        }
    }
    if (del && await confirmBox(T.delTitle, del)) {
        await serverCall('delete', { name: del });
        refreshScenes();
    }
});

$('#btn-save').addEventListener('click', async () => {
    if (!state.scene.name.trim()) {
        toast(T.needName, 'error');
        return $('#scene-name').focus();
    }
    if (state.scene.points.length < 2) return toast(T.needPoints, 'error');
    await serverCall('save', { scene: sceneForExport() });
    refreshScenes();
});

$('#btn-new').addEventListener('click', async () => {
    if (state.scene.points.length && !(await confirmBox(T.newTitle, T.newText))) return;
    state.scene = { name: '', points: [], settings: { ...DEFAULT_SETTINGS } };
    state.selected = null;
    $('#scene-name').value = '';
    saveDraft();
    renderPoints();
    renderSettings();
    pushPreview();
    refreshScenes();
});

$('#btn-broadcast').addEventListener('click', async () => {
    if (state.scene.points.length < 2) return toast(T.needPoints, 'error');
    if (!(await confirmBox(T.bcTitle, T.bcText))) return;
    serverCall('broadcast', { scene: sceneForExport() });
});

$('#btn-copy').addEventListener('click', () => {
    const ta = $('#export');
    ta.select();
    try { document.execCommand('copy'); } catch (e) { /* negeren */ }
    toast(T.copied, 'success');
});

$('#scene-name').addEventListener('input', (e) => {
    state.scene.name = e.target.value;
    saveDraft();
    renderExport();
});

$('#btn-close').addEventListener('click', async () => {
    post('close');
});

/* ------------------------------------------------------------
   Afspelen: tijdlijn
   ------------------------------------------------------------ */

function playStart(d) {
    state.playing = true;
    state.playBars = d.bars || 0;
    $('#editor').classList.add('hidden');
    $('#hint').classList.add('hidden');
    $('#tl-name').textContent = d.name || '';
    $('#tl-fill').style.width = '0';
    $('#tl-marks').innerHTML = (d.marks || []).map((m) => `<span class="mark" style="left:${m * 100}%"></span>`).join('');
    $('#timeline').classList.remove('hidden');
    $('#timeline').classList.toggle('viewer', !d.editor);
    state.total = d.total;
    updateBars();
}

function playStop() {
    state.playing = false;
    $('#timeline').classList.add('hidden');
    if (state.open) $('#editor').classList.remove('hidden');
    updateBars();
}

function progress(d) {
    $('#tl-fill').style.width = `${Math.min(100, (d.t / d.total) * 100)}%`;
    $('#tl-time').textContent = `${d.t.toFixed(1)} / ${d.total.toFixed(1)} s`;
}

/* ------------------------------------------------------------
   Berichten vanuit Lua
   ------------------------------------------------------------ */

const handlers = {
    open(d) {
        applyLang(d.locale);
        if (d.accent) {
            const n = parseInt(d.accent.slice(1), 16);
            const rgb = `${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}`;
            const root = document.documentElement.style;
            root.setProperty('--accent', d.accent);
            root.setProperty('--accent-soft', `rgba(${rgb}, .14)`);
            root.setProperty('--accent-line', `rgba(${rgb}, .5)`);
        }
        fillSelect($('#s-filter'), d.filters);
        fillSelect($('#s-shake'), d.shakes);
        fillSelect($('#s-weather'), d.weathers);
        state.defaults = d.defaults || state.defaults;
        state.broadcast = !!d.broadcast;
        $('#btn-broadcast').classList.toggle('off', !state.broadcast);
        loadDraft();
        $('#scene-name').value = state.scene.name;
        state.open = true;
        $('#editor').classList.remove('hidden');
        renderPoints();
        renderSettings();
        pushPreview();
    },
    close() {
        state.open = false;
        $('#editor').classList.add('hidden');
        $('#hint').classList.add('hidden');
        closeModal(false);
        updateBars();
    },
    mode: (d) => setMode(d.mode),
    addPoint,
    removeLast() {
        state.scene.points.pop();
        state.selected = null;
        saveDraft();
        renderPoints();
    },
    requestPlay: () => play(0),
    camInfo(d) {
        $('#cam-info').textContent = `FOV ${Math.round(d.fov)} · ${d.speed.toFixed(2)}x · ${Math.round(d.roll)}° · ${Math.round(d.dist)} m`;
    },
    playStart,
    playStop,
    progress,
    toast: (d) => toast(d.msg, d.kind),
};

window.addEventListener('message', (e) => {
    const m = e.data;
    if (m && handlers[m.action]) handlers[m.action](m.data || {});
});

/* ------------------------------------------------------------
   Voorbeeldmodus (buiten FiveM)
   ------------------------------------------------------------ */

const preview = {
    saved: [
        { name: 'Intro Nijmegen', points: 6, by: 'Dayverse', date: '28-09-2026 14:12' },
        { name: 'Politiebureau', points: 4, by: 'Sanne', date: '27-09-2026 21:40' },
        { name: 'Zonsondergang strand', points: 3, by: 'Dayverse', date: '26-09-2026 19:03' },
    ],
    handle(name, data) {
        if (name === 'capture') return { x: 215.7 + Math.random() * 40, y: -810.1 + Math.random() * 40, z: 40 + Math.random() * 10, rx: -8, ry: 0, rz: 150 + Math.random() * 60, fov: 50 };
        if (name === 'call' && data.name === 'list') return { ok: true, scenes: this.saved };
        if (name === 'call') return { ok: true, msg: 'OK' };
        return { ok: true };
    },
};

if (!IS_FIVEM) {
    document.body.classList.add('preview');
    handlers.open({
        locale: 'nl',
        filters: [{ id: '', label: 'Geen / None' }, { id: 'cinema', label: 'Cinema' }, { id: 'NG_filmic02', label: 'Filmic warm' }],
        shakes: [{ id: '', label: 'Geen / None' }, { id: 'HAND_SHAKE', label: 'Handcamera' }],
        weathers: [{ id: '', label: 'Server / Server' }, { id: 'CLEAR', label: 'Helder' }],
        defaults: { dur: 4, ease: 'inout' },
        broadcast: true,
    });
    if (!state.scene.points.length) {
        state.scene.name = 'Intro Nijmegen';
        $('#scene-name').value = state.scene.name;
        [
            { x: 215.7, y: -810.1, z: 45.2, rx: -12, rz: 160, fov: 55, dur: 5, hold: 0, ease: 'inout' },
            { x: 190.3, y: -840.6, z: 38.9, rx: -6, rz: 190, fov: 48, dur: 4, hold: 1, ease: 'inout' },
            { x: 150.8, y: -870.2, z: 34.1, rx: -4, rz: 220, fov: 40, dur: 6, hold: 0, ease: 'linear' },
            { x: 118.2, y: -902.7, z: 52.6, rx: -20, rz: 250, fov: 60, dur: 4, hold: 2, ease: 'out' },
        ].forEach((p) => state.scene.points.push({ ry: 0, ...p }));
        state.selected = 1;
        renderPoints();
    }
    setMode(location.hash === '#camera' ? 'camera' : 'mouse');
    handlers.camInfo({ fov: 50, speed: 0.35, roll: 0, dist: 42 });
}
