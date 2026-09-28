/* ============================================================
   dv-admin  |  NUI
   ============================================================ */

const IS_FIVEM = typeof GetParentResourceName === 'function';
const RESOURCE = IS_FIVEM ? GetParentResourceName() : 'dv-admin';

const $ = (s, root = document) => root.querySelector(s);
const $$ = (s, root = document) => [...root.querySelectorAll(s)];

const state = {
    open: false,
    tab: 'self',
    perms: {},
    flags: {},
    durations: [],
    players: [],
    selected: null,
    bans: [],
    pollTimer: null,
};

const ICONS = {
    success: '<svg viewBox="0 0 24 24"><path d="M20 6 9 17l-5-5"/></svg>',
    error: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M15 9l-6 6M9 9l6 6"/></svg>',
    warn: '<svg viewBox="0 0 24 24"><path d="M12 3 2 20h20zM12 10v4M12 17v.5"/></svg>',
    info: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8v.5"/></svg>',
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
        return { ok: false, msg: 'Geen verbinding met de client' };
    }
}

/** Voert een staff-actie uit en toont het resultaat. */
async function action(name, data = {}, { silent = false } = {}) {
    const res = await post('action', { name, data }) || {};
    if (!silent || !res.ok) {
        if (res.msg) toast(res.msg, res.ok ? 'success' : 'error');
    }
    if (res.close) closeMenu(false);
    return res;
}

/* ------------------------------------------------------------
   Helpers
   ------------------------------------------------------------ */

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function fmtTime(sec) {
    const h = Math.floor(sec / 3600);
    const m = Math.floor((sec % 3600) / 60);
    return h > 0 ? `${h}u ${m}m` : `${m}m`;
}

function initials(name) {
    return (String(name || '?').trim()[0] || '?').toUpperCase();
}

function copy(text) {
    const ta = document.createElement('textarea');
    ta.value = text;
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand('copy'); } catch (e) { /* negeren */ }
    ta.remove();
    toast('Gekopieerd naar klembord', 'success');
}

function toast(msg, kind = 'info', duration = 3500) {
    const el = document.createElement('div');
    el.className = `toast ${kind}`;
    el.innerHTML = `${ICONS[kind] || ICONS.info}<span>${esc(msg)}</span>`;
    $('#toasts').appendChild(el);
    setTimeout(() => {
        el.classList.add('out');
        setTimeout(() => el.remove(), 260);
    }, duration);
}

/* ------------------------------------------------------------
   Modal
   ------------------------------------------------------------ */

let modalResolve = null;

/**
 * fields: [{ name, label, type: 'text'|'textarea'|'chips', placeholder, options }]
 * Geeft een object met waarden terug, of null bij annuleren.
 */
function modal({ title, text = '', fields = [], ok = 'Bevestigen', danger = false }) {
    $('#modal-title').textContent = title;
    $('#modal-text').textContent = text;
    const okBtn = $('#modal-ok');
    okBtn.textContent = ok;
    okBtn.className = `btn${danger ? ' danger' : ''}`;

    const wrap = $('#modal-fields');
    wrap.innerHTML = '';
    fields.forEach((f) => {
        if (f.label) wrap.insertAdjacentHTML('beforeend', `<div class="field-label">${esc(f.label)}</div>`);
        if (f.type === 'textarea') {
            wrap.insertAdjacentHTML('beforeend', `<textarea name="${f.name}" rows="3" maxlength="500" placeholder="${esc(f.placeholder || '')}" required></textarea>`);
        } else if (f.type === 'chips') {
            const chips = f.options.map((o, i) =>
                `<button type="button" class="chip${i === (f.default ?? 0) ? ' active' : ''}" data-v="${esc(o.value)}">${esc(o.label)}</button>`).join('');
            wrap.insertAdjacentHTML('beforeend', `<div class="chips" data-name="${f.name}">${chips}</div>`);
        } else {
            wrap.insertAdjacentHTML('beforeend', `<input name="${f.name}" placeholder="${esc(f.placeholder || '')}" required autocomplete="off">`);
        }
    });

    $$('.chips', wrap).forEach((group) => group.addEventListener('click', (e) => {
        const chip = e.target.closest('.chip');
        if (!chip) return;
        $$('.chip', group).forEach((c) => c.classList.toggle('active', c === chip));
    }));

    $('#modal').classList.remove('hidden');
    const first = $('input, textarea', wrap);
    if (first) setTimeout(() => first.focus(), 30);

    return new Promise((resolve) => { modalResolve = resolve; });
}

