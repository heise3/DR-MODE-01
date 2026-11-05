# Independent verification from aggregate outputs only; no participant data loaded.
suppressPackageStartupMessages(library(jsonlite))
o<-'DR-MODE-01/s2';rd<-function(f)read.csv(file.path(o,f));tol<-1e-10
pt<-rd('Taylor_estimates_all.csv');sh<-rd('bootstrap_shares_and_R.csv');rp<-rd('bootstrap_share_replicates.csv')
scale<-fromJSON('outputs/S2_uncertainty/provenance/design_status.json')$scale
checks<-list();add<-function(k,error,tolerance=tol){checks[[k]]<<-data.frame(check=k,max_absolute_error=error,tolerance=tolerance,status=if(is.finite(error)&&error<tolerance)'PASS'else'FAIL')}
old<-read.csv(file.path(o,'provenance/engineering_E01/first_attempt/Taylor_estimates_all.csv'))
cols<-names(pt)[vapply(pt,is.numeric,TRUE)];add('E01_all_Taylor_numeric_cells_unchanged',max(abs(as.matrix(pt[,cols])-as.matrix(old[,cols])),na.rm=TRUE))
cierr<-rerr<-perr<-0;ratio_status<-list()
for(i in seq_len(nrow(sh))) {
 a<-sh[i,];rr<-rp[rp$endpoint==a$endpoint&rp$reference==a$reference,];stopifnot(nrow(rr)==200,all(is.finite(rr$share)))
 se<-sqrt(scale*sum((rr$share-a$share)^2));ci<-a$share+c(-1,1)*qt(.975,77)*se
 cierr<-max(cierr,abs(c(se-a$se,ci-c(a$ci_low,a$ci_high))))
 if(is.finite(a$R_g)){
  vr<-rr$share/rr$s_g
  ratio_status[[paste(a$endpoint,a$reference)]]<-data.frame(endpoint=a$endpoint,reference=a$reference,finite_R_replicates=sum(is.finite(vr)),undefined_R_replicates=sum(!is.finite(vr)),status=a$R_test_status)
  if(any(!is.finite(vr))){
   stopifnot(a$R_test_status=='NO_VALID_RESULT',all(is.na(c(a$R_se,a$R_ci_low,a$R_ci_high,a$R_p,a$R_q_BH))))
   next
  }
  rs<-sqrt(scale*sum((vr-a$R_g)^2))
  rc<-a$R_g+c(-1,1)*qt(.975,77)*rs;pv<-2*pt(-abs((a$R_g-1)/rs),77)
  rerr<-max(rerr,abs(c(rs-a$R_se,rc-c(a$R_ci_low,a$R_ci_high),vr-rr$R_g)))
  perr<-max(perr,abs(pv-a$R_p))
 }
}
add('All_share_CI_from_200_replicates',cierr);add('All_R_SE_CI_and_ratio_replicates',rerr);add('R_P_two_sided_t77',perr)
qerr<-0
for(ref in unique(sh$reference))for(fam in c('occasion_3','food_10')){
 ix<-which(sh$reference==ref&!is.na(sh$R_family)&sh$R_family==fam);stopifnot(length(ix)==if(fam=='occasion_3')3 else 10)
 qerr<-max(qerr,abs(p.adjust(sh$R_p[ix],'BH',n=length(ix))-sh$R_q_BH[ix]),na.rm=TRUE)
}
add('R_BH_separate_3_and_10_families',qerr)
H<-sh[sh$endpoint=='food_H_omit_kcal'&sh$reference=='control_mean',];stopifnot(nrow(H)==1,H$R_ci_low>1)
cm<-sh[sh$reference=='control_mean'&is.finite(sh$R_q_BH)&!is.na(sh$R_q_BH),];tr<-sh[sh$reference=='linear_extrapolation',]
eligible<-cm$R_q_BH<.05 & sign(cm$R_g-1)==sign(tr$R_g[match(cm$endpoint,tr$endpoint)]-1)
decision<-if(H$R_ci_low>1||any(eligible))'YES'else'NO';v<-fromJSON(file.path(o,'verdict.json'));stopifnot(v$composition_signal==decision)
b<-rd('B2_corrected_vs_2017.csv');br<-rd('B2_joint_replicates.csv');be<-bi<-0
for(ref in unique(b$reference)){
 r<-br[br$reference==ref,];stopifnot(nrow(r)==200)
 be<-max(be,abs(r$corrected_minus_J-(r$L_corrected-r$J_original)),abs(r$correction-(r$L_corrected-r$L_original)))
 for(metric in unique(b$metric)){
  row<-b[b$reference==ref&b$metric==metric,];se<-sqrt(scale*sum((r[[metric]]-row$estimate)^2));ci<-row$estimate+c(-1,1)*qt(.975,77)*se
  bi<-max(bi,abs(c(se-row$se,ci-c(row$ci_low,row$ci_high))))
 }
}
add('B2_joint_replicate_subtraction_identity',be);add('B2_joint_CI_recomputed',bi)
aa<-rd('additivity_QA.csv');add('Log_and_kcal_additivity',max(abs(as.matrix(aa[,2:5]))))
unit<-rd('unit_multiplier_calibration.csv');add('Unit_multiplier_vs_Taylor_all_92_fits',max(unit$unit_multiplier_absolute_error),1e-8)
cc<-rd('G1_pretrend_calibration.csv');add('Original_domain_pretrend_calibration',max(as.matrix(cc[,c('wald_p_absolute_error','width_absolute_error','low_absolute_error','high_absolute_error')])),1e-8)
pp<-rd('replicate_DiD_estimates.csv');stopifnot(nrow(pp)==200*nrow(pt),all(pp$status=='PASS'))
result<-do.call(rbind,checks);write.csv(result,file.path(o,'provenance/aggregate_verification.csv'),row.names=FALSE)
write.csv(do.call(rbind,ratio_status),file.path(o,'provenance/R_ratio_validity.csv'),row.names=FALSE)
write_json(list(status=if(all(result$status=='PASS'))'PASS'else'FAIL',scope='AGGREGATE_OUTPUTS_ONLY',checks=nrow(result),failed_checks=sum(result$status!='PASS'),
 bootstrap_replicates=200,failed_replicate_estimates=sum(pp$status!='PASS'),individual_data_loaded=FALSE),file.path(o,'provenance/aggregate_verification.json'),auto_unbox=TRUE,pretty=TRUE)
stopifnot(all(result$status=='PASS'));print(result,row.names=FALSE)
