options(survey.lonely.psu='fail')
suppressPackageStartupMessages({library(survey);library(haven);library(jsonlite);library(digest)})
out<-'DR-MODE-01/s2';refs<-c('control_mean','linear_extrapolation');cycs<-c('G','H','I','J','L')
stamp<-function()format(Sys.time(),tz='UTC',usetz=TRUE)
js<-function(x,p)write_json(x,file.path(out,p),pretty=TRUE,auto_unbox=TRUE,digits=16,na='null')
csv<-function(x,p)write.csv(x,file.path(out,p),row.names=FALSE,na='')
fr<-fromJSON(file.path(out,'freeze_record.json'));stopifnot(fr$status=='FROZEN')
for(p in names(fr$hashes))stopifnot(digest(file=file.path(out,p),algo='sha256')==fr$hashes[[p]])
source(file.path(out,'scripts/s2_inference_helpers.R'))
stopifnot(fromJSON(file.path(out,'G0_checks.json'))$status=='PASS')
js(list(status='RUNNING',started_utc=stamp(),freeze_commit=fr$commit_hash), 'analysis_status.json')
z<-readRDS('outputs/S1_writing/provenance/analysis_input.rds');d<-z$data;full<-z$full_design
cc<-d$adult&d$cov_complete
stopifnot(sum(cc)==20875L,identical(d,full$variables),!anyDuplicated(paste(d$cycle,d$SEQN)))
old<-readRDS('work/stage_c12.rds')
stopifnot(identical(d,old$data))
templates<-lapply(refs,function(ref)old$models[[paste('Y2',ref)]]);names(templates)<-refs
# Reuse the frozen v1.0 svyglm calls and actual fitted formulas, changing only response/design.
calls<-lapply(templates,getCall);formulas<-lapply(templates,formula)
rm(old,templates);gc()
bs<-readRDS('outputs/S2_uncertainty/provenance/bootstrap_weights.rds')
pm<-read.csv('outputs/S2_uncertainty/provenance/PSU_multiplier_matrix.csv')
stopifnot(length(bs$repweights$index)==nrow(d),ncol(bs$repweights$weights)==200,
 all(as.character(pm$psu[bs$repweights$index])==as.character(d$psu)),
 max(abs(as.matrix(pm[,-(1:3)])-bs$repweights$weights))==0,degf(full)==77)
mulmat<-bs$repweights$weights[bs$repweights$index,,drop=FALSE]
js(list(sample_n=sum(cc),n_by_cycle=as.list(table(d$cycle[cc])),base_design_df=degf(full),
 weight_divisor=5,bootstrap_replicates=200,bootstrap_matrix_sha256=digest(file='outputs/S2_uncertainty/provenance/PSU_multiplier_matrix.csv',algo='sha256'),
 bootstrap_scale=bs$scale,bootstrap_new_draws=0,covariates=z$covariates,
 template_calls=vapply(calls,function(x)paste(deparse(x),collapse=' '),'')), 'provenance/implementation.json')