function closeModal(value) {
    $('#modal').classList.add('hidden');
    if (modalResolve) modalResolve(value);
    modalResolve = null;
}

$('#modal-form').addEventListener('submit', (e) => {
    e.preventDefault();
    const out = {};
    $$('#modal-fields [name]').forEach((el) => { out[el.name] = el.value.trim(); });
    $$('#modal-fields .chips').forEach((g) => { out[g.dataset.name] = $('.chip.active', g)?.dataset.v; });
    closeModal(out);
});
$('#modal-cancel').addEventListener('click', () => closeModal(null));

const confirmBox = (title, text, danger = false) => modal({ title, text, danger, ok: 'Ja, doorgaan' });

/* ------------------------------------------------------------
   Menu openen / sluiten / tabs
   ------------------------------------------------------------ */

function openMenu(d) {
    state.open = true;
    state.perms = d.perms || {};
    state.flags = d.flags || {};
    state.durations = d.durations || [];
    state.myName = d.name;

    $('#me-name').textContent = d.name || 'Staff';
    $('#me-avatar').textContent = initials(d.name);
    $('#me-rank').textContent = d.rank || 'Staff';
    $('#server-name').textContent = d.serverName || '';

    $$('[data-perm]').forEach((el) => el.classList.toggle('off', !state.perms[el.dataset.perm]));
    $('#nav-reports').classList.toggle('off', !d.reports);
    renderFlags();

    $('#menu').classList.remove('hidden');
    setTab(d.tab || state.tab);
    refreshPlayers();
}

function closeMenu(notify = true) {
    if (!state.open) return;
    state.open = false;
    clearInterval(state.pollTimer);
    $('#menu').classList.add('hidden');
    closeModal(null);
    if (notify) post('close');
}

function setTab(tab) {
    const btn = $(`.nav-btn[data-tab="${tab}"]`);
    if (!btn || btn.classList.contains('off')) tab = 'self';
    state.tab = tab;
    $$('.nav-btn').forEach((b) => b.classList.toggle('active', b.dataset.tab === tab));
    $$('.tab').forEach((t) => t.classList.toggle('active', t.dataset.tab === tab));

    clearInterval(state.pollTimer);
    if (tab === 'players') {
        refreshPlayers();
        state.pollTimer = setInterval(refreshPlayers, 3000);
    }
    if (tab === 'bans') refreshBans();
    if (tab === 'logs') refreshLogs();
}

$$('.nav-btn[data-tab]').forEach((b) => b.addEventListener('click', () => setTab(b.dataset.tab)));
$('#nav-reports').addEventListener('click', () => {
    state.open = false;
    clearInterval(state.pollTimer);
    $('#menu').classList.add('hidden');
    post('openReports');
});
$('#close-menu').addEventListener('click', () => closeMenu());

document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    if (!$('#modal').classList.contains('hidden')) return closeModal(null);
    if (state.open) closeMenu();
});

/* ------------------------------------------------------------
   Tab: Mijzelf
   ------------------------------------------------------------ */

function renderFlags() {
    $$('[data-toggle]').forEach((el) => el.classList.toggle('on', !!state.flags[el.dataset.toggle]));
}

