/* Data explorer: interactive plots of the published (processed) CSVs. Needs PapaParse + Plotly. */
(function () {
  "use strict";
  var $ = function (s) { return document.querySelector(s); };
  var R = "assets/results/";
  var cache = {};

  function load(path) {
    if (!cache[path]) cache[path] = new Promise(function (res, rej) {
      Papa.parse(R + path, { download: true, header: true, dynamicTyping: true, skipEmptyLines: true,
        transformHeader: function (h) { return h.replace(/^﻿/, ""); },
        complete: function (r) { res(r.data); }, error: rej });
    });
    return cache[path];
  }
  function css(v) { return getComputedStyle(document.documentElement).getPropertyValue(v).trim(); }
  function series(i) { return css("--series-" + (i + 1)); }
  function hexA(hex, a) {
    var n = parseInt(hex.replace("#", ""), 16);
    return "rgba(" + (n >> 16 & 255) + "," + (n >> 8 & 255) + "," + (n & 255) + "," + a + ")";
  }
  function layout(extra) {
    var ink = css("--text"), muted = css("--muted"), grid = css("--line");
    var base = {
      paper_bgcolor: "rgba(0,0,0,0)", plot_bgcolor: "rgba(0,0,0,0)",
      font: { family: getComputedStyle(document.body).fontFamily, size: 12, color: ink },
      margin: { l: 56, r: 16, t: 12, b: 44 }, hovermode: "x unified",
      legend: { orientation: "h", y: -0.18, font: { color: muted } },
      xaxis: { gridcolor: grid, zerolinecolor: grid, linecolor: grid, tickfont: { color: muted } },
      yaxis: { gridcolor: grid, zerolinecolor: muted, linecolor: grid, tickfont: { color: muted } }
    };
    for (var k in extra || {}) {
      if (typeof extra[k] === "object" && base[k] && !Array.isArray(extra[k])) Object.assign(base[k], extra[k]); else base[k] = extra[k];
    }
    return base;
  }
  var CFG = { responsive: true, displaylogo: false, modeBarButtonsToRemove: ["lasso2d", "select2d"] };
  function plot(el, data, lay) { Plotly.react(el, data, layout(lay), CFG); }
  function band(x, lo, hi, color, name) {
    return { x: x.concat(x.slice().reverse()), y: hi.concat(lo.slice().reverse()), fill: "toself", fillcolor: hexA(color, 0.18),
      line: { width: 0 }, hoverinfo: "skip", showlegend: false, name: name, type: "scatter" };
  }
  var TREAT = "2024-01-29";
  function treatLine() {
    return { type: "line", xref: "x", yref: "paper", x0: TREAT, x1: TREAT, y0: 0, y1: 1, line: { color: css("--muted"), width: 1, dash: "dash" } };
  }

  /* 1. Citywide weekly effects */
  var METRIC = {
    effect_pct: ["반사실 대비 효과 (%)", "Effect vs counterfactual (%)"],
    ATT_count: ["OD당 주간 ATT (건)", "ATT per OD per week (trips)"],
    weekly_total_gap: ["409쌍 합산 주간 효과 (건)", "Weekly effect summed over 409 ODs (trips)"],
    cumulative_total_gap: ["누적 효과 (건)", "Cumulative effect (trips)"]
  };
  function drawCity() {
    var m = $("#c-metric").value;
    load("01_citywide_gsynth/R2_r4_submission_20261010/weekly_effects_B1000.csv").then(function (d) {
      d = d.filter(function (r) { return r.metric === m; });
      var x = d.map(function (r) { return r.start; }), c = series(0);
      plot("c-plot", [band(x, d.map(function (r) { return r.normal_lo; }), d.map(function (r) { return r.normal_hi; }), c, "CI"),
        { x: x, y: d.map(function (r) { return r.estimate; }), type: "scatter", mode: "lines+markers", name: t("점추정", "Estimate"),
          line: { color: c, width: 2 }, marker: { size: 5 },
          customdata: d.map(function (r) { return [r.normal_lo, r.normal_hi]; }),
          hovertemplate: "%{y:.3f}<br>95% CI %{customdata[0]:.3f} – %{customdata[1]:.3f}<extra></extra>" }],
        { yaxis: { title: { text: t(METRIC[m][0], METRIC[m][1]) } }, showlegend: false });
    });
  }

  /* 2. Heterogeneity weekly */
  var AXES = { transfer: ["환승 부담", "Transfer burden"], wait: ["환승 대기 시간", "Waiting time"], access: ["접근성", "Accessibility"],
    distance: ["통행 거리", "Trip distance"], youth: ["청년 비율", "Youth share"], elderly: ["고령 비율", "Elderly share"], region: ["권역", "Planning region"] };
  var LAB3 = { transfer: ["Low", "Middle", "High"], wait: ["Short", "Middle", "Long"], distance: ["Short", "Middle", "Long"] };
  function glabel(ax, g) {
    if (ax === "region") return g;
    var i = parseInt(String(g).replace("Q", ""), 10) - 1;
    return g + " (" + (LAB3[ax] || ["Low", "Middle", "High"])[i] + ")";
  }
  function drawHet() {
    var ax = $("#h-axis").value, showCI = $("#h-ci").checked;
    load("02_heterogeneity/R2_r4_cf_tertiles_timepath_20261103/fig_hetero_weekly_cf_all_en_data.csv").then(function (d) {
      d = d.filter(function (r) { return r.axis === ax; });
      var groups = Array.from(new Set(d.map(function (r) { return r.group; })));
      var traces = [];
      groups.forEach(function (g, i) {
        var s = d.filter(function (r) { return r.group === g; }), x = s.map(function (r) { return r.date; }), c = series(i);
        if (showCI) traces.push(band(x, s.map(function (r) { return r.lo; }), s.map(function (r) { return r.hi; }), c, g));
        traces.push({ x: x, y: s.map(function (r) { return r.est; }), type: "scatter", mode: "lines", name: glabel(ax, g),
          line: { color: c, width: 2 }, hovertemplate: "%{y:.2f}%<extra>" + glabel(ax, g) + "</extra>" });
      });
      plot("h-plot", traces, { yaxis: { title: { text: t("반사실 대비 (%)", "vs counterfactual (%)") } }, shapes: [treatLine()] });
    });
  }

  /* 3. Road SCM placebo distribution */
  var roadSummary;
  function fillRoad() {
    return load("03_road_scm/summary/road_abadie2015_placebo_loo_cf.csv").then(function (d) {
      roadSummary = d;
      $("#r-unit").innerHTML = d.map(function (r) {
        return '<option value="' + r.unit + '">' + String(r.unit).padStart(2, "0") + " " + r.name + (r.p_all < 0.05 ? " *" : "") + "</option>";
      }).join("");
      $("#r-unit").value = "4";
    });
  }
  function drawRoad() {
    var u = Number($("#r-unit").value), uu = String(u).padStart(2, "0");
    var s = roadSummary.find(function (r) { return r.unit === u; });
    Promise.all([load("03_road_scm/unit_" + uu + "/placebo_results.csv"), load("03_road_scm/unit_" + uu + "/loo_twostep.csv")]).then(function (a) {
      var pl = a[0].filter(function (r) { return r.ratio != null; }).sort(function (x, y) { return x.ratio - y.ratio; });
      var all = pl.map(function (r) { return { id: "placebo " + r.placebo_unit, ratio: r.ratio, tr: false }; })
        .concat([{ id: t("처치 링크", "treated link"), ratio: s.rmspe_ratio, tr: true }])
        .sort(function (x, y) { return x.ratio - y.ratio; });
      plot("r-plot", [{ type: "bar", x: all.map(function (r, i) { return i + 1; }), y: all.map(function (r) { return r.ratio; }),
        marker: { color: all.map(function (r) { return r.tr ? series(1) : hexA(series(0), 0.55); }) },
        text: all.map(function (r) { return r.id; }), textposition: "none", hovertemplate: "%{text}<br>RMSPE ratio %{y:.2f}<extra></extra>" }],
        { hovermode: "closest", xaxis: { title: { text: t("순위 (낮음 → 높음)", "Rank (low → high)") } },
          yaxis: { title: { text: t("처치 후/전 RMSPE 비율", "Post/pre RMSPE ratio") } }, showlegend: false, bargap: 0.15 });
      var lo = a[1];
      plot("r-loo", [{ type: "scatter", mode: "markers", x: lo.map(function (r) { return r.att_pct; }), y: lo.map(function (r) { return "−" + r.omitted; }),
        marker: { color: series(0), size: 9 }, hovertemplate: "donor %{y} omitted: %{x:.2f}%<extra></extra>", name: "LOO" }],
        { hovermode: "closest", height: Math.max(260, 16 * lo.length + 90), xaxis: { title: { text: t("처치 전 평균 대비 효과 (%)", "Effect vs pre-period mean (%)") } },
          yaxis: { automargin: true, type: "category" }, showlegend: false,
          shapes: [{ type: "line", xref: "x", yref: "paper", x0: s.cf_pct, x1: s.cf_pct, y0: 0, y1: 1, line: { color: series(1), width: 2 } }] });
      $("#r-note").textContent = t(
        "처치 링크 비율 " + s.rmspe_ratio.toFixed(2) + ", 순위 " + s.rank + "/54, p = " + s.p_all.toFixed(3) + " (위약 전체). 반사실 대비 " + s.cf_pct + "%. 오른쪽 그림의 세로선은 본 추정치(반사실 대비)이고 점은 LOO(처치 전 평균 대비)입니다.",
        "Treated ratio " + s.rmspe_ratio.toFixed(2) + ", rank " + s.rank + " of 54, p = " + s.p_all.toFixed(3) + " (all placebos). Effect vs counterfactual " + s.cf_pct + "%. In the LOO chart the vertical line is the main estimate (vs counterfactual); dots are LOO estimates (vs pre-period mean).");
    });
  }

  /* 4. Yeouido transit */
  function drawYeo() {
    Promise.all([load("04_yeouido_transit_scm/nested79/placebo_summary_D79_nested.csv"), load("04_yeouido_transit_scm/nested79/summary_D79_nested.csv"),
      load("04_yeouido_transit_scm/nested79/weights_D79_nested.csv")]).then(function (a) {
      var tr = a[1][0];
      var all = a[0].map(function (r) { return { id: "placebo " + r.placebo_unit, ratio: r.ratio, tr: false }; })
        .concat([{ id: t("여의도동 (처치)", "Yeouido-dong (treated)"), ratio: tr.rmspe_ratio, tr: true }])
        .sort(function (x, y) { return x.ratio - y.ratio; });
      plot("y-plot", [{ type: "bar", x: all.map(function (r, i) { return i + 1; }), y: all.map(function (r) { return r.ratio; }),
        marker: { color: all.map(function (r) { return r.tr ? series(1) : hexA(series(0), 0.55); }) },
        text: all.map(function (r) { return r.id; }), textposition: "none", hovertemplate: "%{text}<br>RMSPE ratio %{y:.2f}<extra></extra>" }],
        { hovermode: "closest", xaxis: { title: { text: t("순위 (낮음 → 높음)", "Rank (low → high)") } },
          yaxis: { title: { text: t("처치 후/전 RMSPE 비율", "Post/pre RMSPE ratio") } }, showlegend: false, bargap: 0.15 });
      var w = a[2].filter(function (r) { return r.weight > 0.001; }).sort(function (x, y) { return x.weight - y.weight; });
      plot("y-w", [{ type: "bar", orientation: "h", x: w.map(function (r) { return r.weight; }), y: w.map(function (r) { return r.unit_name; }),
        marker: { color: series(0) }, hovertemplate: "%{y}<br>w = %{x:.3f}<extra></extra>" }],
        { hovermode: "closest", height: 48 * w.length + 90, margin: { l: 16 }, yaxis: { automargin: true }, xaxis: { title: { text: t("도너 가중치", "Donor weight") } }, showlegend: false });
    });
  }

  /* 5. Any CSV */
  var gen = { rows: [], cols: [] };
  function fillGenFiles() {
    return fetch("assets/manifest.json").then(function (r) { return r.json(); }).then(function (m) {
      $("#g-file").innerHTML = m.tables.map(function (x) { return '<option value="' + x.path.replace(R, "") + '">' + x.repo_path.replace(/^results\//, "") + " (" + x.rows + ")</option>"; }).join("");
      $("#g-file").value = "03_road_scm/summary/road_windows_cf.csv";
    });
  }
  function loadGen() {
    load($("#g-file").value).then(function (d) {
      gen.rows = d; gen.cols = d.length ? Object.keys(d[0]) : [];
      var num = gen.cols.filter(function (c) { return d.some(function (r) { return typeof r[c] === "number"; }); });
      var opt = function (list, none) { return (none ? '<option value="">—</option>' : "") + list.map(function (c) { return "<option>" + c + "</option>"; }).join(""); };
      $("#g-x").innerHTML = opt(gen.cols); $("#g-y").innerHTML = opt(num); $("#g-c").innerHTML = opt(gen.cols, true);
      $("#g-x").value = gen.cols[0];
      var pref = ["estimate", "est", "cf_pct", "effect_pct", "pct", "att_pct", "pct_cf", "ATT", "att", "ratio", "weight"];
      var yv = pref.find(function (c) { return num.indexOf(c) >= 0; }) || num.find(function (c) { return c !== gen.cols[0]; }) || num[0] || "";
      $("#g-y").value = yv;
      var cat = gen.cols.find(function (c) { return num.indexOf(c) < 0 && c !== gen.cols[0]; });
      $("#g-c").value = cat && new Set(d.map(function (r) { return r[cat]; })).size <= 8 ? cat : "";
      drawGen();
    });
  }
  function drawGen() {
    var x = $("#g-x").value, y = $("#g-y").value, c = $("#g-c").value, kind = $("#g-kind").value;
    if (!y) { Plotly.purge("g-plot"); return; }
    var groups = c ? Array.from(new Set(gen.rows.map(function (r) { return r[c]; }))) : [null];
    var note = "";
    if (groups.length > 8) { note = t("색 구분 값이 8개를 넘어 상위 8개만 표시합니다.", "More than 8 colour groups; showing the first 8."); groups = groups.slice(0, 8); }
    var traces = groups.map(function (g, i) {
      var s = g === null ? gen.rows : gen.rows.filter(function (r) { return r[c] === g; });
      var tr = { x: s.map(function (r) { return r[x]; }), y: s.map(function (r) { return r[y]; }), name: g === null ? y : String(g) };
      if (kind === "bar") { tr.type = "bar"; tr.marker = { color: series(i) }; }
      else { tr.type = "scatter"; tr.mode = kind === "line" ? "lines+markers" : "markers"; tr.line = { color: series(i), width: 2 }; tr.marker = { color: series(i), size: 8 }; }
      return tr;
    });
    plot("g-plot", traces, { hovermode: "closest", xaxis: { title: { text: x }, automargin: true }, yaxis: { title: { text: y } }, showlegend: groups.length > 1, barmode: "group" });
    $("#g-note").textContent = note;
  }

  function redrawAll() { drawCity(); drawHet(); if (roadSummary) drawRoad(); drawYeo(); if (gen.rows.length) drawGen(); }

  document.addEventListener("DOMContentLoaded", function () {
    if (!window.Plotly || !window.Papa) { document.querySelector("main").insertAdjacentHTML("afterbegin", '<div class="note">Plotly / PapaParse could not be loaded.</div>'); return; }
    $("#c-metric").addEventListener("change", drawCity);
    $("#h-axis").innerHTML = Object.keys(AXES).map(function (k) { return '<option value="' + k + '">' + t(AXES[k][0], AXES[k][1]) + "</option>"; }).join("");
    ["#h-axis", "#h-ci"].forEach(function (s) { $(s).addEventListener("change", drawHet); });
    $("#r-unit").addEventListener("change", drawRoad);
    ["#g-x", "#g-y", "#g-c", "#g-kind"].forEach(function (s) { $(s).addEventListener("change", drawGen); });
    $("#g-file").addEventListener("change", loadGen);
    drawCity(); drawHet(); drawYeo();
    fillRoad().then(drawRoad);
    fillGenFiles().then(loadGen);
    document.addEventListener("langchange", function () {
      var v = $("#h-axis").value;
      $("#h-axis").innerHTML = Object.keys(AXES).map(function (k) { return '<option value="' + k + '">' + t(AXES[k][0], AXES[k][1]) + "</option>"; }).join("");
      $("#h-axis").value = v; redrawAll();
    });
    if (window.matchMedia) window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", redrawAll);
  });
})();
