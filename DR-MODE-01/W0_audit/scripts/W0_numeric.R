options(survey.lonely.psu='fail')
suppressPackageStartupMessages(library(haven));suppressPackageStartupMessages(library(survey));library(jsonlite)
out<-'DR-MODE-01/W0_audit';v1<-'outputs/DR-MODE-01';cycs<-c('G','H','I','J','L')
writeout<-function(x,path)write.csv(x,file.path(out,path),row.names=FALSE,na='NA')
raw<-list();flow<-list();counts<-list();checks<-list()
for(cy in cycs){
 a<-as.data.frame(read_xpt(file.path(v1,'A_access/data',paste0('DR1TOT_',cy,'.xpt'))))
 b<-as.data.frame(read_xpt(file.path(v1,'A_access/data',paste0('DR2TOT_',cy,'.xpt'))))
 dm<-as.data.frame(read_xpt(file.path(v1,'A_access/data',paste0('DEMO_',cy,'.xpt'))))
 stopifnot(!anyDuplicated(a$SEQN),!anyDuplicated(b$SEQN),!anyDuplicated(dm$SEQN))
 d<-merge(a,b[,c('SEQN',setdiff(names(b),names(a)))],by='SEQN',all.x=TRUE)
 d<-merge(d,dm[,c('SEQN','RIDAGEYR','RIAGENDR','RIDRETH3','DMDEDUC2','SDMVSTRA','SDMVPSU')],by='SEQN',all.x=TRUE)
 d$cycle<-cy;d$both_reliable<-!is.na(d$DR1DRSTZ)&!is.na(d$DR2DRSTZ)&d$DR1DRSTZ==1&d$DR2DRSTZ==1
 d$adult<-d$both_reliable & d$RIDAGEYR>=20 & !is.na(d$DRABF)&d$DRABF!=1
 d$interval<-abs(d$DR1DBIH-d$DR2DBIH)
 d$weekend1<-ifelse(is.na(d$DR1DAY),NA,as.integer(d$DR1DAY %in% c(1,7)))
 d$weekend2<-ifelse(is.na(d$DR2DAY),NA,as.integer(d$DR2DAY %in% c(1,7)))
 d$language1<-ifelse(d$DR1LANG %in% 1:6,pmin(d$DR1LANG,4),NA)
 d$language2<-ifelse(d$DR2LANG %in% 1:6,pmin(d$DR2LANG,4),NA)
 proxyvalid<-if(cy %in% c('G','H'))c(1:12,14) else c(1:3,5:11)
 pr1<-d[[if(cy %in% c('G','H'))'DR1MNRSP' else 'DR1MRESP']]
 pr2<-d[[if(cy %in% c('G','H'))'DR2MNRSP' else 'DR2MRESP']]
 d$proxy1<-ifelse(pr1 %in% proxyvalid,as.integer(pr1!=1),NA);d$proxy2<-ifelse(pr2 %in% proxyvalid,as.integer(pr2!=1),NA)
 d$age_group<-cut(d$RIDAGEYR,c(19,39,59,Inf),labels=c('20-39','40-59','60+'))
 covs<-c('weekend1','weekend2','interval','language1','language2','proxy1','proxy2','age_group','RIAGENDR')
 d$cov_complete<-complete.cases(d[,covs])
 masks<-list(DR1TOT_all=rep(TRUE,nrow(d)),age_ge20=!is.na(d$RIDAGEYR)&d$RIDAGEYR>=20,day1_reliable=!is.na(d$DR1DRSTZ)&d$DR1DRSTZ==1,day2_reliable=!is.na(d$DR2DRSTZ)&d$DR2DRSTZ==1,non_breastmilk=!is.na(d$DRABF)&d$DRABF!=1,positive_WTDR2D=!is.na(d$WTDR2D)&d$WTDR2D>0,complete_fixed_covariates=d$cov_complete)
 keep<-rep(TRUE,nrow(d));previous<-nrow(d)
 for(k in seq_along(masks)){
  keep<-keep&masks[[k]];nn<-sum(keep)
  flow[[paste(cy,k)]]<-data.frame(cycle=cy,step=k-1,criterion=names(masks)[k],n_before=previous,n_excluded=previous-nn,n_remaining=nn,unit='persons',role=if(k==5)'eligible_paired_adults' else if(k==7)'C_DiD_complete_cases' else 'flow',source_package='W0',source_file=normalizePath(file.path(v1,'A_access/data',paste0('DR1TOT_',cy,'.xpt'))))
  previous<-nn
 }
 counts[[cy]]<-data.frame(cycle=cy,n_DR1TOT=nrow(d),n_adults=sum(d$adult),n_positive_weight=sum(d$adult&d$WTDR2D>0),n_complete_covariates=sum(d$adult&d$cov_complete),n_missing_interval=sum(d$adult&is.na(d$interval)),n_other_covariate_missing=sum(d$adult&!complete.cases(d[,setdiff(covs,'interval')])),interval_max=max(d$interval[d$adult],na.rm=TRUE),n_DRABF_missing_adults=sum(d$both_reliable&d$RIDAGEYR>=20&is.na(d$DRABF)))
 d$Y1_day1<-d$DR1TNUMF;d$Y1_day2<-d$DR2TNUMF;d$Y1<-d$Y1_day2-d$Y1_day1
 d$Y2_day1<-log1p(d$DR1TKCAL);d$Y2_day2<-log1p(d$DR2TKCAL);d$Y2<-d$Y2_day2-d$Y2_day1
 d$energy_kcal_day1<-d$DR1TKCAL;d$energy_kcal_day2<-d$DR2TKCAL;d$energy_kcal<-d$DR2TKCAL-d$DR1TKCAL
 raw[[cy]]<-d
}
counttab<-do.call(rbind,counts);st<-fromJSON(file.path(v1,'status.json'))
counttab$expected_n_adults<-unlist(st$n_adults_by_cycle[cycs]);counttab$expected_n_complete<-unlist(st$n_complete_covariates_adults_by_cycle[cycs])
counttab$PASS<-counttab$n_adults==counttab$expected_n_adults & counttab$n_complete_covariates==counttab$expected_n_complete
writeout(counttab,'checks/person_counts.csv');writeout(do.call(rbind,flow),'figdata/tab1_flow.csv')
stopifnot(all(counttab$PASS))