$$('[data-toggle]').forEach((el) => el.addEventListener('click', async () => {
    const key = el.dataset.toggle;
    const res = await action(key, {}, { silent: true });
    if (res.ok) {
        state.flags[key] = !!res.state;
        renderFlags();
        toast(`${$('span', el).textContent} ${res.state ? 'aan' : 'uit'}`, 'success', 1800);
    }
}));

$$('[data-act]').forEach((el) => el.addEventListener('click', async () => {
    if (el.dataset.confirm) {
        const ok = await confirmBox(el.textContent.trim(), el.dataset.confirm, el.classList.contains('danger-soft'));
        if (!ok) return;
    }
    const res = await action(el.dataset.act);
    if (res.ok && res.coords) renderCoords(res.coords);
}));

function renderCoords(c) {
    const out = $('#coords-out');
    out.innerHTML = [['vec3', c.vec3], ['vec4', c.vec4], ['heading', c.heading]]
        .map(([, v]) => `<div class="coord-line"><span>${esc(v)}</span><button class="btn sm soft" data-copy="${esc(v)}">Kopieer</button></div>`)
        .join('');
    out.classList.remove('hidden');
    $$('[data-copy]', out).forEach((b) => b.addEventListener('click', () => copy(b.dataset.copy)));
}

$('#tp-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const f = e.target;
    let { x, y, z } = Object.fromEntries(new FormData(f));
    // vector3(1, 2, 3) of "1, 2, 3" in het X-veld plakken
    const nums = String(x).match(/-?\d+(\.\d+)?/g);
    if (nums && nums.length >= 2 && !y) [x, y, z] = nums;
    await action('tpCoords', { x, y, z: z || null });
});

$('#veh-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const model = e.target.model.value.trim();
    if (!model) return;
    const res = await action('spawnVehicle', { model });
    if (res.ok) e.target.reset();
});

/* ------------------------------------------------------------
   Tab: Spelers
   ------------------------------------------------------------ */

async function refreshPlayers() {
    if (!state.perms.players) return;
    const res = await post('action', { name: 'players' });
    if (!res || !res.ok) return;
    state.players = res.players || [];
    $('#player-count').textContent = state.players.length;
    $('#players-online').textContent = state.players.length;
    renderPlayers();
    renderDetail();
}

function pingClass(p) {
    return p < 80 ? 'good' : p < 160 ? 'mid' : 'bad';
}

function renderPlayers() {
    const q = $('#player-search').value.trim().toLowerCase();
    const list = state.players.filter((p) => !q || p.name.toLowerCase().includes(q) || String(p.id) === q);

    $('#player-list').innerHTML = list.map((p) => `
        <button class="p-row${p.id === state.selected ? ' active' : ''}" data-id="${p.id}">
            <span class="p-id">${p.id}</span>
            <span class="p-name">
                <b><span class="nm">${esc(p.name)}</span>${p.self ? '<span class="badge you">jij</span>' : ''}${p.staff ? `<span class="badge staff">${esc(p.staff)}</span>` : ''}${p.frozen ? '<span class="badge frozen">bevroren</span>' : ''}${p.warns?.length ? `<span class="badge warns">${p.warns.length} warn</span>` : ''}</b>
                <small>${fmtTime(p.playtime)} online${p.distance != null ? ` · ${p.distance}m` : ''}</small>
            </span>
            <span class="hp">
                <span class="hp-bar"><i style="width:${p.health}%"></i></span>
                <span class="hp-bar armor"><i style="width:${p.armor}%"></i></span>
            </span>
            <span class="ping ${pingClass(p.ping)}">${p.ping} ms</span>
        </button>`).join('') || '<div class="empty">Geen spelers gevonden</div>';
}

$('#player-search').addEventListener('input', renderPlayers);
$('#player-list').addEventListener('click', (e) => {
    const row = e.target.closest('.p-row');
    if (!row) return;
    state.selected = +row.dataset.id;
    renderPlayers();
    renderDetail(true);
});

