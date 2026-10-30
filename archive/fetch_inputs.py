"""Fetch only source-bound CDC/NCI public files; never accept a changed hash."""
from pathlib import Path
import argparse, hashlib, json, urllib.request, zipfile, io

ROOT=Path(__file__).resolve().parents[1]
ap=argparse.ArgumentParser();ap.add_argument('--stage',choices=['main','x1','nci'],required=True);ap.add_argument('--only',help='Optional exact filename for a download smoke check');args=ap.parse_args()
sha=lambda b:hashlib.sha256(b).hexdigest()
def fetch(url):
    with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'DR-MODE-01-reproduction/1.0'}),timeout=180) as r:return r.read()
def store(p,b,expected):
    assert sha(b)==expected, f'Original source hash mismatch: {p.name}; retain the frozen manifest and report changed source'
    p.parent.mkdir(parents=True,exist_ok=True)
    if p.exists():assert p.read_bytes()==b, f'Do not overwrite different file: {p}'
    else:p.write_bytes(b)
    print('VERIFIED',str(p.relative_to(ROOT)),len(b))
if args.stage=='nci':
    meta=json.loads((ROOT/'outputs/S1_writing/software/source.json').read_text())
    z=zipfile.ZipFile(io.BytesIO(fetch(meta['official_zip_url'])))
    names=[n for n in z.namelist() if n.endswith('ncimultivar_1.1.2.tar.gz')];assert len(names)==1
    store(ROOT/'outputs/S1_writing/software/ncimultivar_1.1.2.tar.gz',z.read(names[0]),meta['tar_sha256'])
else:
    base=ROOT/('outputs/DR-MODE-01' if args.stage=='main' else 'DR-MODE-01/X1')
    paths=['A_access/download_manifest.json','A_access/download_P_manifest.json'] if args.stage=='main' else ['provenance/download_log.json']
    jobs=[r for path in paths for r in json.loads((base/path).read_text()) if r.get('sha256') and r.get('path') and r.get('url')]
    if args.only:jobs=[r for r in jobs if Path(r['path']).name==args.only];assert len(jobs)==1,'Filename must identify exactly one frozen source'
    for r in jobs:
        p=base/r['path'];b=p.read_bytes() if p.exists() else fetch(r['url']);store(p,b,r['sha256'])
