
/* 军队兵种/加成明细 — 依赖 app.js 的 api()/el()/fmtNum()/CURRENT_SAVE_ID */
"use strict";

const STAT_LABEL = {
  melee_attack: "近战攻击", melee_defence: "近战防御",
  weapon_strength: "武器威力", charge_bonus: "冲锋加成",
  morale: "士气", health: "生命值", armour_value: "护甲强度",
  shield: "盾牌格挡", speed: "移动速度", mass: "质量",
  missile_strength: "远程威力", ammo: "弹药量", range: "射程",
  accuracy: "精准", melee_bonus_v_infantry: "反步兵加成",
  melee_bonus_v_large: "反大型加成",
  physical_resistance: "物理抗性", missile_resistance: "远程抗性",
  magic_resistance: "魔法抗性", fire_resistance: "火焰抗性",
  ward_save: "特保",
};
const STAT_ORDER = ["melee_attack", "melee_defence", "weapon_strength",
  "charge_bonus", "morale", "health", "armour_value", "shield",
  "speed", "mass", "missile_strength", "ammo", "range", "accuracy",
  "melee_bonus_v_infantry", "melee_bonus_v_large",
  "physical_resistance", "missile_resistance", "magic_resistance",
  "fire_resistance", "ward_save"];
const PCT_STATS = new Set(["shield", "physical_resistance",
  "missile_resistance", "magic_resistance", "fire_resistance",
  "ward_save", "accuracy"]);

const armyCache = new Map();

function fmtStat(k, v) {
  if (v === null || v === undefined) return "-";
  if (PCT_STATS.has(k)) return Math.round(v) + "%";
  return (Math.round(v * 10) / 10).toString();
}

async function toggleArmyDetail(container, idx) {
  const old = container.querySelector(".army-detail");
  if (old) { old.remove(); return; }
  const box = document.createElement("div");
  box.className = "army-detail";
  box.textContent = "正在解析加成…";
  container.appendChild(box);
  try {
    if (!armyCache.has(idx)) {
      const rep = await api("/api/army?id=" + CURRENT_SAVE_ID + "&i=" + idx);
      armyCache.set(idx, rep);
    }
    renderArmyDetail(box, armyCache.get(idx));
  } catch (e) {
    box.textContent = "加成解析不可用：" + e.message;
  }
}

function renderArmyDetail(box, rep) {
  box.innerHTML = "";
  const grid = document.createElement("div");
  grid.className = "unit-cards";
  for (const u of rep.units || []) {
    grid.appendChild(unitCard(u));
  }
  box.appendChild(grid);

  const side = document.createElement("div");
  side.className = "army-fx";
  const effs = (rep.effects || []).filter((r) => r.target_kind !== "other");
  const others = rep.army_level_effects || [];
  const h = document.createElement("div");
  h.className = "army-fx-head";
  h.textContent = "生效效果 " + effs.length + " 条 · 非单位目标 " +
    others.length + " 条 · 数据源: " + (rep.playset || "?");
  side.appendChild(h);
  const seen = new Set();
  for (const r of others.slice(0, 60)) {
    const key = (r.effect || "") + "|" + (r.source || "");
    if (seen.has(key)) continue;
    seen.add(key);
    const row = document.createElement("div");
    row.className = "fx-row";
    const val = (typeof r.value === "number") ?
      (" " + (r.value > 0 ? "+" : "") + Math.round(r.value * 10) / 10) : "";
    row.textContent = (r.name || r.effect || "?") + val +
      "  [" + (r.source || "") + "]";
    if (r.note) row.title = r.note;
    side.appendChild(row);
  }
  box.appendChild(side);
}

