from pathlib import Path
import hashlib,json,datetime,shutil

PROJECT=Path(__file__).resolve().parents[3]
OUT=PROJECT/'DR-MODE-01/s2'
def stamp(): return datetime.datetime.now(datetime.timezone.utc).isoformat()
def digest(p):
    h=hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
    return h.hexdigest()
def snapshot():
    rows=[]
    for p in sorted(PROJECT.rglob('*')):
        if not p.is_file() or OUT in p.parents or p.name=='.DS_Store' or p.name.startswith('~$'):continue
        rows.append({'path':str(p.relative_to(PROJECT)),'bytes':p.stat().st_size,'sha256':digest(p)})
    return {'created_utc':stamp(),'root':str(PROJECT),'excluded':'new DR-MODE-01/s2; Finder .DS_Store and transient Word lockfiles','files':rows}

if __name__=='__main__':
    for d in ['provenance','scripts','metadata','data','logs','figures']: (OUT/d).mkdir(parents=True,exist_ok=True)
    dest=OUT/'provenance/s2_protected_before.json'
    assert not dest.exists(),'Never overwrite the initial protection manifest'
    source=Path('/Users/feishuduobang/.codex/attachments/30c92ffe-b16e-4c51-9517-f2d62a0f995d/已粘贴的文本.txt')
    shutil.copyfile(source,OUT/'user_request_verbatim.md')
    dest.write_text(json.dumps(snapshot(),ensure_ascii=False,indent=2))
    meta={'task':'DR-MODE-01-S2_food_decomposition','created_utc':stamp(),'status':'STRUCTURE_ONLY_NOT_FROZEN',
          'distinct_from':'outputs/S2_uncertainty', 'author_confirmed_manuscript_base':'DR-MODE-01/manuscript_v1.5_AJCN',
          'new_manuscript_target':'DR-MODE-01/s2/manuscript_v1.6_AJCN','author_confirmed_utc':stamp(),
          'no_new_outcome_means_or_DiD_computed':True,'frozen_v1_verdict':'GO_UNCHANGED'}
    (OUT/'provenance/task_initialization.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2))
    print(json.dumps({'protected_files':len(json.loads(dest.read_text())['files']),'snapshot':str(dest),'new_outcome_analysis':'NOT_RUN'}))
