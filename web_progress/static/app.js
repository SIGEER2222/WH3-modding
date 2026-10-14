/* 战锤3 战役进度仪表盘 */
"use strict";

const CAMPAIGN_NAMES = {
  "wh3_main_combi": "帝国争霸 Immortal Empires",
  "wh3_main_chaos": "混沌魔域 Realms of Chaos",
  "wh3_dlc23_prologue": "序章 Prologue",
};

// 常见原版派系 key 的中文名（未命中的显示原 key）
const FACTION_NAMES = {
  "wh3_main_emp_empire": "帝国",
  "wh_main_emp_empire": "帝国",
  "wh3_main_dwf_dwarfs": "矮人",
  "wh_main_dwf_dwarfs": "矮人",
  "wh3_main_grn_greenskins": "绿皮",
  "wh_main_grn_greenskins": "绿皮",
  "wh3_main_ksl_kislev": "基斯里夫",
  "wh3_main_cth_cathay": "震旦",
  "wh3_main_brt_bretonnia": "巴托尼亚",
  "wh_main_brt_bretonnia": "巴托尼亚",
  "wh3_main_hef_high_elves": "高等精灵",
  "wh_main_hef_high_elves": "高等精灵",
  "wh3_main_def_dark_elves": "黑暗精灵",
  "wh_main_def_dark_elves": "黑暗精灵",
  "wh3_main_lzd_lizardmen": "蜥蜴人",
  "wh_main_lzd_lizardmen": "蜥蜴人",
  "wh3_main_skv_skaven": "斯卡文鼠人",
  "wh_main_skv_skaven": "斯卡文鼠人",
  "wh3_main_chs_chaos": "混沌勇士",
  "wh_main_chs_chaos": "混沌勇士",
  "wh3_main_nor_norsca": "诺斯卡",
  "wh3_main_vmp_vampire_counts": "吸血鬼伯爵",
  "wh_main_vmp_vampire_counts": "吸血鬼伯爵",
  "wh3_main_teb_tomb_kings": "古墓王",
  "wh2_teb_tomb_kings": "古墓王",
  "wh3_main_wef_wood_elves": "木精灵",
  "wh_main_wef_wood_elves": "木精灵",
  "wh3_dlc20_ogr_ogre_kingdoms": "食人魔王国",
  "wh3_main_ogr_ogre_kingdoms": "食人魔王国",
  "wh3_dlc13_nur_nurgle": "纳垢",
  "wh3_dlc13_kho_khorne": "恐虐",
  "wh3_dlc13_sla_slaanesh": "色孽",
  "wh3_dlc13_tze_tzeentch": "奸奇",
  "wh3_dlc03_bst_beastmen": "野兽人",
  "wh2_main_lzd_hexoatl": "赫斯奥塔",
  "wh2_main_def_naggarond": "纳迦隆德",
  "wh2_main_hef_avelorn": "阿维隆",
  "wh2_dlc11_cst_vampire_coast": "吸血鬼海岸",
  "wh3_dlc26_kho_skulltaker": "取颅者",
  "wh3_dlc29_nag_host_of_nagash": "纳迦什军团",
};

const TYPE_NAMES = {
  general: "领主", engineer: "工程师", colonel: "驻军官", spy: "间谍",
  wizard: "法师", champion: "勇士", dignitary: "使节", assassin: "刺客",
};

const STANCE_NAMES = { war: "交战", neutral: "中立", master: "宗主", vassal: "附庸",
  military_alliance: "军事同盟", defensive_alliance: "防御同盟", trade: "贸易" };

