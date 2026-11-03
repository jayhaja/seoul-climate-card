/* Figure gallery: filters by analysis / site / text, click to enlarge, arrow keys to step. */
(function () {
  "use strict";
  var AN = {
    citywide: ["① 서울 내부 대중교통", "① Seoul transit"],
    heterogeneity: ["② 이질성", "② Heterogeneity"],
    road_scm: ["③ 여의도 도로 SCM", "③ Yeouido roads"],
    yeouido: ["④ 여의도 대중교통 SCM", "④ Yeouido transit"]
  };
  var figs = [], view = [], cur = -1;
  var $ = function (s) { return document.querySelector(s); };
  function esc(s) { return String(s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  function kind(f) { return t(f.kind_ko, f.kind_en); }
  function note(f) { return t(f.note_ko, f.note_en); }
  function title(f) { return (f.site ? f.site + " · " : "") + kind(f); }

  function fillFilters() {
    var a = $("#g-analysis"), av = a.value;
    a.innerHTML = '<option value="">' + t("전체", "All") + "</option>" + Object.keys(AN).map(function (k) {
      return '<option value="' + k + '">' + t(AN[k][0], AN[k][1]) + "</option>";
    }).join("");
    a.value = av;
    fillSites();
  }
  function fillSites() {
    var s = $("#g-site"), sv = s.value, an = $("#g-analysis").value;
    var sites = Array.from(new Set(figs.filter(function (f) { return !an || f.analysis === an; }).map(function (f) { return f.site; }).filter(Boolean))).sort();
    s.innerHTML = '<option value="">' + t("전체", "All") + "</option>" + sites.map(function (x) { return '<option>' + esc(x) + "</option>"; }).join("");
    if (sites.indexOf(sv) >= 0) s.value = sv;
  }

  function render() {
    var an = $("#g-analysis").value, site = $("#g-site").value, q = $("#g-text").value.trim().toLowerCase();
    var thesisOnly = $("#g-thesis").checked, tau5 = $("#g-tau5").checked;
    view = figs.filter(function (f) {
      if (an && f.analysis !== an) return false;
      if (site && f.site !== site) return false;
      if (thesisOnly && !f.thesis) return false;
      if (tau5 && !/placebo_gaps.*_tau5\./.test(f.src)) return false;
      if (q && (f.src + " " + f.kind_ko + " " + f.kind_en + " " + f.site).toLowerCase().indexOf(q) < 0) return false;
      return true;
    });
    $("#g-grid").innerHTML = view.map(function (f, i) {
      return '<button class="thumb" type="button" data-i="' + i + '"><img loading="lazy" src="' + encodeURI(f.src) + '" alt="' + esc(title(f)) + '">' +
        '<span class="cap"><b>' + esc(f.site || "") + "</b>" + esc(kind(f)) +
        (f.note_ko ? '<br><span class="badge">' + esc(/placebo_gaps.*_tau5/.test(f.src) ? t("원고용 · p는 위약 전체 기준", "manuscript · p uses all placebos") : (/_tau5\./.test(f.src) ? t("민감도 ≤5배", "sensitivity ≤5×") : t("위약 전체", "all placebos"))) + "</span>" : "") +
        "</span></button>";
    }).join("");
    $("#g-count").textContent = t(view.length + "개 그림", view.length + " figures");
  }

  function show(i) {
    if (i < 0 || i >= view.length) return;
    cur = i; var f = view[i];
    openLightbox(encodeURI(f.src), title(f) + "  (" + (i + 1) + "/" + view.length + ")", note(f));
  }

  document.addEventListener("DOMContentLoaded", function () {
    fetch("assets/manifest.json").then(function (r) { return r.json(); }).then(function (m) {
      figs = m.figures;
      var p = new URLSearchParams(location.search);
      fillFilters();
      if (p.get("analysis")) { $("#g-analysis").value = p.get("analysis"); fillSites(); }
      if (p.get("tau5")) $("#g-tau5").checked = true;
      render();
    });
    $("#g-analysis").addEventListener("change", function () { fillSites(); render(); });
    ["#g-site", "#g-thesis", "#g-tau5"].forEach(function (s) { $(s).addEventListener("change", render); });
    $("#g-text").addEventListener("input", render);
    $("#g-grid").addEventListener("click", function (e) { var b = e.target.closest("button.thumb"); if (b) show(Number(b.dataset.i)); });
    document.addEventListener("keydown", function (e) {
      var d = document.querySelector("dialog.lightbox[open]"); if (!d || cur < 0) return;
      if (e.key === "ArrowRight") show(cur + 1); else if (e.key === "ArrowLeft") show(cur - 1);
    });
    document.addEventListener("langchange", function () { fillFilters(); render(); });
  });
})();