# Reconcile fresh XPT fields with S1's frozen compact analysis input.
z<-readRDS('outputs/S1_writing/provenance/analysis_input.rds');d0<-z$data
for(cy in cycs){
 a<-raw[[cy]];b<-d0[as.character(d0$cycle)==cy,];ii<-match(b$SEQN,a$SEQN);stopifnot(!anyNA(ii))
 for(v in c('adult','cov_complete','interval','weekend1','weekend2','Y1','Y2','WTDR2D')){
  aa<-a[[v]][ii];bb<-b[[v]];ok<-identical(is.na(aa),is.na(bb))&&isTRUE(all.equal(as.numeric(aa),as.numeric(bb),tolerance=1e-13))
  checks[[paste(cy,v)]]<-data.frame(cycle=cy,field=v,n=nrow(b),status=if(ok)'PASS' else 'FAIL')
 }
}
writeout(do.call(rbind,checks),'checks/fresh_XPT_vs_S1.csv');stopifnot(all(vapply(checks,function(x)x$status=='PASS',TRUE)))

# Per-cycle adult descriptions, W0 requested original energy scale.
desc<-list();fig9<-list();fig1<-list()
official<-rbind(G=c(.3,.4,.2),H=c(.3,.5,.2),I=c(0,.1,0),J=c(.72,.82,.63),L=c(-.3,-.2,-.4))
for(cy in cycs){
 d<-raw[[cy]];d<-d[!is.na(d$WTDR2D)&d$WTDR2D>0,]
 d$absY1<-abs(d$Y1);d$absenergy_kcal<-abs(d$energy_kcal)
 des<-svydesign(ids=~SDMVPSU,strata=~SDMVSTRA,weights=~WTDR2D,nest=TRUE,data=d)
 ad<-subset(des,adult);df<-degf(ad)
 for(y in c('Y1','energy_kcal')){
  mm<-svymean(as.formula(paste0('~',y,'+',y,'_day1+abs',y)),ad)
  rr<-svyratio(as.formula(paste0('~',y)),as.formula(paste0('~',y,'_day1')),ad)
  desc[[paste(cy,y)]]<-data.frame(cycle=cy,outcome=y,n_persons=nrow(ad$variables),day1_mean=coef(mm)[2],day1_se=SE(mm)[2],signed_D_mean=coef(mm)[1],signed_D_se=SE(mm)[1],mean_absolute_individual_D=coef(mm)[3],mean_absolute_individual_D_se=SE(mm)[3],absolute_signed_D_mean=abs(coef(mm)[1]),relative_D=coef(rr)[1],relative_D_se=SE(rr)[1],relative_D_percent=100*coef(rr)[1],relative_D_percent_se=100*SE(rr)[1],df=df,definition='D=Day2-Day1; relative=E[D]/E[Day1]; mean_abs=E[abs(D)]',inference='Taylor')
 }
 for(y in c('Y1','Y2')){
  mm<-svymean(as.formula(paste0('~',y)),ad);ci<-coef(mm)+c(-1,1)*qt(.975,df)*SE(mm)
  fig1[[paste(cy,y)]]<-data.frame(record_type='cycle_mean',cycle=cy,outcome=y,estimate=unname(coef(mm)),se=unname(SE(mm)),ci_low=ci[1],ci_high=ci[2],df=df,n_persons=nrow(ad$variables),reference='unadjusted',unit=if(y=='Y1')'food_items' else 'log(kcal+1)',source_package='W0',source_file=normalizePath(file.path(out,'scripts/W0_numeric.R')),source_key=paste0('lines70-72;cycle=',cy,';outcome=',y,';fresh_XPT_svymean'),inference='Taylor t')
 }
 for(pop in c('frozen_adults','whitepaper_nonfasting'))for(sx in 0:2){
  flag<-d$adult;if(pop=='whitepaper_nonfasting')flag<-flag&d$DR1TKCAL>0&d$DR2TKCAL>0
  if(sx>0)flag<-flag&d$RIAGENDR==sx
  dd<-des[which(flag),];m<-svymean(~Y1,dd);v<- -unname(coef(m));digits<-if(cy=='J')2 else 1
  target<-official[cy,sx+1]
  fig9[[paste(cy,pop,sx)]]<-data.frame(cycle=cy,population=pop,sex=c('Overall','Male','Female')[sx+1],n_persons=nrow(dd$variables),day1_minus_day2=v,se=unname(SE(m)),published_figure9=target,published_decimals=digits,error=v-target,rounding_match=round(v,digits)==target,direction=if(v>0)'positive' else if(v<0)'negative' else 'zero',official_source='NCHS whitepaper page18 Figure9')
 }
}
desc<-do.call(rbind,desc);writeout(desc,'checks/paired_differences.csv');writeout(do.call(rbind,fig9),'checks/whitepaper_figure9.csv')

