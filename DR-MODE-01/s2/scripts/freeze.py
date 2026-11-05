from pathlib import Path
import hashlib,json,datetime,subprocess,sys
from setup import digest
OUT=Path(__file__).resolve().parents[1]
def stamp():return datetime.datetime.now(datetime.timezone.utc).isoformat()
def run(*args):return subprocess.check_output(args,cwd=OUT,text=True).strip()
if __name__=='__main__':
    assert '--author-confirmed' in sys.argv,'An actual author response is required before freezing.'
    control=json.loads((OUT/'provenance/freeze_control.json').read_text())
    assert control['status']=='AUTHORIZED','Freeze is on HOLD by the latest author instruction; no Git operation performed.'
    for p,sha in control['approved_source_hashes'].items():
        assert digest(OUT/p)==sha,f'Approval does not cover the current file: {p}'
    rec=OUT/'freeze_record.json';assert not rec.exists(),'Never overwrite freeze record'
    assert json.loads((OUT/'G0_checks.json').read_text())['status']=='PASS'
    paths=['protocol_S2.md','wweia_group_map.csv','metadata/category_review.csv','metadata/occasion_codebook_map.csv','metadata/cross_cycle_group_migrations.csv','metadata/cross_cycle_migration_summary.csv','user_request_verbatim.md','user_amendment_20261104.md']
    paths+=sorted(str(p.relative_to(OUT)) for p in (OUT/'scripts').glob('*') if p.suffix in {'.R','.py'})
    assert set(paths)<=set(control['approved_source_hashes']),'Every frozen source file must be covered by the current author approval'
    # A separate repository preserves the public v1.0.0 checkout unchanged.
    run('git','init','-q')
    (OUT/'.gitignore').write_text('data/\nlogs/\nfigures/\n__pycache__/\nprovenance/s2_protected_*.json\n')
    run('git','add',*paths,'.gitignore')
    run('git','-c','user.name=DR-MODE-01 analysis automation','-c','user.email=dr-mode-01@example.invalid','commit','-q','-m','Freeze post hoc S2 protocol and cycle-specific USDA food mapping before outcome analysis')
    commit=run('git','rev-parse','HEAD');git_time=run('git','show','-s','--format=%cI',commit)
    record=dict(task='DR-MODE-01-S2_food_decomposition',status='FROZEN',commit_hash=commit,commit_time=git_time,
                frozen_at_utc=stamp(),protocol_sha256=digest(OUT/'protocol_S2.md'),
                hashes={p:digest(OUT/p) for p in paths},author_mapping_confirmation='Confirmed in current chat; revised protocol/source approval recorded in provenance/freeze_control.json',
                analysis_sha256=digest(OUT/'scripts/analyze.R'),helper_sha256=digest(OUT/'scripts/s2_inference_helpers.R'),
                manuscript_base='manuscript_v1.5_AJCN',manuscript_target='s2/manuscript_v1.6_AJCN',
                timing='post hoc, specified after the primary results; G0 structure only before this commit',
                new_outcome_means_or_DiD_before_freeze=False,external_registration=False,git_repository=str(OUT))
    rec.write_text(json.dumps(record,indent=2));print(json.dumps(record,indent=2))
