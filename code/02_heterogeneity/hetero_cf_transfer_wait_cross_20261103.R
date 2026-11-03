## RESTRICTED DATA REQUIRED: model fits and bootstrap draws derived from the smart-card OD panel, plus OD/origin-level covariates.
## Required input files (place under RAW_DIR unless noted):
##   - R2_r4_환승5분위_사전CI_20261011/<eng>/chunk_01.rds ... chunk_05.rds   [folder = "r4 transfer quintiles, pre-computed CI"]
##       (1,000 bootstrap draws per OD pair; the script that produced them is not in this repo)
##   - R2_r4_인구대비_추가이용_20261011/dong_population_effects.csv           [folder = "r4 additional use per population"]
##       (unit_id, pre_population; the script that produced it is not in this repo)
##   - 규모통제_거리환승_20261011/OD_analysis_data.csv                          [folder = "size-controlled distance/transfer"]
##       (transfer, distance_km per OD pair)
##   - AI_uc_보정_20261101.csv, youth_region_20261101.csv, elderly_ratio_unit_20261102.csv, 환승시간_unit매칭_20261101.csv
##       (covariates matched on unit_id; 보정 = "adjusted", 환승시간_unit매칭 = "transfer time, unit-matched")
##   - point.rds: produced by code/01_citywide_gsynth/R2_r4_xu_diagnostics_20261010.R
##       → REPO_ROOT/output/01_citywide_gsynth/R2_r4_xu_diagnostics_20261010/<eng>/point.rds (override: XU_DIR)
## ---- Paths (edit here or set env vars) -------------------------------
REPO_ROOT <- Sys.getenv("REPO_ROOT", ".")                       # run from repo root
RAW_DIR   <- Sys.getenv("RAW_DIR", file.path(REPO_ROOT, "data/restricted"))   # inputs not in the repository (restricted OD panel or not-yet-uploaded files)
OUT_DIR   <- Sys.getenv("OUT_DIR", file.path(REPO_ROOT, "output", "02_heterogeneity/R2_r4_transfer_wait_cross_20261103"))
XU_DIR    <- Sys.getenv("XU_DIR", file.path(REPO_ROOT, "output", "01_citywide_gsynth", "R2_r4_xu_diagnostics_20261010"))   # location of point.rds
## Run (from repo root): Rscript code/02_heterogeneity/hetero_cf_transfer_wait_cross_20261103.R
eng <- "PATCHED_local_weight_v2_cvmax_v1_audit_v1_fect2.4.7_h748c651816_srce78b1e9155"
f <- readRDS(file.path(XU_DIR, eng, "point.rds"))$fit
chunks <- file.path(RAW_DIR, "R2_r4_환승5분위_사전CI_20261011", eng, sprintf("chunk_%02d.rds", 1:5))
out <- OUT_DIR
p  <- read.csv(file.path(RAW_DIR, "R2_r4_인구대비_추가이용_20261011/dong_population_effects.csv"))
x  <- read.csv(file.path(RAW_DIR, "규모통제_거리환승_20261011/OD_analysis_data.csv"))
ai <- read.csv(file.path(RAW_DIR, "AI_uc_보정_20261101.csv")); yr <- read.csv(file.path(RAW_DIR, "youth_region_20261101.csv"))
el <- read.csv(file.path(RAW_DIR, "elderly_ratio_unit_20261102.csv")); wt <- read.csv(file.path(RAW_DIR, "환승시간_unit매칭_20261101.csv"))
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
# Map Korean planning-region values in the input (도심권 = Downtown, 동북권 = Northeast, 서북권 = Northwest, 서남권 = Southwest, 동남권 = Southeast)
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

transfer_group<-axes$transfer;wait_group<-axes$wait
joint<-paste(transfer_group,wait_group,sep="_");joint[is.na(transfer_group)|is.na(wait_group)]<-NA
axes<-list(joint=joint)
counts<-as.data.frame(table(transfer=transfer_group[keep & !is.na(joint)],wait=wait_group[keep & !is.na(joint)]))
write.csv(counts,file.path(out,"cell_counts.csv"),row.names=FALSE)
theta<-lapply(axes,function(g)gw(f$id[tr],f$Y.dat[,tr]-f$Y.ct[,tr],g))
sims<-lapply(theta,function(t)matrix(NA_real_,length(t),1000,dimnames=list(names(t),NULL)))
for(j in 1:5){a<-readRDS(chunks[j]);stopifnot(identical(a$all_week_index,f$rawtime),length(a$od_draws)==200)
 for(i in 1:200){d<-a$od_draws[[i]];for(nm in names(axes))sims[[nm]][,(j-1)*200+i]<-gw(d$unit_id,d$gap_all_weeks,axes[[nm]])}
 rm(a);gc(FALSE);cat("Completed chunk",j,"/5\n")
}
ci<-function(t,s){ok<-is.finite(s);se<-sd(s[ok]);c(est=unname(t),SE=se,lo=unname(t)-1.96*se,hi=unname(t)+1.96*se,p=2*pnorm(-abs(unname(t)/se)),n_valid=sum(ok))}
G<-do.call(rbind,lapply(names(axes),function(nm)do.call(rbind,lapply(names(theta[[nm]]),function(k){z<-strsplit(k,"|",fixed=TRUE)[[1]];data.frame(axis=nm,group=z[1],window=z[2],t(ci(theta[[nm]][k],sims[[nm]][k,])))}))))

