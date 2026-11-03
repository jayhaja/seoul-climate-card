library(ggplot2)
out<-"scm_results/R2_r4_반사실_3분위_시간경로_20261103"
d<-read.csv(file.path(out,"group_cf_pct.csv"));d<-d[d$window %in% c("early","late"),]
d$axis<-factor(d$axis,levels=c("transfer","wait","access","distance","youth","elderly","region"),labels=c("Transfer burden","Waiting time","Accessibility","Travel distance","Youth share","Elderly share","Planning region"))
d$window<-factor(d$window,levels=c("early","late"),labels=c("Weeks 1–12","Weeks 13–46"))
d$group<-factor(d$group,levels=c("Q1","Q2","Q3","Downtown","Northeast","Northwest","Southeast","Southwest"),labels=c("Low / Short","Middle","High / Long","Central","NE","NW","SE","SW"))
p<-ggplot(d,aes(group,est,shape=window))+geom_hline(yintercept=0,colour="grey65",linetype=2)+geom_pointrange(aes(ymin=lo,ymax=hi),position=position_dodge(.45),linewidth=.35)+facet_wrap(~axis,ncol=3,scales="free_x")+scale_shape_manual(values=c(1,16))+labs(x=NULL,y="Increase relative to counterfactual (%)",shape=NULL)+theme_minimal(base_size=11)+theme(legend.position="bottom",axis.text.x=element_text(size=8))
ggsave(file.path(out,"fig6_5_cf_early_late.png"),p,width=11,height=8,dpi=180,bg="white")