const EVENT_STYLES = {
  war_declared: { icon: "⚔", cat: "war", text: (e) => `宣战：对 ${factionDisplay(e.key)}` },
  war_ended: { icon: "☮", cat: "war", text: (e) => `停战：与 ${factionDisplay(e.key)}` },
  faction_destroyed: { icon: "☠", cat: "faction", text: (e) => `派系灭亡：${factionDisplay(e.key)}` },
  faction_emerged: { icon: "✦", cat: "faction", text: (e) => `派系出现：${factionDisplay(e.key)}` },
  units_dropped: { icon: "▼", cat: "military", text: (e) => `军力骤减：${factionDisplay(e.key)}（${e.detail.delta} 单位）` },
  units_surge: { icon: "▲", cat: "military", text: (e) => `军力激增：${factionDisplay(e.key)}（+${e.detail.delta} 单位）` },
  forces_dropped: { icon: "⬇", cat: "military", text: (e) => `军团被歼：${factionDisplay(e.key)}（−${-e.detail.delta} 队）` },
  forces_surge: { icon: "⬆", cat: "military", text: (e) => `军团扩充：${factionDisplay(e.key)}（+${e.detail.delta} 队）` },
  characters_dropped: { icon: "💀", cat: "military", text: (e) => `角色折损：${factionDisplay(e.key)}（−${-e.detail.delta} 名）` },
  player_characters_changed: { icon: "👤", cat: "military", text: (e) => e.detail.delta > 0 ? `新角色加入：+${e.detail.delta} 名` : `角色折损：${e.detail.delta} 名` },
  building_completed: { icon: "🏛", cat: "building", text: (e) => `${shortRegion(e.key)} 建成 ${shortBuilding(e.detail.building)}` },
  building_lost: { icon: "🔥", cat: "building", text: (e) => `${shortRegion(e.key)} 失去 ${shortBuilding(e.detail.building)}` },
  ancillary_gained: { icon: "🎁", cat: "player", text: (e) => `获得装备：${shortBuilding(e.detail.item)}` },
  ancillary_lost: { icon: "📤", cat: "player", text: (e) => `失去装备：${shortBuilding(e.detail.item)}` },
  mission_issued: { icon: "📜", cat: "player", text: (e) => `发布任务：${missionName(e.detail.mission)}（${missionStatus(e.detail.status)}）` },
  mission_status: { icon: "📜", cat: "player", text: (e) => `任务 ${missionName(e.detail.mission)}：${missionStatus(e.detail.from)} → ${missionStatus(e.detail.to)}` },
  storm_spawned: { icon: "🌪", cat: "world", text: (e) => `魔法风暴生成：${stormName(e.detail.storm)}` },
  storm_ended: { icon: "🌤", cat: "world", text: (e) => `风暴消散：${stormName(e.detail.storm)}` },
  crisis_triggered: { icon: "🌋", cat: "world", text: () => `终局危机触发！` },
};

const EVENT_CATS = [
  { id: "war", label: "战争 ⚔" },
  { id: "faction", label: "派系兴亡 ☠" },
  { id: "military", label: "军力 ⚔" },
  { id: "building", label: "建筑 🏛" },
  { id: "player", label: "任务/装备 📜" },
  { id: "world", label: "世界 🌪" },
];

const STATUS_NAMES = { SUCCEEDED: "已完成", ACTIVE: "进行中", FAILED: "失败", CANCELLED: "已取消", COMPLETED: "已完成" };

function missionStatus(s) { return STATUS_NAMES[s] || s || "?"; }
function missionName(id) {
  if (!id) return "?";
  const m = id.match(/_v\d+$/);
  return (m ? id.slice(0, m.index) : id).split("_").slice(-3).join("_");
}
function shortRegion(k) { return (k || "").replace(/^wh[0-9a-z_]*_region_/, ""); }
function shortBuilding(k) {
  if (!k) return "?";
  return k.split("_").slice(-2).join("_");
}
function stormName(k) { return (k || "").replace(/^wandering_/, "").replace(/_/g, " "); }

const RIVAL_COLORS = ["#e8c87e", "#d96b5b", "#7fae7d", "#6b9bd9", "#b58ad9", "#d9c16b"];

// server-provided name maps (per latest summary/timeline response)
let FACTION_CN = {};
let REGION_CN = {};

function mergeNames(summary) {
  const n = (summary && summary.names) || {};
  Object.assign(FACTION_CN, n.factions || {});
  Object.assign(REGION_CN, n.regions || {});
}

function factionDisplay(key) {
  if (!key) return "?";
  return FACTION_CN[key] || FACTION_NAMES[key] || key;
}
function typeDisplay(t) { return TYPE_NAMES[t] || t || "?"; }

function fmtNum(n) {
  if (n === null || n === undefined) return "–";
  return Number(n).toLocaleString("zh-CN");
}

const el = (id) => document.getElementById(id);

async function api(path) {
  const res = await fetch(path);
  const obj = await res.json();
  if (!res.ok) throw new Error(obj.error || ("HTTP " + res.status));
  return obj;
}

function show(id, on) { el(id).classList.toggle("hidden", !on); }

async function loadSaves() {
  const data = await api("/api/saves");
  const sel = el("save-select");
  sel.innerHTML = "";
  if (data.error || !data.saves.length) {
    const opt = document.createElement("option");
    opt.textContent = data.error || "未找到存档";
    sel.appendChild(opt);
    return null;
  }
  for (const s of data.saves) {
    const opt = document.createElement("option");
    opt.value = s.id;
    const d = new Date(s.mtime * 1000);
    opt.textContent = `${s.name}  (${d.toLocaleString("zh-CN")})`;
    sel.appendChild(opt);
  }
  return data.saves[0].id;
}

