# Synthetic summaries only. Never load NHANES files or run analyze.R here.
suppressPackageStartupMessages(library(jsonlite))
root<-'DR-MODE-01/s2'
source(file.path(root,'scripts/s2_inference_helpers.R'))
fixture<-function(){
  md<-do.call(rbind,lapply(c('control_mean','linear_extrapolation'),function(ref){
    groups<-c('Meals','Snacks_drinks','Other',paste0('G',1:10),'H_omit')
    data.frame(endpoint=c(paste0('occasion_',groups[1:3],'_kcal'),paste0('food_',groups[4:14],'_kcal')),
      reference=ref,module=c(rep('A2',3),rep('A3',11)),group=groups,metric='kcal',
      # Very small DiD q-values deliberately reproduce the old gate's failure mode.
      q_BH=1e-20,DiD=seq_along(groups)*10)
  }))
  sh<-data.frame(endpoint=md$endpoint,reference=md$reference,R_g=1,R_se=.05,R_ci_low=.90,R_ci_high=1.10)
  list(metadata=md,shares=sh)
}
checks<-list()
record<-function(name,pass,note){stopifnot(isTRUE(pass));checks[[name]]<<-data.frame(check=name,status='PASS',evidence=note)}
f<-fixture();x<-add_R_tests(f$shares,f$metadata);a<-composition_from_R(x)
record('uniform_proportional_change_is_NO',a$composition_signal=='NO'&&all(x$R_q_BH[is.finite(x$R_q_BH)]==1),
       'All R=1 gives P=q=1 and NO, even though every kcal DiD q is 1e-20.')
f<-fixture();ii<-f$shares$endpoint=='food_G1_kcal'
f$shares$R_g[ii]<-ifelse(f$shares$reference[ii]=='control_mean',1.8,1.4)
x<-add_R_tests(f$shares,f$metadata);a<-composition_from_R(x)
record('nonuniform_R_same_trend_sign_is_YES',a$composition_signal=='YES'&&any(a$significant_R_components$trend_same_sign),
       'A precisely estimated R>1 survives food-family BH and agrees in trend direction.')
f$shares$R_g[f$shares$endpoint=='food_G1_kcal'&f$shares$reference=='linear_extrapolation']<-.6
x<-add_R_tests(f$shares,f$metadata);a<-composition_from_R(x)
record('opposite_trend_R_sign_is_NO',a$composition_signal=='NO','Sign agreement uses R-1, not the sign of the positive kcal DiD.')
f<-fixture();ih<-f$shares$endpoint=='food_H_omit_kcal'&f$shares$reference=='control_mean'
f$shares$R_g[ih]<-1.2;f$shares$R_ci_low[ih]<-1.1;f$shares$R_ci_high[ih]<-1.3
x<-add_R_tests(f$shares,f$metadata);a<-composition_from_R(x)
record('H_omit_original_CI_rule_unchanged',a$composition_signal=='YES'&&a$H_omit_lower_CI_gt_1,
       'H-omit lower CI>1 independently passes the unchanged first branch.')
family_counts<-table(x$reference[!is.na(x$R_family)],x$R_family[!is.na(x$R_family)])
record('two_BH_families_per_reference',all(family_counts[,'occasion_3']==3)&all(family_counts[,'food_10']==10),
       'Exactly three occasions and ten food groups per reference; H-omit excluded.')
record('H_omit_not_in_BH',all(is.na(x$R_q_BH[x$group=='H_omit'])), 'Combined hypothesis does not enlarge either BH family.')
f<-fixture();f$shares$R_se[f$shares$endpoint=='food_G5_kcal']<-0
x<-add_R_tests(f$shares,f$metadata)
record('invalid_SE_is_not_a_significant_result',all(x$R_test_status[x$group=='G5']=='NO_VALID_RESULT')&&all(is.na(x$R_p[x$group=='G5'])),
       'Non-positive SE yields NO_VALID_RESULT and no P/q; family size remains ten.')
record('two_sided_t77',all(abs(x$R_p[is.finite(x$R_p)]-2*pt(-abs(x$R_t[is.finite(x$R_p)]),77))<1e-15),
       'Two-sided t reference uses the frozen cross-cycle df=77.')
result<-do.call(rbind,checks)
write.csv(result,file.path(root,'provenance/composition_synthetic_QA.csv'),row.names=FALSE)
write_json(list(status='PASS',scope='SYNTHETIC_SUMMARY_LOGIC_ONLY',n_checks=nrow(result),NHANES_loaded=FALSE,new_outcome_means_or_DiD_computed=FALSE),
           file.path(root,'provenance/composition_synthetic_QA.json'),pretty=TRUE,auto_unbox=TRUE)
print(result[,c('check','status')],row.names=FALSE)
