/* ============================================================
   dv-inventory  |  NUI
   ============================================================ */

const IS_FIVEM = typeof GetParentResourceName === 'function';
const RESOURCE = IS_FIVEM ? GetParentResourceName() : 'dv-inventory';

const $ = (s, root = document) => root.querySelector(s);
const $$ = (s, root = document) => [...root.querySelectorAll(s)];
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const kg = (g) => (g / 1000).toFixed(g % 1000 === 0 ? 0 : 1);

const state = {
    open: false,
    defs: {},            // itemdefinities uit config.lua
    player: null,        // { id, slots, maxWeight, weight, items: [{slot,name,count}] }
    second: null,        // idem, of null = "grond"
    equipped: null,
    hotbar: true,
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
        return { ok: false };
    }
}

async function request(name, data) {
    const res = (await post(name, data)) || {};
    if (!res.ok && res.msg) toast(res.msg, 'error');
    else if (res.ok && res.msg) toast(res.msg, 'success');
    return res;
}

function toast(msg, kind = 'info', duration = 3500) {
    const el = document.createElement('div');
    el.className = `toast ${kind}`;
    el.textContent = msg;
    $('#toasts').appendChild(el);
    setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 260); }, duration);
}

/* ------------------------------------------------------------
   Tekenen
   ------------------------------------------------------------ */

function itemHTML(it) {
    const d = state.defs[it.name] || { label: it.name, icon: '❔' };
    return `<div class="item" data-name="${esc(it.name)}">
        <span class="icon">${esc(d.icon || '❔')}</span>
        ${d.account ? `<span class="count">€ ${Number(it.count).toLocaleString('nl-NL')}</span>` : (it.count > 1 || d.stack ? `<span class="count">${it.count}x</span>` : '')}
        <span class="label">${esc(d.label)}</span>
    </div>`;
}

function renderGrid(el, inv, which) {
    const bySlot = {};
    (inv?.items || []).forEach((it) => { bySlot[it.slot] = it; });
    const slots = inv?.slots || 30;
    let html = '';
    for (let s = 1; s <= slots; s++) {
        const it = bySlot[s];
        const hot = which === 'player' && state.hotbar && s <= 5;
        const eq = which === 'player' && state.equipped === s;
        html += `<div class="slot${hot ? ' hot' : ''}${eq ? ' equipped' : ''}" data-inv="${which}" data-slot="${s}">
            ${hot ? `<span class="hotnum">${s}</span>` : ''}${it ? itemHTML(it) : ''}
        </div>`;
    }
    el.innerHTML = html;
}

function renderWeight(prefix, inv) {
    const w = inv?.weight || 0;
    const max = inv?.maxWeight || 1;
    $(`#${prefix}-weight`).textContent = kg(w);
    $(`#${prefix}-max`).textContent = kg(max);
    const bar = $(`#${prefix}-bar`);
    bar.style.width = `${Math.min(100, (w / max) * 100)}%`;
    bar.classList.toggle('full', w / max > 0.9);
}

const SECOND_ICONS = {
    ground: '<svg viewBox="0 0 24 24"><path d="M3 20h18M6 20l2-6h8l2 6M9 14V9a3 3 0 0 1 6 0v5"/></svg>',
    drop: '<svg viewBox="0 0 24 24"><path d="M6 8h12l-1 12H7zM9 8V6a3 3 0 0 1 6 0v2"/></svg>',
    trunk: '<svg viewBox="0 0 24 24"><path d="M3 13l2-6h14l2 6v5H3zM3 13h18M7 16h.01M17 16h.01"/></svg>',
    glovebox: '<svg viewBox="0 0 24 24"><rect x="3" y="7" width="18" height="11" rx="2"/><path d="M8 12h8"/></svg>',
    stash: '<svg viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="12" cy="12" r="3"/><path d="M12 9v-1M15 12h1"/></svg>',
};

function render() {
    const p = state.player;
    $('#player-name').textContent = p?.label || 'Dayverse Roleplay';
    renderGrid($('#grid-player'), p, 'player');
    renderWeight('player', p);

    const s = state.second;
    const type = s?.type || 'ground';
    $('#second-icon').innerHTML = SECOND_ICONS[type] || SECOND_ICONS.ground;
    $('#second-label').textContent = s?.label || 'Grond';
    $('#second-sub').textContent = {
        ground: 'Sleep items hierheen om ze neer te leggen',
        drop: 'Spullen die hier op de grond liggen',
        trunk: 'Deel deze ruimte met iedereen die erbij kan',
        glovebox: 'Klein opbergvak in het voertuig',
        stash: 'Opslag',
    }[type] || '';
    renderGrid($('#grid-second'), s || { slots: 30, items: [] }, 'second');
    $('#second-weight-wrap').style.visibility = s && s.maxWeight < 1e8 ? 'visible' : 'hidden';
    if (s) renderWeight('second', s);
}

