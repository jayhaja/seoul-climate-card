## scm_v4_plots.R — 원고용 플롯 (정본 Rmd §11 플롯 헬퍼 + §107 재집계 플롯과 동일한 스타일·파일 번호)
## 1.scm_path  2.scm_gap  3.mspe_ratio_tau{2,3,5}  4.placebo_gaps_tau{2,3,5}  10.placebo_hist_tau{2,3,5}
## 5.loo_<mode>_synthstyle  6.in_time_path_f<start>  7.in_time_gap_f<start>
## 모두 10×10 in, 300 dpi, jpg. 입력은 run_scm_v4.R이 만든 path/placebo/loo/in_time 데이터프레임.
suppressMessages({ library(ggplot2); library(dplyr) })

## 정본 재현의 핵심: Rmd의 plot_loo_synthstyle이 showtext_auto()를 켜고(세션 전체 유지) 글꼴 "nsanskr"(Noto Sans KR)를 쓴다.
## showtext는 글자를 기본 dpi 96 기준으로 그리므로 300dpi 장치에서 글자가 약 1/3 크기가 된다 — 정본 그림의 작은 글씨는 이 효과다.
## 같은 모양을 내기 위해 플롯 전에 동일하게 켠다.
.SHOWTEXT_ON <- FALSE
.showtext_on <- function() {
  if (.SHOWTEXT_ON) return(invisible(TRUE))
  ok <- requireNamespace("showtext", quietly = TRUE) && requireNamespace("sysfonts", quietly = TRUE)
  if (!ok) { message("[plot] showtext/sysfonts 미설치 → 정본과 글자 크기가 다르게 나옴. install.packages(c('showtext','sysfonts'))"); return(invisible(FALSE)) }
  if (!"nsanskr" %in% sysfonts::font_families())
    tryCatch(sysfonts::font_add_google("Noto Sans KR", "nsanskr"), error = function(e) message("[plot] Noto Sans KR 내려받기 실패: ", conditionMessage(e)))
  showtext::showtext_auto()
  .SHOWTEXT_ON <<- TRUE; invisible(TRUE)
}
.kr_family <- function() {
  if (.SHOWTEXT_ON && "nsanskr" %in% sysfonts::font_families()) return("nsanskr")
  if (grepl("darwin", R.version$os)) "AppleGothic" else if (.Platform$OS.type == "windows") "Malgun Gothic" else "NanumGothic"
}
.open_jpg <- function(file, w = 10, h = 10) {
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  if (requireNamespace("ragg", quietly = TRUE)) ragg::agg_jpeg(file, width = w, height = h, units = "in", res = 300)
  else jpeg(file, width = w, height = h, units = "in", res = 300)
}

## path CSV → Synth 객체 모사 (path.plot/gaps.plot은 Y1plot, Y0plot %*% solution.w, tag$time.plot만 참조)
.mk_synth_objs <- function(pth) {
  tt <- as.numeric(pth$week_index)
  list(dp = list(Y1plot = matrix(pth$actual, ncol = 1, dimnames = list(tt, "treated")),
                 Y0plot = matrix(pth$synthetic, ncol = 1, dimnames = list(tt, "synthetic")),
                 tag = list(time.plot = tt)),
       so = list(solution.w = matrix(1, 1, 1)))
}

## 1·2·6·7: Synth 기본 path/gap 플롯 (정본 plot_synth_custom, cex_axis=1, cex_lab=1.2, cex_main=2)
plot_path_legacy <- function(pth, file, title_main, title_y, treat_time, type = c("path", "gap"),
                             legend_pos = "bottomleft", scale_factor = 3, cex_axis = 1, cex_lab = 1.2, cex_main = 2) {
  type <- match.arg(type); o <- .mk_synth_objs(pth)
  .open_jpg(file); on.exit(dev.off(), add = TRUE)
  op <- par(no.readonly = TRUE); on.exit(par(op), add = TRUE)
  par(family = .kr_family(), mai = c(1.8, 2.0, 1.2, 0.8), cex = scale_factor, cex.axis = cex_axis, cex.lab = cex_lab, mgp = c(1.5, 0.5, 0))
  if (type == "path") Synth::path.plot(synth.res = o$so, dataprep.res = o$dp, Main = "", Ylab = title_y, Xlab = "Week",
                                       Legend.position = legend_pos, tr.intake = treat_time)
  else { Synth::gaps.plot(synth.res = o$so, dataprep.res = o$dp, Main = "", Ylab = title_y, Xlab = "Week", tr.intake = treat_time)
         abline(h = 0, lty = 2, col = "grey40") }
  mtext(title_main, side = 3, line = 1.0, cex = cex_main * scale_factor, font = 2)
}