const PLAYER_ACTIONS = [
    ['goto', 'Ga naar', 'soft'],
    ['bring', 'Haal', 'soft'],
    ['spectate', 'Spectate', 'soft'],
    ['heal', 'Genezen', 'soft'],
    ['revive', 'Reviven', 'soft'],
    ['freeze', 'Bevriezen', 'soft'],
    ['dm', 'Bericht', 'soft'],
    ['warn', 'Waarschuw', 'soft warn-soft'],
    ['kill', 'Doden', 'soft danger-soft'],
    ['kick', 'Kick', 'soft danger-soft'],
    ['ban', 'Ban', 'danger'],
];

let lastDetailId = null;
function renderDetail(force = false) {
    const box = $('#player-detail');
    const p = state.players.find((x) => x.id === state.selected);
    if (!p) {
        lastDetailId = null;
        box.innerHTML = `<div class="empty"><svg viewBox="0 0 24 24"><circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 4-6 8-6s8 2 8 6"/></svg>${state.selected ? 'Speler is offline' : 'Kies een speler'}</div>`;
        return;
    }

    // alleen de cijfers verversen tijdens polling, zodat knoppen niet verspringen
    if (!force && lastDetailId === p.id) {
        const set = (k, v) => { const el = $(`[data-stat="${k}"]`, box); if (el) el.textContent = v; };
        set('health', p.health);
        set('armor', p.armor);
        set('ping', p.ping);
        set('dist', p.distance != null ? `${p.distance}m` : '—');
        const fr = $('[data-a="freeze"]', box);
        if (fr) fr.textContent = p.frozen ? 'Ontdooien' : 'Bevriezen';
        return;
    }
    lastDetailId = p.id;

    const ids = [['license', p.license], ['discord', p.discord], ['steam', p.steam], ['fivem', p.fivem]].filter(([, v]) => v);
    const actions = PLAYER_ACTIONS
        .filter(([a]) => state.perms[a])
        .filter(([a]) => !p.self || ['heal', 'revive', 'dm'].includes(a))
        .map(([a, label, cls]) => `<button class="btn ${cls}" data-a="${a}">${a === 'freeze' && p.frozen ? 'Ontdooien' : label}</button>`)
        .join('');

    box.innerHTML = `
        <div class="pd">
            <div class="pd-head">
                <div class="avatar">${esc(initials(p.name))}</div>
                <div>
                    <h2>${esc(p.name)}</h2>
                    <p>ID ${p.id} · ${fmtTime(p.playtime)} online${p.staff ? ` · <span class="badge staff">${esc(p.staff)}</span>` : ''}</p>
                </div>
            </div>
            <div class="stats">
                <div class="stat"><b data-stat="health">${p.health}</b><span>Leven</span></div>
                <div class="stat"><b data-stat="armor">${p.armor}</b><span>Pantser</span></div>
                <div class="stat"><b data-stat="ping">${p.ping}</b><span>Ping</span></div>
                <div class="stat"><b data-stat="dist">${p.distance != null ? `${p.distance}m` : '—'}</b><span>Afstand</span></div>
            </div>
            ${actions ? `<div class="pd-section"><h3>Acties</h3><div class="pd-actions">${actions}</div></div>` : ''}
            <div class="pd-section">
                <h3>Identifiers <small style="text-transform:none;letter-spacing:0">(klik om te kopiëren)</small></h3>
                <div class="ids">${ids.map(([k, v]) => `<div class="id-line" data-copy="${esc(v)}"><b>${k}</b><span>${esc(v.replace(/^\w+:/, ''))}</span></div>`).join('') || '<span class="hint">Geen</span>'}</div>
            </div>
            <div class="pd-section">
                <h3>Waarschuwingen (${p.warns?.length || 0})</h3>
                <div class="warn-list">${(p.warns || []).slice().reverse().map((w) =>
                    `<div class="warn-item">${esc(w.reason)}<small>${esc(w.by)} · ${esc(w.date)}</small></div>`).join('') || '<span class="hint">Geen waarschuwingen</span>'}</div>
            </div>
        </div>`;

    $$('[data-copy]', box).forEach((el) => el.addEventListener('click', () => copy(el.dataset.copy)));
    $$('[data-a]', box).forEach((el) => el.addEventListener('click', () => playerAction(el.dataset.a, p)));
}