function invOf(which) {
    return which === 'player' ? state.player : state.second;
}

function itemIn(which, slot) {
    return (invOf(which)?.items || []).find((it) => it.slot === slot);
}

/* ------------------------------------------------------------
   Acties
   ------------------------------------------------------------ */

function amountFor(it, half) {
    const v = parseInt($('#amount').value, 10);
    if (v > 0) return Math.min(v, it.count);
    if (half) return Math.max(1, Math.ceil(it.count / 2));
    return it.count;
}

async function move(fromWhich, fromSlot, toWhich, toSlot, count) {
    const from = invOf(fromWhich);
    const to = toWhich === 'second' && !state.second ? { id: 'ground' } : invOf(toWhich);
    if (!from || !to) return;
    await request('move', { from: from.id, fromSlot, to: to.id, toSlot, count });
}

async function useItem(slot) {
    const it = itemIn('player', slot);
    if (!it) return;
    const d = state.defs[it.name] || {};
    if (!d.usable) return toast(`${d.label || it.name} kun je niet gebruiken`, 'error');
    await request('use', { slot });
}

async function giveItem(slot, count) {
    await request('give', { slot, count });
}

async function dropItem(slot, count) {
    const target = state.second && state.second.type === 'drop' ? 'second' : 'second';
    await move('player', slot, target, 0, count);
}

function close() {
    if (!state.open) return;
    state.open = false;
    hideTooltip();
    hideCtx();
    $('#inv').classList.add('hidden');
    $('#amount').value = '';
    post('close');
}

$('#close').addEventListener('click', close);
document.addEventListener('keydown', (e) => {
    if (!state.open) return;
    if (e.key === 'Escape' || (e.key.toLowerCase() === 'i' && document.activeElement !== $('#amount')) || e.key === 'Tab') {
        e.preventDefault();
        close();
    }
});

/* ------------------------------------------------------------
   Slepen en neerzetten
   ------------------------------------------------------------ */

let drag = null;

document.addEventListener('pointerdown', (e) => {
    if (e.button !== 0 || !state.open || e.target.closest('#ctx')) return;
    hideCtx();
    const slotEl = e.target.closest('.slot');
    if (!slotEl || !slotEl.querySelector('.item') || slotEl.closest('.hotbar')) return;
    drag = {
        which: slotEl.dataset.inv,
        slot: +slotEl.dataset.slot,
        x: e.clientX,
        y: e.clientY,
        half: e.shiftKey,
        started: false,
        source: slotEl.querySelector('.item'),
    };
});

document.addEventListener('pointermove', (e) => {
    if (!drag) return;
    if (!drag.started) {
        if (Math.hypot(e.clientX - drag.x, e.clientY - drag.y) < 5) return;
        drag.started = true;
        hideTooltip();
        const ghost = $('#ghost');
        ghost.innerHTML = drag.source.outerHTML;
        ghost.classList.remove('hidden');
        drag.source.classList.add('dragging');
        document.body.classList.add('is-dragging');
    }
    const ghost = $('#ghost');
    ghost.style.left = `${e.clientX}px`;
    ghost.style.top = `${e.clientY}px`;
    $$('.slot.over, .zone.over').forEach((el) => el.classList.remove('over'));
    const under = document.elementFromPoint(e.clientX, e.clientY);
    const target = under?.closest('.inv .slot, .zone');
    if (target) target.classList.add('over');
});

document.addEventListener('pointerup', async (e) => {
    if (!drag) return;
    const d = drag;
    drag = null;
    if (!d.started) return;

    $('#ghost').classList.add('hidden');
    d.source.classList.remove('dragging');
    document.body.classList.remove('is-dragging');
    $$('.slot.over, .zone.over').forEach((el) => el.classList.remove('over'));

    const it = itemIn(d.which, d.slot);
    if (!it) return;
    const count = amountFor(it, d.half);
    const under = document.elementFromPoint(e.clientX, e.clientY);

    const zone = under?.closest('.zone');
    if (zone) {
        if (d.which !== 'player') return toast('Pak het eerst in je eigen inventaris', 'error');
        if (zone.dataset.zone === 'use') return useItem(d.slot);
        if (zone.dataset.zone === 'give') return giveItem(d.slot, count);
    }

    const slotEl = under?.closest('.inv .slot');
    if (slotEl) {
        return move(d.which, d.slot, slotEl.dataset.inv, +slotEl.dataset.slot, count);
    }
    // losgelaten op een leeg stuk van het andere venster
    const pane = under?.closest('.pane');
    if (pane) {
        const toWhich = pane.id === 'pane-player' ? 'player' : 'second';
        if (toWhich !== d.which) move(d.which, d.slot, toWhich, 0, count);
    }
});