## 3: 사후/사전 RMSPE 비율 순위도 (처치 = 빨간 삼각형)
plot_mspe_ratio_ranked <- function(res_pl, pre_rmspe, ratio_main, treat_label, tau, file, base_size = 30) {
  pl <- res_pl %>% filter(is.finite(pre_rmspe), is.finite(ratio), pre_rmspe <= !!pre_rmspe * tau) %>%
    transmute(label = substr(unit_name, 1, 60), ratio, kind = "Placebo")
  d <- bind_rows(pl, data.frame(label = treat_label, ratio = ratio_main, kind = "Treated")) %>% arrange(ratio) %>% mutate(y = row_number())
  g <- ggplot(d, aes(ratio, y)) +
    geom_point(data = subset(d, kind == "Placebo"), shape = 15, size = 2.8) +
    geom_point(data = subset(d, kind == "Treated"), shape = 17, size = 5, colour = "red") +
    scale_y_continuous(breaks = d$y, labels = d$label, expand = expansion(mult = 0.02)) +
    labs(x = paste0("Post/Pre RMSPE ratio - ", treat_label), y = NULL) +
    theme_bw(base_size = base_size) +
    theme(panel.grid.minor = element_blank(), panel.grid.major.y = element_line(linewidth = 0.2, colour = "grey85"),
          axis.text.y = element_text(size = base_size), axis.text.x = element_text(size = base_size + 5))
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  ggsave(file, g, width = 10, height = 9, dpi = 300, limitsize = FALSE)
}

## 4: 위약 갭 묶음 (회색) + 처치 갭 (검정)
plot_placebo_gaps_limit <- function(paths_pl, res_pl, main_path, pre_rmspe, n_pre, tau, treat_label, file, base_size = 30) {
  ok <- res_pl$placebo_unit[is.finite(res_pl$pre_rmspe) & res_pl$pre_rmspe <= pre_rmspe * tau]
  Tmax <- max(main_path$week_index)
  df_pl <- paths_pl %>% filter(placebo_unit %in% ok, week_index <= Tmax)
  g <- ggplot() +
    geom_hline(yintercept = 0, linetype = "dotted", linewidth = 0.4) +
    geom_vline(xintercept = n_pre + 1, linetype = "dashed", linewidth = 0.5) +
    geom_line(data = df_pl, aes(week_index, gap, group = placebo_unit), linewidth = 0.3, alpha = 0.2) +
    geom_line(data = main_path, aes(week_index, gap), linewidth = 0.6) +
    labs(x = "Week", y = "Gap (Treated - Synthetic)", title = paste0("Placebos Plot - ", treat_label)) +
    theme_bw(base_size = base_size) +
    theme(panel.grid = element_blank(), axis.text = element_text(size = base_size + 10),
          axis.title = element_text(size = base_size + 15), plot.title = element_text(size = base_size + 18, face = "bold", hjust = 0.5)) +
    scale_x_continuous(limits = c(1, Tmax), expand = expansion(mult = 0)) + scale_y_continuous(expand = expansion(mult = 0))
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  ggsave(file, g, width = 10, height = 10, dpi = 300)
}

## 10: 비율 히스토그램 (ADH 2010 Fig.4 식, 처치 막대 진회색)
plot_placebo_ratio_hist <- function(res_pl, pre_rmspe, ratio_main, tau, file, bins = 30, base_size = 30) {
  d <- res_pl %>% filter(is.finite(pre_rmspe), pre_rmspe > 0, pre_rmspe <= !!pre_rmspe * tau, is.finite(ratio), ratio > 0) %>%
    transmute(ratio, kind = "Placebo") %>% bind_rows(data.frame(ratio = ratio_main, kind = "Treated"))
  d$kind <- factor(d$kind, c("Placebo", "Treated"))
  n_pl <- sum(d$kind == "Placebo"); p <- (1 + sum(d$ratio[d$kind == "Placebo"] >= ratio_main)) / (1 + n_pl)
  rng <- range(d$ratio); brk <- seq(rng[1], rng[2], length.out = bins + 1); brk[length(brk)] <- brk[length(brk)] + diff(rng) * 1e-9
  g <- ggplot(d, aes(ratio, fill = kind)) +
    geom_histogram(breaks = brk, colour = "black", linewidth = 0.4, position = "stack") +
    geom_vline(xintercept = 1, linetype = "dotted", linewidth = 0.8) +
    scale_fill_manual(values = c(Placebo = "grey85", Treated = "grey15"), guide = "none") +
    scale_y_continuous(expand = expansion(mult = c(0, 0.05))) +
    labs(x = "RMSPE ratio (Post / Pre)", y = "Count", title = sprintf("Placebo RMSPE Ratio Histogram (limit%g)", tau),
         subtitle = sprintf("Treated ratio = %.3f  |  n_placebo = %d  |  p = %.4f", ratio_main, n_pl, p)) +
    theme_classic(base_size = base_size) +
    theme(legend.position = "none", axis.text = element_text(size = base_size + 5), axis.title = element_text(size = base_size + 8),
          plot.title = element_text(size = base_size + 10, face = "bold"), plot.subtitle = element_text(size = base_size + 4))
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  ggsave(file, g, width = 10, height = 8, dpi = 300)
}