async function playerAction(a, p) {
    const target = p.id;
    let data = { target };

    if (a === 'kick') {
        const r = await modal({ title: `${p.name} kicken`, fields: [{ name: 'reason', label: 'Reden', type: 'textarea', placeholder: 'Waarom wordt deze speler gekickt?' }], ok: 'Kicken', danger: true });
        if (!r) return;
        data.reason = r.reason;
    } else if (a === 'ban') {
        const r = await modal({
            title: `${p.name} verbannen`,
            text: 'De speler wordt direct van de server verwijderd.',
            fields: [
                { name: 'hours', label: 'Duur', type: 'chips', options: state.durations.map((d) => ({ label: d.label, value: d.hours })), default: 2 },
                { name: 'reason', label: 'Reden', type: 'textarea', placeholder: 'Waarom wordt deze speler verbannen?' },
            ],
            ok: 'Verbannen',
            danger: true,
        });
        if (!r) return;
        data.reason = r.reason;
        data.hours = +r.hours;
    } else if (a === 'warn') {
        const r = await modal({ title: `${p.name} waarschuwen`, text: 'De speler krijgt een melding in beeld die hij moet bevestigen.', fields: [{ name: 'reason', label: 'Reden', type: 'textarea', placeholder: 'Waarvoor krijgt deze speler een waarschuwing?' }], ok: 'Waarschuwen' });
        if (!r) return;
        data.reason = r.reason;
    } else if (a === 'dm') {
        const r = await modal({ title: `Bericht aan ${p.name}`, fields: [{ name: 'message', type: 'textarea', placeholder: 'Je bericht…' }], ok: 'Versturen' });
        if (!r) return;
        data.message = r.message;
    } else if (a === 'kill') {
        if (!await confirmBox(`${p.name} doden?`, '', true)) return;
    }

    const res = await action(a, data);
    if (res.ok && (a === 'kick' || a === 'ban')) state.selected = null;
    if (res.ok && !res.close) setTimeout(refreshPlayers, 300);
}

/* ------------------------------------------------------------
   Tab: Server
   ------------------------------------------------------------ */

$('#announce-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const message = e.target.message.value.trim();
    if (!message) return;
    const res = await action('announce', { message });
    if (res.ok) e.target.reset();
});

/* ------------------------------------------------------------
   Tab: Bans
   ------------------------------------------------------------ */

async function refreshBans() {
    const res = await post('action', { name: 'bans' });
    if (!res || !res.ok) return;
    state.bans = res.bans || [];
    $('#bans-count').textContent = state.bans.length;
    renderBans();
}

function renderBans() {
    const q = $('#ban-search').value.trim().toLowerCase();
    const list = state.bans.filter((b) => !q || [b.id, b.name, b.reason, b.by, b.license].some((v) => String(v || '').toLowerCase().includes(q)));
    $('#ban-list').innerHTML = list.map((b) => `
        <div class="ban-row">
            <span class="ban-id">${esc(b.id)}</span>
            <div><b>${esc(b.name)}</b><small>door ${esc(b.by)}</small></div>
            <div class="reason">${esc(b.reason)}</div>
            <div><b>${esc(b.expires)}</b><small>sinds ${esc(b.created)}</small></div>
            ${state.perms.unban ? `<button class="btn sm soft" data-unban="${esc(b.id)}">Unban</button>` : '<span></span>'}
        </div>`).join('') || '<div class="empty">Geen actieve bans</div>';

    $$('[data-unban]').forEach((el) => el.addEventListener('click', async () => {
        const b = state.bans.find((x) => x.id === el.dataset.unban);
        if (!await confirmBox(`${b.name} unbannen?`, `Ban ${b.id} wordt verwijderd.`)) return;
        const res = await action('unban', { id: b.id });
        if (res.ok) refreshBans();
    }));
}