// dubbelklik = gebruiken
document.addEventListener('dblclick', (e) => {
    const slotEl = e.target.closest('.inv .slot');
    if (slotEl && slotEl.dataset.inv === 'player' && slotEl.querySelector('.item')) useItem(+slotEl.dataset.slot);
});

/* ------------------------------------------------------------
   Tooltip
   ------------------------------------------------------------ */

function hideTooltip() { $('#tooltip').classList.add('hidden'); }

document.addEventListener('mousemove', (e) => {
    if (!state.open || drag?.started || !$('#ctx').classList.contains('hidden')) return hideTooltip();
    const slotEl = e.target.closest('.inv .slot');
    const it = slotEl && itemIn(slotEl.dataset.inv, +slotEl.dataset.slot);
    if (!it) return hideTooltip();
    const d = state.defs[it.name] || {};
    const tip = $('#tooltip');
    tip.innerHTML = `
        <h3><i>${esc(d.icon || '❔')}</i>${esc(d.label || it.name)}</h3>
        ${d.desc ? `<p>${esc(d.desc)}</p>` : ''}
        <div class="meta">
            <span>${d.account ? 'Bedrag' : 'Aantal'} <b>${d.account ? '€ ' + Number(it.count).toLocaleString('nl-NL') : it.count}</b></span>
            <span>Gewicht <b>${kg((d.weight || 0) * it.count)} kg</b></span>
        </div>
        ${d.weapon ? '<span class="tag">Wapen</span>' : d.usable ? '<span class="tag">Te gebruiken</span>' : ''}`;
    tip.classList.remove('hidden');
    const x = Math.min(e.clientX + 16, window.innerWidth - 250);
    const y = Math.min(e.clientY + 16, window.innerHeight - tip.offsetHeight - 10);
    tip.style.left = `${x}px`;
    tip.style.top = `${y}px`;
});

/* ------------------------------------------------------------
   Rechtsklik-menu
   ------------------------------------------------------------ */

function hideCtx() { $('#ctx').classList.add('hidden'); }

const CTX_ICONS = {
    use: '<svg viewBox="0 0 24 24"><path d="M5 12l5 5L20 7"/></svg>',
    give: '<svg viewBox="0 0 24 24"><path d="M20 12v9H4v-9M2 7h20v5H2zM12 22V7"/></svg>',
    split: '<svg viewBox="0 0 24 24"><path d="M16 3h5v5M8 3H3v5M21 3l-7 7M3 3l7 7M12 22v-8"/></svg>',
    drop: '<svg viewBox="0 0 24 24"><path d="M12 3v12M7 10l5 5 5-5M5 21h14"/></svg>',
    take: '<svg viewBox="0 0 24 24"><path d="M12 21V9M7 14l5-5 5 5M5 3h14"/></svg>',
};

document.addEventListener('contextmenu', (e) => {
    e.preventDefault();
    if (!state.open) return;
    const slotEl = e.target.closest('.inv .slot');
    const it = slotEl && itemIn(slotEl.dataset.inv, +slotEl.dataset.slot);
    if (!it) return hideCtx();
    hideTooltip();
    const which = slotEl.dataset.inv;
    const slot = +slotEl.dataset.slot;
    const d = state.defs[it.name] || {};
    const opts = [];
    if (which === 'player') {
        if (d.usable) opts.push(['use', d.weapon ? (state.equipped === slot ? 'Wegstoppen' : 'Pakken') : 'Gebruiken']);
        opts.push(['give', 'Geven']);
        if (it.count > 1) opts.push(['split', 'Splitsen']);
        opts.push(['hr']);
        opts.push(['drop', 'Weggooien', 'danger']);
    } else {
        opts.push(['take', 'Pakken']);
        if (it.count > 1) opts.push(['split', 'Splitsen']);
    }
    const ctx = $('#ctx');
    ctx.innerHTML = opts.map(([a, label, cls]) => (a === 'hr' ? '<hr>' : `<button data-a="${a}" class="${cls || ''}">${CTX_ICONS[a] || ''}${label}</button>`)).join('');
    ctx.classList.remove('hidden');
    ctx.style.left = `${Math.min(e.clientX, window.innerWidth - 190)}px`;
    ctx.style.top = `${Math.min(e.clientY, window.innerHeight - ctx.offsetHeight - 10)}px`;
    ctx.onclick = (ev) => {
        const a = ev.target.closest('button')?.dataset.a;
        if (!a) return;
        hideCtx();
        const count = amountFor(it, false);
        if (a === 'use') useItem(slot);
        if (a === 'give') giveItem(slot, count);
        if (a === 'drop') dropItem(slot, count);
        if (a === 'take') move('second', slot, 'player', 0, count);
        if (a === 'split') move(which, slot, which, 0, parseInt($('#amount').value, 10) > 0 ? count : Math.floor(it.count / 2));
    };
});