t<-theta$joint;ss<-sims$joint
pairs<-list()
for(q in paste0("Q",1:3)){
 pairs[[paste0("wait_long_minus_short_at_transfer_",q)]]<-setNames(c(1,-1),paste0(q,c("_Q3","_Q1")))
 pairs[[paste0("transfer_high_minus_low_at_wait_",q)]]<-setNames(c(1,-1),paste0(c("Q3_","Q1_"),q))
}
pairs$interaction<-c(Q3_Q3=1,Q3_Q1=-1,Q1_Q3=-1,Q1_Q1=1)
C<-do.call(rbind,lapply(names(pairs),function(nm){
 a<-pairs[[nm]]
 pt<-function(w)sum(a*t[paste(names(a),w,sep="|")])
 draws<-function(w)colSums(ss[paste(names(a),w,sep="|"),,drop=FALSE]*a)
 rbind(do.call(rbind,lapply(names(win),function(w)data.frame(contrast=nm,window=w,t(ci(pt(w),draws(w)))))),data.frame(contrast=nm,window="late_minus_early",t(ci(pt("late")-pt("early"),draws("late")-draws("early")))))
}))
write.csv(G,file.path(out,"group_cf_pct.csv"),row.names=FALSE)
write.csv(C,file.path(out,"contrast_cf_pct.csv"),row.names=FALSE)
saveRDS(list(theta=theta,sims=sims,windows=win,boundaries=bounds),file.path(out,"bootstrap_aggregates.rds"))
writeLines(c("Joint transfer burden x waiting time analysis (2026-11-03)",
"Existing marginal tertile boundaries retained: transfer all409 origins, waiting matched354; population>=1000 joint sample.",
"Each cell: 100*sum(gap)/sum(counterfactual), fixed full-model fit, 1000 paired bootstrap draws with resampled IDs retained.",
"Normal 95% CI; unadjusted p-values; cell effects in %, contrasts in percentage points.",
"Interaction = (long-short wait effect difference within high transfer) - (long-short within low transfer). This is descriptive effect heterogeneity, not causal effects of transfer or waiting time.",
"Waiting time includes transfer walking plus waiting, source June-August2023, all day, initial wait excluded.",
"No subgroup refits, no thresholds chosen using estimated effects. Invalid draw counts reported via n_valid.",
"Script: _review/hetero_cf_transfer_wait_cross_20261103.R"),file.path(out,"README.txt"))
print(counts);print(G[G$window %in% c("full","early","late"),],row.names=FALSE)
print(C[C$window %in% c("full","late_minus_early"),],row.names=FALSE)
library(ggplot2)
pd<-G[grepl("^w",G$window),]
pd$transfer<-factor(substr(pd$group,1,2),levels=c("Q1","Q2","Q3"),labels=c("Low transfer burden","Medium transfer burden","High transfer burden"))
pd$wait<-factor(substr(pd$group,4,5),levels=c("Q1","Q2","Q3"),labels=c("Short waiting time","Medium waiting time","Long waiting time"))
pd$window<-factor(pd$window,levels=c("w01_12","w13_24","w25_36","w37_46"),labels=c("1–12","13–24","25–36","37–46"))
plot<-ggplot(pd,aes(window,est,colour=wait,group=wait))+geom_hline(yintercept=0,linetype=2,colour="grey65")+geom_errorbar(aes(ymin=lo,ymax=hi),width=.12,alpha=.5,position=position_dodge(.18))+geom_line(position=position_dodge(.18))+geom_point(position=position_dodge(.18))+facet_wrap(~transfer,nrow=1)+scale_colour_manual(values=c("#2166ac","#777777","#b2182b"))+labs(x="Observed post-treatment weeks",y="Increase relative to counterfactual (%)",colour=NULL,caption="95% normal-approximation intervals; 1,000 bootstrap draws. Final interval: 10 weeks.")+theme_minimal(base_size=11)+theme(legend.position="bottom")
ggsave(file.path(out,"joint_timepath.png"),plot,width=12,height=5,dpi=180,bg="white")