function rankRows(container, rows, playerKey, valFmt) {
  container.innerHTML = "";
  const max = Math.max(...rows.map((r) => r.val), 1);
  for (const r of rows) {
    const row = document.createElement("div");
    row.className = "rank-row" + (r.key === playerKey ? " player" : "");
    const name = document.createElement("div");
    name.className = "name";
    name.textContent = factionDisplay(r.key);
    name.title = r.key;
    const wrap = document.createElement("div");
    wrap.className = "bar-wrap";
    const bar = document.createElement("div");
    bar.className = "bar";
    bar.style.width = Math.max((r.val / max) * 100, 1.5) + "%";
    wrap.appendChild(bar);
    const val = document.createElement("div");
    val.className = "val";
    val.textContent = valFmt(r.val);
    row.appendChild(name); row.appendChild(wrap); row.appendChild(val);
    container.appendChild(row);
  }
}

function render(summary) {
  mergeNames(summary);
  const save = summary.save;
  const player = summary.player || {};
  el("turn").textContent = save.turn ?? "–";
  el("season").textContent = save.season || "";
  el("player-name").textContent = save.player_faction_name || factionDisplay(save.player_faction_key);
  el("player-key").textContent = save.player_faction_key || "";
  el("campaign").textContent = save.campaign_cn || CAMPAIGN_NAMES[save.campaign] || save.campaign || "?";
  el("version").textContent = save.version || "";
  const sf = summary.save_file || {};
  const dt = sf.mtime ? new Date(sf.mtime * 1000).toLocaleString("zh-CN") : "";
  el("save-meta").textContent = `存档：${save.name || sf.name || ""} · 保存于 ${dt}`;

  const cards = [
    [fmtNum(player.treasury), "金库"],
    [fmtNum((player.regions || []).length), "城市数"],
    [fmtNum(player.forces), "军团数"],
    [fmtNum(player.units), "总单位数"],
    [fmtNum(player.characters ? player.characters.length : 0), "角色数"],
    [fmtNum(summary.world.faction_count), "存活派系"],
    [fmtNum(summary.world.region_count), "地图地区"],
    [fmtNum((save.mods || []).length), "已加载 MOD"],
  ];
  el("cards").innerHTML = "";
  for (const [num, label] of cards) {
    const c = document.createElement("div");
    c.className = "card";
    c.innerHTML = `<div class="num">${num}</div><div class="label">${label}</div>`;
    el("cards").appendChild(c);
  }

  const pk = save.player_faction_key;
  const byTreasury = summary.factions
    .filter((f) => f.key && typeof f.treasury === "number")
    .sort((a, b) => b.treasury - a.treasury).slice(0, 12)
    .map((f) => ({ key: f.key, val: f.treasury }));
  rankRows(el("rank-treasury"), byTreasury, pk, fmtNum);

  const byUnits = summary.factions
    .filter((f) => f.key)
    .sort((a, b) => (b.units || 0) - (a.units || 0)).slice(0, 12)
    .map((f) => ({ key: f.key, val: f.units || 0 }));
  rankRows(el("rank-units"), byUnits, pk, (v) => fmtNum(v));

  // forces (schema>=5: player.armies carries names/location/commander/power)
  const armies = player.armies || [];
  el("force-count").textContent = armies.length ? `共 ${armies.length} 队` :
    (player.forces ? `共 ${player.forces} 队` : "");
  const forces = el("forces");
  forces.innerHTML = "";
  armies.slice(0, 10).forEach((a, i) => {
    const d = document.createElement("div");
    d.className = "force";
    const head = document.createElement("div");
    head.className = "force-head";
    const bits = [];
    if (a.garrison_cn) bits.push(`驻军·${a.garrison_cn}`);
    else if (a.location_cn) bits.push(a.location_cn);
    if (a.power_estimate) bits.push(`战力≈${fmtNum(a.power_estimate)}`);
    bits.push(`${a.unit_count} 单位`);
    const title = (a.name ? `「${a.name}」` : `军团 #${i + 1}`) +
      (a.commander_cn ? ` · ${a.commander_cn}` : "");
    head.innerHTML = `<span>${title}</span><span class="dim">${bits.join(" · ")}</span>`;
    head.classList.add("clickable");
    head.title = "点击查看兵种与加成明细";
    head.addEventListener("click", () => toggleArmyDetail(d, i));
    const list = document.createElement("div");
    list.className = "force-units";
    const groups = new Map();
    for (const u of (a.units || [])) {
      const nm = u.name_cn || u.key || "?";
      if (!groups.has(nm)) groups.set(nm, { n: 0, str: [], rank: [], keys: u.key });
      const g = groups.get(nm);
      g.n += 1;
      if (u.strength) g.str.push(u.strength);
      if (u.rank) g.rank.push(u.rank);
    }
    for (const [nm, g] of groups) {
      const chip = document.createElement("span");
      chip.className = "unit-chip";
      let txt = nm + (g.n > 1 ? `×${g.n}` : "");
      if (g.str.length) {
        const kind = g.str[0][1] <= 200 ? "" : "HP";
        txt += ` ${g.str.map((s) => `${s[0]}/${s[1]}`).join(",")}${kind}`;
      }
      if (g.rank.length) txt += ` 经验${g.rank.join("/")}`;
      chip.textContent = txt;
      chip.title = g.keys || "";
      list.appendChild(chip);
    }
    d.appendChild(head); d.appendChild(list);
    forces.appendChild(d);
  });
  if (armies.length > 10) {
    const more = document.createElement("div");
    more.className = "dim";
    more.textContent = `…还有 ${armies.length - 10} 队未显示`;
    forces.appendChild(more);
  }
  if (!armies.length && (player.force_units || []).length) {
    const more = document.createElement("div");
    more.className = "dim";
    more.textContent = "旧缓存数据——重新解析存档以查看军团详情";
    forces.appendChild(more);
  }

  // characters (schema>=7: members carry name/subtype/rank/xp/skill points)
  const members = player.members || [];
  const chars = members.length ? members : (player.characters || []);
  el("char-count").textContent = `共 ${chars.length} 名`;
  const cwrap = el("characters");
  cwrap.innerHTML = "";
  chars.slice(0, 14).forEach((c) => {
    const row = document.createElement("div");
    row.className = "char-row";
    const nm = c.name_cn ? `${c.name_cn} · ` : "";
    const tp = c.subtype_cn || c.type_cn || typeDisplay(c.type);
    const bits = [];
    if (c.rank !== null && c.rank !== undefined) bits.push(`Lv.${c.rank}`);
    if (c.xp) bits.push(`XP ${fmtNum(c.xp)}`);
    if (c.skill_points) bits.push(`未分配技能点 ${c.skill_points}`);
    if (c.army) bits.push(`领「${c.army}」`);
    else if (c.near_cn) bits.push(`近 ${c.near_cn}`);
    else if (c.x !== null && c.x !== undefined) bits.push(`(${c.x.toFixed(0)}, ${c.y.toFixed(0)})`);
    row.innerHTML = `<span class="ctype">${nm}${tp}</span>` +
      `<span class="crank">${bits.join(" · ")}</span>` +
      `<span class="cpos"></span>`;
    cwrap.appendChild(row);
  });
  if (chars.length > 14) {
    const more = document.createElement("div");
    more.className = "dim";
    more.textContent = `…还有 ${chars.length - 14} 名未显示`;
    cwrap.appendChild(more);
  }

  // mods
  const mods = save.mods || [];
  el("mod-count").textContent = `共 ${mods.length} 项`;
  const mwrap = el("mods");
  mwrap.innerHTML = "";
  for (const m of mods) {
    const d = document.createElement("div");
    const idPart = m.id && !/^\d+$/.test(m.id) ? "" : (m.id ? ` <span class="dim">(${m.id})</span>` : "");
    d.innerHTML = `<code>${m.pack}</code>${idPart}`;
    mwrap.appendChild(d);
  }

  renderDiplomacy(player, pk);
  renderSnapshotExtras(save, player, summary);

  show("content", true);
}

