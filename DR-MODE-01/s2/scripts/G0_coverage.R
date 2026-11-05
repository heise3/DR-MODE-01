suppressPackageStartupMessages({library(haven);library(jsonlite)})
out<-'DR-MODE-01/s2';mp<-read.csv(file.path(out,'wweia_group_map.csv'))
rows<-list()
for(cy in c('G','H','I','J','L')) {
 en<-un<-unc<-cnt<-miss<-0
 for(day in 1:2) {
  dr<-paste0('DR',day)
  columns<-c('SEQN',paste0(dr,c('IFDCD','IKCAL','DRSTZ')))
  q<-as.data.frame(read_xpt(sprintf('DR-MODE-01/X1/data/%sIFF_%s.xpt',dr,cy),col_select=all_of(columns)))
  q<-q[!is.na(q[[paste0(dr,'DRSTZ')]])&q[[paste0(dr,'DRSTZ')]]==1,]
  mm<-mp[mp$cycle==cy,];idx<-match(q[[paste0(dr,'IFDCD')]],mm$food_code)
  e<-q[[paste0(dr,'IKCAL')]];stopifnot(!anyNA(e))
  en<-en+sum(e);un<-un+sum(e[is.na(idx)]);unc<-unc+sum(e[!is.na(idx)&mm$coverage_unclassified[idx]==1])
  cnt<-cnt+nrow(q);miss<-miss+sum(is.na(idx))
 }
 rows[[cy]]<-data.frame(cycle=cy,iff_records=cnt,records_without_official_mapping=miss,
  unmatched_energy_share=un/en,official_category_9999_energy_share=unc/en,
  unclassified_combined_energy_share=(un+unc)/en,
  G0_5=if(un/en<.01)'PASS'else'STOP_DATA',
  reason='Gate uses food-code-to-official-category mapping coverage; published category 9999 is retained in G10 and separately disclosed')
}
z<-do.call(rbind,rows);write.csv(z,file.path(out,'metadata/G0_5_coverage.csv'),row.names=FALSE)
print(z,row.names=FALSE)
