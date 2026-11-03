## Read-only postprocessing of the completed 1000-draw r4 run. No model fitting.
root<-path.expand('~/Thesis/0614/public.transportation/0702')
engine_id<-'PATCHED_local_weight_v2_cvmax_v1_audit_v1_fect2.4.7_h748c651816_srce78b1e9155'
b<-file.path(root,'scm_results/R2_원값_인구_비가중_r4_BOOT_20261010',engine_id)
out<-path.expand('~/Documents/thesis_summary/scm_results/R2_r4_제출용_20261010')
dir.create(out,recursive=TRUE,showWarnings=FALSE)
p<-readRDS(file.path(b,'point_r4.rds'));parts<-lapply(1:5,function(j)readRDS(file.path(b,sprintf('chunk_%02d.rds',j))))
w<-p$weekly;w$date<-as.Date(w$date);B<-do.call(cbind,lapply(parts,`[[`,'weekly_total'));P<-do.call(cbind,lapply(parts,`[[`,'weekly_pct'))
stopifnot(identical(dim(B),c(46L,1000L)),identical(dim(B),dim(P)),all(is.finite(B)),all(is.finite(P)),all(P!=0),all(vapply(parts,function(a)identical(a$week_index,w$week_index),logical(1))))
# Recover each draw's weekly counterfactual from the saved exact ratio, NOT from the original observed totals.
C<-100*B/P;stopifnot(all(is.finite(C)),all(C>0))
original<-do.call(rbind,lapply(parts,`[[`,'overall'))
stopifnot(isTRUE(all.equal(unname(100*colSums(B)/colSums(C)),unname(original[,'effect_pct']),tolerance=1e-10)))
ci<-function(theta,draws){
 q<-quantile(draws,c(.025,.975),names=FALSE);se<-sd(draws)
 c(estimate=theta,SE=se,basic_lo=2*theta-q[2],basic_hi=2*theta-q[1],percentile_lo=q[1],percentile_hi=q[2],normal_lo=theta-qnorm(.975)*se,normal_hi=theta+qnorm(.975)*se,nboots=length(draws))
}
window<-function(idx,label){
 stopifnot(length(idx)>0)
 th<-c(ATT_count=mean(w$gap[idx])/409,weekly_total_gap=mean(w$gap[idx]),cumulative_total_gap=sum(w$gap[idx]),effect_pct=100*sum(w$gap[idx])/sum(w$counterfactual[idx]))
 draws<-list(ATT_count=colMeans(B[idx,,drop=FALSE])/409,weekly_total_gap=colMeans(B[idx,,drop=FALSE]),cumulative_total_gap=colSums(B[idx,,drop=FALSE]),effect_pct=100*colSums(B[idx,,drop=FALSE])/colSums(C[idx,,drop=FALSE]))
 do.call(rbind,lapply(names(th),function(nm)data.frame(window=label,start=min(w$date[idx]),end=max(w$date[idx]),weeks=length(idx),metric=nm,t(ci(unname(th[nm]),draws[[nm]])),row.names=NULL)))
}
windows<-list(full_46weeks=seq_len(nrow(w)),through_August=which(w$date<=as.Date('2024-08-31')),exclude_December=which(w$date<as.Date('2024-12-01')),first_12_observed_weeks=1:12,first_24_observed_weeks=1:24,first_36_observed_weeks=1:36)
summary<-do.call(rbind,lapply(names(windows),function(nm)window(windows[[nm]],nm)))
summary$engine_id<-engine_id
write.csv(summary,file.path(out,'window_effects_B1000.csv'),row.names=FALSE)
monthly<-do.call(rbind,lapply(unique(format(w$date,'%Y-%m')),function(m)window(which(format(w$date,'%Y-%m')==m),m)))
write.csv(monthly,file.path(out,'monthly_effects_B1000.csv'),row.names=FALSE)
weekly<-do.call(rbind,lapply(seq_len(nrow(w)),function(j)window(j,as.character(w$date[j]))))
write.csv(weekly,file.path(out,'weekly_effects_B1000.csv'),row.names=FALSE)
cumulative<-do.call(rbind,lapply(seq_len(nrow(w)),function(j)window(seq_len(j),as.character(w$date[j]))))
write.csv(cumulative,file.path(out,'cumulative_effects_B1000.csv'),row.names=FALSE)
write.csv(p$negative,file.path(out,'negative_prediction_audit.csv'),row.names=FALSE)
# Point-only distribution by fixed pre-period size: no unsupported subgroup bootstrap claims.
z<-p$cells;z$gap<-z$observed-z$counterfactual
u<-aggregate(cbind(observed,counterfactual,gap)~unit_id,z,mean)
panel<-readRDS(file.path(root,'panels/d_w30_no과천.rds'));weights<-unique(panel[c('unit_id','use_pre')]);stopifnot(!anyDuplicated(weights$unit_id))
u$use_pre<-weights$use_pre[match(u$unit_id,weights$unit_id)];stopifnot(!anyNA(u$use_pre))
u$effect_pct<-ifelse(u$counterfactual>0,100*u$gap/u$counterfactual,NA_real_)
u$size_quintile<-as.integer(cut(rank(u$use_pre,ties.method='first'),breaks=c(0,409/5,2*409/5,3*409/5,4*409/5,409),labels=FALSE))
u<-u[order(-u$gap),];write.csv(u,file.path(out,'OD_point_effects.csv'),row.names=FALSE)
g<-do.call(rbind,lapply(1:5,function(k){a<-u[u$size_quintile==k,];data.frame(size_quintile=k,ODs=nrow(a),pre_size_min=min(a$use_pre),pre_size_max=max(a$use_pre),weekly_gap=sum(a$gap),effect_pct=100*sum(a$gap)/sum(a$counterfactual),positive_ODs=sum(a$gap>0))}))
write.csv(g,file.path(out,'size_quintiles_POINT_only.csv'),row.names=FALSE)
concentration<-data.frame(ODs=nrow(u),positive_ODs=sum(u$gap>0),negative_ODs=sum(u$gap<0),top5_positive_weekly_gap=sum(head(u$gap,5)),bottom5_weekly_gap=sum(tail(u$gap,5)),total_weekly_gap=sum(u$gap))
write.csv(concentration,file.path(out,'concentration_POINT_only.csv'),row.names=FALSE)
diagdir<-file.path(root,'scm_results/R2_원값_인구_비가중_주모형진단_20261010',engine_id)
pre<-read.csv(file.path(diagdir,'pre_validation.csv'));write.csv(pre,file.path(out,'pre_validation_POINT_only.csv'),row.names=FALSE)
r1<-readRDS(file.path(diagdir,'policy_r1.rds'))
comparison<-data.frame(r=c(1,4),criterion=c('MSPE_1se','GMSPE_1se'),ATT_count=c(r1$report$ATT_count,p$theta['ATT_count']),effect_pct=c(r1$report$effect_pct_counterfactual,p$theta['effect_pct']),CI_basic_lo=c(NA,summary$basic_lo[summary$window=='full_46weeks' & summary$metric=='effect_pct']),CI_basic_hi=c(NA,summary$basic_hi[summary$window=='full_46weeks' & summary$metric=='effect_pct']),nboots=c(0,1000))
write.csv(comparison,file.path(out,'rank_sensitivity.csv'),row.names=FALSE)
# Copy inference audit metadata; all source files remain untouched.
file.copy(file.path(b,c('engine_provenance.csv','INFERENCE_NOTES.txt','sessionInfo.txt')),out,overwrite=TRUE)
writeLines(c('All windows reuse the SAME full-panel r4 fit and SAME 1000 draws. No truncated-window refitting.',
 'Weekly/monthly assignment uses week-start dates; weeks can straddle calendar boundaries. Omitted holiday weeks stay omitted.',
 'Intervals use the fixed model and are pointwise. Window comparisons are descriptive, not multiple-testing adjusted.',
 'Ratio denominators recovered per replicate from weekly gap / weekly percent; pooled overall ratio verified against original saved draws.',
 'Aggregate effect=sum(gaps)/sum(counterfactual), no use_pre size weights. log_pop covariate; no outcome logarithm.',
 'Subgroup, OD and concentration statistics are point estimates only: original boot unit mappings were not retained in compact chunks.',
 'Pre-holdout results are diagnostic point estimates, not formal placebo/equivalence tests. Windows overlap; CV has used donor information.',
 'Main r4 was selected after examining alternative criteria and pre-holdout diagnostics; intervals do not account for model selection.',
 'r1 inference is not available. Do not describe the r1 estimate as statistically insignificant.',
 'No transport-mode substitution, unique-rider totals or benefit-cost calculations follow from these trip/usage counts alone.'),file.path(out,'REPORT_NOTES.txt'))
