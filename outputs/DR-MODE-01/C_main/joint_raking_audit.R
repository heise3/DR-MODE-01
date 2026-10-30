library(survey);library(jsonlite)
root<-'outputs/DR-MODE-01';s<-readRDS('work/stage_c12.rds');d<-s$data
d$race<-factor(d$RIDRETH3,levels=c(1,2,3,4,6,7));d$education<-factor(ifelse(d$DMDEDUC2 %in% 1:5,d$DMDEDUC2,NA),levels=1:5)
d$eligible<-d$adult&d$cov_complete&!is.na(d$race)&!is.na(d$education)
f<-~age_group+RIAGENDR+race+education
target<-xtabs(w~age_group+RIAGENDR+race+education,data=d[d$eligible&d$cycle=='J',])
rows<-list();errors<-list()
full<-svydesign(ids=~psu,strata=~stratum,weights=~w,data=d,nest=TRUE)
for(cy in levels(d$cycle)) {
 dc<-subset(full,eligible&cycle==cy)
 obs<-xtabs(~age_group+RIAGENDR+race+education,data=dc$variables)
 absent<-obs==0 & target>0
 fit<-tryCatch(rake(dc,sample.margins=list(f),population.margins=list(as.data.frame(target)),control=list(maxit=100,epsilon=1e-7)),error=function(e)e)
 ok<-!inherits(fit,'error')
 errors[[cy]]<-if(ok)'NONE' else conditionMessage(fit)
 rows[[cy]]<-data.frame(cycle=cy,n_persons=nrow(dc$variables),n_joint_cells=length(target),n_positive_J_target_cells=sum(target>0),n_positive_target_cells_absent_in_cycle=sum(absent),target_population_fraction_in_absent_cells=sum(target[absent])/sum(target),rake_call_status=if(ok)'EXECUTED' else 'FAILED_STRUCTURAL_ZERO')
}
tab<-do.call(rbind,rows);write.csv(tab,file.path(root,'C_main/joint_raking_coverage.csv'),row.names=FALSE)
write_json(list(status=if(all(tab$rake_call_status=='EXECUTED'))'INPUT_PASS' else 'NOT_RUN',result_validity=if(all(tab$rake_call_status=='EXECUTED'))'PENDING_ESTIMATES' else 'NO_VALID_RESULT',reason='Full age x sex x race x education joint-target raking audited separately from four marginal raking. No cell collapsing or target replacement.',errors=errors),file.path(root,'C_main/joint_raking_status.json'),pretty=TRUE,auto_unbox=TRUE)
print(tab,row.names=FALSE)
