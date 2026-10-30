suppressPackageStartupMessages(library(survey));library(jsonlite)
root<-'outputs/DR-MODE-01'
res<-read.csv(file.path(root,'C_main/DiD_all_outcomes.csv'));cm<-read.csv(file.path(root,'C_main/cycle_means.csv'))
elig<-fromJSON(file.path(root,'C_main/C12_results.json'))$C3_eligible_outcomes
out<-list()
for(y in elig)for(ref in c('control_mean','linear_extrapolation')) {
 z<-res[res$outcome==y&res$reference==ref,];a<-cm[cm$outcome==y&cm$cycle=='J',];b<-cm[cm$outcome==y&cm$cycle=='L',]
 delta<-b$day1_mean-a$day1_mean;share<-if(delta==0)NA_real_ else 100*z$mode_effect/delta
 out[[paste(y,ref)]]<-data.frame(outcome=y,reference=ref,n_J=a$n_persons,n_L=b$n_persons,J_day1_mean=a$day1_mean,L_day1_mean=b$day1_mean,observed_change=delta,mode_effect=z$mode_effect,mode_share_percent=share,share_ge_30=if(is.na(share))FALSE else share>=30,literal_C3a_L_plus_minus_DiD=b$day1_mean+z$mode_effect,literal_C3a_change=z$mode_effect,valid_inperson_counterfactual=FALSE,correction_status='NO_VALID_RESULT: frozen correction sign conflicts with effect definition')
}
tab<-do.call(rbind,out)
write.csv(tab,file.path(root,'C_main/C3ab_impact.csv'),row.names=FALSE)
write_json(list(C3b_pass=any(tab$share_ge_30[tab$reference=='control_mean']),C3a_arithmetic='EXECUTED_AS_WRITTEN',C3a_counterfactual_status='NO_VALID_RESULT',C3a_reason='Literal L + (-DiD) adds the telephone-minus-inperson effect; it does not remove it',C3b_scale='Contract-defined outcome scale; signed point-estimate ratio; no ratio CI computed'),file.path(root,'C_main/C3ab_status.json'),pretty=TRUE,auto_unbox=TRUE)
print(tab[,c('outcome','reference','observed_change','mode_effect','mode_share_percent','share_ge_30')],row.names=FALSE)
