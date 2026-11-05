from pathlib import Path
import json,csv,hashlib,math,ast
R=Path(__file__).resolve().parents[1]
m=json.loads((R/'post_hoc_extension/manifest.json').read_text())
for p,h in m['sha256'].items():assert hashlib.sha256((R/p).read_bytes()).hexdigest()==h,p
s=R/'DR-MODE-01/s2';f=json.loads((s/'freeze_record.json').read_text())
for p,h in f['hashes'].items():assert hashlib.sha256((s/p).read_bytes()).hexdigest()==h,p
rows=lambda p:list(csv.DictReader((s/p).open()))
a=rows('A1_decomposition.csv')
for ref in ['control_mean','linear_extrapolation']:
 d={r['endpoint']:r for r in a if r['reference']==ref};assert abs(float(d['log_E']['DiD'])-float(d['log_N']['DiD'])-float(d['log_P']['DiD']))<1e-10
for r in rows('bootstrap_shares_and_R.csv'):
 if r['R_g']:assert abs(float(r['R_g'])-float(r['share'])/float(r['s_g']))<1e-10
for r in rows('composition_R_tests.csv'):
 if r.get('R_test_status')=='COMPLETE' and r.get('R_family'):assert r['R_q_BH']!=''
assert len(list(csv.DictReader((s/'replay_inputs/PSU_multiplier_matrix.csv').open())))==151
print('PASS: frozen and release hashes; exact log identities; R ratios; PSU matrix. No models fitted.')