bootstrap_X<-function(ref,valid)model.matrix(delete.response(terms(formulas[[ref]])),data=d[valid,,drop=FALSE])
fit_one<-function(y,valid,ref) {
 dd<-full;dd$variables$D_new<-y;dd$variables$valid_S2<-valid
 des<-subset(dd,valid_S2)
 cl<-calls[[ref]];ff<-formulas[[ref]];ff[[2]]<-as.name('D_new');cl$formula<-ff;cl$design<-quote(des)
 mod<-eval(cl);beta<-unname(coef(mod)['is_L']);se<-unname(SE(mod)['is_L']);df<-mod$df.residual
 stopifnot(is.finite(beta),is.finite(se));ci<-beta+c(-1,1)*qt(.975,df)*se
 # Same matrix and weights as the replicate path, with all PSU multipliers set to one.
 X<-bootstrap_X(ref,valid);stopifnot(nrow(X)==sum(valid),nobs(mod)==sum(valid))
 unit_multipliers<-rep(1,sum(valid))
 uf<-lm.wfit(X,y[valid],d$w[valid]*unit_multipliers)
 ub<-unname(uf$coefficients['is_L']);unit_error<-abs(ub-beta)
 list(row=data.frame(reference=ref,n_persons=nobs(mod),DiD=beta,se=se,df=df,ci_low=ci[1],ci_high=ci[2],p=2*pt(-abs(beta/se),df),mode_effect=-beta,inference='Taylor',
  unit_multiplier_DiD=ub,unit_multiplier_absolute_error=unit_error,unit_multiplier_pass=is.finite(unit_error)&&unit_error<1e-8),formula=ff)
}
pts<-list();endpoints<-list();pre<-list();cyclemeans<-list();point_fail<-list()
pretrend<-function(y,valid,id) {
 dc<-d[d$cycle!='L',];dc$cycle<-droplevels(dc$cycle);dc$w<-dc$WTDR2D/4
 dc$D<-y[d$cycle!='L'];dc$valid_S2<-valid[d$cycle!='L']
 cd<-svydesign(ids=~psu,strata=~stratum,weights=~w,data=dc,nest=TRUE);cd<-subset(cd,valid_S2)
 hm<-svyglm(D~cycle,design=cd,na.action=na.omit);ht<-regTermTest(hm,~cycle,method='Wald')
 tr<-svyglm(D~time,design=cd,na.action=na.omit);a<-c(1,2022.7-2015)
 ex<-sum(a*coef(tr));es<-sqrt(drop(t(a)%*%vcov(tr)%*%a));eci<-ex+c(-1,1)*qt(.975,tr$df.residual)*es
 mu<-svymean(~D,cd);p<-as.numeric(ht$p);bound<-2*abs(as.numeric(coef(mu)));wid<-diff(eci)
 data.frame(endpoint=id,n_persons=nobs(hm),wald_p=p,wald_F=as.numeric(ht$Ftest),wald_df_num=as.numeric(ht$df),wald_df_den=as.numeric(ht$ddf),
  control_D_mean=as.numeric(coef(mu)),control_D_se=as.numeric(SE(mu)),trend_per_year=unname(coef(tr)['time']),trend_se=unname(SE(tr)['time']),trend_df=tr$df.residual,
  L_extrapolated_D=ex,L_extrapolated_se=es,L_ci_low=eci[1],L_ci_high=eci[2],L_ci_width=wid,width_threshold=bound,
  wald_pass=p>.05,width_pass=wid<bound,pretrend_pass=p>.05&wid<bound,sample='adult covariate-complete domain',inference='Taylor_unadjusted_post_hoc',status='COMPLETE',reason='')
}
pretrend_safe<-function(y,valid,id)tryCatch(pretrend(y,valid,id),error=function(e){
 numeric_names<-c('wald_p','wald_F','wald_df_num','wald_df_den','control_D_mean','control_D_se','trend_per_year','trend_se','trend_df','L_extrapolated_D','L_extrapolated_se','L_ci_low','L_ci_high','L_ci_width','width_threshold')
 row<-data.frame(endpoint=id,n_persons=sum(valid&d$cycle!='L'))
 for(n in numeric_names)row[[n]]<-NA_real_
 row$wald_pass<-row$width_pass<-row$pretrend_pass<-NA
 row$sample<-'adult covariate-complete domain';row$inference<-'Taylor_unadjusted_post_hoc';row$status<-'NO_VALID_RESULT';row$reason<-conditionMessage(e);row
})
add_endpoint<-function(id,v1,v2,module,group,metric,valid=cc) {
 valid<-valid&is.finite(v1)&is.finite(v2);y<-v2-v1
 endpoints[[id]]<<-list(id=id,y=y,v1=v1,v2=v2,valid=valid,module=module,group=group,metric=metric)
 for(ref in refs) {
  ans<-tryCatch({a<-fit_one(y,valid,ref)$row;a$status<-'COMPLETE';a$reason<-'';a},error=function(e){
    point_fail[[length(point_fail)+1L]]<<-data.frame(endpoint=id,reference=ref,reason=conditionMessage(e))
    data.frame(reference=ref,n_persons=sum(valid),DiD=NA_real_,se=NA_real_,df=NA_real_,ci_low=NA_real_,ci_high=NA_real_,p=NA_real_,mode_effect=NA_real_,inference='Taylor',
      unit_multiplier_DiD=NA_real_,unit_multiplier_absolute_error=NA_real_,unit_multiplier_pass=FALSE,status='NO_VALID_RESULT',reason=conditionMessage(e))
  });ans$endpoint<-id;ans$module<-module;ans$group<-group;ans$metric<-metric
  pts[[paste(id,ref)]]<<-ans
 }
 pre[[id]]<<-pretrend_safe(y,valid,id)
 for(cy in cycs) {
  dd<-full;dd$variables$D_new<-y;dd$variables$valid_S2<-valid
  sc<-subset(dd,valid_S2&cycle==cy);m<-svymean(~D_new,sc,na.rm=TRUE);df<-degf(sc);ci<-as.numeric(coef(m))+c(-1,1)*qt(.975,df)*as.numeric(SE(m))
  cyclemeans[[paste(id,cy)]]<<-data.frame(endpoint=id,cycle=cy,n_persons=nrow(sc$variables),D_mean=as.numeric(coef(m)),se=as.numeric(SE(m)),df=df,ci_low=ci[1],ci_high=ci[2])
 }
}

