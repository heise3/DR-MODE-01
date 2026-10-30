options(survey.lonely.psu='fail')
suppressPackageStartupMessages(library(survey));library(haven);library(jsonlite)
root<-'outputs/DR-MODE-01';saved<-readRDS('work/stage_c12.rds');d<-saved$data
covars<-saved$covariates;outcomes<-saved$outcomes
rows<-list();errors<-list();nrows<-list()
fit_panel<-function(des,label) {
 for(y in outcomes)for(ref in c('control_mean','linear_extrapolation')) {
  key<-paste(label,y,ref)
  fit<-tryCatch(svyglm(as.formula(paste(y,'~ is_L +',covars,if(ref=='linear_extrapolation')'+ time' else '')),design=des,na.action=na.omit),error=function(e)e)
  if(inherits(fit,'error')) {errors[[key]]<<-conditionMessage(fit);next}
  b<-unname(coef(fit)['is_L']);se<-unname(SE(fit)['is_L']);df<-fit$df.residual;ci<-b+c(-1,1)*qt(.975,df)*se
  rows[[key]]<<-data.frame(analysis=label,outcome=y,reference=ref,n_persons=nobs(fit),DiD=b,se=se,df=df,ci_low=ci[1],ci_high=ci[2],p=2*pt(-abs(b/se),df))
 }
 for(cy in unique(as.character(des$variables$cycle)))nrows[[paste(label,cy)]]<<-data.frame(analysis=label,cycle=cy,n_persons=sum(des$variables$cycle==cy))
}
# 1: fixed interval sensitivity
fit_panel(subset(saved$adult_design,interval>=3&interval<=10),'interval_3_10')
# 2: youth, same covariates with age groups appropriate to 2-19
dy<-d;dy$age_group<-cut(dy$RIDAGEYR,c(1,5,11,19),labels=c('2-5','6-11','12-19'))
dy$cc_youth<-complete.cases(dy[,c('weekend1','weekend2','interval','language1','language2','proxy1','proxy2','age_group','RIAGENDR')])
yd<-svydesign(ids=~psu,strata=~stratum,weights=~w,data=dy,nest=TRUE)
fit_panel(subset(yd,youth&cc_youth),'youth_2_19')
# 3: rake four margins to J
dr<-d;dr$global_row<-seq_len(nrow(dr));dr$race<-factor(dr$RIDRETH3,levels=c(1,2,3,4,6,7));dr$education<-factor(ifelse(dr$DMDEDUC2 %in% 1:5,dr$DMDEDUC2,NA),levels=1:5)
dr$rake_eligible<-dr$adult&dr$cov_complete&!is.na(dr$race)&!is.na(dr$education)
rd<-svydesign(ids=~psu,strata=~stratum,weights=~w,data=dr,nest=TRUE)
vars<-c('age_group','RIAGENDR','race','education')
formulas<-lapply(vars,function(v)as.formula(paste0('~',v)))
target<-lapply(vars,function(v)as.data.frame(xtabs(as.formula(paste('w~',v)),data=dr[dr$rake_eligible&dr$cycle=='J',])))
dr$rw<-dr$w;rq<-list();rerrors<-list()
for(cy in levels(dr$cycle)) {
 dc<-subset(rd,rake_eligible&cycle==cy)
 rr<-tryCatch(rake(dc,sample.margins=formulas,population.margins=target,control=list(maxit=100,epsilon=1e-7,verbose=FALSE)),error=function(e)e)
 if(inherits(rr,'error')) {rerrors[[cy]]<-conditionMessage(rr);next}
 ww<-as.numeric(weights(rr));dr$rw[rr$variables$global_row]<-ww
 err<-max(vapply(seq_along(vars),function(i) {tab<-as.data.frame(svytable(formulas[[i]],rr));max(abs(tab$Freq-target[[i]]$Freq)/sum(target[[i]]$Freq))},numeric(1)))
 rq[[cy]]<-data.frame(cycle=cy,n_persons=length(ww),sum_weights=sum(ww),min_weight=min(ww),max_weight=max(ww),min_adjustment=min(ww/weights(dc)),max_adjustment=max(ww/weights(dc)),kish_effective_n=sum(ww)^2/sum(ww^2),max_abs_margin_fraction_error=err)
 if(err>1e-7)rerrors[[cy]]<-paste('raking convergence error',err)
}
if(length(rerrors)==0) {
 rd2<-svydesign(ids=~psu,strata=~stratum,weights=~rw,data=dr,nest=TRUE)
 fit_panel(subset(rd2,rake_eligible),'raked_to_J_four_margins')
} else errors[['raking']]<-rerrors
write.csv(do.call(rbind,rq),file.path(root,'C_main/raking_diagnostics.csv'),row.names=FALSE)
# 4: P replaces J
p1<-as.data.frame(read_xpt(file.path(root,'A_access/data/P_DR1TOT.xpt')))
p2<-as.data.frame(read_xpt(file.path(root,'A_access/data/P_DR2TOT.xpt')))
pm<-as.data.frame(read_xpt(file.path(root,'A_access/data/P_DEMO.xpt')))
stopifnot(!anyDuplicated(p1$SEQN),!anyDuplicated(p2$SEQN),!anyDuplicated(pm$SEQN))
pd<-merge(p1,p2[,c('SEQN',setdiff(names(p2),names(p1)))],by='SEQN',all=TRUE)
pd<-merge(pm,pd,by='SEQN',all.x=TRUE)
pd$cycle<-'P';pd$WTDR2D<-pd$WTDR2DPP;pd$WTDRD1<-pd$WTDRD1PP
pd$both<-!is.na(pd$DR1DRSTZ)&!is.na(pd$DR2DRSTZ)&pd$DR1DRSTZ==1&pd$DR2DRSTZ==1
pd$adult<-pd$both&pd$RIDAGEYR>=20&!is.na(pd$DRABF)&pd$DRABF!=1
pd$interval<-abs(pd$DR1DBIH-pd$DR2DBIH)
pd$weekend1<-ifelse(is.na(pd$DR1DAY),NA,as.numeric(pd$DR1DAY %in% c(1,7)))
pd$weekend2<-ifelse(is.na(pd$DR2DAY),NA,as.numeric(pd$DR2DAY %in% c(1,7)))
pd$language1<-factor(ifelse(pd$DR1LANG %in% 1:6,pmin(pd$DR1LANG,4),NA),levels=1:4)
pd$language2<-factor(ifelse(pd$DR2LANG %in% 1:6,pmin(pd$DR2LANG,4),NA),levels=1:4)
pd$proxy1<-factor(ifelse(pd$DR1MRESP %in% c(1:3,5:11),as.numeric(pd$DR1MRESP!=1),NA),levels=0:1)
pd$proxy2<-factor(ifelse(pd$DR2MRESP %in% c(1:3,5:11),as.numeric(pd$DR2MRESP!=1),NA),levels=0:1)
pd$age_group<-cut(pd$RIDAGEYR,c(19,39,59,Inf),labels=c('20-39','40-59','60+'))
pd$RIAGENDR<-factor(pd$RIAGENDR,levels=1:2)
pd$cov_complete<-complete.cases(pd[,c('weekend1','weekend2','interval','language1','language2','proxy1','proxy2','age_group','RIAGENDR')])
suffix<-c('TNUMF','TKCAL','TSUGR','TALCO','TCAFF','TMOIS','TIRON','TCALC','TSODI','TPROT','TTFAT','TFIBE')
for(y in outcomes) {
 s<-suffix[match(y,outcomes)];v1<-pd[[paste0('DR1',s)]];v2<-pd[[paste0('DR2',s)]]
 if(y=='protein_energy_pct') {v1<-400*v1/pd$DR1TKCAL;v2<-400*v2/pd$DR2TKCAL}
 else if(y=='fat_energy_pct') {v1<-900*v1/pd$DR1TKCAL;v2<-900*v2/pd$DR2TKCAL}
 else if(y!='Y1') {v1<-log1p(v1);v2<-log1p(v2)}
 pd[[y]]<-v2-v1;pd[[y]][!is.finite(pd[[y]])]<-NA_real_
}
write_json(list(cycle='P',n_both_reliable_all_ages=sum(pd$both),n_adults=sum(pd$adult),n_adults_cov_complete=sum(pd$adult&pd$cov_complete),overlap_rule='P replaces J'),file.path(root,'C_main/P_person_counts.json'),pretty=TRUE,auto_unbox=TRUE)
pd<-pd[!is.na(pd$WTDR2D)&pd$WTDR2D>0,]
keep<-c('SEQN','cycle','adult','WTDR2D','SDMVSTRA','SDMVPSU','interval','weekend1','weekend2','language1','language2','proxy1','proxy2','age_group','RIAGENDR','cov_complete',outcomes)
dp<-rbind(d[d$cycle!='J',keep],pd[,keep]);dp$cycle<-factor(dp$cycle,levels=c('G','H','I','P','L'))
stopifnot(!anyDuplicated(paste(dp$cycle,dp$SEQN)),!('J' %in% as.character(dp$cycle)))
dp$is_L<-as.numeric(dp$cycle=='L');dp$time<-c(G=2012,H=2014,I=2016,P=2018.6,L=2022.7)[as.character(dp$cycle)]-2015
dp$w<-dp$WTDR2D*ifelse(dp$cycle=='P',3.2,2)/11.2
dp$stratum<-interaction(dp$cycle,dp$SDMVSTRA,drop=TRUE);dp$psu<-interaction(dp$cycle,dp$SDMVSTRA,dp$SDMVPSU,drop=TRUE)
pdes<-svydesign(ids=~psu,strata=~stratum,weights=~w,data=dp,nest=TRUE)
fit_panel(subset(pdes,adult&cov_complete),'P_replaces_J')
res<-do.call(rbind,rows);res$q_BH<-NA_real_
for(an in unique(res$analysis))for(ref in unique(res$reference)) {
 ix<-which(res$analysis==an & res$reference==ref & !res$outcome %in% c('Y1','Y2'));res$q_BH[ix]<-p.adjust(res$p[ix],'BH')
}
write.csv(res,file.path(root,'C_main/sensitivity_results.csv'),row.names=FALSE)
write.csv(do.call(rbind,nrows),file.path(root,'C_main/sensitivity_person_counts.csv'),row.names=FALSE)
write_json(list(status=if(length(errors))'PARTIAL' else 'EXECUTED',errors=errors),file.path(root,'C_main/sensitivity_status.json'),auto_unbox=TRUE,pretty=TRUE)
print(res[res$outcome %in% c('Y1','Y2'),],row.names=FALSE)
