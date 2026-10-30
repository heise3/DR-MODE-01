from pathlib import Path
import urllib.request, hashlib, json, datetime, concurrent.futures, time
ROOT=Path(__file__).resolve().parents[1]
freeze=json.loads((ROOT/'provenance/freeze.json').read_text())
assert hashlib.sha256((ROOT/'CONTRACT_X1_v1.0.md').read_bytes()).hexdigest()==freeze['contract_sha256']
jobs=[]
for cy,year in [('G',2011),('H',2013),('I',2015),('J',2017),('L',2021),('P',2017)]:
    for day in ([1] if cy=='P' else [1,2]):
        stem=f'P_DR{day}IFF' if cy=='P' else f'DR{day}IFF_{cy}'
        for ext in ['xpt','htm']:
            dest=ROOT/('data' if ext=='xpt' else 'provenance')/f'{stem}.{ext}'
            jobs.append((f'https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/{year}/DataFiles/{stem}.{ext}',dest))
jobs.append(('https://www.cdc.gov/nchs/products/databriefs/db533.htm',ROOT/'provenance/DB533.htm'))
def get(job):
    url,p=job
    for attempt in range(3):
        try:
            req=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0 (public NHANES research)'})
            with urllib.request.urlopen(req,timeout=120) as r:
                data=r.read(); status=r.status; final_url=r.url
            if p.suffix=='.xpt': assert data.startswith(b'HEADER RECORD'),data[:100]
            p.write_bytes(data)
            return {'url':url,'final_url':final_url,'path':str(p.relative_to(ROOT)),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'http_status':status,'downloaded_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'PASS'}
        except Exception as e:
            err=str(e)
            if attempt<2: time.sleep(2)
    return {'url':url,'path':str(p.relative_to(ROOT)),'status':'FAIL','error':err}
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool: rows=list(pool.map(get,jobs))
(ROOT/'provenance/download_log.json').write_text(json.dumps(rows,indent=2))
for r in rows: print(r['path'],r['status'],r.get('bytes',r.get('error')))
assert all(r['status']=='PASS' for r in rows)
