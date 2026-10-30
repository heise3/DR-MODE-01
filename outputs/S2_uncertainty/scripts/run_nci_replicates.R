.libPaths(c('work/Rlib','outputs/S1_writing/software/Rlib',.libPaths()))
suppressPackageStartupMessages(library(ncimultivar));library(coda);library(jsonlite)
source('outputs/S2_uncertainty/scripts/nci_streaming.R')
root<-'outputs/S2_uncertainty'
args<-commandArgs(TRUE);worker<-as.integer(args[1]);workers<-if(length(args)>1)as.integer(args[2]) else 1L
ids<-if(worker==0)0L else seq(worker,200,by=workers)
src<-readRDS('outputs/S1_writing/provenance/analysis_input.rds');d<-src$data
boot<-readRDS(file.path(root,'provenance/bootstrap_weights.rds'))
cc<-d$adult&d$cov_complete
baseL<-d[d$adult&d$cycle=='L'&d$cov_complete,]
int_center<-mean(baseL$interval);int_scale<-sd(baseL$interval)
rhs<-setNames(lapply(c('control_mean','linear_extrapolation'),function(ref)model.matrix(as.formula(paste('~ is_L +',src$covariates,if(ref=='linear_extrapolation')'+ time' else '')),d[cc,])),c('control_mean','linear_extrapolation'))
deadline<-fromJSON(file.path(root,'provenance/runtime_control.json'))$deadline_unix
write_atomic<-function(x,path){tmp<-paste0(path,'.tmp');write.csv(x,tmp,row.names=FALSE);stopifnot(file.rename(tmp,path))}
fit_chains<-function(pre,covs,n,iterations,burn,thin,folder,label,fullsample=FALSE) {
  ms<-list();tr<-list()
  for(k in 1:4) {
    if(as.numeric(Sys.time())>deadline)stop('NOT_RUN_BUDGET_36H')
    m<-nci_multivar_mcmc(pre.mcmc.data=pre,id='SEQN',weight='WTDR2D',repeat.obs='DAY',daily.variables=c('iron','calcium'),default.covariates=c(covs,'Day2'),num.mcmc.iterations=iterations,num.burn=burn,num.thin=thin,num.post=0,mcmc.seed=102900+k,log.file=NULL,log.to.console=TRUE)
    stopifnot(m$num.subjects==n)
    tt<-cbind(do.call(cbind,m$beta),m$sigma.u,m$sigma.e);stopifnot(all(is.finite(tt)))
    ix<-seq(burn+1,iterations,by=thin);tr[[k]]<-mcmc(tt[ix,,drop=FALSE],start=burn+1,thin=thin)
    if(fullsample)saveRDS(m,file.path(folder,paste0('chain',k,'.rds')))
    ms[[k]]<-m
  }
  cl<-as.mcmc.list(tr);gd<-gelman.diag(cl,autoburnin=FALSE,multivariate=FALSE)$psrf;ess<-effectiveSize(cl)
  diagnostics<-data.frame(parameter=rownames(gd),Rhat=gd[,1],Rhat_upper=gd[,2],ESS=ess[rownames(gd)])
  write_atomic(diagnostics,file.path(folder,paste0('convergence_',label,'.csv')))
  saveRDS(cl,file.path(folder,paste0('traces_',label,'.rds')))
  pooled<-ms[[1]]
  pooled$beta.mean<-lapply(seq_along(pooled$beta.mean),function(j)Reduce('+',lapply(ms,function(m)m$beta.mean[[j]]))/4)
  names(pooled$beta.mean)<-names(ms[[1]]$beta.mean)
  pooled$sigma.u.mean<-Reduce('+',lapply(ms,function(m)m$sigma.u.mean))/4
  pooled$sigma.e.mean<-Reduce('+',lapply(ms,function(m)m$sigma.e.mean))/4
  # Full traces are saved separately; these fields are not read by marginal distribution simulation.
  pooled$beta<-NULL;pooled$sigma.u<-NULL;pooled$sigma.e<-NULL
  list(model=pooled,max_Rhat=max(diagnostics$Rhat),min_ESS=min(diagnostics$ESS),iterations=iterations,burn=burn,thin=thin)
}
for(r in ids) {
  repdir<-file.path(root,'replicates',sprintf('rep_%03d',r));dir.create(repdir,recursive=TRUE,showWarnings=FALSE)
  if(file.exists(file.path(repdir,'COMPLETE.json')))next
  stamp<-Sys.time();cat('REPLICATE',r,'START',format(stamp),'\n');flush.console()
  mul<-if(r==0)rep(1,nrow(d)) else boot$repweights$weights[boot$repweights$index,r]
  w<-d$WTDR2D*mul
  shifts<-list()
  for(ref in names(rhs))for(y in c('Y2','calcium','iron')) {
    fit<-lm.wfit(rhs[[ref]],d[[y]][cc],w[cc]/5)
    shifts[[paste(y,ref)]]<-unname(fit$coefficients['is_L']);stopifnot(is.finite(shifts[[paste(y,ref)]]))
  }
  L<-d[d$adult & d$cycle=='L' & d$cov_complete & w>0,]
  L$WTDR2D<-w[d$adult & d$cycle=='L' & d$cov_complete & w>0]
  N<-nrow(L); Xfull<-model.matrix(as.formula(paste('~',src$covariates)),L)
  keep<-apply(Xfull,2,function(v)length(unique(v))>1);X<-Xfull[,keep,drop=FALSE]
  # Remove only exact dependent encodings, preserving the same fitted covariate space.
  qq<-qr(cbind('(Intercept)'=1,X));good<-sort(qq$pivot[seq_len(qq$rank)]);good<-good[good>1]-1L;X<-X[,good,drop=FALSE]
  stopifnot(qr(cbind(1,X))$rank==ncol(X)+1)
  colnames(X)<-make.names(colnames(X));if('interval'%in%colnames(X))X[,'interval']<-(X[,'interval']-int_center)/int_scale
  covs<-colnames(X);records<-list()
  for(sc in c('original','control_mean','linear_extrapolation')) {
    folder<-file.path(repdir,sc);dir.create(folder,showWarnings=FALSE)
    row<-data.frame(replicate=r,endpoint='calcium',scale='percent_below_EAR',scenario=sc,n_eligible_persons=4285,n_nonzero_weight_persons=N,DiD_calcium=if(sc=='original')0 else shifts[[paste('calcium',sc)]],DiD_iron_nuisance=if(sc=='original')0 else shifts[[paste('iron',sc)]],estimate=NA_real_,mean_mg=NA_real_,status='STARTED',reason='',negative_calcium_persons=0L,negative_iron_persons=0L,max_Rhat=NA_real_,min_ESS=NA_real_,iterations=NA_integer_,burnin=NA_integer_,thin=NA_integer_,distribution_MCSE=NA_real_,seconds=NA_real_)
    t0<-Sys.time()
    answer<-tryCatch({
      if(as.numeric(Sys.time())>deadline)stop('NOT_RUN_BUDGET_36H')
      dat<-data.frame(SEQN=rep(L$SEQN,each=2),DAY=rep(1:2,N),WTDR2D=rep(L$WTDR2D,each=2),X[rep(seq_len(N),each=2),,drop=FALSE]);dat$Day2<-as.integer(dat$DAY==2)
      dat$EAR_calcium<-rep(ifelse(L$RIDAGEYR>70|(L$RIAGENDR==2&L$RIDAGEYR>50),1000,800),each=2)
      bcl<-list();mal<-list();bad<-FALSE
      for(y in c('iron','calcium')) {
        suf<-if(y=='iron')'TIRON' else 'TCALC';a<-L[[paste0('DR1',suf)]];b<-L[[paste0('DR2',suf)]]
        shift<-if(sc=='original')0 else shifts[[paste(y,sc)]];v<-if(sc=='original')as.numeric(a) else expm1(log1p(a)+shift)
        dat[[y]]<-as.vector(rbind(v,b));stopifnot(identical(dat[[y]][dat$DAY==2],as.numeric(b)))
        row[[paste0('negative_',y,'_persons')]]<-sum(v<0)
        bad<-bad || any(v<0)
      }
      if(bad) {
        write_atomic(dat[dat$DAY==1 & (dat$iron<0|dat$calcium<0),c('SEQN','iron','calcium','WTDR2D')],file.path(folder,'invalid_amounts.csv'))
        stop('NO_VALID_RESULT_NEGATIVE_CORRECTED_AMOUNT; no clipping, recall deletion, or replicate replacement')
      }
      for(y in c('iron','calcium')) {
        bcl[[y]]<-boxcox_survey(input.data=dat,row.subset=dat$DAY==1,variable=y,weight='WTDR2D',covariates=covs,do.plots=FALSE)
        mal[[y]]<-calculate_minimum_amount(input.data=dat,row.subset=dat$DAY==1,daily.variables=y)
      }
      bc<-do.call(rbind,bcl);ma<-do.call(rbind,mal)
      pre<-nci_multivar_preprocessor(input.data=dat,daily.variables=c('iron','calcium'),boxcox.lambda.data=bc,minimum.amount.data=ma)
      stopifnot(nrow(pre$mcmc.input)==nrow(dat),all(table(pre$mcmc.input$SEQN)==2))
      write_atomic(bc,file.path(folder,'boxcox.csv'));write_atomic(ma,file.path(folder,'minimum_amount.csv'));writeLines(covs,file.path(folder,'covariates.txt'))
      if(r==0) {
        fit<-fit_chains(pre,covs,N,12000,2000,25,folder,'full',TRUE)
      } else {
        fit<-fit_chains(pre,covs,N,3000,1000,5,folder,'short')
        if(!is.finite(fit$max_Rhat)||fit$max_Rhat>=1.05)fit<-fit_chains(pre,covs,N,12000,2000,25,folder,'full')
      }
      row$max_Rhat<-fit$max_Rhat;row$min_ESS<-fit$min_ESS;row$iterations<-fit$iterations;row$burnin<-fit$burn;row$thin<-fit$thin
      if(!is.finite(fit$max_Rhat)||fit$max_Rhat>=1.05)stop('NO_VALID_RESULT_MCMC_CONVERGENCE')
      pop<-make_distribution_population(pre,N);sim<-nci_calcium_stream(fit$model,pop)
      saveRDS(fit$model,file.path(folder,'pooled_parameters.rds'))
      saveRDS(sim$simulation,file.path(folder,'simulation_aggregates.rds'))
      row$estimate<-sim$percent;row$mean_mg<-sim$mean_mg;row$distribution_MCSE<-sim$MCSE_percent
      row$status<-'COMPLETE';row
    },error=function(e){row$status<-if(grepl('BUDGET',conditionMessage(e)))'NOT_RUN' else 'NO_VALID_RESULT';row$reason<-conditionMessage(e);row})
    answer$seconds<-as.numeric(difftime(Sys.time(),t0,units='secs'));records[[sc]]<-answer
    write_atomic(do.call(rbind,records),file.path(repdir,'estimates.csv'))
    cat('REPLICATE',r,sc,answer$status,'Rhat',answer$max_Rhat,'seconds',answer$seconds,'\n');flush.console()
  }
  write_json(list(replicate=r,finished=format(Sys.time(),tz='UTC',usetz=TRUE),seconds=as.numeric(difftime(Sys.time(),stamp,units='secs')),status='ATTEMPTS_COMPLETE',scenario_status=vapply(records,function(x)x$status,character(1))),file.path(repdir,'COMPLETE.json'),auto_unbox=TRUE,pretty=TRUE)
  gc()
}