## 5: LOO 경로 (정본 plot_loo_synthstyle, §107 호출 인자 그대로)
plot_loo_synthstyle <- function(main_path, loo_paths, title_main, treat_time, file,
                                scale_factor = 1.2, cex_axis = 1.8, cex_lab = 2.2, cex_main = 2.0, cex_legend = 2,
                                mgp_title = 1.3, mgp_ticks = 0.35, main_line = 0.5, ylim_pad = 2, legend_pos = "bottomleft") {
  .open_jpg(file); on.exit(dev.off(), add = TRUE)
  op <- par(no.readonly = TRUE); on.exit(par(op), add = TRUE)
  par(pty = "s", xaxs = "i", yaxs = "i", mai = c(1, 1, 0.8, 0.4), cex = scale_factor, cex.axis = cex_axis, cex.lab = cex_lab,
      mgp = c(mgp_title, mgp_ticks, 0), font.main = 2, family = .kr_family())
  base_rng <- range(c(main_path$actual, main_path$synthetic), na.rm = TRUE); pad <- ylim_pad * diff(base_rng)
  ## 정본은 use_baseline_ylim=TRUE, ylim_pad=2 → 기준 범위의 ±2배 여백
  plot(main_path$week_index, main_path$actual, type = "n", xlim = range(main_path$week_index),
       ylim = c(base_rng[1] - pad, base_rng[2] + pad), xlab = "Week", ylab = "Weekly traffic", main = "")
  for (d in unique(loo_paths$omitted)) { s <- loo_paths[loo_paths$omitted == d, ]; lines(s$week_index, s$synthetic, col = "grey60", lwd = 0.8) }
  lines(main_path$week_index, main_path$synthetic, lty = 5, lwd = 1.2)
  lines(main_path$week_index, main_path$actual, lwd = 1.8)
  abline(v = treat_time, lty = 2)
  legend(legend_pos, c("Treated", "Baseline Synthetic", "LOO Synthetic"), col = c("black", "black", "grey60"), lty = c(1, 5, 1),
         lwd = c(1.8, 1.2, 0.8), cex = cex_legend, text.font = 2, y.intersp = 0.5, x.intersp = 0.8, bty = "o", box.lwd = 1)
  title(main = title_main, line = main_line, cex.main = cex_main); box()
}

## 묶음 호출: 한 지점의 원고용 플롯 전부
make_unit_plots <- function(cfg, u, treat_label, main_fit, pl = NULL, lo_paths = NULL, it_paths = NULL, pdir, taus = c(2, 3, 5)) {
  .showtext_on()
  P <- main_fit$path; m <- main_fit$metrics; t0 <- max(cfg$pre_idx) + 1; tag <- cfg$run_tag
  plot_path_legacy(P, file.path(pdir, sprintf("1.scm_path_%s_%s.jpg", u, tag)), paste0("SCM Path Plot - ", treat_label), "Weekly traffic", t0, "path")
  plot_path_legacy(P, file.path(pdir, sprintf("2.scm_gap_%s_%s.jpg", u, tag)), paste0("Gap Plot - ", treat_label), "Gap (Treated - Synthetic)", t0, "gap")
  if (!is.null(pl) && nrow(pl$res)) for (tau in taus) {
    plot_mspe_ratio_ranked(pl$res, m$final_pre_rmspe, m$rmspe_ratio, treat_label, tau, file.path(pdir, sprintf("3.mspe_ratio_%s_%s_tau%g.jpg", u, tag, tau)))
    plot_placebo_gaps_limit(pl$paths, pl$res, P, m$final_pre_rmspe, length(cfg$pre_idx), tau, treat_label, file.path(pdir, sprintf("4.placebo_gaps_%s_%s_tau%g.jpg", u, tag, tau)))
    plot_placebo_ratio_hist(pl$res, m$final_pre_rmspe, m$rmspe_ratio, tau, file.path(pdir, sprintf("10.placebo_hist_%s_%s_tau%g.jpg", u, tag, tau)))
  }
  if (!is.null(lo_paths) && nrow(lo_paths))
    plot_loo_synthstyle(P, lo_paths, paste0("Leave-One-Out Path Plot - ", treat_label, if (cfg$loo_mode == "fixedV") " (V fixed)" else ""), t0,
                        file.path(pdir, sprintf("5.loo_%s_%s_%s_synthstyle.jpg", u, tag, cfg$loo_mode)))
  if (!is.null(it_paths) && nrow(it_paths)) for (f0 in unique(it_paths$fake_start)) {
    s <- it_paths[it_paths$fake_start == f0, ]
    plot_path_legacy(s, file.path(pdir, sprintf("6.in_time_path_%s_%s_f%d.jpg", u, tag, f0)), paste0("In-time Placebo Path Plot - ", treat_label), "Weekly traffic", f0, "path")
    plot_path_legacy(s, file.path(pdir, sprintf("7.in_time_gap_%s_%s_f%d.jpg", u, tag, f0)), paste0("In-time Placebo Gap Plot - ", treat_label), "Gap (Treated - Synthetic)", f0, "gap")
  }
  invisible(NULL)
}
