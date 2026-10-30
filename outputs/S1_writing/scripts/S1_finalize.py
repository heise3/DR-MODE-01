from pathlib import Path
import csv, json, hashlib, statistics, datetime

base=Path('outputs/S1_writing'); nci=base/'S1b_C3c_usual_intake'; sealed=Path('outputs/DR-MODE-01')
def rows(p):
    with open(p,newline='') as f:return list(csv.DictReader(f))
def put_csv(p,data):
    with open(p,'w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(data[0]));w.writeheader();w.writerows(data)
scenarios=['original','control_mean','linear_extrapolation']
summaries={s:{r['nutrient']:r for r in rows(nci/s/'usual_intake_summary.csv')} for s in scenarios}
sim={s:{(r['nutrient'],r['replicate']):float(r['below_EAR_percent']) for r in rows(nci/s/'simulation_replicates.csv')} for s in scenarios}
effects=[]
for y in ['iron','calcium']:
    b=summaries['original'][y]
    for s in scenarios[1:]:
        a=summaries[s][y]; diffs=[v-sim['original'][k] for k,v in sim[s].items() if k[0]==y]
        delta=float(a['below_EAR_percent'])-float(b['below_EAR_percent'])
        assert abs(delta-statistics.mean(diffs))<1e-9
        effects.append(dict(nutrient=y,reference=s,n_eligible_persons=4285,n_model_persons=4041,
            original_below_EAR_percent=b['below_EAR_percent'],corrected_below_EAR_percent=a['below_EAR_percent'],
            change_percentage_points=delta,original_usual_mean_mg=b['usual_intake_mean_mg'],corrected_usual_mean_mg=a['usual_intake_mean_mg'],
            simulation_only_MCSE_change_pp=statistics.stdev(diffs)/len(diffs)**.5,
            uncertainty='MCSE is only distribution-simulation error; no sampling CI or DiD uncertainty',
            numerical_status='EXECUTED',inadequacy_interpretation='NO_VALID_RESULT_FULL_ADULT_IRON' if y=='iron' else 'CONDITIONAL_MODEL_ESTIMATE',
            claim='nominal below-EAR proportion only' if y=='iron' else 'food/beverage inadequacy under NCI and EAR assumptions'))
put_csv(nci/'S1b_prevalence_comparison.csv',effects)
put_csv(nci/'S1b_all_scenario_estimates.csv',[summaries[s][y] for s in scenarios for y in ['iron','calcium']])

diag=[]
for s in scenarios:
    rr=rows(nci/s/'convergence.csv')
    diag.append(dict(scenario=s,chains=4,iterations_per_chain=12000,burnin=2000,thin=25,
                     retained_draws_per_chain=400,max_Rhat=max(float(r['Rhat']) for r in rr),
                     min_ESS=min(float(r['ESS']) for r in rr),model_persons=4041))
put_csv(nci/'convergence_summary.csv',diag)

old=json.loads((base/'provenance/contract_comparison_preflight.json').read_text())
changed=[];missing=[]
for rel,h in old['baseline_files'].items():
    f=sealed/rel
    if not f.exists():missing.append(rel)
    elif hashlib.sha256(f.read_bytes()).hexdigest()!=h:changed.append(rel)
added=sorted(str(f.relative_to(sealed)) for f in sealed.rglob('*') if f.is_file() and str(f.relative_to(sealed)) not in old['baseline_files'])
ziphash=hashlib.sha256(Path('outputs/DR-MODE-01_v1.0_GO.zip').read_bytes()).hexdigest()
assert not changed and not missing and not added and ziphash==old['original_zip_sha256']
v1=json.loads((sealed/'status.json').read_text());assert v1['verdict']=='GO'
rake_source=[r for r in rows(sealed/'C_main/sensitivity_results.csv') if 'rak' in r['analysis']]
rake_final=rows(base/'S1d_raking_table.csv')
assert len(rake_source)==len(rake_final)==24
assert all(all(a[k]==b[k] for k in a) for a,b in zip(rake_source,rake_final))
closure=rows(base/'provenance/S1c_identity_check.csv');assert max(abs(float(r['closure_error'])) for r in closure)<1e-11
qa=dict(verified_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),sealed_files_verified=len(old['baseline_files']),changed_files=changed,missing_files=missing,added_files=added,original_zip_sha256=ziphash,v1_verdict='GO_UNCHANGED',raking_exact_original_fields=True,identity_max_absolute_error=max(abs(float(r['closure_error'])) for r in closure),raw_input_reconstruction=json.loads((base/'provenance/input_reconstruction_QA.json').read_text()),NCI_day2_mode_shift_max=0.0)
(base/'provenance/final_QA.json').write_text(json.dumps(qa,ensure_ascii=False,indent=2)+'\n')
status=dict(task='DR-MODE-01 S1 writing supplement',version='S1; not v1.1',contract_sha256=old['sealed_contract_sha256_verified'],inherited_v1_verdict='GO',gates_reassessed=False,contract_comparison='FORMAT_ONLY_CONTINUE',S1a='COMPLETE',S1b={'computation':'COMPLETE_NCIMULTIVAR_1.1.2','calcium':'CONDITIONAL_MODEL_ESTIMATE','iron_below_EAR':'EXECUTED_NOMINAL_ONLY','iron_full_adult_inadequacy':'NO_VALID_RESULT_METHOD_ASSUMPTION_VIOLATION','sampling_CI':'NOT_RUN','DiD_uncertainty':'NOT_PROPAGATED'},S1c='COMPLETE_IDENTITY_VERIFIED',S1d='COMPLETE_ORIGINAL_RESULTS_CARRIED',full_joint_raking='NOT_RUN_STRUCTURAL_ZEROS_CARRIED_NO_RETRY',original_unchanged=True)
(base/'status_S1.json').write_text(json.dumps(status,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'effects':effects,'diagnostics':diag,'QA':qa},ensure_ascii=False,indent=2))
