/* ============================================================
   dv-reports  |  NUI
   ============================================================ */

const IS_FIVEM = typeof GetParentResourceName === 'function';
const RESOURCE = IS_FIVEM ? GetParentResourceName() : 'dv-reports';

const $ = (s, root = document) => root.querySelector(s);
const $$ = (s, root = document) => [...root.querySelectorAll(s)];
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

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

async function call(name, data = {}, { silent = false } = {}) {
    const res = (await post('call', { name, data })) || {};
    if (res.msg && (!silent || !res.ok)) toast(res.msg, res.ok ? 'success' : 'error');
    return res;
}

function toast(msg, kind = 'info', duration = 4000) {
    const el = document.createElement('div');
    el.className = `toast ${kind}`;
    el.innerHTML = `${ICONS[kind] || ICONS.info}<span>${esc(msg)}</span>`;
    $('#toasts').appendChild(el);
    setTimeout(() => {
        el.classList.add('out');
        setTimeout(() => el.remove(), 260);
    }, duration);
}

function threadHTML(messages) {
    return (messages || []).map((m) => m.from === 'system'
        ? `<div class="msg system"><div class="bubble">${esc(m.text)} · ${esc(m.time)}</div></div>`
        : `<div class="msg ${m.from}"><div class="bubble">${esc(m.text)}</div><small>${esc(m.name || '')} · ${esc(m.time)}</small></div>`).join('');
}

function closeAll() {
    $('#rp').classList.add('hidden');
    $('#panel').classList.add('hidden');
    closeModal(null);
    post('close');
}

document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    if (!$('#modal').classList.contains('hidden')) return closeModal(null);
    if (!$('#rp').classList.contains('hidden') || !$('#panel').classList.contains('hidden')) closeAll();
});

/* ------------------------------------------------------------
   Modal (notitie bij sluiten)
   ------------------------------------------------------------ */

let modalResolve = null;

function modal(title, text, placeholder) {
    $('#modal-title').textContent = title;
    $('#modal-text').textContent = text;
    const input = $('#modal-input');
    input.value = '';
    input.placeholder = placeholder || '';
    $('#modal').classList.remove('hidden');
    setTimeout(() => input.focus(), 30);
    return new Promise((resolve) => { modalResolve = resolve; });
}

function closeModal(value) {
    $('#modal').classList.add('hidden');
    if (modalResolve) modalResolve(value);
    modalResolve = null;
}

$('#modal-form').addEventListener('submit', (e) => { e.preventDefault(); closeModal($('#modal-input').value.trim()); });
$('#modal-cancel').addEventListener('click', () => closeModal(null));

/* ------------------------------------------------------------
   Spelers: /report
   ------------------------------------------------------------ */

const rp = { report: null };

function openPlayer(d) {
    rp.report = d.report || null;
    $('#rp-cats').innerHTML = (d.categories || []).map((c, i) =>
        `<button type="button" class="chip cat${i === 0 ? ' active' : ''}" data-v="${esc(c)}">${esc(c)}</button>`).join('');
    const form = $('#rp-form');
    form.reset();
    if (d.prefill) form.message.value = d.prefill;
    renderMine();
    $('#rp').classList.remove('hidden');
    setTimeout(() => (rp.report ? $('#rp-reply input') : form.message).focus(), 50);
}

function renderMine() {
    const r = rp.report;
    const has = !!r && r.status !== 'closed';
    $('#rp-form').classList.toggle('off', has);
    $('#rp-chat').classList.toggle('off', !has);
    $('#rp-heading').textContent = has ? `Report #${r.id}` : 'Report maken';
    $('#rp-sub').textContent = has ? r.category : 'Dayverse Roleplay · staff krijgt direct een melding.';
    if (!has) return;

    $('#rp-status').innerHTML = r.claimedBy
        ? `<span class="dot"></span><span><b>${esc(r.claimedBy)}</b> helpt je. Reageer hieronder.</span>`
        : '<span class="dot live" style="background:var(--warn);box-shadow:0 0 8px var(--warn)"></span><span>Wachten op staff… je krijgt een melding zodra iemand je report oppakt.</span>';
    const thread = $('#rp-thread');
    thread.innerHTML = threadHTML(r.messages);
    thread.scrollTop = thread.scrollHeight;
}

