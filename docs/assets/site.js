/* Shared header, footer, language toggle and figure zoom. No dependencies. */
(function () {
  "use strict";
  var REPO = "https://github.com/jayhaja/seoul-climate-card";
  var PAGES = [
    ["index.html", "개요", "Overview"],
    ["citywide.html", "① 서울 내부 대중교통", "① Seoul transit"],
    ["heterogeneity.html", "② 이질성", "② Heterogeneity"],
    ["road-scm.html", "③ 여의도 도로 SCM", "③ Yeouido roads"],
    ["yeouido.html", "④ 여의도 대중교통 SCM", "④ Yeouido transit"],
    ["results.html", "결과 표", "Results"],
    ["explore.html", "데이터 탐색", "Explore data"],
    ["gallery.html", "그림", "Figures"],
    ["data.html", "자료·한계", "Data & limits"]
  ];

  function store(k, v) {
    try { if (v === undefined) return window.localStorage.getItem(k); window.localStorage.setItem(k, v); } catch (e) { return null; }
  }
  var lang = (new URLSearchParams(location.search).get("lang")) || store("lang") || "en";
  if (lang !== "ko") lang = "en";
  document.documentElement.lang = lang;

  function setLang(l) {
    lang = l; document.documentElement.lang = l; store("lang", l);
    var b = document.querySelector(".lang-btn"); if (b) b.textContent = l === "ko" ? "English" : "한국어";
    document.dispatchEvent(new CustomEvent("langchange", { detail: l }));
  }
  window.SiteLang = function () { return lang; };
  window.t = function (ko, en) { return lang === "en" ? en : ko; };

  function el(tag, attrs, html) {
    var e = document.createElement(tag);
    for (var k in attrs || {}) e.setAttribute(k, attrs[k]);
    if (html != null) e.innerHTML = html;
    return e;
  }

  function header() {
    var here = location.pathname.split("/").pop() || "index.html";
    var h = el("header", { "class": "site-header" });
    var inner = el("div", { "class": "inner" });
    inner.appendChild(el("a", { "class": "brand", href: "index.html" },
      '<span class="ko">기후동행카드 효과 분석</span><span class="en">Seoul Climate Card study</span>'));
    var nav = el("nav", { "class": "site-nav", "aria-label": "Main" });
    PAGES.forEach(function (p) {
      var a = el("a", { href: p[0] }, '<span class="ko">' + p[1] + '</span><span class="en">' + p[2] + "</span>");
      if (p[0] === here) a.setAttribute("aria-current", "page");
      nav.appendChild(a);
    });
    var tog = el("button", { "class": "btn nav-toggle", type: "button", "aria-expanded": "false" }, '<span class="ko">메뉴</span><span class="en">Menu</span>');
    tog.addEventListener("click", function () { var o = nav.classList.toggle("open"); tog.setAttribute("aria-expanded", o); });
    var lb = el("button", { "class": "lang-btn", type: "button", lang: "" }, lang === "ko" ? "English" : "한국어");
    lb.addEventListener("click", function () { setLang(lang === "ko" ? "en" : "ko"); });
    inner.appendChild(tog); inner.appendChild(lb); inner.appendChild(nav);
    h.appendChild(inner);
    document.body.insertBefore(h, document.body.firstChild);
  }

  function footer() {
    var f = el("footer", { "class": "site-footer" });
    f.appendChild(el("div", { "class": "inner" },
      '<span class="ko">코드 MIT · 결과·그림 CC BY 4.0 · 원자료(교통카드 OD)는 반출 제한으로 미포함.</span>' +
      '<span class="en">Code MIT · results and figures CC BY 4.0 · raw smart-card OD data are export-restricted and not included.</span> ' +
      '<a href="' + REPO + '">GitHub</a>'));
    document.body.appendChild(f);
  }

  /* Lightbox shared by inline figures and the gallery */
  var dlg;
  window.openLightbox = function (src, title, note) {
    if (!dlg) {
      dlg = el("dialog", { "class": "lightbox" },
        '<img alt=""><div class="lb-bar"><div class="lb-text"></div>' +
        '<a class="btn lb-open" target="_blank" rel="noopener"><span class="ko">원본</span><span class="en">Original</span></a>' +
        '<button class="btn lb-close" type="button"><span class="ko">닫기</span><span class="en">Close</span></button></div>');
      document.body.appendChild(dlg);
      dlg.querySelector(".lb-close").addEventListener("click", function () { dlg.close(); });
      dlg.addEventListener("click", function (e) { if (e.target === dlg) dlg.close(); });
    }
    var img = dlg.querySelector("img"); img.src = src; img.alt = title || "";
    dlg.querySelector(".lb-open").href = src;
    dlg.querySelector(".lb-text").innerHTML = "<b></b>" + (note ? '<div class="note lb-note"></div>' : "");
    dlg.querySelector(".lb-text b").textContent = title || "";
    if (note) dlg.querySelector(".lb-note").textContent = note;
    if (typeof dlg.showModal === "function") dlg.showModal(); else window.open(src, "_blank");
    return dlg;
  };

  function zoomable() {
    document.querySelectorAll("main figure img").forEach(function (img) {
      img.addEventListener("click", function () {
        var cap = img.closest("figure").querySelector("figcaption");
        var title = cap ? (cap.querySelector("." + lang) || cap).textContent : img.alt;
        openLightbox(img.getAttribute("src"), title);
      });
    });
  }

  document.addEventListener("DOMContentLoaded", function () { header(); footer(); zoomable(); });
})();
