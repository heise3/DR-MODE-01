# Independent matrix WLS + stratum/PSU Taylor sandwich check for the four primary estimates.
suppressPackageStartupMessages(library(survey))
s<-readRDS('work/stage_c12.rds');d<-s$data;z<-d[d$adult&d$cov_complete,]
out<-list()
for(y in c('Y1','Y2'))for(ref in c('control_mean','linear_extrapolation')) {
 m<-s$models[[paste(y,ref)]];X<-model.matrix(formula(m),data=z);Y<-z[[y]];w<-z$w
 bread<-solve(crossprod(X,w*X));b<-drop(bread%*%crossprod(X,w*Y));names(b)<-colnames(X)
 residual<-Y-drop(X%*%b);influence<-(X*as.vector(w*residual))%*%bread
 cluster<-aggregate(influence,list(stratum=z$stratum,psu=z$psu),sum)
 V<-matrix(0,ncol(X),ncol(X))
 for(h in unique(cluster$stratum)) {
  u<-as.matrix(cluster[cluster$stratum==h,-c(1,2)]);nh<-nrow(u);stopifnot(nh>1)
  centered<-sweep(u,2,colMeans(u),'-');V<-V+nh/(nh-1)*crossprod(centered)
 }
 k<-which(colnames(X)=='is_L');se<-sqrt(V[k,k]);rse<-sqrt(vcov(m)['is_L','is_L'])
 out[[paste(y,ref)]]<-data.frame(outcome=y,reference=ref,matrix_DiD=b[k],survey_DiD=coef(m)['is_L'],matrix_se=se,survey_se=rse,abs_coef_difference=abs(b[k]-coef(m)['is_L']),abs_se_difference=abs(se-rse))
}
tab<-do.call(rbind,out);print(tab,row.names=FALSE);stopifnot(max(tab$abs_coef_difference)<1e-9,max(tab$abs_se_difference)<1e-9)
write.csv(tab,'outputs/DR-MODE-01/C_main/independent_primary_QA.csv',row.names=FALSE);print(tab,row.names=FALSE)