plot_all<-function(){
 par(mfrow=c(2,2),mar=c(4,4,3,1))
 plot(w$date,w$observed/1e6,type='l',col='#111827',lwd=2,ylim=range(w$observed,w$counterfactual)/1e6,xlab='Week',ylab='Million uses / week',main='Observed and counterfactual')
 lines(w$date,w$counterfactual/1e6,col='#2563eb',lwd=2,lty=2);legend('topleft',c('Observed','Counterfactual'),col=c('#111827','#2563eb'),lty=c(1,2),bty='n',cex=.8)
 for(metric in c('weekly_total_gap','effect_pct')){
  q<-weekly[weekly$metric==metric,];x<-as.Date(q$start);scale<-if(metric=='weekly_total_gap')1000 else 1
  plot(x,q$estimate/scale,type='n',ylim=range(q$basic_lo,q$basic_hi,0)/scale,xlab='Week',ylab=if(scale==1000)'Thousand uses / week'else'Percent',main=if(scale==1000)'Weekly effect: 95% basic CI'else'Counterfactual-relative effect: 95% CI')
  polygon(c(x,rev(x)),c(q$basic_lo,rev(q$basic_hi))/scale,col=adjustcolor('#2563eb',.15),border=NA);lines(x,q$estimate/scale,col='#2563eb',lwd=2);abline(h=0,lty=2,col='gray50')
 }
 q<-cumulative[cumulative$metric=='cumulative_total_gap',];x<-as.Date(q$end)
 plot(x,q$estimate/1e6,type='n',ylim=range(q$basic_lo,q$basic_hi,0)/1e6,xlab='Through week',ylab='Million uses',main='Cumulative effect: 95% basic CI')
 polygon(c(x,rev(x)),c(q$basic_lo,rev(q$basic_hi))/1e6,col=adjustcolor('#2563eb',.15),border=NA);lines(x,q$estimate/1e6,col='#2563eb',lwd=2);abline(h=0,lty=2,col='gray50')
}
pdf(file.path(out,'r4_main_figures.pdf'),width=12,height=8);plot_all();dev.off()
png(file.path(out,'r4_main_figures.png'),width=1800,height=1200,res=150);plot_all();dev.off()
print(summary[summary$metric=='effect_pct',c('window','weeks','estimate','basic_lo','basic_hi')],row.names=FALSE)
print(g,row.names=FALSE);cat('Saved:',out,'\n')