# Martin/Steinfeldt 2021 external reproduction only, not a changed main domain.
hi<-do.call(rbind,lapply(raw[c('H','I')],function(d)d[,c('SEQN','cycle','RIDAGEYR','RIAGENDR','both_reliable','WTDR2D','SDMVSTRA','SDMVPSU','DR1_300','DR2_300','DR1TKCAL','DR2TKCAL')]))
hi<-hi[!is.na(hi$WTDR2D)&hi$WTDR2D>0,];hi$w<-hi$WTDR2D/2
hi$stratum<-interaction(hi$cycle,hi$SDMVSTRA,drop=TRUE);hi$psu<-interaction(hi$cycle,hi$SDMVSTRA,hi$SDMVPSU,drop=TRUE)
hi$eligible<-hi$RIDAGEYR>=20 & hi$both_reliable & !is.na(hi$DR1_300)&!is.na(hi$DR2_300)&hi$DR1_300==2 & hi$DR2_300==2
hd<-svydesign(ids=~psu,strata=~stratum,weights=~w,nest=TRUE,data=hi);mr<-list()
for(pop in c('W0_as_written','paper_nonfasting'))for(sx in 1:2){
  flag<-hi$eligible & hi$RIAGENDR==sx
  if(pop=='paper_nonfasting')flag<-flag & hi$DR1TKCAL>0 & hi$DR2TKCAL>0
  ds<-hd[which(flag),];m<-svymean(~DR1TKCAL+DR2TKCAL,ds)
  target<-if(sx==1)c(2425,2334) else c(1832,1775);setarget<-if(sx==1)c(26,32) else c(18,26)
  for(day in 1:2)mr[[paste(pop,sx,day)]]<-data.frame(reproduction_definition=pop,sex=c('Male','Female')[sx],day=day,n_persons=nrow(ds$variables),target_N=c(2599,2624)[sx],estimate=unname(coef(m)[day]),se=unname(SE(m)[day]),target_mean=target[day],target_se=setarget[day],error_kcal=unname(coef(m)[day])-target[day],SE_error=unname(SE(m)[day])-setarget[day],mean_rounding_match=round(coef(m)[day])==target[day],SE_rounding_match=round(SE(m)[day])==setarget[day],n_nonfasting=sum(ds$variables$DR1TKCAL>0&ds$variables$DR2TKCAL>0),inference='Taylor',weight='WTDR2D/2',population=paste('H+I; age>=20; both reliable; DR1_300=DR2_300=2',if(pop=='paper_nonfasting')'; both kcal>0 per paper Methods' else ''))
}
writeout(do.call(rbind,mr),'checks/Martin2021_reproduction.csv')
writeout(hi[hi$eligible & (hi$DR1TKCAL==0 | hi$DR2TKCAL==0),c('cycle','SEQN','RIAGENDR','DR1TKCAL','DR2TKCAL','DR1_300','DR2_300')],'checks/Martin_nonfasting_difference_public_records.csv')

