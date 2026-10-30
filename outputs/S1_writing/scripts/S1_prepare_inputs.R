suppressPackageStartupMessages(library(haven));suppressPackageStartupMessages(library(survey));library(jsonlite)
out<-'outputs/S1_writing/provenance';dir.create(out,showWarnings=FALSE,recursive=TRUE)
cycles<-c('G','H','I','J','L');raw<-list()
suffix<-c('TNUMF','TKCAL','TSUGR','TALCO','TCAFF','TMOIS','TIRON','TCALC','TSODI','TPROT','TTFAT','TFIBE')
outcomes<-c('Y1','Y2','total_sugars','alcohol','caffeine','moisture','iron','calcium','sodium','protein_energy_pct','fat_energy_pct','fiber')
for(cy in cycles) {
  x<-lapply(c('DR1TOT','DR2TOT','DEMO'),function(s)as.data.frame(read_xpt(file.path('outputs/DR-MODE-01/A_access/data',paste0(s,'_',cy,'.xpt')))))
  stopifnot(all(vapply(x,function(d)!anyDuplicated(d$SEQN),logical(1))))
  d1<-x[[1]];d2<-x[[2]];dm<-x[[3]]
  if(cy %in% c('G','H')){names(d1)[names(d1)=='DR1MNRSP']<-'DR1MRESP';names(d2)[names(d2)=='DR2MNRSP']<-'DR2MRESP'}
  d<-merge(d1,d2[,c('SEQN',setdiff(names(d2),names(d1)))],by='SEQN',all=TRUE)
  d<-merge(dm,d,by='SEQN',all.x=TRUE);d$cycle<-cy
  both<-!is.na(d$DR1DRSTZ)&!is.na(d$DR2DRSTZ)&d$DR1DRSTZ==1&d$DR2DRSTZ==1
  d$adult<-both&d$RIDAGEYR>=20&!is.na(d$DRABF)&d$DRABF!=1
  d$youth<-both&d$RIDAGEYR>=2&d$RIDAGEYR<=19&!is.na(d$DRABF)&d$DRABF!=1
  d$interval<-abs(d$DR1DBIH-d$DR2DBIH)
  for(day in 1:2){
    dow<-d[[paste0('DR',day,'DAY')]];v<-as.numeric(dow %in% c(1,7));v[is.na(dow)]<-NA;d[[paste0('weekend',day)]]<-v
    lang<-d[[paste0('DR',day,'LANG')]];d[[paste0('language',day)]]<-ifelse(lang %in% 1:6,pmin(lang,4),NA)
    proxy<-d[[paste0('DR',day,'MRESP')]];valid<-if(cy %in% c('G','H'))c(1:12,14) else c(1:3,5:11)
    d[[paste0('proxy',day)]]<-ifelse(proxy %in% valid,as.numeric(proxy!=1),NA)
  }
  d$age_group<-cut(d$RIDAGEYR,c(19,39,59,Inf),labels=c('20-39','40-59','60+'))
  d$cov_complete<-complete.cases(d[,c('weekend1','weekend2','interval','language1','language2','proxy1','proxy2','age_group','RIAGENDR')])
  raw[[cy]]<-d
}
basecols<-c('SEQN','cycle','adult','youth','WTDRD1','WTDR2D','SDMVSTRA','SDMVPSU','RIDAGEYR','RIAGENDR','RIDRETH3','DMDEDUC2','interval','weekend1','weekend2','language1','language2','proxy1','proxy2','age_group','cov_complete')
d<-do.call(rbind,lapply(raw,function(x)x[,c(basecols,paste0('DR1',suffix),paste0('DR2',suffix))]))
for(y in outcomes){
  for(day in 1:2){
    v<-d[[paste0('DR',day,suffix[match(y,outcomes)])]]
    if(y=='protein_energy_pct')v<-100*4*v/d[[paste0('DR',day,'TKCAL')]] else if(y=='fat_energy_pct')v<-100*9*v/d[[paste0('DR',day,'TKCAL')]] else if(y!='Y1')v<-log1p(v)
    v[!is.finite(v)]<-NA_real_;d[[paste0(y,'_day',day)]]<-v
  }
  d[[y]]<-d[[paste0(y,'_day2')]]-d[[paste0(y,'_day1')]]
}
d<-d[!is.na(d$WTDR2D)&d$WTDR2D>0,];d$cycle<-factor(d$cycle,levels=cycles);d$is_L<-as.numeric(d$cycle=='L')
d$time<-c(G=2012,H=2014,I=2016,J=2018,L=2022.7)[as.character(d$cycle)]-2015;d$w<-d$WTDR2D/5
d$stratum<-interaction(d$cycle,d$SDMVSTRA,drop=TRUE);d$psu<-interaction(d$cycle,d$SDMVSTRA,d$SDMVPSU,drop=TRUE)
for(v in c('language1','language2','proxy1','proxy2','RIAGENDR'))d[[v]]<-factor(d[[v]])
full<-svydesign(ids=~psu,strata=~stratum,weights=~w,data=d,nest=TRUE)
covariates<-'weekend1 + weekend2 + interval + language1 + language2 + proxy1 + proxy2 + age_group + RIAGENDR'
# Optional live-cache audit; no dependency on the cache for later reproduction.
audit<-list(source='sealed public XPT files; mappings copied from sealed code',n_by_cycle=as.list(table(d$cycle[d$adult])),data_identical_to_v1_cache=NA)
if(file.exists('work/stage_c12.rds')){old<-readRDS('work/stage_c12.rds');stopifnot(identical(d,old$data));audit$data_identical_to_v1_cache<-TRUE;rm(old)}
saveRDS(list(data=d,full_design=full,covariates=covariates,outcomes=outcomes),file.path(out,'analysis_input.rds'))
saveRDS(raw$L[,c('SEQN','RIDEXPRG','adult','WTDR2D')],file.path(out,'L_lifestage_input.rds'))
write_json(audit,file.path(out,'input_reconstruction_QA.json'),auto_unbox=TRUE,pretty=TRUE)
print(audit)