function renderSnapshotExtras(save, player, summary) {
  // missions
  const missions = player.missions || [];
  el("snap-mission-count").textContent = `共 ${missions.length} 项`;
  const mwrap = el("snap-missions");
  mwrap.innerHTML = "";
  const order = { ACTIVE: 0, SUCCEEDED: 1, FAILED: 2, CANCELLED: 3 };
  missions.sort((a, b) => (order[a.status] ?? 9) - (order[b.status] ?? 9));
  for (const m of missions.slice(0, 24)) {
    const row = document.createElement("div");
    row.className = "mission-row";
    const cls = m.status === "ACTIVE" ? "st-active" : (m.status === "SUCCEEDED" ? "st-done" : "st-off");
    const tip = (m.id || "") + (m.desc_cn ? " — " + m.desc_cn.split("\n").join(" ") : "");
    row.innerHTML = `<span class="st ${cls}">${m.status_cn || missionStatus(m.status)}</span>` +
      `<span class="mn" title="${tip}">${m.title_cn || missionName(m.id)}</span>`;
    mwrap.appendChild(row);
  }
  if (missions.length > 24) {
    const more = document.createElement("div");
    more.className = "dim";
    more.textContent = `…还有 ${missions.length - 24} 项`;
    mwrap.appendChild(more);
  }
  if (!missions.length) mwrap.innerHTML = '<div class="dim">未读到任务数据</div>';

  // ancillaries
  const anc = player.ancillary_named ||
    (player.ancillaries || []).map((a) => ({ key: a, name: a }));
  el("snap-anc-count").textContent = `共 ${anc.length} 件`;
  const awrap = el("snap-ancillaries");
  awrap.innerHTML = "";
  for (const a of anc.slice(0, 30)) {
    const chip = document.createElement("span");
    chip.className = "unit-chip";
    chip.textContent = a.name || shortBuilding(a.key);
    chip.title = a.key;
    awrap.appendChild(chip);
  }
  if (anc.length > 30) {
    const more = document.createElement("span");
    more.className = "unit-chip";
    more.textContent = `+${anc.length - 30}`;
    awrap.appendChild(more);
  }
  if (!anc.length) awrap.innerHTML = '<div class="dim">无装备数据</div>';

  // world state
  const w = summary.world || {};
  const bits = [];
  bits.push(`终局危机：${w.crisis_triggered ? "已触发" : "未触发"}`);
  bits.push(`活跃魔法风暴：${(w.storms || []).length} 场`);
  el("snap-world").innerHTML = bits.map((b) => `<div>${b}</div>`).join("");
}

