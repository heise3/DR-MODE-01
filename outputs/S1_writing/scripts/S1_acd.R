options(survey.lonely.psu='fail')
suppressPackageStartupMessages(library(survey));library(jsonlite)
out <- 'outputs/S1_writing'; src <- 'outputs/DR-MODE-01'
z <- readRDS('outputs/S1_writing/provenance/analysis_input.rds')
res <- read.csv(file.path(src,'C_main/DiD_all_outcomes.csv'))
elig <- fromJSON(file.path(src,'C_main/C12_results.json'))$C3_eligible_outcomes
L <- subset(z$full_design,adult & cycle=='L')
suffix <- c(Y1='TNUMF',Y2='TKCAL',total_sugars='TSUGR',alcohol='TALCO',caffeine='TCAFF',moisture='TMOIS',iron='TIRON',calcium='TCALC',sodium='TSODI',fiber='TFIBE')
a <- list()
for(y in elig) for(ref in c('control_mean','linear_extrapolation')) {
  b <- res$DiD[res$outcome==y & res$reference==ref]
  v <- L$variables[[paste0(y,'_day1')]]
  w <- weights(L); ok <- is.finite(v); v <- v[ok];w<-w[ok]
  scales <- if(y %in% c('Y1','protein_energy_pct','fat_energy_pct')) 'contract_scale' else c('log1p','original_units')
  for(sc in scales) {
    original <- if(sc=='original_units')expm1(v) else v
    corrected <- if(sc=='original_units')expm1(v+b) else v+b
    before <- weighted.mean(original,w); after <- weighted.mean(corrected,w)
    algebra <- if(sc=='original_units') exp(b)*(before+1)-1 else before+b
    stopifnot(abs(after-algebra)<1e-9)
    a[[paste(y,ref,sc)]] <- data.frame(outcome=y,reference=ref,scale=sc,n_persons=length(v),DiD_contract_scale=b,original_L_day1_mean=before,corrected_L_day1_mean=after,change=after-before,conversion='individual shift then weighted mean',uncertainty='point estimates; DiD uncertainty not propagated',claim_tier=if(y=='Y2')'primary' else if(y=='Y1')'supportive_B_failed' else if(all(res$q_BH[res$outcome==y]<.05))'both_references_FDR_significant_no_B_test' else 'reference_dependent_no_B_test')
  }
}
write.csv(do.call(rbind,a),file.path(out,'S1a_C3a_corrected.csv'),row.names=FALSE)

# All eligible paired adults, unadjusted descriptive estimand; same sample/weights for both days.
JL <- subset(z$full_design,adult & cycle %in% c('J','L'))
brows <- list(); closure <- list(); means <- list()
for(y in c('Y1','Y2')) {
  m <- list()
  for(cy in c('J','L')) {
    des <- subset(JL,cycle==cy)
    m[[cy]] <- svymean(as.formula(paste0('~',y,'_day1+',y,'_day2+',y)),des)
    means[[paste(y,cy)]] <- data.frame(outcome=y,cycle=cy,n_persons=nrow(des$variables),day1=coef(m[[cy]])[1],day2=coef(m[[cy]])[2],D=coef(m[[cy]])[3])
  }
  delta <- coef(m$L)-coef(m$J); vv<-vcov(m$L)+vcov(m$J)
  # Disjoint cycle strata; cycle-specific design df summed for independent survey contrast.
  df <- degf(subset(JL,cycle=='J'))+degf(subset(JL,cycle=='L'))
  for(i in 1:3) {
    se <- sqrt(vv[i,i]); ci <- delta[i]+c(-1,1)*qt(.975,df)*se
    brows[[paste(y,i)]] <- data.frame(outcome=y,contrast=c('Day1_L_minus_J','Day2_L_minus_J','DiD_J_only_unadjusted')[i],n_J=nrow(subset(JL,cycle=='J')$variables),n_L=nrow(subset(JL,cycle=='L')$variables),J_mean=unname(coef(m$J)[i]),L_mean=unname(coef(m$L)[i]),change=unname(delta[i]),se=se,df=df,ci_low=ci[1],ci_high=ci[2],adjustment='none; descriptive paired-adult domain; WTDR2D',ci_method='Taylor; independent cycle contrasts; t with sum cycle df')
  }
  err<-unname(delta[2]-delta[1]-delta[3]);verr<-unname(vv[1,1]+vv[2,2]-2*vv[1,2]-vv[3,3])
  stopifnot(abs(err)<1e-11,abs(verr)<1e-11)
  closure[[y]]<-data.frame(outcome=y,delta_Day2=unname(delta[2]),delta_Day1=unname(delta[1]),DiD_J=unname(delta[3]),closure_error=err,variance_closure_error=verr)
}
write.csv(do.call(rbind,brows),file.path(out,'S1c_day2_direct.csv'),row.names=FALSE)
write.csv(do.call(rbind,closure),file.path(out,'provenance/S1c_identity_check.csv'),row.names=FALSE)
sens<-read.csv(file.path(src,'C_main/sensitivity_results.csv'))
print(unique(sens$analysis))
r<-sens[grepl('rak',sens$analysis),]
stopifnot(nrow(r)==24)
r$note<-'Four separate margins: age, sex, race, education. Full four-way joint raking NOT_RUN: structural zeros. Values carried verbatim from v1.0.'
write.csv(r,file.path(out,'S1d_raking_table.csv'),row.names=FALSE)
stopifnot(identical(r[,names(sens)],sens[grepl('rak',sens$analysis),]))
write.csv(res,file.path(out,'provenance/v1_C1_C2_carried.csv'),row.names=FALSE)
write.csv(read.csv(file.path(src,'C_main/C3ab_impact.csv')),file.path(out,'provenance/v1_C3b_carried.csv'),row.names=FALSE)
write_json(list(S1a='COMPLETE',S1c='COMPLETE',S1d='COMPLETE',identity=do.call(rbind,closure),raking_rows_copied=nrow(r),v1_unchanged=TRUE),file.path(out,'provenance/acd_status.json'),pretty=TRUE,auto_unbox=TRUE,digits=16)
print(do.call(rbind,a)[do.call(rbind,a)$outcome %in% c('Y1','Y2'),],row.names=FALSE)
print(do.call(rbind,brows),row.names=FALSE)
