from pathlib import Path
import csv,json,re,math

P=Path('DR-MODE-01/W0_audit');V=Path('outputs/DR-MODE-01');S=Path('outputs/S2_uncertainty')
def rows(p):
    with Path(p).open(newline='') as h:return list(csv.DictReader(h))
def close(a,b):return math.isclose(float(a),float(b),rel_tol=1e-12,abs_tol=1e-11)
ledger=rows(P/'claims_ledger.csv');assert len({r['claim_id'] for r in ledger})==len(ledger)
for r in ledger:
    assert Path(r['文件路径']).is_file()
    assert not ('bootstrap' in r['推断方法'] and r['p 或 q']!='NA')
    if r['p 或 q']!='NA':assert r['来源包']=='v1.0'
    m=re.search(r'line=(\d+)',r['行或键'])
    if m:
        original=rows(r['文件路径']);assert 2<=int(m[1])<=len(original)+1

cm=rows(V/'C_main/cycle_means.csv');fg1=rows(P/'figdata/fig1_pretrend.csv')
errors=[]
for r in fg1:
    assert Path(r['source_file']).is_file()
    if r['record_type']=='cycle_mean':
        x=next(x for x in cm if x['cycle']==r['cycle'] and x['outcome']==r['outcome'])
        assert close(r['estimate'],x['D_mean']) and close(r['se'],x['D_se']) and r['n_persons']==x['n_persons']
        errors.append(abs(float(r['estimate'])-float(x['D_mean'])))
assert len(fg1)==14

fg2=rows(P/'figdata/fig2_correction.csv');unc=rows(S/'S2_1_summary_CI.csv')
for r in fg2:
    assert Path(r['source_file']).is_file()
    if r['source_package']=='S2':
        x=unc[int(r['source_line'])-2]
        for k in ['estimate','se','ci_low','ci_high','CI_status','valid_replicates']:assert r[k]==x[k]
    else:
        assert r['CI_status']=='NOT_RUN' and r['ci_low']==r['ci_high']=='NA'
assert len(fg2)==25
flow=rows(P/'figdata/tab1_flow.csv')
for cy in ['G','H','I','J','L']:
    rr=[r for r in flow if r['cycle']==cy];assert len(rr)==7
    for i,r in enumerate(rr):
        assert int(r['n_before'])-int(r['n_excluded'])==int(r['n_remaining'])
        if i:assert rr[i-1]['n_remaining']==r['n_before']
        assert Path(r['source_file']).is_file()
panel=rows(P/'figdata/supp_panel.csv');assert len(panel)==20
assert len({r['outcome'] for r in panel})==10
by_tier={tier:len({r['outcome'] for r in panel if r['tier']==tier}) for tier in {r['tier'] for r in panel}}
assert by_tier=={'both_references_FDR_lt_0.05':3,'reference_dependent':6,'neither_reference_FDR_lt_0.05':1}
fail=rows(P/'checks/failed_replicates_detail.csv');assert len(fail)==30
assert all('NEGATIVE_CORRECTED_AMOUNT' in r['reason'] and r['scenario']=='linear_extrapolation' for r in fail)
assert sum(int(r['negative_calcium_persons'])>0 for r in fail)==2
assert sum(int(r['negative_iron_persons'])>0 for r in fail)==28
status=json.loads((P/'status_W0.json').read_text())
assert all(v=='PASS' for v in status['audit'].values())
assert status['bootstrap_rao_wu'] and not status['S2c_run']
assert status['reconcile']=='RECONCILED' and status['writing_gate']=='OPEN'
qa={'status':'PASS','ledger_rows':len(ledger),'unique_claim_ids':True,'source_paths_exist':True,'no_Taylor_p_bootstrap_CI_mixing':True,'fig1_cycle_mean_max_difference':max(errors),'fig2_rows':len(fg2),'fig2_CI_NOT_RUN_rows':sum(r['CI_status']=='NOT_RUN' for r in fg2),'fig2_CI_NO_VALID_RESULT_rows':sum(r['CI_status'].startswith('NO_VALID_RESULT') for r in fg2),'flow_telescopes':True,'panel_tier_counts':by_tier,'failed_replicates':len(fail),'writing_gate':'OPEN'}
(P/'provenance/final_data_QA.json').write_text(json.dumps(qa,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(qa,ensure_ascii=False,indent=2))
