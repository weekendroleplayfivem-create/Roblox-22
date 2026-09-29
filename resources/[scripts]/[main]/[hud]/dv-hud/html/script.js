/* ============================================================
   dv-hud  |  NUI
   ============================================================ */

const IS_FIVEM = typeof GetParentResourceName === 'function';
const RESOURCE = IS_FIVEM ? GetParentResourceName() : 'dv-hud';
const STORAGE_KEY = 'dv-hud:settings:v3';

const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => document.querySelectorAll(sel);

const ACCENTS = ['#ff8c1a', '#4ade80', '#38bdf8', '#a78bfa', '#f472b6', '#facc15', '#f4f6fb'];

const ELEMENTS = [
    ['compass', 'Kompas'],
    ['street', 'Straatnaam'],
    ['clock', 'Klok'],
    ['money', 'Geld'],
    ['job', 'Baan'],
    ['speedo', 'Snelheidsmeter'],
    ['health', 'Leven'],
    ['armor', 'Pantser'],
    ['hunger', 'Honger'],
    ['thirst', 'Dorst'],
    ['stress', 'Stress'],
    ['stamina', 'Uithouding'],
    ['oxygen', 'Zuurstof'],
    ['voice', 'Stem'],
];

// Wanneer een ring rood gaat knipperen
const LOW = {
    health: (v) => v <= 25,
    armor: () => false,
    hunger: (v) => v <= 20,
    thirst: (v) => v <= 20,
    stress: (v) => v >= 80,
    stamina: (v) => v <= 15,
    oxygen: (v) => v <= 25,
};

// Wanneer een ring verborgen mag worden (bij "automatisch verbergen")
const AUTOHIDE = {
    armor: (v) => v <= 0,
    stress: (v) => v <= 0,
    stamina: (v) => v >= 100,
};

const DEFAULTS = {
    scale: 100,
    accent: ACCENTS[0],
    unit: null,          // null = standaard uit config.lua
    values: false,
    autohide: true,
    hidden: {},
};

/* ------------------------------------------------------------
   State
   ------------------------------------------------------------ */

const state = {
    config: { speedUnit: 'kmh', lowFuel: 20, framework: 'standalone' },
    settings: loadSettings(),
    status: {},
    vehicle: { inVehicle: false },
    heading: 0,
    seatbelt: false,
    money: { cash: null, bank: null },
};

/* ------------------------------------------------------------
   Helpers
   ------------------------------------------------------------ */

function loadSettings() {
    try {
        const raw = localStorage.getItem(STORAGE_KEY);
        if (raw) return { ...DEFAULTS, ...JSON.parse(raw), hidden: { ...(JSON.parse(raw).hidden || {}) } };
    } catch (e) { /* geen opslag beschikbaar */ }
    return { ...DEFAULTS, hidden: {} };
}

function saveSettings() {
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(state.settings)); } catch (e) { /* negeren */ }
}

