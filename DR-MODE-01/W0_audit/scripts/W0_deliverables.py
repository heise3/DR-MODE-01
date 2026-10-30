from pathlib import Path
import csv,json,hashlib,datetime

ROOT=Path.cwd();OUT=ROOT/'DR-MODE-01/W0_audit'
V1=ROOT/'outputs/DR-MODE-01';S1=ROOT/'outputs/S1_writing';S2=ROOT/'outputs/S2_uncertainty'
def read(path):
    with Path(path).open(newline='') as f:return list(csv.DictReader(f))
def write(path,rows,fields=None):
    if fields is None:fields=list(dict.fromkeys(k for r in rows for k in r))
    with Path(path).open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=fields);w.writeheader();w.writerows(rows)
def fnum(s):return float(s)
def boolstr(s):return s=='TRUE'
def fmt(x,d=4):
    if x in ['',None,'NA']:return 'NA'
    return f'{float(x):.{d}f}'
def rng(lo,hi):return 'NA' if lo in ['',None,'NA'] or hi in ['',None,'NA'] else f'[{lo}, {hi}]'
def src(path):return str(Path(path).resolve())
def line_for(rows,row):return rows.index(row)+2
def citation(path,line):return f'[{Path(path).name}:L{line}]({src(path)}:{line})'

main=read(V1/'C_main/DiD_all_outcomes.csv');gate=read(V1/'C_main/C1_gate_results.csv')
bgate=read(V1/'B_pretrend/gate_results.csv');impact=read(V1/'C_main/C3ab_impact.csv')
corrected=read(S1/'S1a_C3a_corrected.csv');unc=read(S2/'S2_1_summary_CI.csv')
day2=read(S1/'S1c_day2_direct.csv');counts=read(OUT/'checks/person_counts.csv')
num=json.loads((OUT/'checks/numeric_audit.json').read_text());model=json.loads((OUT/'checks/model_audit.json').read_text())
descs=read(OUT/'checks/paired_differences.csv');wp=read(OUT/'checks/whitepaper_figure9.csv');martin=read(OUT/'checks/Martin2021_reproduction.csv')

# Figure 2: carry S2's final inference, with no Taylor p values attached.
fig2=[]
for r in unc:
    fig2.append(dict(endpoint=r['endpoint'],measure='usual_intake_inadequacy' if r['endpoint']=='calcium' else 'day1_intake_mean',scale=r['scale'],scenario=r['scenario'],statistic=r['statistic'],estimate=r['estimate'],se=r['se'],ci_low=r['ci_low'],ci_high=r['ci_high'],CI_status=r['CI_status'],n_persons=4041 if r['endpoint']=='calcium' else 4285,valid_replicates=r['valid_replicates'],inference='Rao-Wu bootstrap; 200 planned',source_package='S2',source_file=src(S2/'S2_1_summary_CI.csv'),source_line=line_for(unc,r),publication_position='附表' if r['publication_placement']=='SUPPLEMENT_REFERENCE_DEPENDENT' else '正文',limitation='钙未检验前趋势；仅均值参照正文' if r['endpoint']=='calcium' else '主结论Y2；模式包；顺序效应稳定',reason=r['reason']))
# Requested calcium first-day means exist in S1, but their CI was not run in S2.
# Preserve NA rather than append a new uncertainty analysis in an audit-only task.
for sc in ['log1p','original_units']:
    rr=[r for r in corrected if r['outcome']=='calcium' and r['scale']==sc]
    for r in rr:
        for scenario,stat,field in [(r['reference'],'mean','corrected_L_day1_mean'),(r['reference'],'corrected_minus_original','change')]+([('original','mean','original_L_day1_mean')] if r['reference']=='control_mean' else []):
            fig2.append(dict(endpoint='calcium',measure='day1_intake_mean',scale='log(mg+1)' if sc=='log1p' else 'mg/day',scenario=scenario,statistic=stat,estimate=r[field],se='NA',ci_low='NA',ci_high='NA',CI_status='NOT_RUN',n_persons=r['n_persons'],valid_replicates='NA',inference='point estimate only',source_package='S1',source_file=src(S1/'S1a_C3a_corrected.csv'),source_line=line_for(corrected,r),publication_position='附表',limitation='点估计；钙均值CI未在S2运行；不可用不足比例CI替代',reason='S2 computed calcium inadequacy CIs, not first-day calcium intake mean CIs; no new inference in W0'))
