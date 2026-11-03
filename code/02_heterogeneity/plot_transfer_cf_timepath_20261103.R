library(ggplot2)
out<-"scm_results/R2_r4_반사실_3분위_시간경로_20261103"
d<-read.csv(file.path(out,"group_cf_pct.csv"))
d<-d[d$axis=="transfer" & grepl("^w",d$window),]
d$window<-factor(d$window,levels=c("w01_12","w13_24","w25_36","w37_46"),labels=c("Weeks 1–12","Weeks 13–24","Weeks 25–36","Weeks 37–46"))
d$group<-factor(d$group,levels=c("Q1","Q2","Q3"),labels=c("Low transfer burden","Medium transfer burden","High transfer burden"))
p<-ggplot(d,aes(window,est,colour=group,group=group))+geom_hline(yintercept=0,linetype=2,colour="grey60")+geom_errorbar(aes(ymin=lo,ymax=hi),width=.10,position=position_dodge(.18),alpha=.6)+geom_line(position=position_dodge(.18),linewidth=.8)+geom_point(position=position_dodge(.18),size=2.5)+scale_colour_manual(values=c("#2166ac","#777777","#b2182b"))+labs(x=NULL,y="Increase relative to counterfactual (%)",colour=NULL,caption="95% normal-approximation confidence intervals; 1,000 bootstrap draws. Final interval: 10 weeks.")+theme_minimal(base_size=12)+theme(legend.position="bottom")
ggsave(file.path(out,"transfer_timepath_cf.png"),p,width=9,height=5.5,dpi=180,bg="white")