$('#rp-cats').addEventListener('click', (e) => {
    const chip = e.target.closest('.chip');
    if (chip) $$('#rp-cats .chip').forEach((c) => c.classList.toggle('active', c === chip));
});

$('#rp-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const f = e.target;
    const res = await call('create', {
        category: $('#rp-cats .chip.active')?.dataset.v,
        target: f.target.value.trim(),
        message: f.message.value.trim(),
    });
    if (res.ok) {
        rp.report = res.report;
        renderMine();
    }
});

$('#rp-reply').addEventListener('submit', async (e) => {
    e.preventDefault();
    const text = e.target.text.value.trim();
    if (!text) return;
    e.target.text.value = '';
    const res = await call('message', { text }, { silent: true });
    if (res.ok) {
        rp.report = res.report;
        renderMine();
    }
});

$('#rp-cancel').addEventListener('click', async () => {
    const res = await call('cancel');
    if (res.ok) {
        rp.report = null;
        closeAll();
    }
});

$('#rp-close').addEventListener('click', closeAll);

/* ------------------------------------------------------------
   Staff: /reports
   ------------------------------------------------------------ */

const st = { open: false, me: null, reports: [], filter: 'open', selected: null, timer: null };
const STATUS = { open: 'open', claimed: 'opgepakt', closed: 'gesloten' };

function setCount(n) {
    $('#open-count').textContent = n;
}

function fmtAge(sec) {
    if (sec < 60) return 'zojuist';
    if (sec < 3600) return `${Math.floor(sec / 60)} min`;
    return `${Math.floor(sec / 3600)} u`;
}

function openStaff(d) {
    st.open = true;
    st.me = d.name;
    $('#me-name').textContent = d.name || 'Staff';
    $('#me-avatar').textContent = (d.name || '?').trim()[0]?.toUpperCase() || '?';
    $('#me-rank').textContent = d.rank || 'Staff';
    setCount(d.open || 0);
    $('#panel').classList.remove('hidden');
    refresh();
    clearInterval(st.timer);
    st.timer = setInterval(refresh, 10000);   // vangnet; live updates komen via 'changed'
}

async function refresh() {
    if (!st.open) return;
    const res = await post('call', { name: 'list' });
    if (!res || !res.ok) return;
    st.reports = res.reports || [];
    setCount(st.reports.filter((r) => r.status !== 'closed').length);
    renderList();
    renderDetail();
}

function filtered() {
    return st.reports.filter((r) => {
        if (st.filter === 'open') return r.status !== 'closed';
        if (st.filter === 'mine') return r.status !== 'closed' && r.claimedBy === st.me;
        return r.status === 'closed';
    });
}

function renderList() {
    $('#list').innerHTML = filtered().map((r) => {
        const last = r.messages.filter((m) => m.from !== 'system').slice(-1)[0];
        return `
        <button class="r-row ${r.status}${r.id === st.selected ? ' active' : ''}" data-id="${r.id}">
            <span class="r-id">#${r.id}</span>
            <span class="r-main">
                <b><span class="nm">${esc(r.name)}</span><span class="badge ${r.status}">${STATUS[r.status]}</span>${r.online ? '' : '<span class="badge offline">offline</span>'}</b>
                <p>${esc(r.category)} · ${esc(last ? last.text : '')}</p>
            </span>
            <span class="r-meta">${fmtAge(r.age)}<br>${r.claimedBy ? esc(r.claimedBy) : '—'}</span>
        </button>`;
    }).join('') || `<div class="empty">${st.filter === 'closed' ? 'Geen gesloten reports' : 'Geen open reports, lekker bezig!'}</div>`;
}

$('#filter').addEventListener('click', (e) => {
    const f = e.target.dataset.f;
    if (!f) return;
    st.filter = f;
    $$('#filter button').forEach((b) => b.classList.toggle('active', b.dataset.f === f));
    renderList();
});