write(OUT/'figdata/fig2_correction.csv',fig2)

tab=[]
for r in main:
    if r['outcome'] not in ['Y1','Y2']:continue
    y,ref=r['outcome'],r['reference'];g=next(x for x in gate if x['outcome']==y)
    aa=next(x for x in corrected if x['outcome']==y and x['reference']==ref and x['scale']==('contract_scale' if y=='Y1' else 'log1p'))
    ii=next(x for x in impact if x['outcome']==y and x['reference']==ref)
    row=dict(r,control_D_mean_SD=g['control_cycle_SD'],two_SD=g['size_threshold'],C3a_original=aa['original_L_day1_mean'],C3a_corrected=aa['corrected_L_day1_mean'],C3a_change=aa['change'],C3a_scale=aa['scale'],C3b_observed_J_to_L=ii['observed_change'],C3b_mode_share_percent=ii['mode_share_percent'],DiD_inference='v1.0 Taylor t',DiD_source=src(V1/'C_main/DiD_all_outcomes.csv'),DiD_source_line=line_for(main,r),SD_source=src(V1/'C_main/C1_gate_results.csv'),C3a_source=src(S1/'S1a_C3a_corrected.csv'),C3a_source_line=line_for(corrected,aa),C3b_source=src(V1/'C_main/C3ab_impact.csv'),C3b_source_line=line_for(impact,ii),publication_position='正文' if y=='Y2' else '附表',limitation='Y2唯一通过B；模式包；顺序效应稳定' if y=='Y2' else 'Y1未通过B；参照依赖；支持性')
    row.pop('q_BH',None)
    if y=='Y2':
        kk=next(x for x in corrected if x['outcome']==y and x['reference']==ref and x['scale']=='original_units')
        row.update(C3a_kcal_original=kk['original_L_day1_mean'],C3a_kcal_corrected=kk['corrected_L_day1_mean'],C3a_kcal_change=kk['change'])
    tab.append(row)
write(OUT/'figdata/tab2_main.csv',tab)
panel=[]
for r in main:
    if r['outcome'] in ['Y1','Y2']:continue
    q=[float(x['q_BH']) for x in main if x['outcome']==r['outcome']]
    tier='both_references_FDR_lt_0.05' if all(v<.05 for v in q) else 'reference_dependent' if any(v<.05 for v in q) else 'neither_reference_FDR_lt_0.05'
    panel.append(dict(r,tier=tier,inference='v1.0 Taylor t; BH across 10 per reference',source_package='v1.0',source_file=src(V1/'C_main/DiD_all_outcomes.csv'),source_line=line_for(main,r),publication_position='附表',limitation='未检验营养素前趋势；稳健仅指两参照FDR一致'))
write(OUT/'figdata/supp_panel.csv',panel)
dd=[dict(r,source_package='S1',source_file=src(S1/'S1c_day2_direct.csv'),source_line=line_for(day2,r),publication_position='附表',limitation='未调整；描述性；受间隔和应答变化影响') for r in day2 if r['contrast']=='Day2_L_minus_J']
write(OUT/'figdata/supp_day2.csv',dd)

# Claims ledger: single inferential family per row; original GO/Taylor p/FDR remain v1.
claims=[]
fields=['claim_id','主张原文','数值','95%CI','p 或 q','推断方法','来源包','文件路径','行或键','允许进入的位置','限定条件']
def claim(cid,text,value,ci='NA',pq='NA',method='描述性',package='W0',file=None,key='',position='附表',limit=''):
    claims.append(dict(zip(fields,[cid,text,value,ci,pq,method,package,src(file) if file else '',key,position,limit])))
