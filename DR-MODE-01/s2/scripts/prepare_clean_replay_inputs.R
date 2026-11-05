# For a CLEAN public-data reproduction directory only. No NCI fitting or PSU resampling.
suppressPackageStartupMessages({library(survey);library(jsonlite)})
stopifnot(!file.exists('work/stage_c12.rds'),!file.exists('outputs/S1_writing/provenance/analysis_input.rds'))
source('outputs/S1_writing/scripts/S1_prepare_inputs.R')
z<-readRDS('outputs/S1_writing/provenance/analysis_input.rds');d<-z$data
des<-subset(z$full_design,adult&cov_complete);models<-list()
for(ref in c('control_mean','linear_extrapolation')){
 rhs<-paste('is_L +',z$covariates,if(ref=='linear_extrapolation')'+ time'else'')
 models[[paste('Y2',ref)]]<-svyglm(as.formula(paste('Y2~',rhs)),design=des,na.action=na.omit)
}
dir.create('work',showWarnings=FALSE)
saveRDS(list(data=d,models=models),'work/stage_c12.rds')
p<-'outputs/S2_uncertainty/provenance';dir.create(p,recursive=TRUE,showWarnings=FALSE)
file.copy('DR-MODE-01/s2/replay_inputs/PSU_multiplier_matrix.csv',file.path(p,'PSU_multiplier_matrix.csv'),overwrite=FALSE)
pm<-read.csv(file.path(p,'PSU_multiplier_matrix.csv'));ds<-fromJSON('DR-MODE-01/s2/replay_inputs/design_status.json')
idx<-match(as.character(d$psu),as.character(pm$psu));stopifnot(!anyNA(idx))
b<-list(repweights=list(weights=as.matrix(pm[,-(1:3)]),index=idx),scale=ds$scale,rscales=ds$rscales,mse=TRUE)
saveRDS(b,file.path(p,'bootstrap_weights.rds'))
cat('Clean replay inputs rebuilt from public data and the exact frozen PSU matrix; no new random draws.\n')