function unitCard(u) {
  const card = document.createElement("div");
  card.className = "unit-card";
  const top = document.createElement("div");
  top.className = "unit-card-head";
  const img = document.createElement("img");
  img.className = "unit-icon";
  img.src = "/api/icon?name=" + encodeURIComponent(u.icon || u.key);
  img.onerror = () => img.classList.add("hidden");
  top.appendChild(img);
  const nm = document.createElement("div");
  nm.className = "unit-card-name";
  const bits = [];
  if (u.is_general) bits.push("将领");
  else if (u.is_character) bits.push("英雄");
  if (u.rank) bits.push("经验" + u.rank);
  if (u.strength) bits.push(u.strength.join("/"));
  nm.innerHTML = "<b></b> <span class=\"dim\"></span>";
  nm.querySelector("b").textContent = u.name || u.key;
  nm.querySelector(".dim").textContent = bits.join(" · ");
  top.appendChild(nm);
  card.appendChild(top);

  const tbl = document.createElement("table");
  tbl.className = "stat-table";
  let hasRows = false;
  for (const s of STAT_ORDER) {
    const fin = (u.final || {})[s];
    if (fin === undefined) continue;
    const mod = (u.mods || {})[s];
    const tr = document.createElement("tr");
    const label = (mod && mod.name) || STAT_LABEL[s] || s;
    const base = mod ? mod.base : fin;
    const changed = mod && Math.abs(mod.final - (mod.base || 0)) > 0.05;
    tr.innerHTML = "<td></td><td class=\"num\"></td><td class=\"num\"></td>";
    tr.children[0].textContent = label;
    tr.children[1].textContent = fmtStat(s, base);
    const fcell = tr.children[2];
    fcell.textContent = fmtStat(s, fin);
    if (changed) {
      fcell.classList.add(mod.final >= (mod.base || 0) ? "stat-up" : "stat-down");
      tr.classList.add("stat-modded");
      tr.addEventListener("click", () => tr.classList.toggle("open"));
      const det = document.createElement("tr");
      det.className = "stat-detail";
      const td = document.createElement("td");
      td.colSpan = 3;
      td.appendChild(modList(u, s, mod));
      det.appendChild(td);
      tbl.appendChild(tr);
      tbl.appendChild(det);
    } else {
      tbl.appendChild(tr);
    }
    hasRows = true;
  }
  card.appendChild(tbl);
  if (!hasRows) {
    const d = document.createElement("div");
    d.className = "dim";
    d.textContent = "无面板数据（该单位不在当前数据库中）";
    card.appendChild(d);
  }
  const grants = u.grants || [];
  if (grants.length) {
    const g = document.createElement("div");
    g.className = "unit-grants";
    const seen = new Set();
    for (const gr of grants) {
      const k = gr.kind + ":" + gr.key;
      if (seen.has(k)) continue;
      seen.add(k);
      const c = document.createElement("span");
      c.className = "grant-chip";
      c.textContent = ((gr.name || gr.key) + "").split("
")[0];
      c.title = (gr.kind || "") + " · " + (gr.source || "");
      g.appendChild(c);
    }
    card.appendChild(g);
  }
  return card;
}

function modList(u, stat, mod) {
  const box = document.createElement("div");
  box.className = "mod-list";
  const parts = [];
  if (mod.pct) parts.push("乘区 +" + Math.round(mod.pct) + "%");
  if (mod.add) parts.push("平加 +" + Math.round(mod.add));
  if (mod.res) parts.push("抗性 +" + Math.round(mod.res) + "%");
  if (mod.rank_bonus) parts.push("经验加成 +" + mod.rank_bonus);
  if (parts.length) {
    const s = document.createElement("div");
    s.className = "dim";
    s.textContent = parts.join(" · ");
    box.appendChild(s);
  }
  for (const r of (mod.rows || [])) {
    const row = document.createElement("div");
    row.className = "fx-row";
    const v = (typeof r.value === "number") ?
      (r.value > 0 ? "+" : "") + Math.round(r.value * 10) / 10 : "";
    const nm = (r.name && !/^[a-z0-9_]+$/.test(r.name)) ? r.name :
      (STAT_LABEL[stat] || r.name || r.bvid || "?");
    row.textContent = nm + " " + v +
      "  — " + (r.source || "") + (r.cond ? "（条件）" : "");
    if (r.note) row.title = r.note;
    box.appendChild(row);
  }
  return box;
}