# Source-aligned graph data: no new gate or alternate model.
b<-read.csv(file.path(v1,'B_pretrend/gate_results.csv'))
for(i in 1:nrow(b)){
 t<-b[i,];ci<-t$trend_per_year+c(-1,1)*qt(.975,t$trend_df)*t$trend_se
 fig1[[paste(t$outcome,'slope')]]<-data.frame(record_type='control_linear_slope',cycle='G-J',outcome=t$outcome,estimate=t$trend_per_year,se=t$trend_se,ci_low=ci[1],ci_high=ci[2],df=t$trend_df,n_persons=t$n_persons,reference='B_unadjusted_control_linear_trend',unit='outcome_units_per_year',source_package='v1.0',source_file=normalizePath('outputs/DR-MODE-01/B_pretrend/gate_results.csv'),source_key=paste0('outcome=',t$outcome,';trend_per_year'),inference='Taylor t; slope CI computed from carried SE/df')
 fig1[[paste(t$outcome,'Lpred')]]<-data.frame(record_type='L_linear_extrapolation',cycle='L',outcome=t$outcome,estimate=t$L_extrapolated_D,se=t$L_extrapolated_se,ci_low=t$L_ci_low,ci_high=t$L_ci_high,df=t$trend_df,n_persons=t$n_persons,reference='B_unadjusted_control_linear_trend',unit=if(t$outcome=='Y1')'food_items' else 'log(kcal+1)',source_package='v1.0',source_file=normalizePath('outputs/DR-MODE-01/B_pretrend/gate_results.csv'),source_key=paste0('outcome=',t$outcome,';L_extrapolated_D'),inference='Taylor t')
}
writeout(do.call(rbind,fig1),'figdata/fig1_pretrend.csv')