function post(name, data = {}) {
    if (!IS_FIVEM) return;
    fetch(`https://${RESOURCE}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).catch(() => {});
}

function hexToRgba(hex, a) {
    const n = parseInt(hex.slice(1), 16);
    return `rgba(${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}, ${a})`;
}

const moneyFmt = new Intl.NumberFormat('nl-NL', { maximumFractionDigits: 0 });
const fmtMoney = (v) => `€ ${moneyFmt.format(v)}`;

function unit() {
    return state.settings.unit || state.config.speedUnit || 'kmh';
}

/* ------------------------------------------------------------
   Geluid (gordel)
   ------------------------------------------------------------ */

let audioCtx = null;
function beep(freqs, duration = 0.08) {
    try {
        audioCtx = audioCtx || new (window.AudioContext || window.webkitAudioContext)();
        freqs.forEach((f, i) => {
            const osc = audioCtx.createOscillator();
            const gain = audioCtx.createGain();
            const t = audioCtx.currentTime + i * (duration + 0.03);
            osc.type = 'sine';
            osc.frequency.value = f;
            gain.gain.setValueAtTime(0.0001, t);
            gain.gain.exponentialRampToValueAtTime(0.12, t + 0.01);
            gain.gain.exponentialRampToValueAtTime(0.0001, t + duration);
            osc.connect(gain).connect(audioCtx.destination);
            osc.start(t);
            osc.stop(t + duration + 0.02);
        });
    } catch (e) { /* geen audio */ }
}

/* ------------------------------------------------------------
   Opbouw
   ------------------------------------------------------------ */

function buildCompass() {
    const strip = $('#compass-strip');
    const PX = 3;
    const names = { 0: 'N', 45: 'NO', 90: 'O', 135: 'ZO', 180: 'Z', 225: 'ZW', 270: 'W', 315: 'NW' };
    let html = '';
    for (let d = -180; d <= 540; d += 5) {
        const x = (d + 180) * PX;
        const norm = ((d % 360) + 360) % 360;
        if (names[norm] !== undefined) {
            html += `<span class="lbl card${norm === 0 ? ' north' : ''}" style="left:${x}px">${names[norm]}</span>`;
        } else if (norm % 15 === 0) {
            html += `<span class="lbl" style="left:${x}px">${norm}</span>`;
        } else {
            html += `<span class="tick${norm % 10 === 0 ? ' mid' : ''}" style="left:${x}px"></span>`;
        }
    }
    strip.innerHTML = html;
}

const RPM_SEGMENTS = 22;
function buildRpm() {
    $('#rpm').innerHTML = '<i></i>'.repeat(RPM_SEGMENTS);
}

/* ------------------------------------------------------------
   Instellingen toepassen
   ------------------------------------------------------------ */

function applySettings() {
    const s = state.settings;
    const root = document.documentElement.style;
    root.setProperty('--scale', s.scale / 100);
    root.setProperty('--accent', s.accent);
    root.setProperty('--accent-soft', hexToRgba(s.accent, 0.35));

    document.body.classList.toggle('show-values', s.values);

    ELEMENTS.forEach(([key]) => {
        $$(`[data-el="${key}"]`).forEach((el) => el.classList.toggle('off', !!s.hidden[key]));
    });

    if (!$('#job').textContent) $('#job-row').classList.add('off');

    $('#unit').textContent = unit() === 'mph' ? 'MPH' : 'KM/U';
    renderStatus();
    renderVehicle();
}

function renderSettingsUI() {
    const s = state.settings;
    $('#opt-scale').value = s.scale;
    $('#scale-val').textContent = `${s.scale}%`;
    $('#opt-values').checked = s.values;
    $('#opt-autohide').checked = s.autohide;

    $$('#opt-unit button').forEach((b) => b.classList.toggle('active', b.dataset.v === unit()));
    $$('.swatch').forEach((b) => b.classList.toggle('active', b.dataset.c === s.accent));
    $$('#element-toggles input').forEach((inp) => { inp.checked = !s.hidden[inp.dataset.key]; });
}

function buildSettings() {
    $('#swatches').innerHTML = ACCENTS
        .map((c) => `<button class="swatch" data-c="${c}" style="background:${c}" aria-label="${c}"></button>`)
        .join('');

    $('#element-toggles').innerHTML = ELEMENTS
        .map(([key, label]) => `<label class="toggle-row"><span>${label}</span><input type="checkbox" data-key="${key}"><i></i></label>`)
        .join('');

    const update = (fn) => { fn(state.settings); saveSettings(); applySettings(); renderSettingsUI(); };

    $('#opt-scale').addEventListener('input', (e) => update((s) => { s.scale = +e.target.value; }));
    $('#opt-values').addEventListener('change', (e) => update((s) => { s.values = e.target.checked; }));
    $('#opt-autohide').addEventListener('change', (e) => update((s) => { s.autohide = e.target.checked; }));
    $('#swatches').addEventListener('click', (e) => {
        const c = e.target.dataset.c;
        if (c) update((s) => { s.accent = c; });
    });
    $('#opt-unit').addEventListener('click', (e) => {
        const v = e.target.dataset.v;
        if (v) update((s) => { s.unit = v; });
    });
    $('#element-toggles').addEventListener('change', (e) => {
        const key = e.target.dataset.key;
        if (key) update((s) => { s.hidden[key] = !e.target.checked; });
    });
    $('#reset-settings').addEventListener('click', () => update((s) => {
        Object.assign(s, { ...DEFAULTS, hidden: {} });
    }));

    $('#close-settings').addEventListener('click', closeSettings);
    $('#done-settings').addEventListener('click', closeSettings);
    $('#settings').addEventListener('click', (e) => { if (e.target.id === 'settings') closeSettings(); });
    document.addEventListener('keydown', (e) => {
        if ((e.key === 'Escape' || e.key === 'Backspace') && !$('#settings').classList.contains('hidden')) closeSettings();
    });
}

function openSettings() {
    renderSettingsUI();
    $('#settings').classList.remove('hidden');
}

function closeSettings() {
    $('#settings').classList.add('hidden');
    post('closeSettings');
}

/* ------------------------------------------------------------
   Render: status
   ------------------------------------------------------------ */

function setRing(key, value) {
    const ring = $(`#ring-${key}`);
    if (!ring) return;

    const available = value !== false && value !== null && value !== undefined;
    const auto = !!(state.settings.autohide && AUTOHIDE[key] && available && AUTOHIDE[key](value));
    ring.classList.toggle('collapsed', !available || auto);
    if (!available) return;

    const v = Math.max(0, Math.min(100, value));
    ring.style.setProperty('--v', v / 100);
    ring.querySelector('.ring-val').textContent = Math.round(v);
    ring.classList.toggle('low', LOW[key](v) && !state.status.dead);
    ring.classList.toggle('dead', !!state.status.dead);
}

function renderStatus() {
    const s = state.status;
    ['health', 'armor', 'hunger', 'thirst', 'stress', 'stamina', 'oxygen'].forEach((k) => {
        if (k in s) setRing(k, s[k]);
    });

    const voice = $('#ring-voice');
    const mode = s.voiceMode || 2;
    voice.classList.toggle('talking', !!s.talking || !!s.radio);
    voice.classList.toggle('radio', !!s.radio);
    voice.style.setProperty('--v', mode / 3);
    voice.querySelectorAll('.voice-bars i').forEach((bar, i) => bar.classList.toggle('on', i < mode));
}

/* ------------------------------------------------------------
   Render: voertuig
   ------------------------------------------------------------ */

function renderVehicle() {
    const v = state.vehicle;
    const el = $('#vehicle');
    el.classList.toggle('away', !v.inVehicle);
    if (!v.inVehicle) return;

    el.classList.toggle('air', v.type === 'air');
    el.classList.toggle('no-belt', v.hasBelt === false);

    const mph = unit() === 'mph';
    const speed = Math.round((v.speed || 0) * (mph ? 0.621371 : 1));
    // 087 -> voorloopnullen gedimd
    const digits = String(Math.min(speed, 999));
    $('#speed').innerHTML = '<i>0</i>'.repeat(3 - digits.length) + digits;

    const rpm = Math.min(v.rpm || 0, 1);
    const lit = Math.round(rpm * RPM_SEGMENTS);
    $$('#rpm i').forEach((seg, i) => {
        seg.classList.toggle('on', i < lit);
        seg.classList.toggle('red', i >= RPM_SEGMENTS * 0.8);
    });

    const gear = $('#gear');
    gear.textContent = v.gear ?? 'N';
    gear.classList.toggle('reverse', v.gear === 'R');

    if (v.altitude !== false && v.altitude !== undefined) $('#alt-val').textContent = v.altitude;

    const fuel = Math.max(0, Math.min(100, v.fuel ?? 100));
    const lowFuel = fuel <= state.config.lowFuel;
    $('#fuel-fill').style.width = `${fuel}%`;
    $('#fuel-val').textContent = `${fuel}%`;
    $('#fuel-bar').classList.toggle('low', lowFuel);
    $('#ic-fuel').classList.toggle('show', lowFuel);

    const engine = Math.max(0, Math.min(100, v.engine ?? 100));
    $('#engine-fill').style.width = `${engine}%`;
    $('#engine-val').textContent = `${engine}%`;
    $('#engine-bar').classList.toggle('low', engine <= 30);

    $('#ic-engine').classList.toggle('on', !!v.engineOn);
    $('#ic-engine').classList.toggle('alert', engine <= 15);

    const lights = $('#ic-lights');
    lights.classList.toggle('on', !!v.lights);
    lights.classList.toggle('high', !!v.highbeam);

    renderSeatbelt();
}

function renderSeatbelt() {
    const belt = $('#ic-belt');
    belt.classList.toggle('on', state.seatbelt);
    belt.classList.toggle('alert', !state.seatbelt && (state.vehicle.speed || 0) > 25);
}

/* ------------------------------------------------------------
   Render: locatie & info
   ------------------------------------------------------------ */

let compassHeading = 0;
function renderHeading(h) {
    const strip = $('#compass-strip');
    const delta = Math.abs(h - compassHeading);
    strip.style.transition = delta > 180 ? 'none' : '';
    compassHeading = h;
    strip.style.transform = `translateX(${165 - (h + 180) * 3}px)`;

    const dirs = ['N', 'NO', 'O', 'ZO', 'Z', 'ZW', 'W', 'NW'];
    $('#dir').textContent = dirs[Math.round(h / 45) % 8];
    $('#heading').textContent = `${h}°`;
}

function setMoney(key, value) {
    const row = $(`#${key}-row`);
    row.classList.toggle('off', value === false || value === null || value === undefined);
    if (row.classList.contains('off')) return;

    const el = $(`#${key}`);
    const prev = state.money[key];
    el.textContent = fmtMoney(value);
    if (prev !== null && prev !== value) {
        el.classList.remove('flash-up', 'flash-down');
        void el.offsetWidth; // animatie herstarten
        el.classList.add(value > prev ? 'flash-up' : 'flash-down');
    }
    state.money[key] = value;
}

/* ------------------------------------------------------------
   Berichten vanuit Lua
   ------------------------------------------------------------ */

const handlers = {
    init(d) {
        Object.assign(state.config, d);
        applySettings();
    },

    visible(d) {
        if ('hud' in d) $('#hud').classList.toggle('hidden', !d.hud);
        if ('cinematic' in d) $('#cinema').classList.toggle('active', !!d.cinematic);
    },

    status(d) {
        Object.assign(state.status, d);
        renderStatus();
    },

    vehicle(d) {
        if (d.inVehicle === false) state.vehicle = { inVehicle: false };
        else Object.assign(state.vehicle, d);
        renderVehicle();
    },

    seatbelt(d) {
        const was = state.seatbelt;
        state.seatbelt = !!d.on;
        if (was !== state.seatbelt) beep(state.seatbelt ? [880, 1320] : [660, 440]);
        renderSeatbelt();
    },

    location(d) {
        if ('street' in d) $('#street').textContent = d.street || '—';
        if ('cross' in d) {
            $('#cross').textContent = d.cross || '';
            $('#cross-sep').classList.toggle('off', !d.cross);
        }
        if ('zone' in d) $('#zone').textContent = d.zone || '';
        if ('heading' in d) renderHeading(d.heading);
    },

    info(d) {
        if ('time' in d) $('#clock').textContent = d.time;
        if ('id' in d) $('#pid').textContent = `ID ${d.id}`;
        if ('cash' in d) setMoney('cash', d.cash);
        if ('bank' in d) setMoney('bank', d.bank);
        if ('job' in d) {
            $('#job-row').classList.toggle('off', !d.job || !!state.settings.hidden.job);
            $('#job').textContent = d.job || '';
        }
    },

    minimap(d) {
        const root = document.documentElement.style;
        if ('left' in d) {
            root.setProperty('--mm-left', `${d.left * 100}vw`);
            root.setProperty('--mm-right', `${d.right * 100}vw`);
            root.setProperty('--mm-top', `${d.top * 100}vh`);
            root.setProperty('--mm-bottom', `${d.bottom * 100}vh`);
        }
        if ('visible' in d) {
            $('#status').classList.toggle('above-map', !!d.visible);
            $('#location').classList.toggle('beside-map', !!d.visible);
            const fake = $('.minimap-fake');
            if (fake) fake.style.opacity = d.visible ? 1 : 0;
        }
    },

    openSettings() {
        openSettings();
    },
};

window.addEventListener('message', (e) => {
    const msg = e.data;
    if (!msg || !msg.action) return;
    const fn = handlers[msg.action];
    if (fn) fn(msg.data || {});
});

/* ------------------------------------------------------------
   Start
   ------------------------------------------------------------ */

buildCompass();
buildRpm();
buildSettings();
applySettings();
renderHeading(0);

/* ------------------------------------------------------------
   Voorbeeldmodus (buiten FiveM, bv. in je browser)
   ------------------------------------------------------------ */

if (!IS_FIVEM) startPreview();

function startPreview() {
    document.body.classList.add('preview');
    const fake = document.createElement('div');
    fake.className = 'minimap-fake';
    document.body.prepend(fake);

    const emit = (action, data) => handlers[action](data);
    emit('init', { framework: 'qb', speedUnit: 'kmh', lowFuel: 20 });
    emit('minimap', { left: 0.015, right: 0.155, top: 0.78, bottom: 0.965 });
    emit('info', { time: '21:37', id: 12, cash: 2450, bank: 48210, job: 'Politie · Agent' });
    emit('location', { street: 'Vespucci Boulevard', cross: 'Palomino Ave', zone: 'Mission Row', heading: 0 });

    let inVeh = true;
    let talking = false;
    let t = 0;
    let speed = 0;

    emit('visible', { hud: true, cinematic: false });

    setInterval(() => {
        t += 0.05;
        speed = inVeh ? Math.max(0, 110 + Math.sin(t * 0.7) * 90) : 0;
        emit('status', {
            health: Math.round(70 + Math.sin(t * 0.3) * 25),
            armor: 45,
            hunger: Math.round(55 + Math.sin(t * 0.2) * 40),
            thirst: 64,
            stress: Math.round(Math.max(0, Math.sin(t * 0.25) * 60)),
            stamina: Math.round(80 + Math.sin(t) * 20),
            oxygen: false,
            talking,
            radio: false,
            voiceMode: 2,
            dead: false,
        });
        if (inVeh) {
            emit('vehicle', {
                inVehicle: true,
                type: 'car',
                speed: Math.round(speed),
                rpm: +(0.25 + ((speed % 60) / 60) * 0.75).toFixed(2),
                gear: speed < 1 ? 'N' : String(Math.min(6, 1 + Math.floor(speed / 60))),
                fuel: Math.round(18 + Math.abs(Math.sin(t * 0.05)) * 60),
                engine: 88,
                engineOn: true,
                lights: true,
                highbeam: false,
                altitude: false,
                hasBelt: true,
            });
        } else {
            emit('vehicle', { inVehicle: false });
        }
        emit('minimap', { visible: inVeh });
        emit('location', { heading: Math.round(((t * 12) % 360 + 360) % 360) });
    }, 60);
}