function renderDiplomacy(player, playerKey) {
  const wrap = el("tl-wars");
  const diplo = player.diplomacy || [];
  const wars = diplo.filter((d) => d.stance === "war" && d.key);
  el("tl-war-count").textContent = `交战 ${wars.length} 家`;
  wrap.innerHTML = "";
  wars.forEach((d) => {
    const row = document.createElement("div");
    row.className = "war-row";
    row.innerHTML = `<span>${d.name_cn || factionDisplay(d.key)}</span>` +
      `<span class="dim">${d.key}${d.attitude != null ? " · 态度 " + d.attitude : ""}</span>`;
    wrap.appendChild(row);
  });
  if (!wars.length) {
    wrap.innerHTML = '<div class="dim">当前无交战对象</div>';
  }
  // notable non-war stances
  const special = diplo.filter((d) => d.stance && d.stance !== "war" && d.stance !== "neutral" && d.key);
  if (special.length) {
    const h = document.createElement("div");
    h.className = "dim";
    h.style.marginTop = "8px";
    h.textContent = "其他关系：";
    wrap.appendChild(h);
    special.slice(0, 8).forEach((d) => {
      const row = document.createElement("div");
      row.className = "war-row";
      row.innerHTML = `<span>${d.name_cn || factionDisplay(d.key)}</span>` +
        `<span>${d.stance_cn || STANCE_NAMES[d.stance] || d.stance}</span>`;
      wrap.appendChild(row);
    });
  }
}

/* ---------- timeline (cross-save diff) ---------- */

function svgLineChart(seriesList, turns, opts) {
  const W = 1100, H = 220, PL = 64, PR = 16, PT = 22, PB = 26;
  const iw = W - PL - PR, ih = H - PT - PB;
  const vals = seriesList.flatMap((s) => s.values.filter((v) => v !== null && v !== undefined));
  if (!vals.length || turns.length < 2) return null;
  const vmax = Math.max(...vals), vmin = Math.min(...vals, 0);
  const xs = (turn) => PL + ((turn - turns[0]) / Math.max(turns[turns.length - 1] - turns[0], 1)) * iw;
  const ys = (v) => PT + ih - ((v - vmin) / Math.max(vmax - vmin, 1)) * ih;
  let grid = "";
  for (let i = 0; i <= 4; i++) {
    const v = vmin + ((vmax - vmin) * i) / 4;
    grid += `<line class="chart-grid" x1="${PL}" y1="${ys(v)}" x2="${W - PR}" y2="${ys(v)}"/>` +
      `<text class="chart-label" x="${PL - 6}" y="${ys(v) + 3}" text-anchor="end">${fmtNum(Math.round(v))}</text>`;
  }
  const tstep = Math.max(Math.round(turns.length / 8), 1);
  let xlabels = "";
  turns.forEach((t, i) => {
    if (i % tstep === 0 || i === turns.length - 1) {
      xlabels += `<text class="chart-label" x="${xs(t)}" y="${H - 8}" text-anchor="middle">${t}</text>`;
    }
  });
  let lines = "";
  for (const s of seriesList) {
    const pts = turns.map((t, i) => {
      const v = s.values[i];
      return v === null || v === undefined ? null : `${xs(t).toFixed(1)},${ys(v).toFixed(1)}`;
    }).filter(Boolean).join(" ");
    lines += `<polyline fill="none" stroke="${s.color}" stroke-width="${s.width || 1.6}" points="${pts}"/>`;
  }
  return `<div class="legend">${seriesList.map((s) =>
    `<span><span class="sw" style="background:${s.color}"></span>${s.label}</span>`).join("")}</div>` +
    `<svg viewBox="0 0 ${W} ${H}" preserveAspectRatio="xMidYMid meet">` +
    `<text class="chart-title" x="${PL}" y="14">${opts.title}</text>` +
    `<line class="chart-axis" x1="${PL}" y1="${PT + ih}" x2="${W - PR}" y2="${PT + ih}"/>` +
    grid + xlabels + lines + "</svg>";
}