# Independent Rao-Wu algorithm and full matrix checks.
saved<-readRDS('outputs/S2_uncertainty/provenance/bootstrap_weights.rds')
set.seed(2026102902);fresh<-subbootweights(d0$stratum,d0$psu,replicates=200,compress=TRUE)
same<-isTRUE(all.equal(saved,fresh,tolerance=0))
ps<-which(!duplicated(d0$psu));mult<-saved$repweights$weights[saved$repweights$index[ps],,drop=FALSE]
bs<-list()
for(s in unique(d0$stratum)){
 ii<-which(d0$stratum[ps]==s);nh<-length(ii);counts<-mult[ii,,drop=FALSE]*(nh-1)/nh
 bs[[as.character(s)]]<-data.frame(stratum=as.character(s),n_PSU=nh,draws_per_replicate=nh-1,multiplier_factor=nh/(nh-1),max_noninteger_count= max(abs(counts-round(counts))),max_draw_count_error=max(abs(colSums(counts)-(nh-1))),max_weight_sum_error=max(abs(colSums(mult[ii,,drop=FALSE])-nh)))
}
bs<-do.call(rbind,bs);writeout(bs,'checks/bootstrap_strata.csv')
capture.output(subbootweights,file=file.path(out,'provenance/survey_subbootweights_source.txt'))
bootstrap_pass<-same&&all(bs$max_noninteger_count<1e-12)&all(bs$max_draw_count_error<1e-12)&all(bs$max_weight_sum_error<1e-12)
ns<-read.csv('outputs/S2_uncertainty/provenance/NCI_all_scenario_status.csv');ns<-ns[ns$replicate>0,]
summary<-read.csv('outputs/S2_uncertainty/S2_1_summary_CI.csv')
failure<-do.call(rbind,lapply(unique(ns$scenario),function(sc){x<-ns[ns$scenario==sc,];data.frame(scenario=sc,planned_replicates=200,n_complete=sum(x$status=='COMPLETE'),n_failed=sum(x$status!='COMPLETE'),failure_fraction=mean(x$status!='COMPLETE'),negative_calcium_replicates=sum(x$negative_calcium_persons>0),negative_iron_replicates=sum(x$negative_iron_persons>0),max_Rhat=max(x$max_Rhat,na.rm=TRUE))}))
writeout(failure,'checks/failed_replicates_summary.csv')
writeout(ns[ns$status!='COMPLETE',],'checks/failed_replicates_detail.csv')
badci<-summary[summary$valid_replicates<200,];failure_handling_pass<-nrow(badci)==2&&all(is.na(badci$se)&is.na(badci$ci_low)&is.na(badci$ci_high))

design_rows<-do.call(rbind,lapply(cycs,function(cy){x<-d0[as.character(d0$cycle)==cy,];data.frame(cycle=cy,n_strata=length(unique(x$stratum)),n_PSU=length(unique(x$psu)),native_stratum_min=min(x$SDMVSTRA),native_stratum_max=max(x$SDMVSTRA),main_weight_divisor=5,control_weight_divisor=if(cy=='L')NA else 4)}))
writeout(design_rows,'checks/weight_design.csv')
signcheck<-max(abs((d0$Y2_day2-d0$Y2_day1)-d0$Y2),na.rm=TRUE)==0&&max(abs((d0$Y1_day2-d0$Y1_day1)-d0$Y1),na.rm=TRUE)==0
write_json(list(a_weight_divisor_B=4,a_weight_divisor_C=5,a_all_w_match=isTRUE(all.equal(d0$w,d0$WTDR2D/5)),a_strata_cycle_unique=all(vapply(split(as.character(d0$cycle),d0$stratum),function(x)length(unique(x))==1,TRUE)),a_psu_cycle_unique=all(vapply(split(as.character(d0$cycle),d0$psu),function(x)length(unique(x))==1,TRUE)),b_counts_pass=all(counttab$PASS),c_difference_direction_pass=signcheck,d_fresh_fields_pass=all(vapply(checks,function(x)x$status=='PASS',TRUE)),e_weekday_probability=5/7,e_weekend_probability=2/7,e_weekend_joint_weights=c(25,10,10,4)/49,f_same_seed_matrix_identical=same,f_rao_wu_pass=bootstrap_pass,f_replicates=ncol(saved$repweights$weights),f_scale=saved$scale,g_failure_CI_handling_pass=failure_handling_pass,n_strata=nrow(bs),n_PSU=sum(bs$n_PSU),n_two_PSU_strata=sum(bs$n_PSU==2),n_three_PSU_strata=sum(bs$n_PSU==3),v1_verdict=st$verdict),file.path(out,'checks/numeric_audit.json'),auto_unbox=TRUE,pretty=TRUE,digits=16)
capture.output(sessionInfo(),file=file.path(out,'provenance/R_sessionInfo.txt'))
print(counttab);print(desc);print(do.call(rbind,mr));print(failure)
