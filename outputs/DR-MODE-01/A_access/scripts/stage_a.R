options(survey.lonely.psu='fail')
suppressPackageStartupMessages(library(haven))
suppressPackageStartupMessages(library(survey))
suppressPackageStartupMessages(library(jsonlite))
root <- 'outputs/DR-MODE-01'
cycles <- c('G','H','I','J','L')
count_rows <- list(); interval_rows <- list(); calibration <- list(); dictionary <- list()
rawlist <- list()
for (cy in cycles) {
  ds <- lapply(c('DR1TOT','DR2TOT','DEMO'), function(stem) as.data.frame(read_xpt(file.path(root,'A_access/data',paste0(stem,'_',cy,'.xpt')))))
  names(ds) <- c('d1','d2','demo')
  for (nm in names(ds)) {
    stopifnot(!anyDuplicated(ds[[nm]]$SEQN), !anyNA(ds[[nm]]$SEQN))
    dictionary[[paste(cy,nm)]] <- data.frame(cycle=cy,file=nm,variable=names(ds[[nm]]),label=vapply(ds[[nm]],function(z) {v<-attr(z,'label');if(is.null(v)) '' else v},character(1)))
  }
  d1<-ds$d1; d2<-ds$d2; dm<-ds$demo
  if(cy %in% c('G','H')) {
    names(d1)[names(d1)=='DR1MNRSP']<-'DR1MRESP'
    names(d2)[names(d2)=='DR2MNRSP']<-'DR2MRESP'
  }
  req<-c('SEQN','WTDRD1','WTDR2D','DRABF',paste0('DR1',c('DRSTZ','DBIH','DAY','LANG','MRESP','TNUMF','TKCAL','TSUGR','TALCO','TCAFF','TMOIS','TIRON','TCALC','TSODI','TPROT','TTFAT','TFIBE')))
  stopifnot(all(req %in% names(d1)))
  req2<-sub('^DR1','DR2',req)
  stopifnot(all(req2 %in% names(d2)))
  stopifnot(all(c('RIDAGEYR','RIAGENDR','RIDRETH3','DMDEDUC2','SDMVSTRA','SDMVPSU') %in% names(dm)))
  overlap<-intersect(setdiff(names(d1),'SEQN'),setdiff(names(d2),'SEQN'))
  ix<-match(d1$SEQN,d2$SEQN)
  for(v in overlap)stopifnot(identical(as.numeric(d1[[v]]),as.numeric(d2[[v]][ix])))
  d <- merge(d1,d2[,c('SEQN',setdiff(names(d2),names(d1)))],by='SEQN',all=TRUE)
  d <- merge(dm,d,by='SEQN',all.x=TRUE)
  stopifnot(!anyDuplicated(d$SEQN),nrow(d)==nrow(dm))
  d$cycle <- cy
  d$both_reliable <- !is.na(d$DR1DRSTZ)&!is.na(d$DR2DRSTZ)&d$DR1DRSTZ==1&d$DR2DRSTZ==1
  d$adult <- d$both_reliable & d$RIDAGEYR>=20 & !is.na(d$DRABF) & d$DRABF!=1
  d$youth <- d$both_reliable & d$RIDAGEYR>=2 & d$RIDAGEYR<=19 & !is.na(d$DRABF) & d$DRABF!=1
  d$interval <- abs(d$DR1DBIH-d$DR2DBIH)
  d$weekend1 <- as.numeric(d$DR1DAY %in% c(1,7));d$weekend1[is.na(d$DR1DAY)]<-NA
  d$weekend2 <- as.numeric(d$DR2DAY %in% c(1,7));d$weekend2[is.na(d$DR2DAY)]<-NA
  d$language1 <- ifelse(d$DR1LANG %in% 1:6,pmin(d$DR1LANG,4),NA)
  d$language2 <- ifelse(d$DR2LANG %in% 1:6,pmin(d$DR2LANG,4),NA)
  proxy_valid <- if(cy %in% c('G','H')) c(1:12,14) else c(1:3,5:11)
  d$proxy1 <- ifelse(d$DR1MRESP %in% proxy_valid,as.numeric(d$DR1MRESP!=1),NA)
  d$proxy2 <- ifelse(d$DR2MRESP %in% proxy_valid,as.numeric(d$DR2MRESP!=1),NA)
  d$age_group <- cut(d$RIDAGEYR,c(19,39,59,Inf),labels=c('20-39','40-59','60+'))
  d$cov_complete <- complete.cases(d[,c('weekend1','weekend2','interval','language1','language2','proxy1','proxy2','age_group','RIAGENDR')])
  count_rows[[cy]]<-data.frame(cycle=cy,n_demo=nrow(dm),n_dr1_file=nrow(d1),n_dr2_file=nrow(d2),n_day1_reliable=sum(d$DR1DRSTZ==1,na.rm=TRUE),n_both_reliable_all_ages=sum(d$both_reliable),n_both_reliable_adults_before_DRABF=sum(d$both_reliable & d$RIDAGEYR>=20),n_adults=sum(d$adult),n_youth=sum(d$youth),n_adult_DRABF_missing=sum(d$both_reliable&d$RIDAGEYR>=20&is.na(d$DRABF)),n_adult_positive_WTDR2D=sum(d$adult&d$WTDR2D>0,na.rm=TRUE),n_adult_complete_covariates=sum(d$adult&d$cov_complete),A3_pass=sum(d$adult)>=2500)
  use <- d$adult & !is.na(d$interval)
  interval_rows[[cy]] <- data.frame(cycle=cy,n_adults=sum(d$adult),n_interval_available=sum(use),n_interval_missing=sum(d$adult&is.na(d$interval)),mean_interval=mean(d$interval[use]),min_interval=min(d$interval[use]),max_interval=max(d$interval[use]),n_signed_negative=sum((d$DR2DBIH-d$DR1DBIH)[use]<0),n_interval_3_10=sum(d$interval[use]>=3&d$interval[use]<=10),n_weekday_arithmetic_disagreement=sum(((d$DR2DBIH[use]-d$DR1DBIH[use])%%7)!=((d$DR2DAY[use]-d$DR1DAY[use])%%7),na.rm=TRUE))
  if(cy %in% c('J','L')) {
    z<-d[!is.na(d$WTDRD1)&d$WTDRD1>0,]
    z$calib<-z$RIDAGEYR>=20 & z$DR1DRSTZ==1 & !is.na(z$DRABF)&z$DRABF!=1 & !is.na(z$DR1TKCAL)&z$DR1TKCAL>0
    des<-svydesign(ids=~SDMVPSU,strata=~SDMVSTRA,weights=~WTDRD1,nest=TRUE,data=z)
    sd<-subset(des,calib)
    m<-svymean(~DR1TNUMF,sd,na.rm=FALSE)
    target<-if(cy=='J')16 else 15.1
    calibration[[cy]]<-data.frame(cycle=cy,n_adults_day1_nonfasting=sum(z$calib),mean=unname(coef(m)),se=unname(SE(m)),target=target,absolute_error=abs(unname(coef(m))-target),tolerance=0.2,pass=abs(unname(coef(m))-target)<=0.2)
  }
  rawlist[[cy]]<-d
}
counts<-do.call(rbind,count_rows); ints<-do.call(rbind,interval_rows); cal<-do.call(rbind,calibration)
write.csv(counts,file.path(root,'A_access/person_counts.csv'),row.names=FALSE)
write.csv(ints,file.path(root,'A_access/interval_diagnostics.csv'),row.names=FALSE)
write.csv(cal,file.path(root,'A_access/calibration.csv'),row.names=FALSE)
write.csv(do.call(rbind,dictionary),file.path(root,'A_access/variable_dictionary.csv'),row.names=FALSE)
saveRDS(rawlist,'work/nhanes_stage_a_merged.rds')
write_json(list(calibration_mean_pass=all(cal$pass),L_day1_reliable_observed=counts$n_day1_reliable[counts$cycle=='L'],L_day1_reliable_target=6694,L_day1_reliable_pass=counts$n_day1_reliable[counts$cycle=='L']==6694,A3_pass=all(counts$A3_pass)),file.path(root,'A_access/stage_a_numeric_gates.json'),pretty=TRUE,auto_unbox=TRUE)
writeLines(capture.output(sessionInfo()),file.path(root,'A_access/R_sessionInfo.txt'))
print(counts,row.names=FALSE);print(cal,row.names=FALSE);print(ints,row.names=FALSE)
