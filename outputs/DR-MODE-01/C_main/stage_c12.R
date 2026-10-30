options(survey.lonely.psu='fail')
suppressPackageStartupMessages(library(survey));library(jsonlite)
root<-'outputs/DR-MODE-01';st<-fromJSON(file.path(root,'status.json'),simplifyVector=FALSE)
stopifnot(st$gates$B$status=='PASS')
raw<-readRDS('work/nhanes_stage_a_merged.rds')
cycs<-c('G','H','I','J','L')
suffix<-c('TNUMF','TKCAL','TSUGR','TALCO','TCAFF','TMOIS','TIRON','TCALC','TSODI','TPROT','TTFAT','TFIBE')
outcomes<-c('Y1','Y2','total_sugars','alcohol','caffeine','moisture','iron','calcium','sodium','protein_energy_pct','fat_energy_pct','fiber')
basecols<-c('SEQN','cycle','adult','youth','WTDRD1','WTDR2D','SDMVSTRA','SDMVPSU','RIDAGEYR','RIAGENDR','RIDRETH3','DMDEDUC2','interval','weekend1','weekend2','language1','language2','proxy1','proxy2','age_group','cov_complete')
d<-do.call(rbind,lapply(raw,function(x)x[,c(basecols,paste0('DR1',suffix),paste0('DR2',suffix))]))
for(y in outcomes) {
 s<-suffix[match(y,outcomes)]
 for(day in 1:2) {
  v<-d[[paste0('DR',day,s)]]
  if(y=='protein_energy_pct')v<-100*4*v/d[[paste0('DR',day,'TKCAL')]]
  else if(y=='fat_energy_pct')v<-100*9*v/d[[paste0('DR',day,'TKCAL')]]
  else if(y!='Y1')v<-log1p(v)
  v[!is.finite(v)]<-NA_real_
  d[[paste0(y,'_day',day)]]<-v
 }
 d[[y]]<-d[[paste0(y,'_day2')]]-d[[paste0(y,'_day1')]]
}
d<-d[!is.na(d$WTDR2D)&d$WTDR2D>0,]
d$cycle<-factor(d$cycle,levels=cycs);d$is_L<-as.numeric(d$cycle=='L')
d$time<-c(G=2012,H=2014,I=2016,J=2018,L=2022.7)[as.character(d$cycle)]-2015
d$w<-d$WTDR2D/5
d$stratum<-interaction(d$cycle,d$SDMVSTRA,drop=TRUE);d$psu<-interaction(d$cycle,d$SDMVSTRA,d$SDMVPSU,drop=TRUE)
for(v in c('language1','language2','proxy1','proxy2','RIAGENDR'))d[[v]]<-factor(d[[v]])
full<-svydesign(ids=~psu,strata=~stratum,weights=~w,data=d,nest=TRUE)
des<-subset(full,adult&cov_complete)
covariates<-'weekend1 + weekend2 + interval + language1 + language2 + proxy1 + proxy2 + age_group + RIAGENDR'
rows<-list();models<-list();cyclemeans<-list()
for(y in outcomes) {
 for(ref in c('control_mean','linear_extrapolation')) {
  rhs<-paste('is_L +',covariates,if(ref=='linear_extrapolation')'+ time' else '')
  mod<-svyglm(as.formula(paste(y,'~',rhs)),design=des,na.action=na.omit)
  stopifnot(!anyNA(coef(mod)))
  b<-unname(coef(mod)['is_L']);se<-unname(SE(mod)['is_L']);df<-mod$df.residual
  ci<-b+c(-1,1)*qt(.975,df)*se;p<-2*pt(-abs(b/se),df)
  rows[[paste(y,ref)]]<-data.frame(outcome=y,reference=ref,n_persons=nobs(mod),DiD=b,se=se,df=df,ci_low=ci[1],ci_high=ci[2],p=p,mode_effect=-b,mode_ci_low=-ci[2],mode_ci_high=-ci[1])
  models[[paste(y,ref)]]<-mod
 }
 for(cy in cycs) {
  ds<-subset(full,adult&cycle==cy)
  z<-svymean(as.formula(paste0('~',y)),ds,na.rm=TRUE)
  m1<-svymean(as.formula(paste0('~',y,'_day1')),ds,na.rm=TRUE)
  cyclemeans[[paste(y,cy)]]<-data.frame(outcome=y,cycle=cy,n_persons=sum(!is.na(ds$variables[[y]])),D_mean=unname(coef(z)),D_se=unname(SE(z)),day1_mean=unname(coef(m1)),day1_se=unname(SE(m1)))
 }
}
res<-do.call(rbind,rows);cm<-do.call(rbind,cyclemeans)
res$q_BH<-NA_real_
for(ref in c('control_mean','linear_extrapolation')) {
 ix<-which(!res$outcome %in% c('Y1','Y2') & res$reference==ref)
 res$q_BH[ix]<-p.adjust(res$p[ix],method='BH')
}
gates<-lapply(c('Y1','Y2'),function(y){
 z<-res[res$outcome==y,];m<-z[z$reference=='control_mean',];csd<-sd(cm$D_mean[cm$outcome==y & cm$cycle %in% c('G','H','I','J')])
 data.frame(outcome=y,both_p_lt_001=all(z$p<.01),same_sign=length(unique(sign(z$DiD)))==1&&all(z$DiD!=0),control_cycle_SD=csd,size_threshold=2*csd,main_abs_DiD=abs(m$DiD),main_size_pass=abs(m$DiD)>2*csd,alternate_abs_DiD=abs(z$DiD[z$reference=='linear_extrapolation']),C1_pass=all(z$p<.01)&&length(unique(sign(z$DiD)))==1&&all(z$DiD!=0)&&abs(m$DiD)>2*csd)
})
gates<-do.call(rbind,gates)
eligible<-c(gates$outcome[gates$C1_pass],res$outcome[res$reference=='control_mean'&!is.na(res$q_BH)&res$q_BH<.05])
write.csv(res,file.path(root,'C_main/DiD_all_outcomes.csv'),row.names=FALSE)
write.csv(cm,file.path(root,'C_main/cycle_means.csv'),row.names=FALSE)
write.csv(gates,file.path(root,'C_main/C1_gate_results.csv'),row.names=FALSE)
write_json(list(C1_pass=any(gates$C1_pass),C3_eligible_outcomes=eligible,primary_gates=gates),file.path(root,'C_main/C12_results.json'),pretty=TRUE,auto_unbox=TRUE,digits=16)
saveRDS(list(data=d,full_design=full,adult_design=des,models=models,outcomes=outcomes,covariates=covariates),'work/stage_c12.rds')
print(res,row.names=FALSE);print(gates,row.names=FALSE);cat('C3 eligible:',paste(eligible,collapse=', '),'\n')
