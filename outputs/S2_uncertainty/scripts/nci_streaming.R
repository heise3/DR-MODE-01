# Exact daily-calcium marginal of ncimultivar::nci_multivar_distrib.
# The NCI initialization, bivariate random draws and backtransformation are unchanged.
# Sum nuisance levels with rowsum(), and retain aggregate simulation results only.
nci_calcium_stream <- function(m,pop,draws=2000,seed=20261029) {
  stopifnot(identical(m$daily.variables,c('iron','calcium')),m$num.episodic==0)
  pop<-pop[order(pop$SEQN),]
  pp<-ncimultivar:::initialize_distrib(distrib.population=pop,id='SEQN',nuisance.weight='nuisance_weight',covariates=m$covariates,intercepts=m$intercepts,beta.mean=m$beta.mean,sigma.u.mean=m$sigma.u.mean,sigma.e.mean=m$sigma.e.mean,block.size=1000,num.variables=m$num.variables,num.covariates=m$num.covariates,num.coefficients=m$num.coefficients,dietary.supplements=NULL,never.consumers.first.episodic=m$never.consumers.first.episodic,never.consumer.covariates=m$never.consumer.covariates,never.consumer.intercept=m$never.consumer.intercept,alpha1.mean=m$alpha1.mean,num.never.consumer.covariates=m$num.never.consumer.covariates,num.never.consumer.coefficients=m$num.never.consumer.coefficients,distrib.seed=seed)
  one<-pop[!duplicated(pop$SEQN),]; w<-one$WTDR2D;ear<-one$EAR_calcium
  group<-rep(seq_len(pp$num.subjects),pp$num.nuisance.levels)
  bt<-m$backtransformation[m$backtransformation$variable=='calcium',]
  pv<-numeric(draws);av<-numeric(draws)
  for(k in seq_len(draws)) {
    u<-ncimultivar:::generate_u_matrix(use.mcmc.u.matrices=FALSE,mcmc.u.matrix=NULL,u.standard.deviation=pp$u.standard.deviation,distrib.subjects=pp$subject.id,mcmc.subjects=m$subject.id,num.subjects=pp$num.subjects,num.variables=m$num.variables)
    # Calcium is the second variable in the unchanged bivariate daily-amount model.
    amounts<-ncimultivar:::backtransform(xbeta.u.var=pp$xbeta[,2]+u[group,2],sigma.e.var=m$sigma.e.mean[2,2],lambda=bt$tran_lambda,center=bt$tran_center,scale=bt$tran_scale,minimum.amount=bt$minamount,is.biomarker=bt$biomarker)
    usual<-as.numeric(rowsum(pp$nuisance.level.weights*amounts,group,reorder=FALSE))
    stopifnot(all(is.finite(usual)))
    pv[k]<-100*weighted.mean(usual<ear,w);av[k]<-weighted.mean(usual,w)
  }
  list(percent=mean(pv),mean_mg=mean(av),MCSE_percent=sd(pv)/sqrt(draws),simulation=data.frame(draw=seq_len(draws),percent=pv,mean_mg=av))
}
make_distribution_population <- function(pre,n) {
  pop<-pre$mcmc.input[!duplicated(pre$mcmc.input$SEQN),];stopifnot(nrow(pop)==n)
  pop$Day2<-0L;pop<-pop[rep(seq_len(n),each=4),]
  pop$weekend1<-rep(c(0,0,1,1),n);pop$weekend2<-rep(c(0,1,0,1),n);pop$nuisance_weight<-rep(c(25,10,10,4),n)
  pop
}