claim('V1_GO','v1.0终局GO','GO',method='冻结门判定',package='v1.0',file=V1/'status.json',key='verdict;execution_state',position='正文',limit='历史终局；W0不重开GO/STOP')
for r in bgate:
    y=r['outcome'];key=f'line={line_for(bgate,r)};outcome={y}'
    claim(f'B_{y}',f'{y}前趋势门',r['endpoint_pass'],pq='Wald p='+r['wald_p'],method='Taylor Wald',package='v1.0',file=V1/'B_pretrend/gate_results.csv',key=key,position='正文',limit='Y2通过；Y1未通过；非证明假设成立')
for r in main:
    y,ref=r['outcome'],r['reference'];primary=y in ['Y1','Y2']
    pq='p='+r['p'] if primary else 'q='+r['q_BH']
    claim(f'DID_{y}_{ref}',f'{y}的DiD；{ref}',r['DiD'],rng(r['ci_low'],r['ci_high']),pq,'Taylor t' if primary else 'Taylor + BH-FDR','v1.0',V1/'C_main/DiD_all_outcomes.csv',f'line={line_for(main,r)};outcome={y};reference={ref}','正文' if y=='Y2' else '附表','Y2：顺序效应稳定；模式包' if y=='Y2' else 'Y1未通过B' if y=='Y1' else '营养素未检验B；按两参照FDR分档')
for r in impact:
    if r['outcome'] not in ['Y1','Y2']:continue
    claim(f'SHARE_{r["outcome"]}_{r["reference"]}',f'{r["outcome"]}模式效应占观察变化比例',r['mode_share_percent']+'%',method='加权点估计比值',package='v1.0',file=V1/'C_main/C3ab_impact.csv',key=f'line={line_for(impact,r)};mode_share_percent',position='正文' if r['outcome']=='Y2' else '附表',limit='不截断>100%；顺序效应稳定假设下可完全解释观察下降；不推断真实摄入上升')
for r in unc:
    ident='_'.join([r['endpoint'],r['scale'],r['scenario'],r['statistic']])
    claim('S2_'+ident,f'{r["endpoint"]} {r["scenario"]} {r["statistic"]}',r['estimate'],rng(r['ci_low'],r['ci_high']),method='bootstrap' if r['CI_status']=='COMPLETE' else 'bootstrap NO_VALID_RESULT',package='S2',file=S2/'S2_1_summary_CI.csv',key=f'line={line_for(unc,r)};scale={r["scale"]}',position='附表' if r['publication_placement']=='SUPPLEMENT_REFERENCE_DEPENDENT' else '正文',limit=r['reason'] or ('钙无B检验；均值参照；EAR；食物饮料来源' if r['endpoint']=='calcium' else 'Y2；个体校正后加权；模式包；顺序效应稳定'))
ca=next(r for r in unc if r['endpoint']=='calcium' and r['scenario']=='control_mean' and r['statistic']=='corrected_minus_original')
claim('S2_CA_THRESHOLD','钙下降量CI跨2个百分点',ca['reduction_CI_includes_plus_2_pp'],rng(ca['reduction_ci_low_pp'],ca['reduction_ci_high_pp']),method='bootstrap',package='S2',file=S2/'S2_1_summary_CI.csv',key=f'line={line_for(unc,ca)};reduction_CI_includes_plus_2_pp',position='正文',limit='下降量正值方向；不是新GO门；不支持95%CI下限>=2pp')
for r in corrected:
    if r['outcome']!='Y1':continue
    claim('S1_Y1_CORR_'+r['reference'],'Y1第一天校正后均值',r['corrected_L_day1_mean'],method='点估计；CI NOT_RUN',package='S1',file=S1/'S1a_C3a_corrected.csv',key=f'line={line_for(corrected,r)}',limit='Y1未通过B；支持性；加DiD；未传播Y1校正不确定性')
for r in day2:
    claim('S1_'+r['outcome']+'_'+r['contrast'],r['outcome']+' '+r['contrast'],r['change'],rng(r['ci_low'],r['ci_high']),method='Taylor',package='S1',file=S1/'S1c_day2_direct.csv',key=f'line={line_for(day2,r)}',limit='未调整；描述性；不能与G-J含协变量DiD互换')