/* ---------- chronicle: filters + flow/chapter views ---------- */

const TL_STATE = {
  data: null,
  cats: new Set(EVENT_CATS.map((c) => c.id)),
  onlyPlayer: true,
  mode: "flow",
  shown: 300,
};

function eventMatches(e) {
  const st = EVENT_STYLES[e.type];
  if (!st || !TL_STATE.cats.has(st.cat)) return false;
  if (TL_STATE.onlyPlayer && e.scope !== "player") return false;
  return true;
}

function renderFilters() {
  const wrap = el("tl-filters");
  wrap.innerHTML = "";
  for (const c of EVENT_CATS) {
    const chip = document.createElement("button");
    chip.className = "tl-chip" + (TL_STATE.cats.has(c.id) ? " on" : "");
    chip.textContent = c.label;
    chip.addEventListener("click", () => {
      if (TL_STATE.cats.has(c.id)) TL_STATE.cats.delete(c.id);
      else TL_STATE.cats.add(c.id);
      renderFilters();
      renderChronicle();
    });
    wrap.appendChild(chip);
  }
}

function evRow(e) {
  const st = EVENT_STYLES[e.type];
  const row = document.createElement("div");
  row.className = `tl-ev ${e.type}`;
  row.innerHTML = `<span class="t">T${e.turn}</span><span class="ic">${st.icon}</span>` +
    `<span>${e.text_cn || st.text(e)}</span>`;
  return row;
}

function renderLatest() {
  const wrap = el("tl-latest");
  wrap.innerHTML = "";
  const pts = (TL_STATE.data && TL_STATE.data.points) || [];
  if (pts.length < 2) return;
  const lastTurn = pts[pts.length - 1].turn;
  const latest = (TL_STATE.data.events || []).filter((e) => e.turn === lastTurn && eventMatches(e));
  if (!latest.length) return;
  const box = document.createElement("div");
  box.className = "tl-latest-box";
  const h = document.createElement("h3");
  h.textContent = `上回战况（回合 ${lastTurn}，${latest.length} 起）`;
  box.appendChild(h);
  for (const e of latest.slice(0, 12)) box.appendChild(evRow(e));
  if (latest.length > 12) {
    const more = document.createElement("div");
    more.className = "dim";
    more.textContent = `…还有 ${latest.length - 12} 起`;
    box.appendChild(more);
  }
  wrap.appendChild(box);
}

function renderChapters() {
  const wrap = el("tl-chapters");
  wrap.innerHTML = "";
  const evs = (TL_STATE.data.events || []).filter(eventMatches);
  const buckets = new Map();
  for (const e of evs) {
    const b = Math.floor((e.turn - 1) / 10) * 10 + 1;
    if (!buckets.has(b)) buckets.set(b, []);
    buckets.get(b).push(e);
  }
  const keys = [...buckets.keys()].sort((a, b) => b - a);
  if (!keys.length) {
    wrap.innerHTML = '<div class="dim">当前过滤条件下没有事件</div>';
    return;
  }
  for (const start of keys) {
    const list = buckets.get(start);
    const end = start + 9;
    const counts = {};
    for (const e of list) {
      const cat = EVENT_STYLES[e.type] ? EVENT_STYLES[e.type].cat : "?";
      counts[cat] = (counts[cat] || 0) + 1;
    }
    const summary = EVENT_CATS.filter((c) => counts[c.id])
      .map((c) => `${c.label.split(" ")[0]}×${counts[c.id]}`).join(" · ");
    const det = document.createElement("details");
    det.className = "chapter";
    const sum = document.createElement("summary");
    sum.innerHTML = `<b>回合 ${start}–${end}</b> <span class="dim">${list.length} 起 · ${summary}</span>`;
    det.appendChild(sum);
    const inner = document.createElement("div");
    for (const e of list.slice(0, 60)) inner.appendChild(evRow(e));
    if (list.length > 60) {
      const more = document.createElement("div");
      more.className = "dim";
      more.textContent = `…还有 ${list.length - 60} 起`;
      inner.appendChild(more);
    }
    det.appendChild(inner);
    wrap.appendChild(det);
  }
}

