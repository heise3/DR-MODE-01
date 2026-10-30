suppressPackageStartupMessages(library(survey));library(jsonlite)
root<-'outputs/S2_uncertainty'; z<-readRDS('outputs/S1_writing/provenance/analysis_input.rds');d<-z$data
set.seed(2026102902)
b<-subbootweights(d$stratum,d$psu,replicates=200,compress=TRUE)
saveRDS(b,file.path(root,'provenance/bootstrap_weights.rds'))
p<-!duplicated(d$psu); ps<-d[p,c('cycle','stratum','psu')]
write.csv(cbind(ps,b$repweights$weights),file.path(root,'provenance/PSU_multiplier_matrix.csv'),row.names=FALSE)
st<-aggregate(psu~cycle+stratum,ps,length);names(st)[3]<-'n_PSU'
write.csv(st,file.path(root,'provenance/design_strata.csv'),row.names=FALSE)
cc<-d$adult & d$cov_complete; L<-d$adult & d$cycle=='L';Lc<-L & d$cov_complete
models<-lapply(c('control_mean','linear_extrapolation'),function(ref)model.matrix(as.formula(paste('~ is_L +',z$covariates,if(ref=='linear_extrapolation')'+ time' else '')),data=d[cc,]))
names(models)<-c('control_mean','linear_extrapolation')
result<-list();audit<-list()
for(r in 0:200) {
  mul<-if(r==0)rep(1,nrow(d)) else b$repweights$weights[b$repweights$index,r]
  w<-d$WTDR2D*mul
  estimates<-list()
  for(ref in names(models))for(y in c('Y2','calcium','iron')) {
    fit<-lm.wfit(models[[ref]],d[[y]][cc],w[cc]/5)
    beta<-fit$coefficients['is_L'];stopifnot(is.finite(beta))
    estimates[[paste(y,ref)]]<-as.numeric(beta)
    if(y!='Y2') {
      suff<-if(y=='calcium')'TCALC' else 'TIRON'
      use<-Lc & w>0; v<-expm1(log1p(d[[paste0('DR1',suff)]][use])+beta)
      audit[[paste(r,ref,y)]]<-data.frame(replicate=r,reference=ref,nutrient=y,DiD=beta,n_model_persons=sum(use),negative_corrected_persons=sum(v<0),min_corrected_day1=min(v),input_status=if(any(v<0))'NO_VALID_RESULT_NEGATIVE_AMOUNT' else 'VALID')
    }
  }
  for(sc in c('original',names(models)))for(scale in c('kcal','log1p_kcal')) {
    orig<-d$Y2_day1[L];shift<-if(sc=='original')0 else estimates[[paste('Y2',sc)]]
    raw<-if(scale=='kcal')expm1(orig) else orig
    cor<-if(scale=='kcal')expm1(orig+shift) else orig+shift
    before<-weighted.mean(raw,w[L]);after<-weighted.mean(cor,w[L])
    result[[paste(r,sc,scale)]]<-data.frame(replicate=r,endpoint='energy',scale=scale,scenario=sc,n_eligible_persons=sum(L),n_nonzero_weight_persons=sum(L&w>0),DiD=shift,original_estimate=before,estimate=after,change=after-before)
  }
}
write.csv(do.call(rbind,result),file.path(root,'provenance/energy_replicates.csv'),row.names=FALSE)
write.csv(do.call(rbind,audit),file.path(root,'provenance/NCI_replicate_input_audit.csv'),row.names=FALSE)
write_json(list(status='DESIGN_AND_DID_COMPLETE',method='Rao-Wu rescaled stratified PSU bootstrap',seed=2026102902,replicates=200,n_strata=nrow(st),n_PSU=nrow(ps),design_df=degf(z$full_design),scale=b$scale,rscales=b$rscales,mse=TRUE),file.path(root,'provenance/design_status.json'),pretty=TRUE,auto_unbox=TRUE,digits=16)
print(aggregate(negative_corrected_persons~reference+nutrient,do.call(rbind,audit),function(x)c(replicates_affected=sum(x>0),max_persons=max(x))))
