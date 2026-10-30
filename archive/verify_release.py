"""Read-only archive verification; no model fitting and no individual records."""
from pathlib import Path
import csv, hashlib, json, ast
ROOT=Path(__file__).resolve().parents[1]
def rows(p):return list(csv.DictReader((ROOT/p).open()))
for r in rows('archive/verbatim_source_manifest.csv'):
    p=ROOT/r['path'];assert hashlib.sha256(p.read_bytes()).hexdigest()==r['sha256'],r['path']
if (ROOT/'SHA256SUMS.txt').exists():
    for line in (ROOT/'SHA256SUMS.txt').read_text().splitlines():
        h,name=line.split('  ',1);assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==h,name
for p in ROOT.rglob('*.py'):ast.parse(p.read_text(),filename=str(p.relative_to(ROOT)))
matrix=rows('outputs/S2_uncertainty/provenance/PSU_multiplier_matrix.csv')
assert len(matrix)==151 and len(matrix[0])==203
reps=rows('outputs/S2_uncertainty/S2_1_replicate_estimates.csv')
assert len(reps)==201 and sorted(int(r['replicate']) for r in reps)==list(range(201))
identity=rows('outputs/S1_writing/provenance/S1c_identity_check.csv')
assert max(abs(float(r['closure_error'])) for r in identity)<1e-11
assert json.loads((ROOT/'outputs/DR-MODE-01/status.json').read_text())['verdict']=='GO'
assert json.loads((ROOT/'DR-MODE-01/X1/status_X1.json').read_text())['verdict']=='NOT_IDENTIFIED'
print(json.dumps({'archive_verification':'PASS','PSUs':151,'bootstrap_replicates':200,'individual_records_republished':False,'full_analysis_refitted':'NOT_RUN_PUBLICATION_VERIFICATION_ONLY'},indent=2))
