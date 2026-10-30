options(survey.lonely.psu='fail')
suppressPackageStartupMessages(library(survey));library(jsonlite)
root<-'outputs/DR-MODE-01';st<-fromJSON(file.path(root,'status.json'),simplifyVector=FALSE)
stopifnot(all(vapply(st$gates[c('A0','A1','A2','A3')],function(x)x$status=='PASS',logical(1))))
raw<-readRDS('work/nhanes_stage_a_merged.rds')
cols<-c('SEQN','cycle','adult','WTDR2D','SDMVSTRA','SDMVPSU','DR1TNUMF','DR2TNUMF','DR1TKCAL','DR2TKCAL')
d<-do.call(rbind,lapply(raw[c('G','H','I','J')],function(x)x[,cols]))
d<-d[!is.na(d$WTDR2D)&d$WTDR2D>0,]
d$Y1<-d$DR2TNUMF-d$DR1TNUMF
d$Y2<-log1p(d$DR2TKCAL)-log1p(d$DR1TKCAL)
d$cycle<-factor(d$cycle,levels=c('G','H','I','J'))
d$time<-c(G=2012,H=2014,I=2016,J=2018)[as.character(d$cycle)]-2015
d$w<-d$WTDR2D/4
d$stratum<-interaction(d$cycle,d$SDMVSTRA,drop=TRUE)
d$psu<-interaction(d$cycle,d$SDMVSTRA,d$SDMVPSU,drop=TRUE)
full<-svydesign(ids=~psu,strata=~stratum,weights=~w,data=d,nest=TRUE)
des<-subset(full,adult)
out<-list(); means<-list(); fits<-list()
for(y in c('Y1','Y2')) {
  f<-as.formula(paste(y,'~cycle')); ft<-as.formula(paste(y,'~time'))
  mod<-svyglm(f,design=des,na.action=na.omit)
  test<-regTermTest(mod,~cycle,method='Wald')
  tr<-svyglm(ft,design=des,na.action=na.omit)
  a<-c(1,2022.7-2015);est<-sum(a*coef(tr));se<-sqrt(drop(t(a)%*%vcov(tr)%*%a))
  ci<-est+c(-1,1)*qt(.975,tr$df.residual)*se
  mu<-svymean(as.formula(paste0('~',y)),des,na.rm=TRUE)
  p<-as.numeric(test$p);width<-diff(ci);bound<-2*abs(unname(coef(mu)))
  out[[y]]<-data.frame(outcome=y,n_persons=nobs(mod),n_control_eligible=sum(d$adult),n_missing_outcome=sum(d$adult&is.na(d[[y]])),design_df=degf(des),wald_F=as.numeric(test$Ftest),wald_num_df=as.numeric(test$df),wald_den_df=as.numeric(test$ddf),wald_p=p,control_D_mean=unname(coef(mu)),control_D_se=unname(SE(mu)),trend_per_year=coef(tr)[2],trend_se=SE(tr)[2],trend_df=tr$df.residual,trend_p=summary(tr)$coefficients[2,4],L_extrapolated_D=est,L_extrapolated_se=se,L_ci_low=ci[1],L_ci_high=ci[2],L_ci_width=width,width_threshold=bound,wald_pass=p>.05,width_pass=width<bound,endpoint_pass=p>.05&width<bound)
  for(cy in levels(d$cycle)) {
    sc<-subset(des,cycle==cy); m<-svymean(as.formula(paste0('~',y)),sc,na.rm=TRUE)
    means[[paste(y,cy)]]<-data.frame(outcome=y,cycle=cy,n_persons=sum(sc$variables$adult&!is.na(sc$variables[[y]])),D_mean=unname(coef(m)),se=unname(SE(m)))
  }
  fits[[y]]<-list(heterogeneity=mod,trend=tr,test=test)
}
res<-do.call(rbind,out);cm<-do.call(rbind,means)
write.csv(res,file.path(root,'B_pretrend/gate_results.csv'),row.names=FALSE)
write.csv(cm,file.path(root,'B_pretrend/control_cycle_means.csv'),row.names=FALSE)
saveRDS(fits,'work/stage_b_models.rds')
write_json(list(stage='B',status=if(any(res$endpoint_pass))'PASS' else 'STOP',gate_definition='At least one same endpoint passes both p>0.05 and width<2*abs(pooled mean)',results=res),file.path(root,'B_pretrend/gate_results.json'),auto_unbox=TRUE,pretty=TRUE,digits=16)
print(res,row.names=FALSE);print(cm,row.names=FALSE)
