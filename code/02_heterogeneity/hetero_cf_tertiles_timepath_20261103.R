ts  <- path.expand("~/Documents/thesis_summary")
eng <- "PATCHED_local_weight_v2_cvmax_v1_audit_v1_fect2.4.7_h748c651816_srce78b1e9155"
f <- readRDS(file.path("/Users/maeg/Thesis/0614/public.transportation/0702/scm_results/R2_r4_Xu권고진단_20261010", eng, "point.rds"))$fit
chunks <- file.path(ts, "scm_results/R2_r4_환승5분위_사전CI_20261011", eng, sprintf("chunk_%02d.rds", 1:5))
out <- file.path(ts, "scm_results/R2_r4_반사실_3분위_시간경로_20261103")
p  <- read.csv(file.path(ts, "scm_results/R2_r4_인구대비_추가이용_20261011/dong_population_effects.csv"))
x  <- read.csv(file.path(ts, "_review/규모통제_거리환승_20261011/OD_analysis_data.csv"))
ai <- read.csv(file.path(ts, "_review/AI_uc_보정_20261101.csv")); yr <- read.csv(file.path(ts, "_review/youth_region_20261101.csv"))
el <- read.csv(file.path(ts, "_review/elderly_ratio_unit_20261102.csv")); wt <- read.csv(file.path(ts, "_review/환승시간_unit매칭_20261101.csv"))
m <- function(d, v) d[[v]][match(p$unit_id, d$unit_id)]

dir.create(out, recursive=TRUE, showWarnings=FALSE)
stopifnot(!anyDuplicated(p$unit_id))
values <- list(transfer=m(x,"transfer"), wait=m(wt,"minutes_per_trip"),
 access=m(ai,"AI_uc"), distance=m(x,"distance_km"), youth=m(yr,"youth_ratio"), elderly=m(el,"elderly_ratio"))