$('#list').addEventListener('click', (e) => {
    const row = e.target.closest('.r-row');
    if (!row) return;
    st.selected = +row.dataset.id;
    renderList();
    renderDetail(true);
});

let lastSig = '';
function renderDetail(force = false) {
    const box = $('#detail');
    const r = st.reports.find((x) => x.id === st.selected);
    if (!r) {
        lastSig = '';
        box.innerHTML = `<div class="empty"><svg viewBox="0 0 24 24"><path d="M4 21V4h11l1 3h4v9h-9l-1-3H4"/></svg>${st.selected ? 'Report niet meer beschikbaar' : 'Kies een report'}</div>`;
        return;
    }

    // niet opnieuw tekenen als er niets veranderd is, zodat je typen niet kwijtraakt
    const sig = `${r.id}|${r.status}|${r.claimedBy}|${r.messages.length}|${r.online}`;
    if (!force && sig === lastSig) return;
    const draft = $('#reply input', box)?.value || '';
    lastSig = sig;

    const closed = r.status === 'closed';
    const mine = r.claimedBy === st.me;

    box.innerHTML = `
        <div class="rd">
            <div class="rd-head">
                <h2>#${r.id} ${esc(r.name)} <span class="badge ${r.status}">${STATUS[r.status]}</span><span class="badge cat">${esc(r.category)}</span></h2>
                <p>ID ${r.src} · ${esc(r.created)}${r.claimedBy ? ` · opgepakt door <b>${esc(r.claimedBy)}</b>` : ''}${r.target ? ` · meldt <b>${esc(r.target.name)} (${r.target.id})</b>` : ''}</p>
            </div>
            ${closed ? '' : `<div class="rd-actions">
                ${mine ? '' : '<button class="btn" data-ra="claim">Oppakken</button>'}
                ${r.online ? '<button class="btn soft" data-ra="goto">Ga naar</button><button class="btn soft" data-ra="bring">Haal</button>' : ''}
                ${r.target ? '<button class="btn soft" data-ra="gotoTarget">Naar gemelde</button>' : ''}
                <button class="btn soft danger-soft" data-ra="close">Sluiten</button>
            </div>`}
            <div class="thread" id="thread">${threadHTML(r.messages)}</div>
            ${closed ? '' : `
            <form class="row" id="reply">
                <input name="text" placeholder="${r.online ? 'Antwoord aan speler…' : 'Speler is offline'}" autocomplete="off" maxlength="500" ${r.online ? '' : 'disabled'}>
                <button class="btn" type="submit" ${r.online ? '' : 'disabled'}>Stuur</button>
            </form>`}
        </div>`;

    const thread = $('#thread', box);
    thread.scrollTop = thread.scrollHeight;
    const input = $('#reply input', box);
    if (input) input.value = draft;

    $$('[data-ra]', box).forEach((el) => el.addEventListener('click', () => act(el.dataset.ra, r)));
    $('#reply', box)?.addEventListener('submit', async (e) => {
        e.preventDefault();
        const text = e.target.text.value.trim();
        if (!text) return;
        e.target.text.value = '';
        const res = await call('reply', { id: r.id, text }, { silent: true });
        if (res.ok) refresh();
    });
}

async function act(a, r) {
    if (a === 'claim') {
        await call('claim', { id: r.id });
    } else if (a === 'close') {
        const note = await modal(`Report #${r.id} sluiten`, 'De speler krijgt een melding dat zijn report is afgehandeld.', 'Notitie (optioneel), bv. opgelost');
        if (note === null) return;
        await call('close', { id: r.id, note });
    } else {
        const bring = a === 'bring';
        const res = await call(bring ? 'bring' : 'goto', { id: r.id, who: a === 'gotoTarget' ? 'target' : 'reporter' });
        if (res.ok && !bring) return closeAll();
    }
    refresh();
}

$('#panel-close').addEventListener('click', closeAll);