function renderChronicle() {
  const evs = (TL_STATE.data.events || []).filter(eventMatches);
  el("tl-more").classList.add("hidden");
  if (TL_STATE.mode === "flow") {
    el("tl-events").classList.remove("hidden");
    el("tl-chapters").classList.add("hidden");
    const wrap = el("tl-events");
    wrap.innerHTML = "";
    if (!evs.length) {
      wrap.innerHTML = '<div class="dim">当前过滤条件下没有事件——试试放宽过滤器，或取消勾选"只看玩家相关"</div>';
      return;
    }
    for (const e of evs.slice(0, TL_STATE.shown)) wrap.appendChild(evRow(e));
    if (evs.length > TL_STATE.shown) {
      const btn = el("tl-more");
      btn.classList.remove("hidden");
      btn.textContent = `显示更多事件（已显示 ${TL_STATE.shown} / ${evs.length}）`;
    }
  } else {
    el("tl-events").classList.add("hidden");
    el("tl-chapters").classList.remove("hidden");
    renderChapters();
  }
}

function renderTimeline(data) {
  TL_STATE.data = data;
  TL_STATE.shown = 300;
  const charts = el("tl-charts");
  charts.innerHTML = "";
  const turns = data.points.map((p) => p.turn);
  const pk = data.player_key;
  const series = data.series || {};
  const entries = Object.entries(series);
  const playerSeries = entries.find(([k]) => k === pk);
  const rivalSeries = entries.filter(([k]) => k !== pk);

  if (playerSeries) {
    const chart1 = svgLineChart(
      [{ label: playerSeries[1].name_cn || factionDisplay(playerSeries[0]), color: RIVAL_COLORS[0], values: playerSeries[1].units, width: 2.4 },
       ...rivalSeries.map(([k, v], i) => ({ label: v.name_cn || factionDisplay(k), color: RIVAL_COLORS[i + 1] || "#888", values: v.units }))],
      turns, { title: "总单位数（玩家与主要对手）" });
    if (chart1) charts.insertAdjacentHTML("beforeend", chart1);
    const chart2 = svgLineChart(
      [{ label: (playerSeries[1].name_cn || factionDisplay(playerSeries[0])) + " 金库", color: RIVAL_COLORS[0], values: playerSeries[1].treasury, width: 2.4 }],
      turns, { title: "玩家金库曲线" });
    if (chart2) charts.insertAdjacentHTML("beforeend", chart2);
  }

  renderLatest();
  renderChronicle();

  // summary stats
  const pts = data.points;
  const first = pts[0] || {}, last = pts[pts.length - 1] || {};
  const activeNow = last.active_count ?? "–";
  el("tl-summary").innerHTML =
    `<div class="tl-stat">` +
    `<span>快照 <b>${data.save_count}</b> 个</span>` +
    `<span>回合跨度 <b>${first.turn ?? "–"} → ${last.turn ?? "–"}</b></span>` +
    `<span>事件 <b>${(data.events || []).length}</b> 起</span>` +
    `<span>活跃派系 <b>${first.active_count ?? "–"} → ${activeNow}</b></span>` +
    `<span>当前交战 <b>${last.war_count ?? "–"}</b> 家</span>` +
    `</div>`;
}

async function pollTimeline() {
  const st = await api("/api/timeline");
  const btn = el("tl-build");
  const status = el("tl-status");
  if (st.status === "building") {
    btn.disabled = true;
    status.textContent = `正在构建：${st.done}/${st.total} 个存档（已 ${Math.round(st.elapsed / 60)} 分钟）`;
    setTimeout(() => pollTimeline().catch(() => {}), 3000);
  } else if (st.status === "ready") {
    btn.disabled = false;
    renderSessionList(st.active_sessions || []);
    status.textContent = `时间线就绪（${(st.active_sessions || []).length} 个战役会话）`;
    renderTimeline(st.data);
    // 保持自愈：服务端重建后自动跟进
    setTimeout(() => pollTimeline().catch(() => {}), 15000);
  } else if (st.status === "error") {
    btn.disabled = false;
    status.textContent = "构建失败：" + st.error;
  } else {
    btn.disabled = false;
    status.textContent = "尚未构建——点击按钮开始（全部存档首次约 10~20 分钟，之后走缓存秒级完成）";
    setTimeout(() => pollTimeline().catch(() => {}), 15000);
  }
}

