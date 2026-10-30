"""Download only the public CDC files specified for Stage A. No credentials."""
from pathlib import Path
import concurrent.futures, subprocess, hashlib, json, datetime, sys
ROOT=Path(__file__).resolve().parents[2]
jobs=[]
for cycle,year in [('G',2011),('H',2013),('I',2015),('J',2017),('L',2021)]:
    for stem in ['DR1TOT','DR2TOT','DEMO']:
        name=f'{stem}_{cycle}'
        for ext,folder in [('htm','codebooks'),('xpt','data')]:
            jobs.append((f'https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/{year}/DataFiles/{name}.{ext}',ROOT/'A_access'/folder/f'{name}.{ext}'))
jobs += [
('https://wwwn.cdc.gov/nchs/data/Nhanes/Public/2021/Whitepapers/Aug2023-What-We-Eat-In-America-Dietary-Data-Whitepaper.pdf',ROOT/'A_access/codebooks/NCHS_whitepaper.pdf'),
('https://wwwn.cdc.gov/nchs/nhanes/continuousnhanes/overviewbrief.aspx?Cycle=2021-2023',ROOT/'A_access/codebooks/overview_L.htm'),
('https://wwwn.cdc.gov/nchs/nhanes/tutorials/weighting.aspx',ROOT/'A_access/codebooks/weighting_tutorial.htm'),
('https://wwwn.cdc.gov/nchs/nhanes/analyticguidelines.aspx',ROOT/'A_access/codebooks/analyticguidelines.htm')]
manifest='download_manifest.json'
if '--P' in sys.argv:
    jobs=[(f'https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/P_{stem}.{ext}',ROOT/'A_access'/folder/f'P_{stem}.{ext}') for stem in ['DR1TOT','DR2TOT','DEMO'] for ext,folder in [('htm','codebooks'),('xpt','data')]]
    manifest='download_P_manifest.json'
def get(job):
    url,path=job
    if path.exists():
        return {'url':url,'path':str(path.relative_to(ROOT)),'status':'EXISTING','bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    t=datetime.datetime.now(datetime.timezone.utc).isoformat()
    tmp=path.with_suffix(path.suffix+'.part')
    r=subprocess.run(['curl','--fail','--location','--silent','--show-error','--retry','2','--connect-timeout','20','--max-time','120','--output',str(tmp),'--write-out','%{http_code}\t%{url_effective}\t%{content_type}',url],capture_output=True,text=True)
    data=tmp.read_bytes() if tmp.exists() else b''
    valid=(r.returncode==0 and len(data)>1000)
    if path.suffix=='.xpt':valid=valid and data.startswith(b'HEADER RECORD*******LIBRARY HEADER RECORD!!!!!!!')
    if path.suffix=='.pdf':valid=valid and data.startswith(b'%PDF')
    if valid:tmp.rename(path)
    out={'url':url,'path':str(path.relative_to(ROOT)),'retrieved_utc':t,'status':'OK' if valid else 'FAILED','curl_returncode':r.returncode,'http':r.stdout,'stderr':r.stderr,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest() if data else None}
    print(json.dumps({'file':path.name,'status':out['status'],'bytes':out['bytes']}),flush=True)
    return out
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    result=list(pool.map(get,jobs))
(ROOT/'A_access'/manifest).write_text(json.dumps(result,indent=2)+'\n')
if any(r['status']=='FAILED' for r in result):raise SystemExit(1)
