## Formal fixed-r inference: users ~ D + log_pop, no size weights, r=4.
## Native fect unit bootstrap, 200 x 5 independent seeded chunks. Never pool chunk confidence limits.
## Percent = total gap / total counterfactual, recomputed in each resampled panel.
## Conditional on chosen specification and rank; original 409-unit population total = 409 * mean unit effect.
suppressPackageStartupMessages({library(readr);library(dplyr)})
script<-normalizePath(sub('^--file=','',grep('^--file=',commandArgs(FALSE),value=TRUE)[1]))
helper_path<-file.path(dirname(script),'R2_fect_가중CV_도구_20261010.R')
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
root<-path.expand(Sys.getenv('ROOT','~/Thesis/0614/public.transportation/0702'))
out_base<-path.expand(Sys.getenv('OUTDIR',file.path(root,'scm_results/R2_원값_인구_비가중_r4_BOOT_20261010')))
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
manifest<-list(engine_id=engine_id,patch_id=patch_id,original_source_md5=original_md5,script=unname(tools::md5sum(script)),helper=unname(tools::md5sum(file.path(dirname(script),'R2_fect_가중CV_도구_20261010.R'))),fect=as.character(packageVersion('fect')),panel=unname(tools::md5sum(file.path(root,'panels/d_w30_no과천.rds'))),raw=file.info(file.path(root,'od_with_pop_sum_without_holiday.csv'))[c('size','mtime')],r=4L,vartype='bootstrap',nboots=1000L,chunk=200L,primary_CI='basic',normalize=FALSE,seed=20261010L)
mp<-file.path(out,'manifest.rds');if(file.exists(mp))stopifnot(identical(readRDS(mp),manifest))else saveRDS(manifest,mp)
engine<-r2_engine()
provenance<-list(engine_id=engine_id,patch_id=patch_id,fect_version=fect_version,helper_md5=helper_md5,
 original_source_md5=original_md5,script_md5=unname(tools::md5sum(script)),
 installation_modified=FALSE,fit_mode='CV=FALSE; r=4; W.est=NULL; W.agg=NULL; vartype=bootstrap; keep.sims=TRUE',
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
stopifnot(mode%in%c('ALL','POINT','BOOT'))
atomic_save<-function(x,path){tmp<-paste0(path,'.tmp');saveRDS(x,tmp);if(!file.rename(tmp,path))stop('Could not save ',path)}
make_args<-function(seed,B=0L){
 a<-r2_args(users~D+log_pop,d,'none',4L,20000L,1e-5,seed)
 a$W.agg<-NULL;a$W.est<-NULL;a$min.T0<-5L;a$normalize<-FALSE
 a$se<-B>0L;a$vartype<-'bootstrap';a$keep.sims<-B>0L;a$nboots<-if(B>0L)B else 200L
 a$ci.method<-'basic';a
}
# Build observed data in the exact fitted matrix order; never assume treated columns are first.
fit_matrices<-function(f){
 stopifnot(f$Ntr==409,f$Nco==941,!isTRUE(f$W.in.fit),!isTRUE(f$W.in.agg))
 ij<-cbind(match(d$week_index,f$rawtime),match(d$unit_id,f$id));stopifnot(!anyNA(ij))
 Y<-D<-matrix(NA_real_,length(f$rawtime),length(f$id));Y[ij]<-d$users;D[ij]<-d$D
 stopifnot(!anyNA(Y),!anyNA(D),nrow(Y)==99,ncol(Y)==1350)
 list(Y=Y,D=D)
}
point_extract<-function(f){
 m<-fit_matrices(f);keep<-m$D==1
 stopifnot(is.matrix(f$Y.ct),identical(dim(f$Y.ct),dim(m$Y)),sum(keep)==409*46)
 ij<-which(keep,arr.ind=TRUE)
 z<-data.frame(unit_id=f$id[ij[,2]],week_index=f$rawtime[ij[,1]],observed=m$Y[keep],counterfactual=f$Y.ct[keep])
 stopifnot(all(is.finite(z$counterfactual)))
 z$gap<-z$observed-z$counterfactual
 stopifnot(isTRUE(all.equal(mean(z$gap),as.numeric(f$att.avg),tolerance=1e-7)))
 w<-aggregate(cbind(observed,counterfactual,gap)~week_index,z,sum);w<-w[order(w$week_index),]
 w$date<-date_map$date[match(w$week_index,date_map$week_index)]
 negative<-z$counterfactual<0
 list(cells=z,weekly=w,theta=c(ATT_count=mean(z$gap),weekly_total_gap=mean(w$gap),
  cumulative_total_gap=sum(w$gap),effect_pct=100*sum(w$gap)/sum(w$counterfactual)),
  negative=data.frame(cells=sum(negative),OD=length(unique(z$unit_id[negative])),sum_negative=sum(z$counterfactual[negative]),
   total_counterfactual=sum(z$counterfactual),effect_pct=100*sum(z$gap)/sum(z$counterfactual),
   clipped_sensitivity_pct=100*sum(z$observed-pmax(z$counterfactual,0))/sum(pmax(z$counterfactual,0))))
}
extract_draws<-function(f){
 stopifnot(identical(f$vartype,'bootstrap'),length(dim(f$eff.boot))==3L,
  identical(dim(f$eff.boot),dim(f$D.boot)),identical(dim(f$eff.boot),dim(f$I.boot)))
 m<-fit_matrices(f);B<-dim(f$eff.boot)[3];stopifnot(length(f$colnames.boot)==B)
 post_rows<-which(rowSums(m$D)>0);stopifnot(length(post_rows)==46)
 total<-matrix(NA_real_,46,B);pct<-total;overall<-matrix(NA_real_,B,4,
  dimnames=list(NULL,c('ATT_count','weekly_total_gap','cumulative_total_gap','effect_pct')))
 for(b in seq_len(B)){
  ids<-as.integer(f$colnames.boot[[b]])
  stopifnot(length(ids)==1350,all(ids>=1&ids<=1350))
  Yb<-m$Y[,ids,drop=FALSE];Db<-f$D.boot[,seq_along(ids),b];Ib<-f$I.boot[,seq_along(ids),b]
  eb<-f$eff.boot[,seq_along(ids),b]
  keep<-Db==1 & Ib==1
  stopifnot(!anyNA(keep),identical(unname(Db),unname(m$D[,ids,drop=FALSE])),sum(keep)==409*46,all(is.finite(eb[keep])))
  # Duplicated sampled units must appear twice in both numerator and denominator.
  obs<-Yb[keep];gap<-eb[keep];counterfactual<-obs-gap
  stopifnot(sum(counterfactual)>0)
  overall[b,]<-c(mean(gap),409*mean(gap),409*46*mean(gap),100*sum(gap)/sum(counterfactual))
  stopifnot(isTRUE(all.equal(mean(gap),as.numeric(f$att.avg.boot)[b],tolerance=1e-7)))
  for(j in seq_along(post_rows)){
   t<-post_rows[j];k<-keep[t,];stopifnot(sum(k)==409)
   denom<-sum(Yb[t,k]-eb[t,k]);stopifnot(denom>0)
   total[j,b]<-sum(eb[t,k]);pct[j,b]<-100*sum(eb[t,k])/denom
  }
 }
 list(overall=overall,weekly_total=total,weekly_pct=pct,week_index=f$rawtime[post_rows])
}
point_path<-file.path(out,'point_r4.rds')
if(file.exists(point_path)){point<-readRDS(point_path)}else{
 cat('[POINT] r=4 users + log_pop, no weights\n');set.seed(20261010L)
 run<-r2_fit(engine,make_args(20261010L));stopifnot(run$convergence_ok)
 point<-point_extract(run$fit);point$provenance<-provenance
 # Verify against the diagnostic point estimate, when available, with matching engine identity.
 ref<-file.path(root,'scm_results/R2_원값_인구_비가중_주모형진단_20261010',engine_id,'policy_r4.rds')
 if(file.exists(ref)){old<-readRDS(ref);stopifnot(identical(old$provenance$engine_id,engine_id),isTRUE(all.equal(unname(point$theta['ATT_count']),old$report$ATT_count,tolerance=1e-7)))}
 atomic_save(point,point_path);rm(run);gc(FALSE)
}
write.csv(point$negative,file.path(out,'negative_counterfactual_audit.csv'),row.names=FALSE)
write.csv(point$weekly,file.path(out,'point_weekly.csv'),row.names=FALSE)
print(point$theta)
ci_row<-function(theta,draws){
 stopifnot(all(is.finite(draws)),length(draws)==1000)
 qq<-as.numeric(quantile(draws,c(.025,.975),type=7));se<-sd(draws)
 c(estimate=theta,SE=se,CI_basic_lo=2*theta-qq[2],CI_basic_hi=2*theta-qq[1],
  CI_percentile_lo=qq[1],CI_percentile_hi=qq[2],CI_normal_lo=theta-qnorm(.975)*se,CI_normal_hi=theta+qnorm(.975)*se,
  boot_mean=mean(draws),boot_median=median(draws),nboots=length(draws))
}
writeLines(c('Primary inference: native fect vartype=bootstrap (OD-level resampling of complete trajectories; treated/control sampled separately).',
 'Fixed rank4 and population specification; no re-selection inside bootstrap. Intervals conditional on selected model, not selection-adjusted.',
 'Total effect is the original 409-OD population size times bootstrap mean effect. This is model/resampling inference, not survey expansion.',
 'Within-OD temporal dependence retained; OD bootstrap does not by itself address extra cross-OD residual dependence.',
 'Each draw uses its own colnames.boot mapping, observed outcomes, D/I masks and counterfactual=observed-eff.',
 'Overall percent is ratio of sums across all post cells. Negative cell predictions retained, positive aggregate denominators required.',
 'Primary 95% CI: basic bootstrap. Percentile and normal shown as sensitivity, never pick by significance. Not BCa.',
 'Weekly intervals are pointwise, not simultaneous. No bootstrap sign fraction mislabeled as p-value.',
 '200 draws per chunk x 5; full arrays discarded only after validated extraction; compact draw-level summaries retained.',
 'Failures/nonconvergence stop the run without automatic replacement. Completed chunks reused only with matching manifest.'),file.path(out,'INFERENCE_NOTES.txt'))
if(mode=='POINT'){cat('Point only; no bootstrap executed.\n');quit(save='no')}
for(chunk in 1:5){
 path<-file.path(out,sprintf('chunk_%02d.rds',chunk))
 if(file.exists(path)){cat('[REUSE]',basename(path),'\n');next}
 chunk_seed<-20261010L+chunk*1009L
 cat(sprintf('[BOOT] chunk %d/5, 200 draws, seed=%d\n',chunk,chunk_seed));flush.console();set.seed(chunk_seed)
 run<-r2_fit(engine,make_args(chunk_seed,200L))
 if(!run$convergence_ok){writeLines(run$warnings,file.path(out,sprintf('chunk_%02d_failed_warnings.txt',chunk)));stop('Nonconvergence: chunk not accepted; review warnings before retrying.')}
 f<-run$fit
 stopifnot(isTRUE(all.equal(as.numeric(f$att.avg),unname(point$theta['ATT_count']),tolerance=1e-7)))
 draws<-extract_draws(f)
 if(nrow(draws$overall)!=200L)stop('fect returned fewer than 200 successful draws; do not silently replace failed draws.')
 draws$seed<-chunk_seed;draws$minutes<-run$minutes;draws$warnings<-run$warnings;draws$provenance<-provenance
 atomic_save(draws,path)
 cat(sprintf('[SAVED] chunk %d/5 %.1f min\n',chunk,run$minutes));flush.console();rm(run,f,draws);gc(FALSE)
}
parts<-lapply(1:5,function(j)readRDS(file.path(out,sprintf('chunk_%02d.rds',j))))
stopifnot(length(unique(vapply(parts,function(x)x$seed,integer(1))))==5)
boot<-do.call(rbind,lapply(parts,`[[`,'overall'));stopifnot(nrow(boot)==1000)
weekly_total<-do.call(cbind,lapply(parts,`[[`,'weekly_total'));weekly_pct<-do.call(cbind,lapply(parts,`[[`,'weekly_pct'))
stopifnot(all(vapply(parts,function(x)identical(x$week_index,point$weekly$week_index),logical(1))))
res<-do.call(rbind,lapply(names(point$theta),function(nm)data.frame(metric=nm,t(ci_row(unname(point$theta[nm]),boot[,nm])),row.names=NULL)))
res$engine_id<-engine_id;res$patch_id<-patch_id
write.csv(res,file.path(out,'summary_B1000.csv'),row.names=FALSE)
write.csv(boot,file.path(out,'bootstrap_draws_B1000.csv'),row.names=FALSE)
w<-point$weekly
wout<-do.call(rbind,lapply(seq_len(nrow(w)),function(j)rbind(
 data.frame(date=w$date[j],metric='weekly_total_gap',t(ci_row(w$gap[j],weekly_total[j,])),row.names=NULL),
 data.frame(date=w$date[j],metric='effect_pct',t(ci_row(100*w$gap[j]/w$counterfactual[j],weekly_pct[j,])),row.names=NULL))))
wout$engine_id<-engine_id;write.csv(wout,file.path(out,'weekly_CI_B1000.csv'),row.names=FALSE)
pdf(file.path(out,'weekly_effect_B1000.pdf'),width=11,height=7)
par(mfrow=c(2,1),mar=c(4,4,3,1))
for(metric in c('weekly_total_gap','effect_pct')){
 z<-wout[wout$metric==metric,];x<-as.Date(z$date)
 plot(x,z$estimate,type='n',ylim=range(z$CI_basic_lo,z$CI_basic_hi,0),xaxt='n',xlab='Week',ylab=metric,main=paste('r4 + log population, no size weights:',metric))
 polygon(c(x,rev(x)),c(z$CI_basic_lo,rev(z$CI_basic_hi)),col=adjustcolor('#2563eb',alpha.f=.15),border=NA)
 lines(x,z$estimate,col='#2563eb',lwd=2);abline(h=0,lty=2)
 ticks<-seq(1,nrow(z),by=6);axis(1,at=as.numeric(x[ticks]),labels=format(x[ticks],'%m-%d'))
}
dev.off();print(res,row.names=FALSE);cat('Saved:',out,'\n')
