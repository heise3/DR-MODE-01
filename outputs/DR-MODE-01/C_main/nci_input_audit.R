.libPaths(c(normalizePath('work/Rlib'),.libPaths()))
library(ncimultivar);library(jsonlite)
root<-'outputs/DR-MODE-01';raw<-readRDS('work/nhanes_stage_a_merged.rds')$L
ds<-raw[raw$adult & raw$WTDR2D>0,]
did<-read.csv(file.path(root,'C_main/DiD_all_outcomes.csv'))
out<-list();prep_status<-list()
for(y in c('iron','calcium')) {
 suffix<-if(y=='iron')'TIRON' else 'TCALC'
 shift<-did$mode_effect[did$outcome==y & did$reference=='control_mean']
 v1<-ds[[paste0('DR1',suffix)]];v2<-ds[[paste0('DR2',suffix)]]
 lit1<-expm1(log1p(v1)+shift)
 dat<-data.frame(SEQN=rep(ds$SEQN,each=2),DAY=rep(1:2,nrow(ds)),WTDR2D=rep(ds$WTDR2D,each=2),nutrient=as.vector(rbind(lit1,v2)))
 # Audit the direct individual log-shift interpretation of the frozen mean formula.
 # This interpretation is NOT asserted to be uniquely prescribed by the contract.
 # No negative intake is clipped, imputed, or silently discarded for inference.
 bc<-boxcox_survey(input.data=dat,row.subset=dat$DAY==1,variable='nutrient',weight='WTDR2D',do.plots=FALSE)
 ma<-calculate_minimum_amount(input.data=dat,row.subset=dat$DAY==1,daily.variables='nutrient')
 pre<-nci_multivar_preprocessor(input.data=dat,daily.variables='nutrient',boxcox.lambda.data=bc,minimum.amount.data=ma)
 excluded_persons<-unique(dat$SEQN[dat$nutrient<0])
 out[[y]]<-data.frame(outcome=y,n_eligible_persons=nrow(ds),n_original_day1_zero_persons=sum(v1==0),literal_log_shift=shift,min_literal_day1= min(lit1),n_literal_negative_persons=length(excluded_persons),n_package_retained_persons=length(unique(pre$mcmc.input$SEQN)),n_package_retained_both_days_persons=sum(table(pre$mcmc.input$SEQN)==2),MCMC_status='NOT_RUN',prevalence_status='NO_VALID_RESULT',reason='Frozen correction sign conflicts with the mode-effect definition; a distribution-level correction is not uniquely specified. Direct per-person log-shift additionally produces negative intake and package preprocessing removes recall records.')
 prep_status[[y]]<-list(boxcox_lambda=bc,minimum_amount=ma,preprocessor_executed=TRUE)
}
write.csv(do.call(rbind,out),file.path(root,'C_main/NCI_input_audit.csv'),row.names=FALSE)
write_json(list(package='ncimultivar',version=as.character(packageVersion('ncimultivar')),source='https://prevention.cancer.gov/sites/default/files/2025-08/ncimultivar_1.1.2.zip',software_installation='PASS',preprocessing='EXECUTED_INPUT_AUDIT_ONLY',MCMC='NOT_RUN',usual_intake='NOT_RUN',EAR_prevalence='NOT_RUN',result_validity='NO_VALID_RESULT',failure_layer='DATA_DEFINITION_NOT_EXECUTABLE',reason='Correction direction is inconsistent within frozen contract; original mean-level correction does not uniquely define correction of the distribution. No sign replacement, no clipping or population rescue.',eligibility=c('iron','calcium'),preprocessing_parameters=prep_status),file.path(root,'C_main/NCI_status.json'),pretty=TRUE,auto_unbox=TRUE,digits=16)
print(do.call(rbind,out)[,1:9],row.names=FALSE)