for r in descs:
    claim('W0_SIGN_'+r['cycle']+'_'+r['outcome'],r['cycle']+' '+r['outcome']+'带符号D均值',r['signed_D_mean'],method='Taylor SE='+r['signed_D_se'],file=OUT/'checks/paired_differences.csv',key=f'line={line_for(descs,r)};signed_D_mean',limit='D=Day2-Day1；冻结成人样本；描述性')
claim('IRON_STATUS','铁不足患病率无有效解释','NO_VALID_RESULT',method='方法适用性判定',package='S1',file=S1/'REPORT_S1.md',key='S1-b：常规摄入与EAR',limit='不换概率法、不换人群；不视为阴性')
claim('RAKING_STATUS','四边际raking已执行；四维联合未执行','四边际=EXECUTED;四维联合=NOT_RUN',package='v1.0',file=V1/'status.json',key='sensitivities.raking_four_margins;sensitivities.raking_full_fourway_joint',limit='结构零；不折叠类别')
for r in counts:
    claim('N_'+r['cycle'],r['cycle']+'成人及固定协变量完整人数',r['n_adults']+'/'+r['n_complete_covariates'],method='人数',package='v1.0',file=V1/'status.json',key='n_adults_by_cycle.'+r['cycle']+';n_complete_covariates_adults_by_cycle.'+r['cycle'],position='正文',limit='前者符合人群定义；后者进入含协变量模型；未插补')
for r in gate:
    claim('SIZE_'+r['outcome'],r['outcome']+'对照周期D均值SD及原2SD门槛',r['control_cycle_SD']+'/'+r['size_threshold'],method='四周期均值的样本SD；原冻结门',package='v1.0',file=V1/'C_main/C1_gate_results.csv',key=f'line={line_for(gate,r)};control_cycle_SD;size_threshold',position='正文' if r['outcome']=='Y2' else '附表',limit='SD分母3；不是个体D标准差；原门不重判')
sens=read(V1/'C_main/sensitivity_results.csv')
for r in sens:
    if r['outcome']=='Y2' and 'rak' in r['analysis']:
        claim('RAKE_Y2_'+r['reference'],'Y2四边际raking DiD；'+r['reference'],r['DiD'],rng(r['ci_low'],r['ci_high']),'p='+r['p'],'Taylor','v1.0',V1/'C_main/sensitivity_results.csv',f'line={line_for(sens,r)}','附表','四个独立边际；完整四维联合raking未执行；不替代主分析')
write(OUT/'claims_ledger.csv',claims,fields)
assert all(not ('bootstrap' in r['推断方法'] and r['p 或 q']!='NA') for r in claims)
assert all(r['来源包']=='v1.0' for r in claims if r['p 或 q']!='NA')

