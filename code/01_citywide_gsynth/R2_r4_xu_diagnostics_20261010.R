# Native fect diagnostics, fixed r=4. Run by user, not by code generation.
# Main ATT B1000 is already complete; diagnostic B200 is a separate run.
# Run (from repo root): Rscript code/01_citywide_gsynth/R2_r4_xu_diagnostics_20261010.R [ALL|POINT|PLACEBO|LOO]
## RESTRICTED DATA REQUIRED (restricted data required): this script needs files that are not
## distributed (smart-card OD data, Data Safety Center export-restricted).
## Required input files (place under RAW_DIR):
##   - panels/d_w30_no과천.rds                 (OD x week panel built from smart-card OD data; builder script not in this repo)
##     (file name kept as delivered by the data holder; no과천 = excluding Gwacheon)
##   - od_with_pop_sum_without_holiday.csv     (OD-level weekly users + population, holiday weeks removed)
##     (column 이용자수_주총합 = weekly total users; Korean column names are kept as in the data)
## Also requires the helper R2_fect_weighted_cv_tools_20261010.R in the same folder as this script (see README).
suppressPackageStartupMessages({library(readr);library(dplyr)})
script<-normalizePath(sub('^--file=','',grep('^--file=',commandArgs(FALSE),value=TRUE)[1]))
helper_path<-file.path(dirname(script),'R2_fect_weighted_cv_tools_20261010.R')
source(helper_path)
patch_id<-'local_weight_v2_cvmax_v1_audit_v1'
fect_version<-as.character(packageVersion('fect'))
helper_md5<-unname(tools::md5sum(helper_path))
# Same dev package version can contain different source: fingerprint original functions too.
ns<-asNamespace('fect')
function_names<-c('fect.formula','fect.default','fect_cv','fect_nevertreated','inter_fe_ub','.fect_cv_score_one_ife_nt_all','.fect_apply_cv_rule')
original_sources<-setNames(lapply(function_names,function(nm)paste(deparse(get(nm,ns)),collapse='\n')),function_names)
fingerprint<-function(x){tmp<-tempfile();on.exit(unlink(tmp));saveRDS(x,tmp,version=2);unname(tools::md5sum(tmp))}
original_md5<-fingerprint(original_sources)
engine_id<-paste0('PATCHED_',patch_id,'_fect',fect_version,'_h',substr(helper_md5,1,10),'_src',substr(original_md5,1,10))
cat('[ENGINE]',engine_id,'\n')
## ---- Paths (edit here or set env vars) -------------------------------
REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")                       # run from repo root
RAW_DIR   <- Sys.getenv("RAW_DIR", Sys.getenv("ROOT", file.path(REPO_ROOT, "data/restricted")))   # restricted data required
OUT_DIR   <- Sys.getenv("OUT_DIR", Sys.getenv("OUTDIR", file.path(REPO_ROOT, "output", "01_citywide_gsynth/R2_r4_xu_diagnostics_20261010")))
root<-path.expand(RAW_DIR)
out_base<-path.expand(OUT_DIR)
out<-file.path(out_base,engine_id)
d<-readRDS(file.path(root,'panels/d_w30_no과천.rds'));tr<-unique(d$unit_id[d$D==1])
needed <- c("unit_id", "week_index", "week", "ym", "origin_region", "origin_sigungu", "origin_dong", "pop_total", "pop_youth", "youth_ratio", "이용자수_주총합")
raw <- readr::read_csv(file.path(root, "od_with_pop_sum_without_holiday.csv"), col_select = all_of(needed), show_col_types = FALSE)
sg <- raw %>% distinct(origin_region, origin_sigungu, origin_dong, ym, pop_total, pop_youth) %>% group_by(origin_region, origin_sigungu, ym) %>%
  summarise(pop_total_sg = sum(pop_total, na.rm = TRUE), pop_youth_sg = sum(pop_youth, na.rm = TRUE), .groups = "drop") %>% mutate(youth_ratio_sg = pop_youth_sg / pop_total_sg)
key <- function(x) paste(x$unit_id, x$week_index, sep = ":"); raw <- raw[key(raw) %in% key(d), ]
stopifnot(!anyDuplicated(key(raw)), nrow(raw)==nrow(d))
raw <- raw %>% left_join(sg, by = c("origin_region", "origin_sigungu", "ym")) %>%
  mutate(fb = pop_total < 100, pop_total = if_else(fb, pop_total_sg, pop_total), youth_ratio = if_else(fb, youth_ratio_sg, youth_ratio))
