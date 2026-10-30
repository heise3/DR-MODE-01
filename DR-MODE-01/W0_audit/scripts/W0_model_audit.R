.libPaths(c('work/Rlib',.libPaths()))
suppressPackageStartupMessages(library(ncimultivar));suppressPackageStartupMessages(library(survey));library(jsonlite)
out<-'DR-MODE-01/W0_audit';z<-readRDS('outputs/S1_writing/provenance/analysis_input.rds');d<-z$data
old<-read.csv('outputs/DR-MODE-01/C_main/DiD_all_outcomes.csv');qa<-list()
design<-svydesign(ids=~psu,strata=~stratum,weights=~w,nest=TRUE,data=d)
ad<-subset(design,adult&cov_complete)
for(i in 1:nrow(old)){
 r<-old[i,];rhs<-paste('is_L +',z$covariates,if(r$reference=='linear_extrapolation')'+ time' else '')
 fit<-svyglm(as.formula(paste(r$outcome,'~',rhs)),design=ad)
 b<-unname(coef(fit)['is_L']);se<-unname(SE(fit)['is_L']);p<-2*pt(-abs(b/se),fit$df.residual)
 qa[[i]]<-data.frame(outcome=r$outcome,reference=r$reference,n=nobs(fit),DiD_error=b-r$DiD,SE_error=se-r$se,p_error=p-r$p,df=fit$df.residual,pass=abs(b-r$DiD)<1e-10&&abs(se-r$se)<1e-10&&abs(p-r$p)<1e-10)
}
qa<-do.call(rbind,qa);write.csv(qa,file.path(out,'checks/DiD_refit_audit.csv'),row.names=FALSE)
L<-subset(d,adult&cycle=='L'&cov_complete);nci<-list()
for(sc in c('original','control_mean','linear_extrapolation')){
 folder<-file.path('outputs/S1_writing/S1b_C3c_usual_intake',sc)
 pre<-readRDS(file.path(folder,'preprocessor.rds'));dat<-pre$mcmc.input
 covs<-read.csv(file.path(folder,'covariate_map.csv'))$encoded
 stopifnot(identical(dat$SEQN,rep(L$SEQN,each=2)))
 for(y in c('iron','calcium')){
  suff<-if(y=='iron')'TIRON' else 'TCALC';b<-if(sc=='original')0 else old$DiD[old$outcome==y&old$reference==sc]
  corrected<-if(sc=='original')L[[paste0('DR1',suff)]] else expm1(log1p(L[[paste0('DR1',suff)]])+b)
  err1<-max(abs(corrected-dat[[y]][dat$DAY==1]));err2<-max(abs(L[[paste0('DR2',suff)]]-dat[[y]][dat$DAY==2]))
  bc<-boxcox_survey(input.data=dat,row.subset=dat$DAY==1,variable=y,weight='WTDR2D',covariates=covs,do.plots=FALSE)
  ma<-calculate_minimum_amount(input.data=dat,row.subset=dat$DAY==1,daily.variables=y)
  obc<-read.csv(file.path(folder,'boxcox_lambda.csv'));oma<-read.csv(file.path(folder,'minimum_amount.csv'))
  lerr<-bc$tran_lambda-obc$tran_lambda[obc$variable==y];merr<-ma$minamount-oma$minamount[oma$variable==y]
  nci[[paste(sc,y)]]<-data.frame(scenario=sc,nutrient=y,n_persons=length(unique(dat$SEQN)),day1_max_error=err1,day2_max_error=err2,lambda=bc$tran_lambda,lambda_error=lerr,minimum_amount=ma$minamount,minimum_error=merr,Day2_indicator_pass=all(dat$Day2==as.integer(dat$DAY==2)),weekend1_pass=all(dat$weekend1==rep(L$weekend1,each=2)),weekend2_pass=all(dat$weekend2==rep(L$weekend2,each=2)),calcium_EAR_pass=all(dat$EAR_calcium==rep(ifelse(L$RIDAGEYR>70|(L$RIAGENDR==2&L$RIDAGEYR>50),1000,800),each=2)),all_two_records=all(table(dat$SEQN)==2),weight_pass=all(dat$WTDR2D==rep(L$WTDR2D,each=2)),pass=err1<1e-10&&err2==0&&abs(lerr)<1e-12&&abs(merr)<1e-12)
 }
}
nci<-do.call(rbind,nci);write.csv(nci,file.path(out,'checks/NCI_preprocessor_audit.csv'),row.names=FALSE)
capture.output(survey:::subbootstratum,file=file.path(out,'provenance/survey_subbootstratum_source.txt'))
ct<-read.csv('outputs/S1_writing/S1a_C3a_corrected.csv')
ct$expected_corrected<-ifelse(ct$scale=='original_units',exp(ct$DiD_contract_scale)*(ct$original_L_day1_mean+1)-1,ct$original_L_day1_mean+ct$DiD_contract_scale)
ct$algebra_error<-ct$corrected_L_day1_mean-ct$expected_corrected
write.csv(ct[,c('outcome','reference','scale','algebra_error')],file.path(out,'checks/S1_correction_algebra.csv'),row.names=FALSE)
write_json(list(DiD_all_24_refits_pass=all(qa$pass),DiD_max_difference=max(abs(qa$DiD_error)),NCI_input_all_pass=all(nci$pass)&all(nci$Day2_indicator_pass)&all(nci$weekend1_pass)&all(nci$weekend2_pass)&all(nci$calcium_EAR_pass)&all(nci$all_two_records)&all(nci$weight_pass),NCI_day2_max_change=max(nci$day2_max_error),S1_correction_max_algebra_error=max(abs(ct$algebra_error)),S1_correction_pass=max(abs(ct$algebra_error))<1e-9,weekend_coding='Saturday/Sunday; not Friday-Sunday',nci_weekday_fraction=5/7,nci_weekend_fraction=2/7),file.path(out,'checks/model_audit.json'),auto_unbox=TRUE,pretty=TRUE,digits=16)
stopifnot(all(qa$pass),all(nci$pass),max(abs(ct$algebra_error))<1e-9)
print(nci)