document.addEventListener('pointerdown', (e) => {
    if (!e.target.closest('#ctx')) hideCtx();
}, true);

/* ------------------------------------------------------------
   Hotbar, itembox, voortgang
   ------------------------------------------------------------ */

let hotbarTimer;
function showHotbar(items, used) {
    const bySlot = {};
    (items || []).forEach((it) => { bySlot[it.slot] = it; });
    $('#hotbar').innerHTML = [1, 2, 3, 4, 5].map((s) => `
        <div class="slot hot${s === used ? ' used' : ''}${state.equipped === s ? ' equipped' : ''}">
            <span class="hotnum">${s}</span>${bySlot[s] ? itemHTML(bySlot[s]) : ''}
        </div>`).join('');
    $('#hotbar').classList.remove('hidden');
    clearTimeout(hotbarTimer);
    hotbarTimer = setTimeout(() => $('#hotbar').classList.add('hidden'), 2200);
}

function itembox(d) {
    const el = document.createElement('div');
    el.className = `ib ${d.delta > 0 ? 'add' : 'remove'}`;
    el.innerHTML = `<i>${esc(d.icon || '❔')}</i><b>${d.delta > 0 ? '+' : ''}${d.delta}</b><span>${esc(d.label)}</span>`;
    const box = $('#itembox');
    box.appendChild(el);
    while (box.children.length > 4) box.firstChild.remove();
    setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 300); }, 3000);
}

let progressTimer;
function progress(d) {
    const el = $('#progress');
    const fill = $('#progress-fill');
    $('#progress-label').textContent = d.label || 'Bezig…';
    fill.style.transition = 'none';
    fill.style.width = '0';
    el.classList.remove('hidden');
    void fill.offsetWidth;
    fill.style.transition = `width ${d.time}ms linear`;
    fill.style.width = '100%';
    clearTimeout(progressTimer);
    progressTimer = setTimeout(() => el.classList.add('hidden'), d.time + 150);
}

/* ------------------------------------------------------------
   Berichten vanuit Lua
   ------------------------------------------------------------ */