raw <- raw[match(key(d), key(raw)), ]; stopifnot(identical(key(d), key(raw)), max(abs(log1p(raw$이용자수_주총합) - log(raw$pop_total) - d$log_pc)) < 1e-8)
d$users <- raw$이용자수_주총합; d$log_users <- log1p(d$users); d$log_pop <- log(raw$pop_total); d$youth_ratio <- raw$youth_ratio; date_map <- unique(data.frame(week_index=d$week_index,date=as.Date(raw$week))); rm(raw, sg)

stopifnot(length(tr)==409,nrow(d)==1350*99,all(is.finite(d$users)),all(is.finite(d$log_pop)))
pre_weeks<-sort(unique(d$week_index[d$week_index<min(d$week_index[d$D==1])]))
stopifnot(length(pre_weeks)==53)
dir.create(out,recursive=TRUE,showWarnings=FALSE)
manifest<-list(engine_id=engine_id,patch_id=patch_id,original_source_md5=original_md5,script=unname(tools::md5sum(script)),helper=unname(tools::md5sum(file.path(dirname(script),'R2_fect_weighted_cv_tools_20261010.R'))),fect=as.character(packageVersion('fect')),panel=unname(tools::md5sum(file.path(root,'panels/d_w30_no과천.rds'))),raw=file.info(file.path(root,'od_with_pop_sum_without_holiday.csv'))[c('size','mtime')],r=4L,vartype='bootstrap',nboots=200L,primary_CI='normal',normalize=FALSE,seed=20261010L)
mp<-file.path(out,'manifest.rds');if(file.exists(mp))stopifnot(identical(readRDS(mp),manifest))else saveRDS(manifest,mp)
engine<-r2_engine()
provenance<-list(engine_id=engine_id,patch_id=patch_id,fect_version=fect_version,helper_md5=helper_md5,
 original_source_md5=original_md5,script_md5=unname(tools::md5sum(script)),
 installation_modified=FALSE,fit_mode='CV=FALSE; r=4; W.est=NULL; W.agg=NULL; vartype=bootstrap; keep.sims=FALSE',
 rank_source='Earlier patched full-panel rolling CV: users__pop__none; MSPE-1SE=1, GMSPE-1SE=4')
saveRDS(provenance,file.path(out,'engine_provenance.rds'))
write.csv(as.data.frame(provenance,stringsAsFactors=FALSE),file.path(out,'engine_provenance.csv'),row.names=FALSE)
writeLines(capture.output(sessionInfo()),file.path(out,'sessionInfo.txt'))
file.copy(script,file.path(out,'executed_script.R'),overwrite=TRUE)
file.copy(helper_path,file.path(out,'executed_helper.R'),overwrite=TRUE)
saveRDS(original_sources,file.path(out,'original_fect_functions.rds'))
saveRDS(setNames(lapply(function_names,function(nm)paste(deparse(get(nm,engine$env)),collapse='\n')),function_names),file.path(out,'effective_fect_functions.rds'))
writeLines(c('Engine is a local patched copy, NOT an unmodified fect release.',
 'Weight v2: complete donor panels with estimation weights use inter_fe_ub; initialize Y0.co.',
 'CV maxiter v1: forward max.iteration through gsynth CV dispatcher.',
 'Audit v1: record solver/fold diagnostics and expose CV SE; scoring and selection formula unchanged.',
 'These fits use no estimation weights and CV=FALSE; r is fixed at 4 throughout all bootstrap replicates.',
 'The r candidates originate from an earlier PATCHED CV run. Do not label this an original-versus-patched equivalence test.',
 'Old results without recorded source fingerprints have unverified provenance; do not relabel them as unpatched.',
 'Do not infer a patch effect from runs that also differ in outcome, covariates, r or aggregation.'),file.path(out,'PATCH_NOTES.txt'))

