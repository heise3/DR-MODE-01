.libPaths(c(c('outputs/S1_writing/software/Rlib','work/Rlib')[dir.exists(c('outputs/S1_writing/software/Rlib','work/Rlib'))],.libPaths()))
library(ncimultivar);library(jsonlite);library(coda)
args<-commandArgs(TRUE); scenario<-if(length(args))args[1] else 'original'
stopifnot(scenario %in% c('original','control_mean','linear_extrapolation'))
out<-file.path('outputs/S1_writing/S1b_C3c_usual_intake',scenario)
dir.create(out,recursive=TRUE,showWarnings=FALSE)
tstart<-Sys.time();cat('Started',scenario,format(tstart),'\n')
src<-readRDS('outputs/S1_writing/provenance/analysis_input.rds'); L<-subset(src$data,adult & cycle=='L' & cov_complete)
rawL<-readRDS('outputs/S1_writing/provenance/L_lifestage_input.rds')
preg<-rawL$RIDEXPRG[match(L$SEQN,rawL$SEQN)]
res<-read.csv('outputs/DR-MODE-01/C_main/DiD_all_outcomes.csv')
Xfull<-model.matrix(as.formula(paste('~',src$covariates)),L)
keep<-apply(Xfull,2,function(v)length(unique(v))>1)
X<-Xfull[,keep,drop=FALSE];stopifnot(qr(cbind(1,X))$rank==ncol(X)+1)
orig_names<-colnames(X);colnames(X)<-make.names(orig_names)
# A scale change of interval improves conditioning and preserves the exact model space.
X[,'interval']<-(X[,'interval']-mean(X[,'interval']))/sd(X[,'interval'])
covs<-colnames(X)
dat<-data.frame(SEQN=rep(L$SEQN,each=2),DAY=rep(1:2,nrow(L)),WTDR2D=rep(L$WTDR2D,each=2),X[rep(seq_len(nrow(L)),each=2),,drop=FALSE])
dat$Day2<-as.integer(dat$DAY==2)
dat$EAR_iron<-rep(ifelse(L$RIAGENDR==1,6,ifelse(L$RIDAGEYR<=50,8.1,5)),each=2)
dat$EAR_iron[rep(!is.na(preg)&preg==1,each=2)]<-22
dat$EAR_calcium<-rep(ifelse(L$RIDAGEYR>70|(L$RIAGENDR==2&L$RIDAGEYR>50),1000,800),each=2)
inputaudit<-list();bcl<-list();mal<-list()
for(y in c('iron','calcium')) {
  suf<-if(y=='iron')'TIRON' else 'TCALC'
  a<-L[[paste0('DR1',suf)]];b<-L[[paste0('DR2',suf)]]
  shift<-if(scenario=='original')0 else res$DiD[res$outcome==y & res$reference==scenario]
  corrected<-if(scenario=='original')a else expm1(log1p(a)+shift)
  dat[[y]]<-as.vector(rbind(corrected,b))
  stopifnot(identical(dat[[y]][dat$DAY==2],as.numeric(b)),all(is.finite(dat[[y]])),all(dat[[y]]>=0))
  inputaudit[[y]]<-data.frame(nutrient=y,n_eligible_persons=sum(rawL$adult & rawL$WTDR2D>0,na.rm=TRUE),n_model_persons=nrow(L),shift_log1p=shift,day2_max_absolute_change=max(abs(dat[[y]][dat$DAY==2]-b)),day1_zero_persons=sum(corrected==0),day2_zero_persons=sum(b==0),known_pregnant_persons=sum(preg==1,na.rm=TRUE),women20_50_persons=sum(L$RIAGENDR==2 & L$RIDAGEYR<=50),minimum_input=min(dat[[y]]))
  bcl[[y]]<-boxcox_survey(input.data=dat,row.subset=dat$DAY==1,variable=y,weight='WTDR2D',covariates=covs,do.plots=FALSE)
  mal[[y]]<-calculate_minimum_amount(input.data=dat,row.subset=dat$DAY==1,daily.variables=y)
}
bc<-do.call(rbind,bcl);ma<-do.call(rbind,mal)
pre<-nci_multivar_preprocessor(input.data=dat,daily.variables=c('iron','calcium'),boxcox.lambda.data=bc,minimum.amount.data=ma)
stopifnot(nrow(pre$mcmc.input)==nrow(dat),length(unique(pre$mcmc.input$SEQN))==nrow(L),all(table(pre$mcmc.input$SEQN)==2))
write.csv(do.call(rbind,inputaudit),file.path(out,'input_audit.csv'),row.names=FALSE)
write.csv(bc,file.path(out,'boxcox_lambda.csv'),row.names=FALSE);write.csv(ma,file.path(out,'minimum_amount.csv'),row.names=FALSE)
write.csv(data.frame(original=orig_names,encoded=covs),file.path(out,'covariate_map.csv'),row.names=FALSE)
writeLines(colnames(Xfull)[!keep],file.path(out,'omitted_constant_columns.txt'))
saveRDS(pre,file.path(out,'preprocessor.rds'))
write_json(list(scenario=scenario,started=format(tstart,tz='UTC',usetz=TRUE),status='FITTING',package=as.character(packageVersion('ncimultivar')),n_persons=nrow(L)),file.path(out,'run_status.json'),auto_unbox=TRUE,pretty=TRUE)
models<-list();traces<-list();timings<-list()
for(chain in 1:4) {
  stamp<-Sys.time();cat('Starting chain',chain,format(stamp),'\n');flush.console()
  m<-nci_multivar_mcmc(pre.mcmc.data=pre,id='SEQN',weight='WTDR2D',repeat.obs='DAY',daily.variables=c('iron','calcium'),default.covariates=c(covs,'Day2'),num.mcmc.iterations=12000,num.burn=2000,num.thin=25,num.post=0,mcmc.seed=102900+chain,log.file=NULL,log.to.console=TRUE)
  stopifnot(m$num.subjects==nrow(L))
  saveRDS(m,file.path(out,paste0('chain',chain,'.rds')))
  tt<-cbind(do.call(cbind,m$beta),m$sigma.u,m$sigma.e)
  stopifnot(all(is.finite(tt)))
  # The package retains the full trace; discard burn-in and use the same retained draws as its posterior means.
  ix<-seq(2001,12000,by=25)
  traces[[chain]]<-mcmc(tt[ix,,drop=FALSE],start=2001,thin=25)
  models[[chain]]<-m
  timings[[chain]]<-data.frame(chain=chain,seed=102900+chain,seconds=as.numeric(difftime(Sys.time(),stamp,units='secs')))
  write.csv(do.call(rbind,timings),file.path(out,'chain_timings.csv'),row.names=FALSE)
  cat('Completed chain',chain,'seconds',tail(timings,1)[[1]]$seconds,'\n');flush.console()
  if(as.numeric(difftime(Sys.time(),tstart,units='hours'))>24)stop('S1 24-hour model budget exceeded')
}
cl<-as.mcmc.list(traces)
gd<-gelman.diag(cl,autoburnin=FALSE,multivariate=FALSE)$psrf
ess<-effectiveSize(cl)
diag<-data.frame(parameter=rownames(gd),Rhat=gd[,1],Rhat_upper95=gd[,2],ESS=ess[rownames(gd)])
write.csv(diag,file.path(out,'convergence.csv'),row.names=FALSE)
saveRDS(cl,file.path(out,'retained_traces.rds'))
pdf(file.path(out,'trace_plots.pdf'),width=11,height=8)
for(i in seq(1,ncol(traces[[1]]),by=6)){par(mfrow=c(3,2));for(j in i:min(i+5,ncol(traces[[1]]))){matplot(sapply(traces, function(x)as.matrix(x)[,j]),type='l',lty=1,col=c('black','red','blue','darkgreen'),xlab='Retained draw',ylab='',main=colnames(traces[[1]])[j])}}
dev.off()
# Combine posterior means across chains; each chain has the same number of retained draws.
pooled<-models[[1]]
pooled$beta.mean<-lapply(seq_along(pooled$beta.mean),function(k)Reduce('+',lapply(models,function(m)m$beta.mean[[k]]))/length(models))
names(pooled$beta.mean)<-names(models[[1]]$beta.mean)
pooled$sigma.u.mean<-Reduce('+',lapply(models,function(m)m$sigma.u.mean))/length(models)
pooled$sigma.e.mean<-Reduce('+',lapply(models,function(m)m$sigma.e.mean))/length(models)
saveRDS(pooled,file.path(out,'pooled_model.rds'))
pop<-pre$mcmc.input[!duplicated(pre$mcmc.input$SEQN),]
pop$Day2<-0L
pop<-pop[rep(seq_len(nrow(pop)),each=4),]
pop$weekend1<-rep(c(0,0,1,1),nrow(L));pop$weekend2<-rep(c(0,1,0,1),nrow(L));pop$nuisance_weight<-rep(c(25,10,10,4),nrow(L))
cat('Starting distribution',format(Sys.time()),'\n');flush.console()
dd<-nci_multivar_distrib(multivar.mcmc.model=pooled,distrib.population=pop,id='SEQN',weight='WTDR2D',nuisance.weight='nuisance_weight',num.simulated.u=2000,distrib.seed=20261029,additional.output=c('EAR_iron','EAR_calcium'))
stopifnot(length(unique(dd$SEQN))==nrow(L),all(is.finite(dd$usual.intake.iron)),all(is.finite(dd$usual.intake.calcium)))
summary<-list();mc<-list()
for(y in c('iron','calcium')) {
  yy<-dd[[paste0('usual.intake.',y)]];ear<-dd[[paste0('EAR_',y)]];w<-dd$WTDR2D
  v<-100*weighted.mean(yy<ear,w)
  summary[[y]]<-data.frame(scenario=scenario,nutrient=y,n_eligible_persons=4285,n_model_persons=nrow(L),usual_intake_mean_mg=weighted.mean(yy,w),below_EAR_percent=v,interpretation=if(y=='iron')'nominal below-EAR only; NO_VALID_RESULT for full-adult inadequacy prevalence' else 'food/beverage inadequacy estimate conditional on NCI and cutpoint assumptions',sampling_CI='NOT_RUN',DiD_uncertainty='NOT_PROPAGATED')
  ss<-split(seq_len(nrow(dd)),dd$replicate)
  mc[[y]]<-data.frame(nutrient=y,replicate=as.integer(names(ss)),mean_mg=vapply(ss,function(ix)weighted.mean(yy[ix],w[ix]),numeric(1)),below_EAR_percent=vapply(ss,function(ix)100*weighted.mean(yy[ix]<ear[ix],w[ix]),numeric(1)))
}
write.csv(do.call(rbind,summary),file.path(out,'usual_intake_summary.csv'),row.names=FALSE)
write.csv(do.call(rbind,mc),file.path(out,'simulation_replicates.csv'),row.names=FALSE)
write_json(list(scenario=scenario,started=format(tstart,tz='UTC',usetz=TRUE),finished=format(Sys.time(),tz='UTC',usetz=TRUE),elapsed_seconds=as.numeric(difftime(Sys.time(),tstart,units='secs')),status='COMPLETED',n_persons=nrow(L),chains=4,iterations=12000,burnin=2000,thin=25,distribution_draws_per_person=2000,max_Rhat=max(diag$Rhat),min_ESS=min(diag$ESS),package=as.character(packageVersion('ncimultivar')),sampling_CI='NOT_RUN',v1_verdict='GO_UNCHANGED'),file.path(out,'run_status.json'),auto_unbox=TRUE,pretty=TRUE,digits=16)
capture.output(sessionInfo(),file=file.path(out,'sessionInfo.txt'))
print(do.call(rbind,summary));cat('DONE',scenario,format(Sys.time()),'\n')