# Post-freeze calibration against the original adult domain, before any component pre-trend.
# Use full-precision sealed targets, not the rounded display values 0.0180 / 0.7720.
pretrend_targets<-read.csv('outputs/DR-MODE-01/B_pretrend/gate_results.csv')
calibration<-do.call(rbind,lapply(c('Y1','Y2'),function(y){
 yy<-if(y=='Y1')d$DR2TNUMF-d$DR1TNUMF else d$Y2
 a<-pretrend_safe(yy,d$adult,paste0('calibration_',y));a$sample<-'v1.0 stage B adult domain, without complete-covariate restriction'
 target<-pretrend_targets[pretrend_targets$outcome==y,];stopifnot(nrow(target)==1)
 a$source_wald_p<-target$wald_p;a$source_L_ci_width<-target$L_ci_width
 a$source_L_ci_low<-target$L_ci_low;a$source_L_ci_high<-target$L_ci_high
 a$wald_p_absolute_error<-abs(a$wald_p-a$source_wald_p)
 a$width_absolute_error<-abs(a$L_ci_width-a$source_L_ci_width)
 a$low_absolute_error<-abs(a$L_ci_low-a$source_L_ci_low)
 a$high_absolute_error<-abs(a$L_ci_high-a$source_L_ci_high)
 a$calibration_pass<-a$status=='COMPLETE'&&a$n_persons==target$n_persons&&
   all(is.finite(c(a$wald_p_absolute_error,a$width_absolute_error,a$low_absolute_error,a$high_absolute_error)))&&
   max(a$wald_p_absolute_error,a$width_absolute_error,a$low_absolute_error,a$high_absolute_error)<1e-8
 a
}))
csv(calibration,'G1_pretrend_calibration.csv')
if(!all(calibration$calibration_pass)){
 js(list(status='STOP_REPRO',reason='PRETREND_CALIBRATION_FAILED',rows=calibration),'G1_repro.json')
 js(list(status='STOP_REPRO',stage='PRETREND_CALIBRATION',component_analysis='NOT_RUN',finished_utc=stamp()),'analysis_status.json')
 stop('STOP_REPRO: original-domain pre-trend calibration failed')
}
# Primary-model reproduction follows the original-domain calibration.
add_endpoint('log1p_energy',d$Y2_day1,d$Y2_day2,'G1','Total','log1p_kcal')
g1<-do.call(rbind,pts);orig<-read.csv('outputs/DR-MODE-01/C_main/DiD_all_outcomes.csv');orig<-orig[orig$outcome=='Y2',]
ix<-match(g1$reference,orig$reference)
g1$source_DiD<-orig$DiD[ix];g1$source_se<-orig$se[ix];g1$source_ci_low<-orig$ci_low[ix];g1$source_ci_high<-orig$ci_high[ix]
g1$DiD_absolute_error<-abs(g1$DiD-g1$source_DiD)
g1$third_decimal_pass<-round(g1$DiD,3)==round(g1$source_DiD,3)&round(g1$ci_low,3)==round(g1$source_ci_low,3)&round(g1$ci_high,3)==round(g1$source_ci_high,3)
g1$full_precision_pass<-g1$DiD_absolute_error<1e-10&abs(g1$se-g1$source_se)<1e-10&g1$unit_multiplier_pass
csv(g1,'G1_reproduction.csv');js(list(status=if(all(g1$third_decimal_pass&g1$full_precision_pass))'PASS'else'STOP_REPRO',rows=g1),'G1_repro.json')
if(!all(g1$third_decimal_pass&g1$full_precision_pass))stop('STOP_REPRO: frozen primary model reproduction failed')
cat('G1 PASS: exact reproduction; start food aggregation\n');flush.console()
add_endpoint('total_kcal',d$DR1TKCAL,d$DR2TKCAL,'G1','Total','kcal')

