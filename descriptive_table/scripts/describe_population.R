# P1b only: descriptive summaries from the sealed analysis input. No hypothesis tests.
args <- commandArgs(trailingOnly=TRUE)
out <- normalizePath(if(length(args)) args[1] else 'DR-MODE-01/manuscript_v1.1_AJCN')
suppressPackageStartupMessages(library(jsonlite))
spec <- fromJSON(file.path(out,'config/P1b_descriptive_spec.json'))
input <- 'outputs/S1_writing/provenance/analysis_input.rds'
d <- readRDS(input)$data
cycles <- c('G','H','I','J','L')
expected <- c(G=4309,H=4479,I=4204,J=4139,L=4285)
d <- d[d$adult,]
stopifnot(!anyDuplicated(paste(d$cycle,d$SEQN)), all(d$WTDR2D>0), !anyNA(d$WTDR2D))
stopifnot(identical(as.integer(table(d$cycle)),as.integer(expected)))
numeric_code <- function(x) as.numeric(as.character(x))
d$age <- as.numeric(d$RIDAGEYR)
d$agecat <- as.character(d$age_group)
d$female <- as.numeric(numeric_code(d$RIAGENDR)==2)
d$race <- as.numeric(d$RIDRETH3)
d$education <- ifelse(d$DMDEDUC2 %in% 1:5,d$DMDEDUC2,NA_real_)
for(day in 1:2){
  x<-numeric_code(d[[paste0('language',day)]])
  d[[paste0('nonenglish',day)]]<-ifelse(is.na(x),NA_real_,as.numeric(x!=1))
  d[[paste0('proxy',day)]]<-numeric_code(d[[paste0('proxy',day)]])
}
stopifnot(all(d$race %in% c(1,2,3,4,6,7)))
rows <- list();missing <- list()
weighted_q <- function(x,w,p){
  k<-order(x);x<-x[k];w<-w[k]
  x[which(cumsum(w)>=p*sum(w))[1]]
}
for(cy in cycles){
  z<-d[as.character(d$cycle)==cy,];w<-z$WTDR2D;total<-nrow(z)
  for(v in c('age','agecat','female','race','education','nonenglish1','nonenglish2','proxy1','proxy2','weekend1','weekend2','interval')){
    missing[[paste(cy,v)]]<-data.frame(cycle=cy,variable=v,n_total=total,n_missing=sum(is.na(z[[v]])))
    if(!v %in% c('education','interval'))stopifnot(!anyNA(z[[v]]))
  }
  add <- function(id,label,type,variable,category=NA_character_){
    x<-if(variable=='population') rep(1,total) else z[[variable]]
    ok<-!is.na(x);nv<-sum(ok);nm<-sum(!ok)
    n<-NA_integer_;pct<-mean<-p25<-p75<-NA_real_
    if(type=='n') n<-total
    if(type=='missing_n')n<-nm
    if(type=='n_pct'){
      hit<-ok & as.character(x)==category
      n<-sum(hit);pct<-100*sum(w[hit])/sum(w[ok])
    }
    if(type=='mean')mean<-weighted.mean(x[ok],w[ok])
    if(type=='quartiles'){
      p25<-weighted_q(x[ok],w[ok],.25);p75<-weighted_q(x[ok],w[ok],.75)
    }
    rows[[paste(cy,id)]]<<-data.frame(cycle=cy,row_id=id,label=label,type=type,variable=variable,category=category,n_total=total,n_valid=nv,n_missing=nm,n=n,weighted_percent=pct,weighted_mean=mean,p25=p25,p75,weight_denominator=sum(w[ok]),source_input=input,weight='WTDR2D',inference='descriptive only; no tests, P values, SEs or CIs')
  }
  add('sample_n','Participants, n','n','population')
  add('age_mean','Age, years, weighted mean','mean','age')
  for(g in c('20-39','40-59','60+'))add(paste0('age_',g),paste('Age',switch(g,'20-39'='20–39','40-59'='40–59','60+'='≥60'),'years'),'n_pct','agecat',g)
  add('female','Female','n_pct','female','1')
  races<-c('Mexican American','Other Hispanic','Non-Hispanic White','Non-Hispanic Black','Non-Hispanic Asian','Other non-Hispanic, including multiracial')
  for(i in seq_along(races))add(paste0('race_',c(1,2,3,4,6,7)[i]),races[i],'n_pct','race',as.character(c(1,2,3,4,6,7)[i]))
  ed<-c('Less than ninth grade','Ninth–eleventh grade, including no diploma','High school graduate/GED','Some college or associate degree','College graduate or higher')
  for(i in 1:5)add(paste0('education_',i),ed[i],'n_pct','education',as.character(i))
  add('education_missing','Education missing, n','missing_n','education')
  for(day in 1:2)add(paste0('nonenglish',day),paste0('Non-English interview, day ',day),'n_pct',paste0('nonenglish',day),'1')
  for(day in 1:2)add(paste0('proxy',day),paste0('Proxy respondent, day ',day),'n_pct',paste0('proxy',day),'1')
  for(day in 1:2)add(paste0('weekend',day),paste0('Weekend recall day, day ',day),'n_pct',paste0('weekend',day),'1')
  add('interval_mean','Recall interval, days, weighted mean','mean','interval')
  add('interval_quartiles','Recall interval, days, weighted P25–P75','quartiles','interval')
  add('interval_missing','Recall interval missing, n','missing_n','interval')
}
res<-do.call(rbind,rows);ms<-do.call(rbind,missing)
write.csv(res,file.path(out,'figdata/table_S1_characteristics.csv'),row.names=FALSE,na='')
write.csv(ms,file.path(out,'qa/characteristics_missingness.csv'),row.names=FALSE)
writeLines(capture.output(sessionInfo()),file.path(out,'provenance/P1b_R_sessionInfo.txt'))
write_json(list(status='COMPLETE',n_by_cycle=as.list(expected),rows=nrow(res),statistics='WTDR2D weighted descriptive summaries; no tests',quantiles=spec$weighted_quantiles),file.path(out,'qa/characteristics_R_status.json'),auto_unbox=TRUE,pretty=TRUE)
print(res[res$row_id %in% c('sample_n','age_mean','education_missing','interval_mean','interval_quartiles','interval_missing'),c('cycle','row_id','n','weighted_mean','p25','p75')],row.names=FALSE)