# Explicit implementation judgments with file/line evidence.
audit=[
dict(item='a',status='PASS' if num['a_all_w_match'] and num['a_strata_cycle_unique'] and num['a_psu_cycle_unique'] else 'FAIL',result='B=WTDR2D/4；C全G-H-I-J-L=WTDR2D/5；74层/151PSU；周期复合编码',evidence='outputs/DR-MODE-01/B_pretrend/stage_b.R:13-16;outputs/DR-MODE-01/C_main/stage_c12.R:26-30;outputs/DR-MODE-01/A_access/codebooks/weighting_tutorial.txt:424;outputs/DR-MODE-01/A_access/codebooks/overview_L.txt:338',numeric_evidence='checks/weight_design.csv;checks/numeric_audit.json',qualification='除数正确；跨疫情周期比较不等同连续2011-2023总体平均；官方合并谨慎条款保留'),
dict(item='b',status='PASS' if num['b_counts_pass'] else 'FAIL',result='成人4309/4479/4204/4139/4285；完整病例4296/4443/4105/3990/4041',evidence='outputs/DR-MODE-01/A_access/scripts/stage_a.R:33-46;outputs/DR-MODE-01/C_main/stage_c12.R:30;outputs/DR-MODE-01/status.json:n_adults_by_cycle,n_complete_covariates_adults_by_cycle',numeric_evidence='checks/person_counts.csv;checks/fresh_XPT_vs_S1.csv;figdata/tab1_flow.csv',qualification='所有N为人；eligible与完整病例分别报告'),
dict(item='c',status='PASS' if num['c_difference_direction_pass'] and model['S1_correction_pass'] and model['DiD_all_24_refits_pass'] else 'FAIL',result=f'D=Day2-Day1；模式效应=-DiD；S1校正=+DiD；24个DiD复算最大误差{model["DiD_max_difference"]:.3g}',evidence='outputs/DR-MODE-01/C_main/stage_c12.R:21,35-40;outputs/S1_writing/scripts/S1_acd.R:11-20;outputs/S1_writing/scripts/S1b_nci.R:28-31',numeric_evidence='checks/DiD_refit_audit.csv;checks/S1_correction_algebra.csv',qualification='v1.0原符号错误保留；S1已授权修正；W0无新更正'),
dict(item='d',status='PASS' if num['d_fresh_fields_pass'] else 'FAIL',result='abs(DR1DBIH-DR2DBIH)；缺失13/36/99/149/244；其他协变量缺失0/0/0/0/0',evidence='outputs/DR-MODE-01/A_access/scripts/stage_a.R:36,45;outputs/DR-MODE-01/C_main/stage_c12.R:30',numeric_evidence='checks/person_counts.csv;checks/fresh_XPT_vs_S1.csv',qualification='不插补；完整病例排除；无额外间隔截断'),
dict(item='e',status='PASS' if model['NCI_input_all_pass'] else 'FAIL',result='Day2=I(DAY=2)；分布Day2=0；周末六/日；5/7与2/7；组合25/10/10/4；钙EAR800/1000',evidence='outputs/DR-MODE-01/config/execution_spec.json:49-51;outputs/S1_writing/S1b_C3c_usual_intake/IMPLEMENTATION.md:4-10;outputs/S1_writing/scripts/S1b_nci.R:20-37,78-88;outputs/S2_uncertainty/scripts/nci_streaming.R:22-25',numeric_evidence='checks/NCI_preprocessor_audit.csv;checks/model_audit.json;provenance/weekend_scope_confirmation.md',qualification='按用户确认以冻结方法判定；W0原括注4/7、3/7定义不同；未改编码'),
dict(item='f',status='PASS' if num['f_rao_wu_pass'] else 'FAIL',result='Rao-Wu：层内抽n_h-1个PSU；乘n_h/(n_h-1)；200组；seed2026102902；矩阵完全相同',evidence='outputs/S2_uncertainty/scripts/prepare_replicates.R:4-6;DR-MODE-01/W0_audit/provenance/survey_subbootstratum_source.txt:3-7',numeric_evidence='checks/bootstrap_strata.csv;checks/numeric_audit.json',qualification='非简单n_h次有放回；不触发S2c重跑'),
dict(item='g',status='PASS' if num['g_failure_CI_handling_pass'] else 'FAIL',result='原始失败0/200；均值参照0/200；外推30/200=15%；钙2、铁28；170组未用于CI',evidence='outputs/S2_uncertainty/scripts/run_nci_replicates.R:70-77;outputs/S2_uncertainty/scripts/summarize_S2.R:58-71',numeric_evidence='checks/failed_replicates_summary.csv;checks/failed_replicates_detail.csv;outputs/S2_uncertainty/S2_1_summary_CI.csv',qualification='外推钙CI=NO_VALID_RESULT；不是阴性；模型内铁未作为新增结局')]
write(OUT/'checks/implementation_audit.csv',audit)
wp_exact=[r for r in wp if r['population']=='whitepaper_nonfasting']
mr_exact=[r for r in martin if r['reproduction_definition']=='paper_nonfasting']
signs=all(float(r['signed_D_mean'])<0 for r in descs if r['cycle']!='L') and all(float(r['signed_D_mean'])>0 for r in descs if r['cycle']=='L')
reconciled=signs and all(boolstr(r['rounding_match']) for r in wp_exact) and all(boolstr(r['mean_rounding_match']) and boolstr(r['SE_rounding_match']) and r['n_persons']==r['target_N'] for r in mr_exact)
reconcile='RECONCILED' if reconciled else 'NOT_RECONCILED'
writing='OPEN' if reconciled and all(r['status']=='PASS' for r in audit) else 'HOLD'
recrows=[dict(item='W0.2a_direction',status='PASS' if signs else 'FAIL',detail='G-J：D<0；L：D>0；Y1及原尺度能量均成立'),dict(item='W0.2b_figure9',status='PASS' if all(boolstr(r['rounding_match']) for r in wp_exact) else 'FAIL',detail='白皮书非禁食定义：15/15显示精度吻合；冻结主样本另列；I女性小负值显示0.0'),dict(item='W0.2c_as_written',status='FAIL',detail='男性2601 vs2599；均值误差-1.6224/-1.8012 kcal；女性匹配；2名男性任一天0 kcal'),dict(item='W0.2c_paper_exact',status='PASS' if all(boolstr(r['mean_rounding_match']) and boolstr(r['SE_rounding_match']) for r in mr_exact) else 'FAIL',detail='按论文明确非禁食条件：N2599/2624；均值4/4、SE4/4整数吻合；主分析人群未改'),dict(item='W0.2d',status=reconcile,detail='方向反转确认；E|D|与|E[D]|及signed E[D]分开；官方图9是signed Day1-Day2；两名禁食男性解释论文对账差异')]
write(OUT/'checks/reconciliation.csv',recrows)

