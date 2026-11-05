from pathlib import Path
import urllib.request,urllib.parse,hashlib,json,datetime,concurrent.futures
OUT=Path(__file__).resolve().parents[1]
DEST=Path('/Volumes/RESCUE_5TB/DR-MODE-01_S2_food_decomposition')
BASE='https://www.ars.usda.gov'
jobs=[]
for v in ['1112','1314','1516','1718','2123']:
    name=f'WWEIA{v}_foodcat_FNDDS.xlsx'
    jobs.append((BASE+'/ARSUserFiles/80400530/apps/'+name,DEST/name))
for v in ['2015-2016','2017-2018','2021-2023']:
    name=f'{v} FNDDS At A Glance - Foods and Beverages.xlsx'
    jobs.append((BASE+'/ARSUserFiles/80400530/apps/'+urllib.parse.quote(name),DEST/name))
jobs.append((BASE+'/ARSUserFiles/80400530/pdf/2123/Food_Categories_August%202021-August%202023.pdf',DEST/'Food_Categories_2123.pdf'))
def get(job):
    u,p=job
    try:
        with urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'Mozilla/5.0'}),timeout=40) as r:
            b=r.read();final=r.url;http=r.status
        assert b.startswith(b'PK') if p.suffix=='.xlsx' else b.startswith(b'%PDF')
        p.write_bytes(b)
        return dict(url=u,final_url=final,path=str(p),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b),http=http,status='PASS',retrieved_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
    except Exception as e:return dict(url=u,path=str(p),status='NOT_DOWNLOADED',reason=str(e))
with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:rows=list(pool.map(get,jobs))
(OUT/'provenance/download_metadata.json').write_text(json.dumps(rows,indent=2))
for r in rows:print(Path(r['path']).name,r['status'],r.get('bytes',r.get('reason')))