/* ------------------------------------------------------------
   Berichten vanuit Lua
   ------------------------------------------------------------ */

const handlers = {
    toast: (d) => toast(d.msg, d.kind),
    playerOpen: openPlayer,
    staffOpen: openStaff,
    myReport(d) {
        rp.report = d.report;
        if (d.toast) toast(d.toast, d.kind || 'info', 6000);
        if (!$('#rp').classList.contains('hidden')) renderMine();
    },
    count: (d) => setCount(d.count || 0),
    changed(d) {
        setCount(d.count || 0);
        if (st.open && !$('#panel').classList.contains('hidden')) refresh();
    },
};

window.addEventListener('message', (e) => {
    const m = e.data;
    if (m && handlers[m.action]) handlers[m.action](m.data || {});
});

// paneel dicht = geen verversing meer
new MutationObserver(() => {
    if ($('#panel').classList.contains('hidden')) {
        st.open = false;
        clearInterval(st.timer);
    }
}).observe($('#panel'), { attributes: true, attributeFilter: ['class'] });

/* ------------------------------------------------------------
   Voorbeeldmodus (buiten FiveM)
   ------------------------------------------------------------ */

const preview = {
    mine: null,
    reports: [
        { id: 7, src: 4, name: 'Jayden_V', online: true, category: 'Speler melden', target: { id: 12, name: 'xXSniperXx' }, status: 'claimed', claimedBy: 'Dayverse', created: '20:52', age: 540, messages: [
            { from: 'player', name: 'Jayden_V', text: 'Speler 12 rijdt steeds mensen aan bij het plein, al 3 keer nu', time: '20:52' },
            { from: 'system', text: 'Dayverse heeft de report opgepakt', time: '20:54' },
            { from: 'staff', name: 'Dayverse', text: 'Thanks! Ik kom eraan en kijk even mee.', time: '20:54' },
            { from: 'player', name: 'Jayden_V', text: 'Top, hij staat nu bij de fontein', time: '20:55' },
        ] },
        { id: 8, src: 15, name: 'Mo Bakker', online: true, category: 'Vastgelopen', status: 'open', created: '21:00', age: 120, messages: [
            { from: 'player', name: 'Mo Bakker', text: 'Ik zit vast onder de map bij de haven', time: '21:00' },
        ] },
        { id: 5, src: 22, name: 'Lisa', online: false, category: 'Vraag', status: 'closed', claimedBy: 'Sanne', created: '19:40', age: 5000, messages: [
            { from: 'player', name: 'Lisa', text: 'Hoe kan ik een baan krijgen?', time: '19:40' },
            { from: 'system', text: 'Gesloten door Sanne: uitgelegd', time: '19:45' },
        ] },
    ],
    handle(name, data) {
        if (name !== 'call') return { ok: true };
        const a = data.name;
        const d = data.data || {};
        if (a === 'list') return { ok: true, reports: this.reports };
        if (a === 'mine') return { ok: true, report: this.mine, categories: ['Speler melden', 'Bug', 'Vraag', 'Vastgelopen', 'Anders'] };
        if (a === 'create') {
            this.mine = { id: 9, category: d.category, status: 'open', messages: [{ from: 'player', name: 'Jij', text: d.message, time: '21:04' }] };
            return { ok: true, msg: 'Report verstuurd, staff is op de hoogte', report: this.mine };
        }
        if (a === 'message') {
            this.mine.messages.push({ from: 'player', name: 'Jij', text: d.text, time: '21:05' });
            return { ok: true, report: this.mine };
        }
        if (a === 'reply') {
            this.reports.find((r) => r.id === d.id).messages.push({ from: 'staff', name: 'Dayverse', text: d.text, time: '21:06' });
            return { ok: true };
        }
        return { ok: true, msg: `Uitgevoerd: ${a}` };
    },
};

if (!IS_FIVEM) {
    document.body.classList.add('preview');
    if (location.hash === '#report') openPlayer(preview.handle('call', { name: 'mine' }));
    else openStaff({ name: 'Dayverse', rank: 'Eigenaar', open: 2 });
}
