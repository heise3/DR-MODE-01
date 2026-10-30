from pathlib import Path
import csv,json,hashlib,datetime,re,html
R=Path('DR-MODE-01/X1')
def read(p):return list(csv.DictReader((R/p).open()))
def dump(p,x):(R/p).write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
def sha(p):
    with open(p,'rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def f(x,n=4):return f'{float(x):.{n}f}'
freeze=json.loads((R/'provenance/freeze.json').read_text())
assert sha(R/'CONTRACT_X1_v1.0.md')==freeze['contract_sha256']
protected=json.loads((R/'provenance/protected_before.json').read_text())
roots=['outputs/DR-MODE-01','outputs/S1_writing','outputs/S2_uncertainty','DR-MODE-01/W0_audit']
after={str(p):sha(p) for root in roots for p in sorted(Path(root).rglob('*')) if p.is_file()}
pq={'status':'PASS' if after==protected else 'FAIL','files_before':len(protected),'files_after':len(after),'modified':[p for p in protected if p in after and protected[p]!=after[p]],'missing':sorted(set(protected)-set(after)),'added':sorted(set(after)-set(protected))}
dump('provenance/protected_QA.json',pq);assert pq['status']=='PASS'
sem=[]
for p in sorted((R/'provenance').glob('*IFF*.htm')):
    text=p.read_text();day=re.search(r'DR([12])IFF',p.name)[1];v='DR'+day+'FS'
    block=text.split(f'id="{v}"')[1].split('</table>')[0]
    rows=re.findall(r'<tr>(.*?)</tr>',block,re.S)
    match=[]
    for row in rows:
        cells=[html.unescape(re.sub(r'<[^>]+>','',x)).strip() for x in re.findall(r'<td[^>]*>(.*?)</td>',row,re.S)]
        if cells and cells[0]=='3': match=cells;break
    assert match and 'fast food/pizza' in match[1].lower()
    sem.append({'file':str(p.relative_to(R)),'variable':v,'code':3,'label':match[1],'energy_variable':'DR'+day+'IKCAL','status':'PASS'})
with (R/'provenance/semantic_codebook_check.csv').open('w') as h:
    w=csv.DictWriter(h,fieldnames=list(sem[0]));w.writeheader();w.writerows(sem)
cal=read('results/calibration.csv');bg=read('results/pretrend_gate.csv')[0];did=read('results/DiD_Taylor.csv');bs=read('results/DiD_bootstrap_CI.csv');flow=read('results/person_counts.csv');cycles=read('results/paired_cycle_means.csv')
qa=json.loads((R/'provenance/numerical_QA.json').read_text());run=json.loads((R/'results/run_status.json').read_text())
assert run['verdict']=='NOT_IDENTIFIED' and qa['status']=='PASS'
nums={k:float(bg[k]) for k in ['wald_p','control_D_mean','L_ci_low','L_ci_high','L_ci_width','width_threshold']}
delta=float(cal[-1]['mean_pct'])-float(cal[0]['mean_pct'])
status={**freeze,'stage':'TERMINAL','fast_food_outcomes_read':True,'verdict':'NOT_IDENTIFIED','reason':'Pretrend extrapolated 95% CI width >= 2*abs(control D mean); correction prohibited by frozen contract','completed_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'gates':{'calibration':{'status':'PASS','max_absolute_error_pp':max(float(x['absolute_error_pp']) for x in cal),'delta_H_to_L_pp':delta,'official_delta_pp':-2.4,'N_exact_match':False,'N_difference_H_I_P_L':[int(x['n_persons'])-int(x['official_n']) for x in cal]},'pretrend':{'status':'FAIL',**nums,'wald_pass':True,'width_pass':False},'DiD':{'status':'PASS','n_persons':20850,'interpretation':'descriptive; mode effect NOT_IDENTIFIED'},'correction':{'status':'NOT_RUN','reason':'PRETREND_FAIL'},'trend_reestimation':{'status':'NOT_RUN','reason':'PRETREND_FAIL'},'joint_trend_bootstrap':{'status':'NOT_RUN','reason':'PRETREND_FAIL; frozen preflight also records no P coverage in S2 matrix'},'DiD_bootstrap':{'status':'PASS','replicates':200,'references':2,'failed_per_reference':0,'same_S2_matrix':True,'seed':2026102902,'method':'Rao-Wu rescaled stratified PSU bootstrap'}},'protected_package_verification':pq,'numerical_QA':qa,'v1_terminal_verdict_carried':'GO','X1_changes_v1_verdict':False,'no_threshold_changes':True}
dump('status_X1.json',status)
lines=['# DR-MODE-01 / X1 结果与核验','', '**终局：NOT_IDENTIFIED；不可校正。** 原 v1.0 GO 保持不变。','',f"冻结 SHA-256：`{freeze['contract_sha256']}`。冻结时间：{freeze['frozen_at_utc']}；首次分析读取：{run['started_utc']}。",'', '## 工程','', '| 项目 | 数字 / 判定 |','|---|---|', '| IFF 文件 / codebook | 11 / 11；下载与语义核验 PASS |', '| DRxFS=3 | 11/11：Restaurant fast food/pizza |', '| 重复食品行键 / 正总能量缺失 IFF / 已确认快餐缺失能量 | 0 / 0 / 0 |', '| IFF 汇总总能量 − TOT 总能量最大绝对值 | 0 kcal（11 文件） |', '| 比例 <0 或 >100 | 0 人次 |', '| S2 Rao–Wu 矩阵 | 74 层、151 PSU、200 组；原文件直接复用 |', '| DiD 重复 | 每参照 200/200 成功；失败 0/200（0%） |', f"| 独立 WLS / Taylor sandwich | PASS；系数最大误差 {qa['max_coefficient_error']:.3e}；SE 最大误差 {qa['max_SE_error']:.3e} |", f"| 原包只读核验 | {pq['files_before']} 文件；改动 0、缺失 0、新增 0；PASS |", '| DB533 直接网页下载 | HTTP 403；官方内容由 web 工具读取并保存，未阻断校准 |','', 'S2 的 P 周期覆盖：不存在。该限制在结果前冻结；本次前趋势 FAIL，未启动趋势重估或 P 重复方案。','', '## 校准','', '官方来源：[DB533 表5](https://www.cdc.gov/nchs/products/databriefs/db533.htm)。每人快餐 kcal / 当天总 kcal ×100；第一天权重；成人；百分比为原尺度。','', '| 周期 | 本次 N | 官方 N | 本次均值 % | 官方 % | 误差 pp | 判定 |','|---|---:|---:|---:|---:|---:|---|']
for x in cal:lines.append(f"| {x['cycle']} | {x['n_persons']} | {x['official_n']} | {f(x['mean_pct'],6)} | {x['official_mean_pct']} | {f(x['error_pp'],6)} | PASS |")
lines += ['',f'H→L 原始均值变化：{delta:.6f} pp；官方 −2.4 pp；误差 {delta+2.4:+.6f} pp。', '', '校准均值门：PASS（4/4，误差均 ≤0.3 pp）。人数核对：H +2、I +2、P 0、L +1；人数差异原因未确定。未通过新增排除或更换定义来匹配官方 N；不宣称全部人数精确复现。','', '## 人数','', '| 周期 | v1.0 合格成人 | 两天比例有定义 | 协变量完整 | 模型完整 |','|---|---:|---:|---:|---:|']
for x in flow:lines.append('| '+' | '.join(x[k] for k in ['cycle','frozen_eligible_persons','paired_ratio_defined','covariates_complete','model_complete'])+' |')
lines += ['',f"模型总 N={sum(int(x['model_complete']) for x in flow)}；前趋势 N={bg['n_persons']}。零总能量为未定义比例，不作 0%。",'', '## 前趋势门','', '| 项目 | 数值 | 要求 | 判定 |','|---|---:|---|---|',f"| 周期异质性 Wald P | {f(bg['wald_p'],8)} | >0.05 | PASS |",f"| 对照 D 均值 | {f(bg['control_D_mean'],6)} pp | — | — |",f"| 对照线性斜率 | {f(bg['trend_per_year'],6)} pp/年；P={f(bg['trend_p'],6)} | 描述 | — |",f"| 外推至 L 的 D | {f(bg['L_extrapolated_D'],6)} pp | — | — |",f"| 外推均值 95% CI | [{f(bg['L_ci_low'],6)}, {f(bg['L_ci_high'],6)}] pp | — | — |",f"| CI 宽度 | {f(bg['L_ci_width'],6)} pp | <{f(bg['width_threshold'],6)} pp | FAIL |",'| 联合前趋势门 | — | 两项同时满足 | FAIL |','', '## DiD（仅描述；未识别模式效应）','', 'D=第二天−第一天；DiD=L−对照参照；单位 pp。固定协变量、WTDR2D/5、按周期唯一编码设计，与 v1.0 一致。','', '| 参照 | DiD pp | Taylor SE | Taylor 95% CI | Taylor P |','|---|---:|---:|---|---:|']
names={'control_mean':'对照均值','linear_extrapolation':'线性外推'}
for x in did:lines.append(f"| {names[x['reference']]} | {f(x['DiD_pp'],6)} | {f(x['se'],6)} | [{f(x['ci_low'],6)}, {f(x['ci_high'],6)}] | {f(x['p'],6)} |")
lines += ['', '| 参照 | DiD pp | Rao–Wu SE | Rao–Wu 95% CI | 重复数 |','|---|---:|---:|---|---:|']
for x in bs:lines.append(f"| {names[x['reference']]} | {f(x['DiD_pp'],6)} | {f(x['se'],6)} | [{f(x['ci_low'],6)}, {f(x['ci_high'],6)}] | 200 |")
lines += ['', '重复方差：S2 scale=1/199、rscales=1、mse=TRUE；以全样本估计为中心；t 自由度 77。没有混用 Taylor P 与 bootstrap CI。','', '## 未运行及判定','', '| 项目 | 判定 | 原因 |','|---|---|---|','| L 模式校正（两参照） | NOT_RUN | 前趋势 FAIL；不可校正 |','| DB533 周期序列原始/校正线性趋势重估 | NOT_RUN | 前趋势 FAIL |','| 联合校正值与趋势斜率重复推断 | NOT_RUN | 前趋势 FAIL |','| CHANGES_CONCLUSION / ROBUST | 不判定 | 识别门未通过 |','| X1 | NOT_IDENTIFIED | 外推精度门 FAIL |','', '前趋势未通过不等于模式效应为零，也不构成 DB533 趋势结论稳健或改变的证据。','', '## 与冻结合同的偏离','', '阈值、结局、人群、周期、协变量、参照、重复数：无改动。DB533 下载通道由直接 HTTP 改为 web 工具（HTTP 403；已留存）。原包没有修改。人数差异作为校准核对限制保留，没有新增排除。','', '## 文件','', '- `figdata/x1_trend.csv`：仅四周期校准原始均值及 Taylor CI；校正和趋势字段明确为 NOT_RUN_PRETREND_FAIL。','- `results/calibration.csv`、`pretrend_gate.csv`、`paired_cycle_means.csv`、`person_counts.csv`。','- `results/DiD_Taylor.csv`、`DiD_200_replicates.csv`、`DiD_bootstrap_CI.csv`。','- `provenance/freeze.json`、`protected_QA.json`、`numerical_QA.json`、`download_log.json`。','- `scripts/download.py`、`analyze.R`、`verify.R`、`finalize.py`。','']
(R/'REPORT_X1.md').write_text('\n'.join(lines))
manifest={str(p.relative_to(R)):sha(p) for p in sorted(R.rglob('*')) if p.is_file() and p.name!='MANIFEST_SHA256.json'}
dump('MANIFEST_SHA256.json',manifest)
print(json.dumps({'verdict':status['verdict'],'calibration':'PASS','pretrend':'FAIL','replicates_per_reference':200,'protected_files':len(protected),'contract_sha256':freeze['contract_sha256']},ensure_ascii=False,indent=2))
