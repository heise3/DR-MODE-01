library(jsonlite)
root<-'outputs/S2_uncertainty';des<-fromJSON(file.path(root,'provenance/design_status.json'))
stopifnot(des$replicates==200,des$design_df==77)
e<-read.csv(file.path(root,'provenance/energy_replicates.csv'))
inputaudit<-read.csv(file.path(root,'provenance/NCI_replicate_input_audit.csv'))
all<-list();ncirows<-list()
for(r in 0:200){
  file<-file.path(root,'replicates',sprintf('rep_%03d',r),'estimates.csv')
  if(!file.exists(file))stop(paste('Incomplete run; missing replicate',r))
  if(!file.exists(file.path(dirname(file),'COMPLETE.json')))stop(paste('Replicate still running',r))
  n<-read.csv(file);stopifnot(nrow(n)==3)
  ncirows[[as.character(r)]]<-n
  row<-data.frame(replicate=r,kind=if(r==0)'FULL_SAMPLE' else 'BOOTSTRAP',L_eligible_persons=4285,L_nonzero_weight_persons_energy=e$n_nonzero_weight_persons[e$replicate==r&e$scenario=='original'&e$scale=='kcal'],L_nonzero_weight_persons_NCI=n$n_nonzero_weight_persons[1])
  for(scale in c('kcal','log1p_kcal')){
    ee<-e[e$replicate==r&e$scale==scale,]
    row[[paste0('energy_',scale,'_original')]]<-ee$estimate[ee$scenario=='original']
    for(sc in c('control_mean','linear_extrapolation')){
      v<-ee[ee$scenario==sc,]
      row[[paste0('energy_',scale,'_',sc)]]<-v$estimate
      row[[paste0('energy_',scale,'_change_',sc)]]<-v$change
      row[[paste0('DiD_Y2_',sc)]]<-v$DiD
    }
  }
  row$calcium_original<-n$estimate[n$scenario=='original']
  for(sc in c('original','control_mean','linear_extrapolation')){
    v<-n[n$scenario==sc,]
    row[[paste0('calcium_',sc)]]<-v$estimate
    if(sc!='original'){
      row[[paste0('calcium_change_',sc)]]<-v$estimate-row$calcium_original
      row[[paste0('DiD_calcium_',sc)]]<-v$DiD_calcium
    }
    row[[paste0('NCI_status_',sc)]]<-v$status
    row[[paste0('NCI_reason_',sc)]]<-v$reason
    row[[paste0('NCI_max_Rhat_',sc)]]<-v$max_Rhat
    row[[paste0('NCI_iterations_',sc)]]<-v$iterations
    row[[paste0('negative_calcium_persons_',sc)]]<-v$negative_calcium_persons
    row[[paste0('negative_iron_nuisance_persons_',sc)]]<-v$negative_iron_persons
  }
  all[[as.character(r)]]<-row
}
tab<-do.call(rbind,all);nci<-do.call(rbind,ncirows)
stopifnot(identical(tab$replicate,0:200))
write.csv(tab,file.path(root,'S2_1_replicate_estimates.csv'),row.names=FALSE)
write.csv(nci,file.path(root,'provenance/NCI_all_scenario_status.csv'),row.names=FALSE)
specs<-list()
for(scale in c('kcal','log1p_kcal')){
  for(sc in c('original','control_mean','linear_extrapolation')){
    specs[[length(specs)+1]]<-list(endpoint='energy',scale=scale,scenario=sc,statistic='mean',field=paste0('energy_',scale,'_',sc))
    if(sc!='original')specs[[length(specs)+1]]<-list(endpoint='energy',scale=scale,scenario=sc,statistic='corrected_minus_original',field=paste0('energy_',scale,'_change_',sc))
  }
}
for(sc in c('original','control_mean','linear_extrapolation')){
  specs[[length(specs)+1]]<-list(endpoint='calcium',scale='percent',scenario=sc,statistic='prevalence',field=paste0('calcium_',sc))
  if(sc!='original')specs[[length(specs)+1]]<-list(endpoint='calcium',scale='percentage_points',scenario=sc,statistic='corrected_minus_original',field=paste0('calcium_change_',sc))
}
out<-list()
for(s in specs){
  point<-tab[[s$field]][1];reps<-tab[[s$field]][-1]
  ci_df<-if(s$scenario=='original')15L else des$design_df
  crit<-qt(.975,ci_df)
  valid<-all(is.finite(reps))&&length(reps)==200
  se<-if(valid)sqrt(des$scale*sum(des$rscales*(reps-point)^2)) else NA_real_
  ci<-point+c(-1,1)*crit*se;diff<-s$statistic=='corrected_minus_original'
  placement<-if(s$endpoint=='calcium'&&s$scenario=='linear_extrapolation')'SUPPLEMENT_REFERENCE_DEPENDENT' else 'MAIN_TEXT_ELIGIBLE'
  invalid_reason<-''
  if(!valid){
    needed<-unique(c(s$scenario,if(diff)'original' else character(0)))
    badrows<-nci[nci$replicate>0 & nci$scenario %in% needed & nci$status!='COMPLETE',]
    invalid_reason<-paste0('No CI from an incomplete 200-replicate chain. Invalid replicate count=',sum(!is.finite(reps)),'. Reasons: ',paste(unique(badrows$reason),collapse=' | '))
  }
  out[[s$field]]<-data.frame(endpoint=s$endpoint,scale=s$scale,scenario=s$scenario,statistic=s$statistic,estimate=point,se=se,ci_low=ci[1],ci_high=ci[2],df=ci_df,planned_replicates=200,valid_replicates=sum(is.finite(reps)),CI_status=if(valid)'COMPLETE' else 'NO_VALID_RESULT_INCOMPLETE_REPLICATE_DOMAIN',reason=invalid_reason,CI_includes_zero=if(valid&&diff)ci[1]<=0&&ci[2]>=0 else NA,CI_includes_minus_2_pp=if(valid&&diff&&s$endpoint=='calcium')ci[1]<= -2 &&ci[2]>= -2 else NA,reduction_estimate_pp=if(diff&&s$endpoint=='calcium')-point else NA_real_,reduction_ci_low_pp=if(diff&&s$endpoint=='calcium')-ci[2] else NA_real_,reduction_ci_high_pp=if(diff&&s$endpoint=='calcium')-ci[1] else NA_real_,reduction_CI_includes_plus_2_pp=if(valid&&diff&&s$endpoint=='calcium') -ci[2]<=2 && -ci[1]>=2 else NA,publication_placement=placement,variance_method='Rao-Wu stratified PSU bootstrap; mse=TRUE; scale=1/199; 200 joint replicates',CI_method='two-sided survey-df t Wald; not truncated')
}
summary<-do.call(rbind,out);write.csv(summary,file.path(root,'S2_1_summary_CI.csv'),row.names=FALSE)
# Point estimates must reproduce the frozen S1 analysis, allowing only floating summation order.
s1<-read.csv('outputs/S1_writing/S1b_C3c_usual_intake/S1b_all_scenario_estimates.csv');s1<-s1[s1$nutrient=='calcium',]
p0<-nci[nci$replicate==0,];err<-max(abs(p0$estimate-s1$below_EAR_percent[match(p0$scenario,s1$scenario)]));stopifnot(err<1e-8)
complete<-nci[nci$status=='COMPLETE',];stopifnot(all(complete$max_Rhat<1.05),all(nci$iterations[nci$replicate==0]==12000))
write_json(list(full_sample_max_S1_prevalence_difference_pp=err,replicates_recorded=200,scenario_attempts=nrow(nci[nci$replicate>0,]),scenario_status=as.data.frame(table(nci$scenario[nci$replicate>0],nci$status[nci$replicate>0])),max_Rhat_completed=max(complete$max_Rhat),min_ESS_completed=min(complete$min_ESS),full_length_repairs=sum(nci$replicate>0 & nci$iterations==12000,na.rm=TRUE),CI_complete_rows=sum(summary$CI_status=='COMPLETE'),CI_invalid_rows=sum(summary$CI_status!='COMPLETE'),calcium_main_text_reference='control_mean',v1_verdict='GO_UNCHANGED',iron_status='NO_VALID_RESULT_CARRIED_UNCHANGED'),file.path(root,'provenance/analysis_QA.json'),auto_unbox=TRUE,pretty=TRUE,digits=16)
print(summary[,c('endpoint','scale','scenario','statistic','estimate','se','ci_low','ci_high','valid_replicates','CI_includes_zero','CI_includes_minus_2_pp')],row.names=FALSE)
