/* Results explorer: loads CSVs listed in assets/manifest.json, sort + filter. Needs PapaParse. */
(function () {
  "use strict";
  var AN = {
    citywide: ["① 서울 내부 대중교통", "① Seoul transit"],
    heterogeneity: ["② 이질성", "② Heterogeneity"],
    road_scm: ["③ 여의도 도로 SCM", "③ Yeouido roads"],
    yeouido: ["④ 여의도 대중교통 SCM", "④ Yeouido transit"],
    seoul_road: ["⑤ 서울 전역 도로", "⑤ Seoul roads"]
  };
  var tables = [], header = [], rows = [], sortCol = -1, sortDir = 1;
  var $ = function (s) { return document.querySelector(s); };

  function isNum(v) { return v !== "" && v != null && !isNaN(Number(v)); }
  function fmt(v) {
    if (!isNum(v)) return v;
    var n = Number(v);
    if (Number.isInteger(n) || Math.abs(n) >= 1000) return String(v).length > 12 ? n.toFixed(1) : v;
    return String(v).length > 9 ? Number(n.toPrecision(5)).toString() : v;
  }
  function esc(s) { return String(s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }

  function fillAnalysis() {
    var sel = $("#f-analysis"), cur = sel.value;
    sel.innerHTML = '<option value="">' + t("전체", "All") + "</option>" +
      Object.keys(AN).map(function (k) { return '<option value="' + k + '">' + t(AN[k][0], AN[k][1]) + "</option>"; }).join("");
    sel.value = cur;
  }
  function fillTables(keep) {
    var a = $("#f-analysis").value, sel = $("#f-table");
    var list = tables.filter(function (x) { return !a || x.analysis === a; });
    sel.innerHTML = list.map(function (x) {
      return '<option value="' + esc(x.path) + '">' + esc(x.repo_path.replace(/^results\//, "")) + " (" + x.rows + ")</option>";
    }).join("");
    if (keep && list.some(function (x) { return x.path === keep; })) sel.value = keep;
  }

  function load(path) {
    var meta = tables.find(function (x) { return x.path === path; });
    if (!meta) return;
    $("#t-status").textContent = t("불러오는 중…", "Loading…");
    Papa.parse(path, {
      download: true, skipEmptyLines: true,
      complete: function (res) {
        var data = res.data;
        if (data.length && data[0].length) data[0][0] = String(data[0][0]).replace(/^﻿/, "");
        header = data[0] || []; rows = data.slice(1); sortCol = -1;
        $("#t-source").innerHTML = t("출처", "Source") + ': <a href="https://github.com/jayhaja/seoul-climate-card/blob/main/' +
          encodeURI(meta.repo_path) + '"><code>' + esc(meta.repo_path) + '</code></a> · <a href="' + encodeURI(path) + '" download>CSV</a>';
        try { history.replaceState(null, "", "?file=" + encodeURIComponent(meta.repo_path)); } catch (e) {}
        render();
      },
      error: function () { $("#t-status").textContent = t("불러오기 실패", "Failed to load"); }
    });
  }

  function render() {
    var q = $("#f-text").value.trim().toLowerCase();
    var view = rows.filter(function (r) { return !q || r.join(" ").toLowerCase().indexOf(q) >= 0; });
    if (sortCol >= 0) {
      view.sort(function (a, b) {
        var x = a[sortCol], y = b[sortCol];
        if (isNum(x) && isNum(y)) return (Number(x) - Number(y)) * sortDir;
        return String(x).localeCompare(String(y), "ko") * sortDir;
      });
    }
    var numCol = header.map(function (_, i) { return rows.length && rows.every(function (r) { return r[i] === "" || r[i] === "NA" || isNum(r[i]); }); });
    var h = "<thead><tr>" + header.map(function (c, i) {
      var cls = "sortable" + (numCol[i] ? " n" : "") + (i === sortCol ? (sortDir > 0 ? " sort-asc" : " sort-desc") : "");
      return '<th class="' + cls + '" data-i="' + i + '" tabindex="0" scope="col">' + esc(c) + "</th>";
    }).join("") + "</tr></thead><tbody>" +
      view.map(function (r) {
        return "<tr>" + r.map(function (v, i) { return numCol[i] ? '<td class="n" title="' + esc(v) + '">' + esc(fmt(v)) + "</td>" : "<td>" + esc(v) + "</td>"; }).join("") + "</tr>";
      }).join("") + "</tbody>";
    $("#t-table").innerHTML = h;
    $("#t-status").textContent = t(view.length + " / " + rows.length + "행 · 숫자는 유효숫자 5자리로 표시(셀에 마우스를 올리면 원값)",
      view.length + " / " + rows.length + " rows · numbers shown to 5 significant digits (hover for raw value)");
  }

  function onSort(e) {
    var th = e.target.closest("th[data-i]"); if (!th) return;
    var i = Number(th.dataset.i);
    if (sortCol === i) sortDir = -sortDir; else { sortCol = i; sortDir = 1; }
    render();
  }

  document.addEventListener("DOMContentLoaded", function () {
    fetch("assets/manifest.json").then(function (r) { return r.json(); }).then(function (m) {
      tables = m.tables;
      var want = new URLSearchParams(location.search).get("file");
      var start = tables.find(function (x) { return x.repo_path === want; }) ||
        tables.find(function (x) { return /R2_normal_final_20261011\/windows\.csv$/.test(x.path); }) || tables[0];
      fillAnalysis();
      $("#f-analysis").value = start.analysis;
      fillTables(start.path);
      load(start.path);
    });
    $("#f-analysis").addEventListener("change", function () { fillTables(); load($("#f-table").value); });
    $("#f-table").addEventListener("change", function () { load(this.value); });
    $("#f-text").addEventListener("input", render);
    $("#t-table").addEventListener("click", onSort);
    $("#t-table").addEventListener("keydown", function (e) { if (e.key === "Enter") onSort(e); });
    document.addEventListener("langchange", function () { fillAnalysis(); if (header.length) render(); });
  });
})();