mp<-read.csv(file.path(out,'wweia_group_map.csv'));food<-vector('list',2);occ<-vector('list',2);grams<-matrix(0,nrow(d),2)
counts<-matrix(0,nrow(d),2);energies<-matrix(0,nrow(d),2);unknown<-list()
for(day in 1:2) {
 F<-array(0,dim=c(nrow(d),10,3),dimnames=list(NULL,paste0('G',1:10),c('kcal','items','grams')))
 O<-array(0,dim=c(nrow(d),3,3),dimnames=list(NULL,c('Meals','Snacks_drinks','Other'),c('kcal','items','occasions')))
 for(cy in cycs) {
  dr<-paste0('DR',day);cols<-c('SEQN',paste0(dr,c('ILINE','IFDCD','IGRMS','IKCAL','_020','_030Z')))
  q<-as.data.frame(read_xpt(sprintf('DR-MODE-01/X1/data/%sIFF_%s.xpt',dr,cy),col_select=all_of(cols)))
  # Individual food lines are aggregated to people before any model is fitted.
  rows_cy<-which(d$cycle==cy);qi<-match(q$SEQN,d$SEQN[rows_cy]);keep<-!is.na(qi)
  keep[keep]<-cc[rows_cy[qi[keep]]];q<-q[keep,];di<-rows_cy[qi[keep]]
  mm<-mp[mp$cycle==cy,];mi<-match(q[[paste0(dr,'IFDCD')]],mm$food_code);fg<-mm$analysis_group[mi];fg[is.na(fg)]<-'G10'
  en<-q[[paste0(dr,'IKCAL')]];gr<-q[[paste0(dr,'IGRMS')]];stopifnot(!anyNA(en),!anyNA(gr))
  co<-q[[paste0(dr,'_030Z')]];ti<-q[[paste0(dr,'_020')]]
  og<-ifelse(co%in%c(1:5,10:12,14),'Meals',ifelse(co%in%c(6,7,9,13,15:19),'Snacks_drinks','Other'))
  for(g in paste0('G',1:10)) {
   sel<-fg==g;if(!any(sel))next
   ag<-rowsum(cbind(kcal=en[sel],items=1,grams=gr[sel]),di[sel],reorder=FALSE)
   F[as.integer(rownames(ag)),g,]<-ag
  }
  event_key<-paste(di,co,ti,sep=':');first<-!duplicated(event_key)
  for(g in dimnames(O)[[2]]) {
   sel<-og==g;if(!any(sel))next
   ag<-rowsum(cbind(kcal=en[sel],items=1,occasions=as.numeric(first[sel])),di[sel],reorder=FALSE)
   O[as.integer(rownames(ag)),g,]<-ag
  }
  unknown[[paste(cy,day)]]<-data.frame(cycle=cy,day=day,persons_with_unknown_time=length(unique(di[cc[di]&(is.na(ti)|ti==9999)])),persons_with_unknown_occasion=length(unique(di[cc[di]&(is.na(co)|co==99)])))
 }
 food[[day]]<-F;occ[[day]]<-O;grams[,day]<-rowSums(F[,,'grams']);counts[,day]<-rowSums(F[,,'items']);energies[,day]<-rowSums(F[,,'kcal'])
 stopifnot(max(abs(energies[cc,day]-d[[paste0('DR',day,'TKCAL')]][cc]))<1e-10,
           max(abs(counts[cc,day]-d[[paste0('DR',day,'TNUMF')]][cc]))<1e-10,
           max(abs(rowSums(O[,,'kcal'])[cc]-energies[cc,day]))<1e-10)
}
csv(do.call(rbind,unknown),'unknown_occasion_time_counts.csv')
pos<-cc&d$DR1TKCAL>0&d$DR2TKCAL>0&d$DR1TNUMF>0&d$DR2TNUMF>0
zero<-do.call(rbind,lapply(cycs,function(cy){a<-cc&d$cycle==cy;data.frame(cycle=cy,n_complete=sum(a),day1_E_or_N_zero=sum(a&(d$DR1TKCAL<=0|d$DR1TNUMF<=0)),day2_E_or_N_zero=sum(a&(d$DR2TKCAL<=0|d$DR2TNUMF<=0)),excluded_common_log_domain=sum(a&!pos),excluded_fraction=sum(a&!pos)/sum(a))}))
csv(zero,'A1_zero_counts.csv')
add_endpoint('log_E',log(d$DR1TKCAL),log(d$DR2TKCAL),'A1','Total','log_kcal',pos)
add_endpoint('log_N',log(d$DR1TNUMF),log(d$DR2TNUMF),'A1','Items','log_items',pos)
add_endpoint('log_P',log(d$DR1TKCAL/d$DR1TNUMF),log(d$DR2TKCAL/d$DR2TNUMF),'A1','Per_item','log_kcal_per_item',pos)
add_endpoint('log_grams_per_item',log(grams[,1]/d$DR1TNUMF),log(grams[,2]/d$DR2TNUMF),'A1','Per_item','log_grams_per_item',pos&grams[,1]>0&grams[,2]>0)
for(g in dimnames(occ[[1]])[[2]])for(metric in c('kcal','items','occasions'))add_endpoint(paste('occasion',g,metric,sep='_'),occ[[1]][,g,metric],occ[[2]][,g,metric],'A2',g,metric)
for(g in paste0('G',1:10)) {
 for(metric in c('kcal','items'))add_endpoint(paste('food',g,metric,sep='_'),food[[1]][,g,metric],food[[2]][,g,metric],'A3',g,metric)
 a<-food[[1]][,g,];b<-food[[2]][,g,];valid<-cc&a[,'items']>0&b[,'items']>0&a[,'grams']>0&b[,'grams']>0
 add_endpoint(paste('food',g,'log_grams_per_item',sep='_'),log(a[,'grams']/a[,'items']),log(b[,'grams']/b[,'items']),'A3',g,'log_grams_per_item',valid)
}
add_endpoint('food_H_omit_kcal',rowSums(food[[1]][,paste0('G',1:4),'kcal']),rowSums(food[[2]][,paste0('G',1:4),'kcal']),'A3','H_omit','kcal')
for(y in setdiff(z$outcomes,c('Y1','Y2'))) {
 pre[[paste0('nutrient_',y)]]<-pretrend_safe(d[[y]],cc&is.finite(d[[y]]),paste0('nutrient_',y))
}
pt<-do.call(rbind,pts);pr<-do.call(rbind,pre)
pt$q_BH<-NA_real_
for(ref in refs)for(module in c('A2','A3')) {
 ii<-which(pt$reference==ref&pt$module==module&pt$metric=='kcal'&pt$group!='H_omit')
 pt$q_BH[ii]<-p.adjust(pt$p[ii],method='BH')
}
csv(pt,'Taylor_estimates_all.csv');csv(pr,'component_pretrend.csv');csv(do.call(rbind,cyclemeans),'component_cycle_means.csv')
if(length(point_fail))csv(do.call(rbind,point_fail),'Taylor_fit_failures.csv')
b1<-pr[grepl('^nutrient_',pr$endpoint),];b1$outcome<-sub('^nutrient_','',b1$endpoint);csv(b1,'B1_nutrient_pretrend.csv')
unitqa<-pt[,c('endpoint','reference','n_persons','DiD','unit_multiplier_DiD','unit_multiplier_absolute_error','unit_multiplier_pass','status','reason')]
csv(unitqa,'unit_multiplier_calibration.csv')
if(any(pt$status=='COMPLETE' & !pt$unit_multiplier_pass)){
 js(list(status='STOP_REPRO',stage='UNIT_MULTIPLIER_CALIBRATION',bootstrap='NOT_RUN',finished_utc=stamp()),'analysis_status.json')
 stop('STOP_REPRO: unit-multiplier point estimate differs from Taylor point estimate')
}

