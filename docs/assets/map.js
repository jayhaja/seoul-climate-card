/* Front-page map: effect vs counterfactual by origin dong (or district). Needs Plotly. */
(function () {
  "use strict";
  var $ = function (s) { return document.querySelector(s); };
  var D = {}, view = "dong", focusGu = null;
  var MIN = 1000;               // pre-period weekly users (person-days) below which a dong is greyed out
  var LIM = 10, LIM_GU = 4;     // colour scale limits (%) for dong and district views; values beyond are clipped in colour only

  function css(v) { return getComputedStyle(document.documentElement).getPropertyValue(v).trim(); }
  function dark() { return window.matchMedia && matchMedia("(prefers-color-scheme: dark)").matches; }
  function scale() {
    var mid = dark() ? "#383835" : "#f0efec";
    return [[0, "#b52f2f"], [0.15, "#e34948"], [0.3, "#ec8c86"], [0.42, "#f6c9c4"], [0.5, mid],
            [0.58, "#b7d3f6"], [0.7, "#6da7ec"], [0.85, "#2a78d6"], [1, "#184f95"]];
  }
  function fmt(x, d) { return (x > 0 ? "+" : "") + x.toFixed(d == null ? 2 : d) + "%"; }

  function load() {
    return Promise.all(["dong.geojson", "gu.geojson", "effects.json"].map(function (f) {
      return fetch("assets/map/" + f).then(function (r) { return r.json(); });
    })).then(function (a) { D.dong = a[0]; D.gu = a[1]; D.eff = a[2]; });
  }

  /* bounding box of a FeatureCollection → map centre and zoom (web mercator), so no basemap or topojson is needed */
  function bbox(fc) {
    var b = [180, 90, -180, -90];
    function walk(c) { if (typeof c[0] === "number") { b[0] = Math.min(b[0], c[0]); b[1] = Math.min(b[1], c[1]); b[2] = Math.max(b[2], c[0]); b[3] = Math.max(b[3], c[1]); } else c.forEach(walk); }
    fc.features.forEach(function (f) { walk(f.geometry.coordinates); });
    return b;
  }
  function view_of(fc) {
    var b = bbox(fc), el = $("#map-plot"), w = el.clientWidth || 600, h = el.clientHeight || 400;
    var y = function (lat) { var s = Math.sin(lat * Math.PI / 180); return Math.log((1 + s) / (1 - s)) / 2; };
    var zx = Math.log2(w * 360 / (512 * (b[2] - b[0]))), zy = Math.log2(h * 2 * Math.PI / (512 * (y(b[3]) - y(b[1]))));   // MapLibre uses 512-px tiles
    return { center: { lon: (b[0] + b[2]) / 2, lat: (b[1] + b[3]) / 2 }, zoom: Math.min(zx, zy) - 0.15 };
  }
  var STYLE = {};
  function mapStyle() {   // one style object per colour scheme: reusing the same object avoids MapLibre style reloads on every redraw
    var bg = css("--surface");
    if (!STYLE[bg]) STYLE[bg] = { version: 8, sources: {}, layers: [{ id: "bg", type: "background", paint: { "background-color": bg } }] };
    return STYLE[bg];
  }
  function narrow() { return ($("#map-plot").clientWidth || 600) < 560; }
  function layout(fc) {
    var v = view_of(fc);
    return {
      paper_bgcolor: "rgba(0,0,0,0)", margin: { l: 0, r: 0, t: 0, b: narrow() ? 56 : 0 },
      font: { family: getComputedStyle(document.body).fontFamily, color: css("--text"), size: 12 },
      map: { style: mapStyle(), center: v.center, zoom: v.zoom },
      hoverlabel: { bgcolor: css("--surface"), bordercolor: css("--line"), font: { color: css("--text") } }
    };
  }
  function colorbar(lim) {
    var n = narrow();
    return { title: { text: t("반사실 대비 (%)", "vs counterfactual (%)"), side: n ? "top" : "right", font: { size: 11 } }, thickness: n ? 8 : 12, len: n ? 0.8 : 0.7,
      orientation: n ? "h" : "v", x: n ? 0.5 : 1.0, xanchor: n ? "center" : "left", y: n ? 0 : 0.5, yanchor: n ? "top" : "middle", tickfont: { size: 10, color: css("--muted") },
      tickvals: [-lim, -lim / 2, 0, lim / 2, lim], ticktext: ["≤ −" + lim, "−" + lim / 2, "0", "+" + lim / 2, "≥ +" + lim], outlinewidth: 0 };
  }

  function draw() {
    var ko = SiteLang() === "ko", line = css("--surface"), traces = [], noteEl = $("#map-note"), gj = null;
    if (view === "gu") {
      var codes = Object.keys(D.eff.gu);
      traces.push({ type: "choroplethmap", geojson: D.gu, featureidkey: "properties.SIG_CD", locations: codes,
        z: codes.map(function (c) { return D.eff.gu[c].effect_pct; }), zmin: -LIM_GU, zmax: LIM_GU, zmid: 0, colorscale: scale(), colorbar: colorbar(LIM_GU),
        marker: { line: { color: line, width: 1.5 } },
        customdata: codes.map(function (c) { var g = D.eff.gu[c]; return [ko ? g.gu : g.gu_en, fmt(g.effect_pct), g.n]; }),
        hovertemplate: "<b>%{customdata[0]}</b><br>%{customdata[1]}<br>" + t("OD 수", "ODs") + ": %{customdata[2]}<extra></extra>" });
      noteEl.textContent = t("자치구 효과 = 구 안 OD들의 Σ(관측 − 반사실) / Σ반사실. 색은 ±" + LIM_GU + "%에서 잘립니다. 구를 누르면 동별로 확대합니다.",
        "District effect = Σ(observed − counterfactual) / Σ counterfactual over the district's ODs. Colours clipped at ±" + LIM_GU + "%. Click a district to zoom to its dongs.");
    } else {
      var feats = D.dong.features.filter(function (f) { return !focusGu || f.properties.EMD_CD.slice(0, 5) === focusGu; });
      var all = feats.map(function (f) { return f.properties.EMD_CD; });
      var big = all.filter(function (c) { var r = D.eff.dong[c]; return r && r.effect_pct != null && r.use_pre >= MIN; });
      var small = all.filter(function (c) { var r = D.eff.dong[c]; return r && (r.effect_pct == null || r.use_pre < MIN); });
      var none = all.filter(function (c) { return !D.eff.dong[c]; });
      gj = focusGu ? { type: "FeatureCollection", features: feats } : D.dong;
      var greyFill = dark() ? "#5c6068" : "#b4b3ad", noFill = css("--surface"), edge = dark() ? "#4a4f57" : "#cfd3d8";
      if (none.length) traces.push({ type: "choroplethmap", geojson: gj, featureidkey: "properties.EMD_CD", locations: none, z: none.map(function () { return 0; }),
        colorscale: [[0, noFill], [1, noFill]], showscale: false, marker: { line: { color: edge, width: 0.6 } },
        customdata: none.map(function (c) { var p = feats.find(function (f) { return f.properties.EMD_CD === c; }).properties; return ko ? p.EMD_KOR_NM : p.EMD_ENG_NM; }),
        hovertemplate: "%{customdata}<br>" + t("분석 대상 OD 없음", "no OD in the analysis") + "<extra></extra>" });
      if (small.length) traces.push({ type: "choroplethmap", geojson: gj, featureidkey: "properties.EMD_CD", locations: small, z: small.map(function () { return 0; }),
        colorscale: [[0, greyFill], [1, greyFill]], showscale: false, marker: { line: { color: line, width: 0.6 } },
        customdata: small.map(function (c) { var r = D.eff.dong[c]; return [ko ? r.gu + " " + r.dong : r.dong_en + ", " + r.gu_en, r.effect_pct == null ? "—" : fmt(r.effect_pct), Math.round(r.use_pre).toLocaleString()]; }),
        hovertemplate: "<b>%{customdata[0]}</b><br>" + t("추정 불안정 (사전 주평균 ", "unstable estimate (pre-period weekly ") + "%{customdata[2]}" + t("인일)", " person-days)") + "<br>%{customdata[1]}<extra></extra>" });
      traces.push({ type: "choroplethmap", geojson: gj, featureidkey: "properties.EMD_CD", locations: big,
        z: big.map(function (c) { return D.eff.dong[c].effect_pct; }), zmin: -LIM, zmax: LIM, zmid: 0, colorscale: scale(), colorbar: colorbar(LIM),
        marker: { line: { color: line, width: 0.6 } },
        customdata: big.map(function (c) { var r = D.eff.dong[c]; return [ko ? r.gu + " " + r.dong : r.dong_en + ", " + r.gu_en, fmt(r.effect_pct), Math.round(r.use_pre).toLocaleString()]; }),
        hovertemplate: "<b>%{customdata[0]}</b><br>%{customdata[1]}<br>" + t("사전 주평균 이용", "Pre-period weekly users") + ": %{customdata[2]}<extra></extra>" });
      var gname = focusGu ? (ko ? D.eff.gu[focusGu].gu : D.eff.gu[focusGu].gu_en) : null;
      noteEl.textContent = t(
        (gname ? gname + ": " : "") + "색칠한 동 " + big.length + "개, 회색(사전 주평균 " + MIN.toLocaleString() + "인일 미만, 추정 불안정) " + small.length + "개, 흰색(분석 대상 아님) " + none.length + "개. 색은 ±" + LIM + "%에서 잘립니다.",
        (gname ? gname + ": " : "") + big.length + " dongs coloured, " + small.length + " grey (pre-period weekly users < " + MIN.toLocaleString() + " person-days; unstable), " + none.length + " white (not in the analysis). Colours are clipped at ±" + LIM + "%.");
    }
    var el = $("#map-plot");
    Plotly.react(el, traces, layout(view === "gu" ? D.gu : (focusGu ? gj : D.dong)), { responsive: true, displayModeBar: false, scrollZoom: false });
    $("#map-back").hidden = !(view === "dong" && focusGu);
    document.querySelectorAll("[data-map-view]").forEach(function (b) { b.setAttribute("aria-pressed", String(b.dataset.mapView === view)); });
  }

  document.addEventListener("DOMContentLoaded", function () {
    if (!window.Plotly || !$("#map-plot")) return;
    load().then(function () {
      draw();
      $("#map-plot").on("plotly_click", function (ev) {
        if (view !== "gu" || !ev.points.length) return;
        focusGu = ev.points[0].location; view = "dong"; draw();
      });
    }).catch(function () { $("#map-note").textContent = "Map data could not be loaded."; });
    document.querySelectorAll("[data-map-view]").forEach(function (b) {
      b.addEventListener("click", function () { view = b.dataset.mapView; if (view === "gu") focusGu = null; draw(); });
    });
    $("#map-back").addEventListener("click", function () { focusGu = null; draw(); });
    document.addEventListener("langchange", function () { if (D.eff) draw(); });
    if (window.matchMedia) matchMedia("(prefers-color-scheme: dark)").addEventListener("change", function () { if (D.eff) draw(); });
  });
})();