titles <- c(transfer="Transfer burden", wait="Waiting time", access="Accessibility", distance="Travel distance", youth="Youth share", elderly="Elderly share", region="Planning region")
keep <- p$pre_population>=1000
bounds <- list(); axes <- list()
for(nm in names(values)) {
 v<-values[[nm]]; q<-quantile(v[is.finite(v)],seq(0,1,length.out=4),type=7)
 stopifnot(length(unique(q))==4)
 g<-paste0("Q",cut(v,q,include.lowest=TRUE,labels=FALSE)); g[!is.finite(v)]<-NA
 axes[[nm]]<-g
 bounds[[nm]]<-data.frame(axis=nm,group=paste0("Q",1:3),lower=q[1:3],upper=q[2:4],
  n_all=sapply(paste0("Q",1:3),function(l)sum(g==l,na.rm=TRUE)),
  n_main=sapply(paste0("Q",1:3),function(l)sum(g==l & keep,na.rm=TRUE)))
}
reg<-c(도심권="Downtown",동북권="Northeast",서북권="Northwest",서남권="Southwest",동남권="Southeast")
axes$region<-unname(reg[m(yr,"region")])
write.csv(do.call(rbind,bounds),file.path(out,"tertile_boundaries_counts.csv"),row.names=FALSE)
write.csv(data.frame(unit_id=p$unit_id,pre_population=p$pre_population,values,setNames(axes,paste0(names(axes),"_group"))),file.path(out,"membership.csv"),row.names=FALSE)
tr<-which(colSums(f$D.dat)>0); post<-which(seq_len(nrow(f$D.dat))>=min(which(rowSums(f$D.dat)>0)))
stopifnot(length(post)==46)
win<-list(full=post,early=post[1:12],late=post[13:46],w01_12=post[1:12],w13_24=post[13:24],w25_36=post[25:36],w37_46=post[37:46])
observed<-lapply(win,function(w)setNames(colSums(f$Y.dat[w,tr,drop=FALSE]),f$id[tr]))
gw<-function(ids,gapmat,g){
 ix<-match(ids,p$unit_id);stopifnot(!anyNA(ix),ncol(gapmat)==length(ids))
 v<-c()
 for(l in sort(unique(na.omit(g)))) {
  k<-g[ix]==l & keep[ix];k[is.na(k)]<-FALSE
  for(w in names(win)) {
   gs<-sum(gapmat[win[[w]],k,drop=FALSE]);ob<-observed[[w]][as.character(ids)]
   stopifnot(!anyNA(ob)); cf<-sum(ob[k])-gs
   v[paste(l,w,sep="|")]<-if(sum(k)>0 && is.finite(cf) && cf>0)100*gs/cf else NA_real_
  }
 };v
}
theta<-lapply(axes,function(g)gw(f$id[tr],f$Y.dat[,tr]-f$Y.ct[,tr],g))
sims<-lapply(theta,function(t)matrix(NA_real_,length(t),1000,dimnames=list(names(t),NULL)))
for(j in 1:5){a<-readRDS(chunks[j]);stopifnot(identical(a$all_week_index,f$rawtime),length(a$od_draws)==200)
 for(i in 1:200){d<-a$od_draws[[i]];for(nm in names(axes))sims[[nm]][,(j-1)*200+i]<-gw(d$unit_id,d$gap_all_weeks,axes[[nm]])}
 rm(a);gc(FALSE);cat("Completed chunk",j,"/5\n")
}
ci<-function(t,s){ok<-is.finite(s);se<-sd(s[ok]);c(est=unname(t),SE=se,lo=unname(t)-1.96*se,hi=unname(t)+1.96*se,p=2*pnorm(-abs(unname(t)/se)),n_valid=sum(ok))}
G<-do.call(rbind,lapply(names(axes),function(nm)do.call(rbind,lapply(names(theta[[nm]]),function(k){z<-strsplit(k,"|",fixed=TRUE)[[1]];data.frame(axis=nm,group=z[1],window=z[2],t(ci(theta[[nm]][k],sims[[nm]][k,])))}))))
C<-do.call(rbind,lapply(names(values),function(nm){
 d<-function(w)theta[[nm]][paste0("Q3|",w)]-theta[[nm]][paste0("Q1|",w)]
 ds<-function(w)sims[[nm]][paste0("Q3|",w),]-sims[[nm]][paste0("Q1|",w),]
 rbind(do.call(rbind,lapply(names(win),function(w)data.frame(axis=nm,contrast="Q3-Q1",window=w,t(ci(d(w),ds(w)))))),
 data.frame(axis=nm,contrast="Q3-Q1",window="late_minus_early",t(ci(d("late")-d("early"),ds("late")-ds("early")))))
}))
write.csv(G,file.path(out,"group_cf_pct.csv"),row.names=FALSE)
write.csv(C,file.path(out,"contrast_cf_pct.csv"),row.names=FALSE)
saveRDS(list(theta=theta,sims=sims,windows=win,boundaries=bounds),file.path(out,"bootstrap_aggregates.rds"))
writeLines(c("Counterfactual-relative effects, tertile sensitivity analysis, 2026-11-03",
"Effect (%) = 100 * sum(observed - counterfactual) / sum(counterfactual). Ratio of sums, not mean of individual percentages.",
"Thresholds: type-7 quantiles of all available origins, then population >=1000 filter. Boundaries fixed in bootstrap.",
"Waiting-time source: June-August 2023; includes walking and waiting during transfers; excludes initial boarding wait.",
"Reaggregates existing full-model point estimates and 1000 paired bootstrap draws. No model refitting.",
"Normal-approximation 95% CI; unadjusted p-values; contrasts in percentage points. All raw precision preserved.",
"Windows use observed post-treatment week order; final window has 10 weeks. No daily conversion required.",
"Resampled duplicate unit IDs retained for both gap and observed totals. Invalid denominator/empty-group draws excluded and counted in n_valid.",
"Source script: _review/hetero_cf_tertiles_20261103.R"),file.path(out,"README.txt"))
print(G[G$window=="full",],row.names=FALSE)
print(C[C$window %in% c("full","late_minus_early"),],row.names=FALSE)
library(ggplot2)
plotdata<-G[G$window=="full" & G$axis!="region",];plotdata$axis<-factor(plotdata$axis,levels=names(values),labels=titles[names(values)])
pngfile<-file.path(out,"tertile_effects.png")
plot<-ggplot(plotdata,aes(group,est,group=1))+geom_hline(yintercept=0,color="grey65",linetype=2)+geom_line(color="#2166ac")+geom_pointrange(aes(ymin=lo,ymax=hi),color="#2166ac")+facet_wrap(~axis,ncol=3)+labs(x="Tertile (Q1 = lowest; Q3 = highest)",y="Increase relative to counterfactual (%)",caption="95% normal-approximation intervals; 1,000 bootstrap draws. Origins with population >= 1,000.")+theme_minimal(base_size=11)
ggsave(pngfile,plot,width=11,height=6,dpi=180,bg="white")