mode<-toupper(if(length(commandArgs(TRUE)))commandArgs(TRUE)[1]else 'ALL')
stopifnot(mode%in%c('ALL','POINT','PLACEBO','LOO'))
atomic_save<-function(x,p){tmp<-paste0(p,'.tmp');saveRDS(x,tmp);stopifnot(file.rename(tmp,p))}
args_for<-function(kind){
 a<-r2_args(users~D+log_pop,d,'none',4L,20000L,1e-5,20261011L)
 a$W<-NULL;a$W.est<-NULL;a$W.agg<-NULL
 a$CV<-FALSE;a$r<-4L;a$normalize<-FALSE;a$min.T0<-5L
 a$parallel<-FALSE;a$cores<-1L;a$keep.sims<-FALSE
 a$se<-kind%in%c('placebo','loo');a$nboots<-200L;a$vartype<-'bootstrap'
 a$ci.method<-'normal';a$loading.bound<-if(kind=='simplex')'simplex' else 'none'
 a$placeboTest<-kind=='placebo';a$loo<-kind=='loo'
 if(kind=='placebo')a$placebo.period<-c(-3L,0L)
 # Native all-pre-period LOO; do NOT substitute a custom rolling holdout.
 # tost.threshold=NULL preserves package default 0.36 * residualized-outcome SD.
 a$tost.threshold<-NULL;a$seed<-switch(kind,point=20261011L,simplex=20261012L,placebo=20261013L,loo=20261014L)
 a
}
status<-data.frame(stage=character(),status=character(),minutes=numeric(),detail=character())
plot_safe<-function(f,label,...){
 p<-file.path(out,paste0(label,'.pdf'));pdf(p,width=10,height=6)
 on.exit(dev.off())
 tryCatch({z<-plot(f,...);if(inherits(z,c('gg','ggplot','grob','gtable')))print(z)},error=function(e){
  writeLines(conditionMessage(e),file.path(out,paste0(label,'_PLOT_ERROR.txt')))
  message('Plot failed: ',label,'; numerical results remain saved.')
 })
}
point_summary<-function(f){
 ij<-cbind(match(d$week_index,f$rawtime),match(d$unit_id,f$id))
 stopifnot(!anyNA(ij),is.matrix(f$Y.ct))
 cf<-f$Y.ct[ij];k<-d$D==1;stopifnot(all(is.finite(cf)),sum(cf[k])>0)
 gap<-d$users[k]-cf[k];nw<-length(unique(d$week_index[k]))
 data.frame(ATT_count=mean(gap),weekly_total_gap=sum(gap)/nw,
 effect_pct_counterfactual=100*sum(gap)/sum(cf[k]),negative_cf_cells=sum(cf[k]<0))
}
run_stage<-function(kind){
 start<-Sys.time();p<-file.path(out,paste0(kind,'.rds'))
 if(file.exists(p)){cat('[REUSE]',kind,'\n');saved<-readRDS(p)}else{
  a<-args_for(kind);cat('[START]',kind,'r=4; B=',if(a$se)200 else 0,'\n');flush.console()
  set.seed(a$seed);run<-r2_fit(engine,a)
  writeLines(run$warnings,file.path(out,paste0(kind,'_warnings.txt')))
  if(!isTRUE(run$convergence_ok))stop('Convergence check failed; inspect warnings. No accepted checkpoint saved.')
  saved<-list(fit=run$fit,provenance=provenance,warnings=run$warnings)
  atomic_save(saved,p)
 }
 f<-saved$fit
 stopifnot(f$Ntr==409,f$Nco==941,!isTRUE(f$W.in.fit),!isTRUE(f$W.in.agg))
 writeLines(capture.output(print(f)),file.path(out,paste0(kind,'_summary.txt')))
 if(kind%in%c('point','simplex')){
  write.csv(point_summary(f),file.path(out,paste0(kind,'_effect.csv')),row.names=FALSE)
  plot_safe(f,paste0(kind,'_gap'),type='gap',main=paste('Fixed r4:',kind))
  plot_safe(f,paste0(kind,'_factors'),type='factors')
  plot_safe(f,paste0(kind,'_loading_overlap'),type='loading.overlap')
  saveRDS(f[intersect(names(f),c('lambda','lambda.co','lambda.tr','wgt.implied','factor','loading.bound'))],file.path(out,paste0(kind,'_support.rds')))
 }else{
  tests<-f[intersect(names(f),c('test.out','loo.test.out','est.placebo','pre.est.att','pre.att.bound','pre.att.boot','tost.threshold'))]
  saveRDS(tests,file.path(out,paste0(kind,'_tests.rds')))
  writeLines(capture.output(str(tests,max.level=4)),file.path(out,paste0(kind,'_tests.txt')))
  for(nm in c('est.placebo','pre.est.att','pre.att.bound'))if(!is.null(f[[nm]]))
   write.csv(f[[nm]],file.path(out,paste0(kind,'_',nm,'.csv')))
  if(kind=='loo'){
   stopifnot(isTRUE(f$loo),is.matrix(f$pre.att.boot),ncol(f$pre.att.boot)==200L)
   plot_safe(f,'loo_gap',type='gap',loo=TRUE,main='LOO pre-treatment diagnostic')
   plot_safe(f,'loo_equivalence',type='equiv',loo=TRUE,stats=c('F.p','equiv.p'),range='both')
  }else{
   stopifnot(isTRUE(f$placeboTest),!is.null(f$est.placebo))
   plot_safe(f,'placebo_gap',type='gap',stats=c('placebo.p','equiv.p'),main='Native placebo: last 4 pre-periods')
  }
 }
 rm(f,saved);gc(FALSE)
 as.numeric(difftime(Sys.time(),start,units='mins'))
}
writeLines(c(
 'Scope: native fect recommended diagnostics; NOT a universal journal acceptance checklist.',
 'Sources (checked 2026-10-10): https://yiqingxu.org/packages/fect/04-ife-mc.html#sec-diagnostics',
 'https://yiqingxu.org/packages/fect/06-gsynth.html',
 'Main model: raw users ~ D + log_pop; gsynth, two-way FE; fixed r4; no estimation or aggregation size weights.',
 'Existing main-effect inference B1000 is not rerun. These native diagnostic calls use B200, normal CI, single core.',
 'Placebo uses native placeboTest, c(-3,0): last FOUR relative pre-periods. This differs from the earlier custom train48/buffer1/score4 procedure.',
 'LOO uses native loo=TRUE over ALL available pre-periods (53); much slower than a single bootstrap. Can take many hours.',
 'LOO and placebo p-values/equivalence thresholds are computed by fect, not custom pooling of chunk p-values.',
 'Default equivalence bound: 0.36 times SD of outcome after two-way FE partialling; report it as a package default, not a substantively justified margin.',
 'Failure to reject zero is not proof of no pretrend. Equivalence is relative to the declared bound.',
 'Simplex is a fixed-r POINT sensitivity only; no CI, no reselection, no replacement of the main specification.',
 'Loading overlap display is a low-dimensional projection, not proof of overlap in the full four-factor space.',
 'Carryover test omitted: no treatment reversal/end. No redundant re-CV; prior MSPE/GMSPE rank discrepancy must still be disclosed.',
 'All inference remains conditional on selected r/specification. Diagnoses cannot rule out spillovers, concurrent shocks, or population endogeneity.',
 'Stage checkpoints permit resuming completed stages; interruption INSIDE a native LOO stage restarts that stage.',
 'Numerical stage failures are recorded; they must not be presented as passed. Plot errors are separately saved.'
),file.path(out,'README.txt'))
# Verify absorbing treatment before deciding carryover is not applicable.
stopifnot(all(vapply(split(d,d$unit_id),function(z){z<-z[order(z$week_index),];all(diff(z$D)>=0)},logical(1))))
stages<-switch(mode,ALL=c('point','simplex','placebo','loo'),POINT=c('point','simplex'),PLACEBO='placebo',LOO='loo')
for(kind in stages){
 result<-tryCatch(list(ok=TRUE,minutes=run_stage(kind),detail='Saved; inspect tests and plot-error files'),
 error=function(e){writeLines(conditionMessage(e),file.path(out,paste0(kind,'_ERROR.txt')));list(ok=FALSE,minutes=NA_real_,detail=conditionMessage(e))})
 status<-rbind(status,data.frame(stage=kind,status=if(result$ok)'completed' else 'FAILED',minutes=result$minutes,detail=result$detail))
 write.csv(status,file.path(out,'run_status.csv'),row.names=FALSE);print(tail(status,1));gc(FALSE)
}
cat('Saved: ',out,'\n')
if(any(status$status=='FAILED'))stop('Some stages failed: see run_status.csv; do not interpret missing diagnostics as passed.')