$('#ban-search').addEventListener('input', renderBans);

/* ------------------------------------------------------------
   Tab: Logs
   ------------------------------------------------------------ */

async function refreshLogs() {
    const res = await post('action', { name: 'logs' });
    if (!res || !res.ok) return;
    $('#log-list').innerHTML = (res.logs || []).map((l) => `
        <div class="log">
            <time>${esc(l.date)} ${esc(l.time)}</time>
            <span class="who">${esc(l.admin)}</span>
            <span class="what"><b>${esc(l.action)}</b>${l.target ? ` → ${esc(l.target)}` : ''}${l.detail ? ` <span>· ${esc(l.detail)}</span>` : ''}</span>
        </div>`).join('') || '<div class="empty">Nog geen acties gelogd</div>';
}
$('#refresh-logs').addEventListener('click', refreshLogs);

/* ------------------------------------------------------------
   Overlays voor spelers
   ------------------------------------------------------------ */

let announceTimer, dmTimer, warnTimer;

function showAnnounce(d) {
    $('#announce-from').textContent = d.from;
    $('#announce-msg').textContent = d.msg;
    $('#announce').classList.remove('hidden');
    clearTimeout(announceTimer);
    announceTimer = setTimeout(() => $('#announce').classList.add('hidden'), 12000);
}

function showDm(d) {
    $('#dm-from').textContent = d.from;
    $('#dm-msg').textContent = d.msg;
    $('#dm').classList.remove('hidden');
    clearTimeout(dmTimer);
    dmTimer = setTimeout(() => $('#dm').classList.add('hidden'), 12000);
}

function showWarn(d) {
    $('#warn-from').textContent = d.from;
    $('#warn-reason').textContent = d.reason;
    $('#warn').classList.remove('hidden');
    const btn = $('#warn-ack');
    let n = 5;
    btn.disabled = true;
    $('#warn-count').textContent = n;
    clearInterval(warnTimer);
    warnTimer = setInterval(() => {
        n -= 1;
        $('#warn-count').textContent = n;
        if (n <= 0) {
            clearInterval(warnTimer);
            btn.disabled = false;
            btn.textContent = 'Ik begrijp het';
        }
    }, 1000);
}

$('#warn-ack').addEventListener('click', () => {
    $('#warn').classList.add('hidden');
    $('#warn-ack').innerHTML = 'Ik begrijp het (<span id="warn-count">5</span>)';
    post('warnAck');
});

/* ------------------------------------------------------------
   Berichten vanuit Lua
   ------------------------------------------------------------ */

const handlers = {
    open: openMenu,
    close: () => closeMenu(false),
    toast: (d) => toast(d.msg, d.kind),
    announce: showAnnounce,
    dm: showDm,
    warn: showWarn,
    spectate(d) {
        $('#spec-name').textContent = d.on ? `${d.name} (${d.id})` : '';
        $('#spectate-bar').classList.toggle('hidden', !d.on);
    },
    noclip(d) {
        state.flags.noclip = !!d.on;
        renderFlags();
        $('#nc-speed').textContent = d.speed;
        $('#noclip-bar').classList.toggle('hidden', !d.on);
    },
};

window.addEventListener('message', (e) => {
    const m = e.data;
    if (m && handlers[m.action]) handlers[m.action](m.data || {});
});

/* ------------------------------------------------------------
   Voorbeeldmodus (buiten FiveM)
   ------------------------------------------------------------ */