snap=json.loads((OUT/'provenance/input_snapshot.json').read_text());changed=[]
for path,h in snap['files'].items():
    f=ROOT/path
    if not f.exists() or hashlib.sha256(f.read_bytes()).hexdigest()!=h:changed.append(path)
new=[]
for root in [V1,S1,S2]:
    new.extend(str(f.relative_to(ROOT)) for f in root.rglob('*') if f.is_file() and str(f.relative_to(ROOT)) not in snap['files'])
assert not changed and not new
integrity=dict(protected_files=len(snap['files']),changed=changed,new_in_protected_trees=new,checked_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
(OUT/'provenance/final_integrity_QA.json').write_text(json.dumps(integrity,indent=2)+'\n')
status=dict(audit={r['item']:r['status'] for r in audit},bootstrap_rao_wu=num['f_rao_wu_pass'],S2c_run=False,reconcile=reconcile,writing_gate=writing,v1_GO='UNCHANGED',weekend_scope='USER_CONFIRMED_FROZEN_SAT_SUN_5_7_2_7',reconciliation_as_written_Martin='MALE_MISMATCH_EXPLAINED_BY_TWO_FASTING_PERSONS',reconciliation_paper_nonfasting='PASS',corrected_primary_numbers=0,correction_records=[],calcium_day1_mean_CI='NOT_RUN_IN_S2',calcium_extrapolation_prevalence_CI='NO_VALID_RESULT_CARRIED',iron='NO_VALID_RESULT_CARRIED',claims_rows=len(claims),figdata_files=6,protected_files_verified=len(snap['files']))
(OUT/'status_W0.json').write_text(json.dumps(status,ensure_ascii=False,indent=2)+'\n')
(OUT/'corrections/correction_register.csv').write_text('record_id,status,reason,changes_to_numbers\nS2c,NOT_RUN_NOT_TRIGGERED,S2 Rao-Wu 200 replicate matrix verified identical,0\n')

lines=['# DR-MODE-01 / W0 写作前终审','',f'| 判定 | 值 |','|---|---|',f'| writing_gate | **{writing}** |',f'| 对账 | **{reconcile}** |','| v1.0 GO | 不变 |',f'| 受保护文件 | {len(snap["files"])}；改动0；新增0 |','| S2c | 未触发；未运行 |','| 新增结局/周期/主分析人群/协变量 | 0/0/0/0 |','', '## W0.1 实现终审','', '| 项目 | 判定 | 核对数字 | 证据行号 |','|---|---|---|---|']
for r in audit:
    refs=[]
    for e in r['evidence'].split(';'):
        path,loc=e.split(':',1);line=loc.split('-')[0].split(',')[0]
        refs.append(citation(ROOT/path,line) if line.isdigit() else f'`{path}` key `{loc}`')
    lines.append(f'| {r["item"]} | {r["status"]} | {r["result"]} | '+ '<br>'.join(refs)+' |')
lines+=['','| 限定/定义差异 | 数字或判定 |','|---|---|','| 周末冻结定义 | 周六/日；工作日5/7，周末2/7 |','| W0原括注定义 | 周五至日；工作日4/7，周末3/7；与冻结定义不同 |','| e项判定口径 | 用户确认按冻结方法；PASS；不改编码 |','| 四组合积分 | 25/49、10/49、10/49、4/49 |','| 回顾顺序 | 拟合Day2指示；分布Day2=0；第一天报告尺度 |','| 钙EAR | 男20–70/女20–50：800 mg；男>70/女>50：1000 mg |','| 铁不足率解释 | NO_VALID_RESULT；沿用S1 |','| 跨周期权重 | 每个二年周期同除5；非连续2011–2023总体平均；官方合并谨慎条款保留 |','| 成人间隔缺失 G/H/I/J/L | 13/36/99/149/244；不插补 |','| 审计脚本浮点比较修复 | CSV序列化误差≤5.21e−17；比较容差1e−12；原分析改动0 |','', '## W0.2 官方数字对账','', '### a. 成人两天差值','', '| 周期 | 指标 | N | D均值（SE） | 逐人绝对差均值（SE） | 相对差%（SE） |','|---|---|---:|---:|---:|---:|']
for r in descs:lines.append(f'| {r["cycle"]} | {r["outcome"]} | {r["n_persons"]} | {fmt(r["signed_D_mean"])}（{fmt(r["signed_D_se"])}） | {fmt(r["mean_absolute_individual_D"])}（{fmt(r["mean_absolute_individual_D_se"])}） | {fmt(r["relative_D_percent"])}（{fmt(r["relative_D_percent_se"])}） |')
lines+=['','D=Day2−Day1；相对差=E[D]/E[Day1]；SE=Taylor。','', '### b. 白皮书图9：Day1−Day2，按白皮书非禁食条件','', '| 周期 | 男：复现 / 图示 | 女：复现 / 图示 | 总体：复现 / 图示 | 判定 |','|---|---:|---:|---:|---|']
for cy in ['G','H','I','J','L']:
    rows=[next(x for x in wp_exact if x['cycle']==cy and x['sex']==sx) for sx in ['Male','Female','Overall']]
    lines.append('| '+cy+' | '+' | '.join(fmt(x['day1_minus_day2'])+' / '+x['published_figure9'] for x in rows)+' | '+('PASS' if all(boolstr(x['rounding_match']) for x in rows) else 'FAIL')+' |')
lines+=['','| 核对项 | 判定 |','|---|---|','| 图示精度一致 | 15/15 |','| L 男/女/总体 | 负/负/负 |','| G–J 总体 | 正/正/正/正 |','| I 女性 | −0.04198；图示0.0；小负值，非“所有对照性别均正” |','| 冻结主样本与白皮书样本 | 分列；白皮书另排任一天0 kcal；主样本未改 |','', '### c. Nutrients 13:2621 对账','', '| 定义 | 性别/天 | N / 目标N | 均值 / 目标 | SE / 目标 | 均值误差 kcal | 判定 |','|---|---|---:|---:|---:|---:|---|']
for r in martin:
    ok=boolstr(r['mean_rounding_match']) and boolstr(r['SE_rounding_match']) and r['n_persons']==r['target_N']
    lines.append(f'| {r["reproduction_definition"]} | {r["sex"]}/{r["day"]} | {r["n_persons"]}/{r["target_N"]} | {fmt(r["estimate"])} / {r["target_mean"]} | {fmt(r["se"])} / {r["target_se"]} | {fmt(r["error_kcal"])} | {"PASS" if ok else "FAIL"} |')
lines+=['','| 差异定位 | 结果 |','|---|---|','| W0所列条件 vs 论文完整条件 | 男性多2人；任一天0 kcal |','| 论文非禁食条件 | 正文Methods明确；主分析不变 |','| 论文完整条件复现 | 男2599；女2624；均值4/4、SE4/4整数一致 |','| 论文作者标识 | Steinfeldt等；Martin为通讯作者；DOI 10.3390/nu13082621 |','', '### d. 对账判定','', '| 项目 | 数字/判定 |','|---|---|',f'| 总判定 | **{reconcile}** |','| 冻结成人总体Y1与能量D方向 | G–J均<0；L均>0 |','| Y1 E|D| | 4.0816–4.7503 条 |','| Y1 |E[D]| | 0.0283–0.7165 条 |','| 能量 E|D| | 694.7022–716.5789 kcal |','| 官方图9 | 带符号Day1−Day2；不是逐人E|D| |','| “绝对差异相似”与方向反转 | 统计量区分后相容；未运行相似性/等效性检验 |','', '## W0.3–4 台账与出图数据','', '| 文件 | 行数 | 状态 |','|---|---:|---|',f'| claims_ledger.csv | {len(claims)} | PASS；无Taylor p与bootstrap CI同一行 |']
for name in ['fig1_pretrend.csv','fig2_correction.csv','tab1_flow.csv','tab2_main.csv','supp_panel.csv','supp_day2.csv']:
    lines.append(f'| figdata/{name} | {len(read(OUT/"figdata"/name))} | COMPLETE |')
lines+=['','| 未运行/无有效结果 | 状态 | 原因 |','|---|---|---|','| S2c重新bootstrap | NOT_RUN（未触发） | S2已是Rao–Wu；200组矩阵相同 |','| 钙第一天摄入均值CI | NOT_RUN | S2仅给出钙不足比例CI；fig2保留S1点估计与NA |','| 外推钙不足比例CI | NO_VALID_RESULT | 30/200输入域失败；未用170组计算CI |','| 铁不足患病率 | NO_VALID_RESULT | 沿用S1；不换方法/人群 |','| 四维联合raking | NOT_RUN | 沿用结构零记录 |','', '## 更正记录清单','', '| 包/项目 | 数值更正 | 判定 |','|---|---:|---|','| v1.0/S1/S2 | 0 | 保持只读 |','| S2c | 0 | 未触发 |','| W0周末括注 | 0 | 用户确认按冻结5/7、2/7核验 |','| W0论文对账定义 | 0项主分析改动 | 两套定义并列；论文非禁食条件解释2名男性差异 |','| W0审计数值容差 | 0项科学结果改动 | 保留初次审计日志；CSV浮点序列化比较修复 |','', '## 来源','', '- [NHANES权重指南](https://wwwn.cdc.gov/nchs/nhanes/tutorials/weighting.aspx)：合并二年周期除数。','- [L周期分析指南](https://wwwn.cdc.gov/nchs/nhanes/continuousnhanes/overviewbrief.aspx?Cycle=2021-2023)：二年周期及跨疫情合并限制。','- [NCHS白皮书](https://wwwn.cdc.gov/nchs/data/Nhanes/Public/2021/Whitepapers/Aug2023-What-We-Eat-In-America-Dietary-Data-Whitepaper.pdf)：第6–7、18页；图9。','- [Steinfeldt/Martin等2021](https://doi.org/10.3390/nu13082621)：Methods、Table4；全文XML及提取文本存official/。','']
# Escape literal pipes inside metric labels to retain valid Markdown tables.
lines=[l.replace('Y1 E|D|','Y1 E(abs(D))').replace('Y1 |E[D]|','Y1 abs(E[D])').replace('能量 E|D|','能量 E(abs(D))').replace('逐人E|D|','逐人E(abs(D))') for l in lines]
(OUT/'REPORT_W0.md').write_text('\n'.join(lines))
print(json.dumps(status,ensure_ascii=False,indent=2))