# Bulk weighted least squares in each fixed eligibility domain, using the exact saved multiplier matrix.
domains<-split(names(endpoints),vapply(endpoints,function(e)digest(e$valid),''))
repvals<-array(NA_real_,dim=c(200,length(endpoints),2),dimnames=list(NULL,names(endpoints),refs))
rep_fail<-list()
for(ids in domains)for(ref in refs) {
 valid<-endpoints[[ids[1]]]$valid
 X<-bootstrap_X(ref,valid);Y<-do.call(cbind,lapply(endpoints[ids],function(e)e$y[valid]));colnames(Y)<-ids
 for(r in 1:200) {
  fit<-tryCatch(lm.wfit(X,Y,d$w[valid]*mulmat[valid,r]),error=function(e)e)
  if(inherits(fit,'error')){rep_fail[[length(rep_fail)+1L]]<-data.frame(replicate=r,reference=ref,endpoints=paste(ids,collapse=';'),reason=conditionMessage(fit));next}
  be<-fit$coefficients['is_L',];repvals[r,ids,ref]<-be
 }
}
getpoint<-function(id,ref)pt$DiD[pt$endpoint==id&pt$reference==ref]
getrep<-function(id,ref)repvals[,id,ref]
ci_boot<-function(point,v) {
 point<-as.numeric(point)
 if(length(v)!=200||any(!is.finite(v)))return(c(se=NA,ci_low=NA,ci_high=NA,successful=sum(is.finite(v))))
 se<-sqrt(bs$scale*sum(bs$rscales*(v-point)^2));c(se=se,ci_low=point-qt(.975,77)*se,ci_high=point+qt(.975,77)*se,successful=200)
}
base_weight<-d$w;control<-cc&d$cycle!='L'
baseline<-function(v,w)sum(v[control]*w[control])/sum(d$DR1TKCAL[control]*w[control])
share_rows<-list();share_reps<-list();B2<-list();B2reps<-list()
for(ref in refs) {
 sh<-getpoint('log_N',ref)/getpoint('log_E',ref);v<-getrep('log_N',ref)/getrep('log_E',ref);ci<-ci_boot(sh,v)
 share_rows[[paste(ref,'share_N')]]<-data.frame(endpoint='share_N',reference=ref,share=sh,se=ci['se'],ci_low=ci['ci_low'],ci_high=ci['ci_high'],successful=ci['successful'],inference='Rao-Wu_200_t77')
 share_reps[[paste(ref,'share_N')]]<-data.frame(replicate=1:200,reference=ref,endpoint='share_N',share=v,s_g=NA,R_g=NA)
 for(id in names(endpoints)) {
  e<-endpoints[[id]];if(!e$module%in%c('A2','A3')||e$metric!='kcal')next
  num<-getpoint(id,ref);den<-getpoint('total_kcal',ref);sg<-baseline(e$v1,base_weight);share<-num/den;R<-share/sg
  vr<-getrep(id,ref)/getrep('total_kcal',ref)
  sr<-vapply(1:200,function(r)baseline(e$v1,base_weight*mulmat[,r]),0)
  rr<-vr/sr;cs<-ci_boot(share,vr);cr<-ci_boot(R,rr)
  share_rows[[paste(id,ref)]]<-data.frame(endpoint=id,reference=ref,share=share,se=cs['se'],ci_low=cs['ci_low'],ci_high=cs['ci_high'],successful=cs['successful'],inference='Rao-Wu_200_t77')
  share_rows[[paste(id,ref)]]$s_g<-sg;share_rows[[paste(id,ref)]]$R_g<-R;share_rows[[paste(id,ref)]]$R_se<-cr['se'];share_rows[[paste(id,ref)]]$R_ci_low<-cr['ci_low'];share_rows[[paste(id,ref)]]$R_ci_high<-cr['ci_high']
  share_reps[[paste(id,ref)]]<-data.frame(replicate=1:200,reference=ref,endpoint=id,share=vr,s_g=sr,R_g=rr)
 }
 L<-cc&d$cycle=='L';J<-cc&d$cycle=='J'
 calc<-function(w,beta) {
  orig<-weighted.mean(d$DR1TKCAL[L],w[L]);cor<-weighted.mean(expm1(d$Y2_day1[L]+beta),w[L]);j<-weighted.mean(d$DR1TKCAL[J],w[J])
  c(L_original=orig,L_corrected=cor,J_original=j,corrected_minus_J=cor-j,original_minus_J=orig-j,correction=cor-orig)
 }
 po<-calc(base_weight,getpoint('log1p_energy',ref));rr<-t(vapply(1:200,function(r)calc(base_weight*mulmat[,r],getrep('log1p_energy',ref)[r]),numeric(6)))
 for(metric in names(po)) {
  ci<-ci_boot(po[metric],rr[,metric]);B2[[paste(ref,metric)]]<-data.frame(reference=ref,metric=metric,estimate=unname(po[metric]),se=ci['se'],ci_low=ci['ci_low'],ci_high=ci['ci_high'],df=77,successful_replicates=ci['successful'],inference='Rao-Wu_200_joint_t77',n_L=sum(L),n_J=sum(J),sample='adult covariate-complete')
 }
 B2reps[[ref]]<-data.frame(replicate=1:200,reference=ref,rr,check.names=FALSE)
}
# Bind with missing columns filled for the generic share_N row.
bind_fill<-function(x){nm<-unique(unlist(lapply(x,names)));do.call(rbind,lapply(x,function(a){for(n in setdiff(nm,names(a)))a[[n]]<-NA;a[,nm]}))}
sh<-add_R_tests(bind_fill(share_rows),pt,df=77)
csv(sh,'bootstrap_shares_and_R.csv')
csv(sh[sh$metric=='kcal' & !is.na(sh$metric),],'composition_R_tests.csv')
csv(do.call(rbind,share_reps),'bootstrap_share_replicates.csv')
csv(do.call(rbind,B2),'B2_corrected_vs_2017.csv');csv(do.call(rbind,B2reps),'B2_joint_replicates.csv')
rp<-do.call(rbind,lapply(refs,function(ref)do.call(rbind,lapply(names(endpoints),function(id)data.frame(replicate=1:200,reference=ref,endpoint=id,DiD=getrep(id,ref),status=ifelse(is.finite(getrep(id,ref)),'PASS','FAIL'))))))
csv(rp,'replicate_DiD_estimates.csv')
if(length(rep_fail))csv(do.call(rbind,rep_fail),'replicate_failures.csv')else csv(data.frame(replicate=integer(),reference=character(),endpoints=character(),reason=character()),'replicate_failures.csv')
for(module in c('A1','A2','A3')) {
 a<-pt[pt$module==module,];m<-match(paste(a$endpoint,a$reference),paste(sh$endpoint,sh$reference))
 for(n in setdiff(names(sh),c('endpoint','reference','inference','module','group','metric')))a[[if(n%in%c('se','ci_low','ci_high'))paste0('share_',n)else n]]<-sh[[n]][m]
 if(module=='A1') {
  nn<-sh[sh$endpoint=='share_N',];a$share_N<-nn$share[match(a$reference,nn$reference)];a$share_N_ci_low<-nn$ci_low[match(a$reference,nn$reference)];a$share_N_ci_high<-nn$ci_high[match(a$reference,nn$reference)]
 }
 csv(a,paste0(module,c(A1='_decomposition.csv',A2='_occasion.csv',A3='_foodgroup.csv')[[module]]))
}
identity<-do.call(rbind,lapply(refs,function(ref){
 logerr<-getpoint('log_E',ref)-getpoint('log_N',ref)-getpoint('log_P',ref)
 occerr<-sum(pt$DiD[pt$reference==ref&pt$module=='A2'&pt$metric=='kcal'])-getpoint('total_kcal',ref)
 fooderr<-sum(pt$DiD[pt$reference==ref&pt$module=='A3'&pt$metric=='kcal'&pt$group!='H_omit'])-getpoint('total_kcal',ref)
 berr<-max(abs(getrep('log_E',ref)-getrep('log_N',ref)-getrep('log_P',ref)))
 data.frame(reference=ref,log_identity_error=logerr,occasion_additivity_error=occerr,food_additivity_error=fooderr,replicate_log_identity_max_error=berr,pass=max(abs(c(logerr,occerr,fooderr,berr)))<1e-10)
}))
csv(identity,'additivity_QA.csv');stopifnot(all(identity$pass))
shN<-sh[sh$endpoint=='share_N',];sm<-shN$share[shN$reference=='control_mean'];st<-shN$share[shN$reference=='linear_extrapolation']
lo<-function(id)pt$ci_low[pt$endpoint==id&pt$reference=='control_mean']
nonzero<-function(id){a<-pt[pt$endpoint==id&pt$reference=='control_mean',];a$ci_low>0||a$ci_high<0}
mc<-if(sm>=.5&&lo('log_N')>0&&st>=.5)'OMISSION_DOMINANT'else if(1-sm>=.5&&lo('log_P')>0&&getpoint('log_P','linear_extrapolation')>0)'PORTION_DOMINANT'else if(nonzero('log_N')&&nonzero('log_P'))'MIXED'else'INDETERMINATE'
cp<-pr[pr$endpoint%in%c('log_N','log_P'),]
h<-sh[sh$endpoint=='food_H_omit_kcal'&sh$reference=='control_mean',]
composition_result<-composition_from_R(sh)
sig<-composition_result$significant_R_components
composition<-composition_result$composition_signal
story<-if(mc!='INDETERMINATE'&&composition=='YES')'UPGRADE_AJCN'else'NO_UPGRADE_SWITCH'
failed<-sum(!is.finite(repvals));status<-if(failed==0)'COMPLETE'else'NO_VALID_RESULT_REPLICATE_FAILURE'
if(failed>0){mc<-NULL;composition<-NULL;story<-NULL}
verdict<-list(status=status,mechanism_class=mc,component_pretrend=list(log_N=if(cp$pretrend_pass[cp$endpoint=='log_N'])'PASS'else'FAIL',log_P=if(cp$pretrend_pass[cp$endpoint=='log_P'])'PASS'else'FAIL',interpretation=if(all(cp$pretrend_pass))'conditional_on_stable_order_effect'else'conditional'),
 composition_signal=composition,story_verdict=story,post_hoc=TRUE,share_N=shN,component_Taylor=pt[pt$endpoint%in%c('log_E','log_N','log_P'),],component_pretrend_numbers=cp,
 H_omit=h,H_omit_lower_CI_gt_1=composition_result$H_omit_lower_CI_gt_1,
 composition_test='R_g vs 1; two-sided bootstrap t(77); BH separately within occasion_3 and food_10 for each reference; control-mean q<0.05 and same sign of trend R_g-1',
 significant_R_components=if(nrow(sig))sig else list(),calcium_pretrend=b1[b1$outcome=='calcium',],
 failed_replicate_endpoint_fits=failed,bootstrap_replicates=200,bootstrap_new_draws=0,original_GO='UNCHANGED',freeze_commit=fr$commit_hash)
js(verdict,'verdict.json')
energy_base<-weighted.mean(d$DR1TKCAL[control],d$w[control])
csv(data.frame(reference=refs,kcal_DiD=vapply(refs,function(r)getpoint('total_kcal',r),0),control_day1_kcal=energy_base,mode_pct_of_control= -100*vapply(refs,function(r)getpoint('total_kcal',r),0)/energy_base),'A4_scale_comparison.csv')
capture.output(sessionInfo(),file=file.path(out,'provenance/R_sessionInfo.txt'))
js(list(status=status,finished_utc=stamp(),person_count=sum(cc),endpoints=length(endpoints),Taylor_rows=nrow(pt),pretrend_rows=nrow(pr),failed_replicate_endpoint_fits=failed,story_verdict=story),'analysis_status.json')
cat('Analysis complete:',status,mc,composition,story,'; individual data not printed\n')