const preview = {
    flags: {},
    players: [
        { id: 1, name: 'Dayverse', ping: 24, health: 100, armor: 50, distance: 0, license: 'license:3f9a1c7e2b', discord: 'discord:28371923', warns: [], staff: 'Eigenaar', playtime: 8420, self: true },
        { id: 4, name: 'Jayden_V', ping: 61, health: 72, armor: 0, distance: 143, license: 'license:a81cc0d2', steam: 'steam:1100001', warns: [{ reason: 'RDM bij de garage', by: 'Dayverse', date: '21-09-2026 20:14' }], playtime: 3600 },
        { id: 7, name: 'Sanne de Boer', ping: 38, health: 100, armor: 100, distance: 1204, license: 'license:77bd21', discord: 'discord:99120', warns: [], staff: 'Moderator', playtime: 12240 },
        { id: 12, name: 'xXSniperXx', ping: 188, health: 31, armor: 0, distance: 402, license: 'license:bb11', warns: [{ reason: 'FailRP', by: 'Sanne de Boer', date: '25-09-2026 22:01' }, { reason: 'Combat logging', by: 'Dayverse', date: '26-09-2026 19:40' }], frozen: true, playtime: 900 },
        { id: 15, name: 'Mo Bakker', ping: 92, health: 88, armor: 20, distance: 87, license: 'license:cc02', warns: [], playtime: 5400 },
    ],
    handle(name, data) {
        if (name !== 'action') return { ok: true };
        const a = data.name;
        const d = data.data || {};
        if (a === 'players') return { ok: true, players: this.players };
        if (a === 'bans') return { ok: true, bans: [
            { id: 'DV-4821', name: 'Cheater123', reason: 'Modmenu / godmode', by: 'Dayverse', created: '20-09-2026 21:12', expires: 'Permanent' },
            { id: 'DV-0937', name: 'Kevin_R', reason: 'Meerdere keren VDM na waarschuwing', by: 'Sanne de Boer', created: '26-09-2026 18:03', expires: '03-10-2026 18:03' },
        ] };
        if (a === 'logs') return { ok: true, logs: [
            { date: '27-09', time: '20:41:12', admin: 'Dayverse', action: 'Waarschuwing', target: 'xXSniperXx', detail: 'Combat logging' },
            { date: '27-09', time: '20:38:02', admin: 'Sanne de Boer', action: 'Teleport naar', target: 'Jayden_V' },
            { date: '27-09', time: '20:30:55', admin: 'Dayverse', action: 'Voertuig gespawnd', detail: 'adder' },
        ] };
        if (['noclip', 'godmode', 'invisible', 'names', 'blips'].includes(a)) {
            this.flags[a] = !this.flags[a];
            if (a === 'noclip') handlers.noclip({ on: this.flags[a], speed: 1 });
            return { ok: true, state: this.flags[a] };
        }
        if (a === 'copyCoords') return { ok: true, coords: { vec3: 'vector3(215.76, -810.12, 30.73)', vec4: 'vector4(215.76, -810.12, 30.73, 157.40)', heading: '157.40' } };
        if (a === 'spectate') { handlers.spectate({ on: true, name: 'Jayden_V', id: 4 }); return { ok: true }; }
        if (a === 'warn') { setTimeout(() => showWarn({ from: 'Dayverse', reason: d.reason }), 300); }
        if (a === 'announce') { showAnnounce({ from: 'Dayverse', msg: d.message }); }
        return { ok: true, msg: `Uitgevoerd: ${a}` };
    },
};

if (!IS_FIVEM) {
    document.body.classList.add('preview');
    openMenu({
        reports: true,
        name: 'Dayverse', rank: 'Eigenaar', serverName: 'Dayverse Roleplay',
        perms: new Proxy({}, { get: () => true }),
        flags: {},
        durations: [
            { label: '1 uur', hours: 1 }, { label: '6 uur', hours: 6 }, { label: '1 dag', hours: 24 },
            { label: '3 dagen', hours: 72 }, { label: '1 week', hours: 168 }, { label: '1 maand', hours: 720 }, { label: 'Permanent', hours: 0 },
        ],
    });
}