const handlers = {
    open(d) {
        state.defs = d.items || state.defs;
        state.player = d.player;
        state.second = d.secondary || null;
        state.hotbar = d.hotbar !== false;
        state.open = true;
        render();
        $('#inv').classList.remove('hidden');
    },
    close() {
        state.open = false;
        hideTooltip();
        hideCtx();
        $('#inv').classList.add('hidden');
    },
    update(d) {
        if (d.player) state.player = d.player;
        if (d.secondary !== undefined) state.second = d.secondary || null;
        if (state.open) render();
    },
    equipped(d) {
        state.equipped = d.slot || null;
        if (state.open) render();
    },
    hotbar: (d) => showHotbar(d.items, d.used),
    itembox,
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
    defs: {
        water: { label: 'Water', icon: '💧', weight: 500, stack: true, usable: true, desc: 'Een flesje koud water.' },
        sandwich: { label: 'Broodje', icon: '🥪', weight: 300, stack: true, usable: true, desc: 'Broodje kaas.' },
        burger: { label: 'Burger', icon: '🍔', weight: 400, stack: true, usable: true, desc: 'Vet lekker.' },
        bandage: { label: 'Verband', icon: '🩹', weight: 100, stack: true, usable: true, desc: 'Stopt kleine bloedingen (+20 leven).' },
        phone: { label: 'Telefoon', icon: '📱', weight: 200, desc: 'Je smartphone.' },
        id_card: { label: 'ID-kaart', icon: '🪪', weight: 20, desc: 'Je identiteitsbewijs.' },
        weapon_pistol: { label: 'Pistool', icon: '🔫', weight: 1100, usable: true, weapon: 'WEAPON_PISTOL', desc: 'Gebruikt pistoolmunitie.' },
        ammo_pistol: { label: 'Pistoolmunitie', icon: '📦', weight: 200, stack: true, usable: true, desc: 'Doos met 12 kogels.' },
        repairkit: { label: 'Reparatieset', icon: '🔧', weight: 2500, stack: true, usable: true, desc: 'Repareert het voertuig waar je naast staat.' },
        lockpick: { label: 'Lockpick', icon: '🗝️', weight: 150, stack: true, desc: 'Voor sloten die niet van jou zijn.' },
        cola: { label: 'Cola', icon: '🥤', weight: 350, stack: true, usable: true, desc: 'Bruisend en zoet.' },
        radio: { label: 'Portofoon', icon: '📻', weight: 500, desc: 'Voor contact met je team.' },
        rope: { label: 'Touw', icon: '🪢', weight: 800, stack: true, desc: 'Stevig touw.' },
    },
    inv: {
        player: { id: 'player:demo', type: 'player', label: 'Dayverse Speler', slots: 30, maxWeight: 30000, items: [
            { slot: 1, name: 'weapon_pistol', count: 1 }, { slot: 2, name: 'water', count: 3 }, { slot: 3, name: 'sandwich', count: 2 },
            { slot: 4, name: 'bandage', count: 5 }, { slot: 6, name: 'phone', count: 1 }, { slot: 7, name: 'id_card', count: 1 },
            { slot: 8, name: 'ammo_pistol', count: 4 }, { slot: 9, name: 'radio', count: 1 }, { slot: 11, name: 'lockpick', count: 3 },
        ] },
        second: { id: 'trunk:DV123', type: 'trunk', label: 'Kofferbak · DV 123', slots: 30, maxWeight: 100000, items: [
            { slot: 1, name: 'repairkit', count: 2 }, { slot: 2, name: 'burger', count: 6 }, { slot: 3, name: 'cola', count: 12 }, { slot: 5, name: 'rope', count: 2 },
        ] },
    },
    weigh(inv) { inv.weight = inv.items.reduce((w, it) => w + (this.defs[it.name].weight || 0) * it.count, 0); },
    handle(name, data) {
        if (name === 'move') {
            const from = data.from === this.inv.player.id ? this.inv.player : this.inv.second;
            const to = data.to === this.inv.player.id ? this.inv.player : this.inv.second;
            const it = from.items.find((x) => x.slot === data.fromSlot);
            if (!it) return { ok: false };
            let toSlot = data.toSlot;
            if (!toSlot) for (let s = 1; s <= to.slots; s++) if (!to.items.find((x) => x.slot === s)) { toSlot = s; break; }
            const dest = to.items.find((x) => x.slot === toSlot);
            const count = Math.min(data.count || it.count, it.count);
            if (!dest) {
                to.items.push({ slot: toSlot, name: it.name, count });
                it.count -= count;
            } else if (dest.name === it.name && this.defs[it.name].stack) {
                dest.count += count;
                it.count -= count;
            } else {
                if (count < it.count) return { ok: false, msg: 'Kan niet wisselen met een deel van een stapel' };
                from.items = from.items.filter((x) => x !== it);
                to.items = to.items.filter((x) => x !== dest);
                it.slot = toSlot; dest.slot = data.fromSlot;
                to.items.push(it); from.items.push(dest);
            }
            from.items = from.items.filter((x) => x.count > 0);
            this.weigh(from); this.weigh(to);
            handlers.update({ player: this.inv.player, secondary: this.inv.second });
            return { ok: true };
        }
        if (name === 'use') {
            const it = this.inv.player.items.find((x) => x.slot === data.slot);
            const d = this.defs[it.name];
            if (d.weapon) { handlers.equipped({ slot: state.equipped === data.slot ? false : data.slot }); return { ok: true }; }
            it.count -= 1;
            this.inv.player.items = this.inv.player.items.filter((x) => x.count > 0);
            this.weigh(this.inv.player);
            handlers.update({ player: this.inv.player });
            itembox({ label: d.label, icon: d.icon, delta: -1 });
            return { ok: true };
        }
        if (name === 'give') return { ok: false, msg: 'Niemand in de buurt' };
        return { ok: true };
    },
};

if (!IS_FIVEM) {
    document.body.classList.add('preview');
    preview.weigh(preview.inv.player);
    preview.weigh(preview.inv.second);
    handlers.open({ player: preview.inv.player, secondary: preview.inv.second, items: preview.defs, hotbar: true });
    handlers.equipped({ slot: 1 });
}