function renderSessionList(sessions) {
  const sel = el("tl-session");
  sel.classList.toggle("hidden", sessions.length < 2);
  const current = TL_STATE.data ? TL_STATE.data.session_key : null;
  sel.innerHTML = "";
  for (const s of sessions) {
    const opt = document.createElement("option");
    opt.value = s.key;
    const span = s.turn_span ? `${s.turn_span[0]}–${s.turn_span[1]}` : "?";
    opt.textContent = `会话 ${s.key} · 回合 ${span} · ${s.save_count} 档 · ${s.events} 事件`;
    sel.appendChild(opt);
  }
  if (current) sel.value = current;
}

async function loadTimelineSession(key) {
  const st = await api("/api/timeline?session=" + encodeURIComponent(key));
  if (st.status === "ready") renderTimeline(st.data);
}

async function buildTimeline() {
  el("tl-build").disabled = true;
  await fetch("/api/timeline/build");
  pollTimeline().catch(() => {});
}

let CURRENT_SAVE_ID = null;
let BRIEF_TEXT = "";

async function loadBrief(saveId) {
  const btn = el("brief-btn");
  const pre = el("brief-text");
  btn.disabled = true;
  pre.textContent = "正在生成简报…";
  try {
    const res = await fetch("/api/brief?id=" + saveId + "&format=md");
    BRIEF_TEXT = await res.text();
    pre.textContent = BRIEF_TEXT;
    el("brief-copy").classList.remove("hidden");
  } catch (err) {
    pre.textContent = "生成失败：" + err.message;
  } finally {
    btn.disabled = false;
  }
}

async function copyBrief() {
  try {
    await navigator.clipboard.writeText(BRIEF_TEXT);
    el("brief-copy").textContent = "已复制";
    setTimeout(() => { el("brief-copy").textContent = "复制全文"; }, 1500);
  } catch (err) {
    const ta = document.createElement("textarea");
    ta.value = BRIEF_TEXT;
    document.body.appendChild(ta);
    ta.select();
    document.execCommand("copy");
    ta.remove();
  }
}

async function loadSummary(saveId) {
  show("loading", true);
  show("error", false);
  show("content", false);
  el("loading-text").textContent = "正在读取存档…（首次解析约需 10~20 秒）";
  try {
    CURRENT_SAVE_ID = saveId;
    const summary = await api("/api/summary?id=" + saveId);
    render(summary);
  } catch (err) {
    el("error").textContent = "解析失败：" + err.message;
    show("error", true);
  } finally {
    show("loading", false);
  }
}

async function init() {
  el("reload-btn").addEventListener("click", async () => {
    const id = await loadSaves();
    if (id) loadSummary(id);
  });
  el("save-select").addEventListener("change", (ev) => {
    if (ev.target.value) loadSummary(ev.target.value);
  });
  el("tl-build").addEventListener("click", buildTimeline);
  el("tl-only-player").addEventListener("change", (ev) => {
    TL_STATE.onlyPlayer = ev.target.checked;
    renderLatest();
    renderChronicle();
  });
  el("tl-session").addEventListener("change", (ev) => {
    if (ev.target.value) loadTimelineSession(ev.target.value);
  });
  el("tl-mode-flow").addEventListener("click", () => setMode("flow"));
  el("tl-mode-chapters").addEventListener("click", () => setMode("chapters"));
  el("tl-more").addEventListener("click", () => {
    TL_STATE.shown += 400;
    renderChronicle();
  });
  el("brief-btn").addEventListener("click", () => loadBrief(CURRENT_SAVE_ID));
  el("brief-copy").addEventListener("click", copyBrief);
  renderFilters();
  const first = await loadSaves();
  if (first) loadSummary(first);
  pollTimeline().catch(() => {});
}

function setMode(mode) {
  TL_STATE.mode = mode;
  el("tl-mode-flow").classList.toggle("active", mode === "flow");
  el("tl-mode-chapters").classList.toggle("active", mode === "chapters");
  renderChronicle();
}

init();
