from pathlib import Path
import csv,json,collections,datetime
p=Path('outputs/S2_uncertainty');rr=[]
for f in (p/'replicates').glob('rep_*/estimates.csv'):
    try:
        with f.open() as h:rr+=list(csv.DictReader(h))
    except (OSError,csv.Error):pass
rr=[x for x in rr if int(x['replicate'])>0]
finished=len(list((p/'replicates').glob('rep_*/COMPLETE.json')))-int((p/'replicates/rep_000/COMPLETE.json').exists())
info={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'replicates_finished':finished,'scenario_results':len(rr),'status':dict(collections.Counter(x['status'] for x in rr)),'max_Rhat_complete':max([float(x['max_Rhat']) for x in rr if x['status']=='COMPLETE'] or [0]),'long_chain_repairs_completed':sum(x['iterations']=='12000' and x['status']=='COMPLETE' for x in rr),'unexpected_errors':[{'replicate':x['replicate'],'scenario':x['scenario'],'reason':x['reason']} for x in rr if x['status']!='COMPLETE' and 'NEGATIVE_CORRECTED_AMOUNT' not in x['reason']]}
(p/'provenance/progress.json').write_text(json.dumps(info,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(info,ensure_ascii=False,indent=2))
