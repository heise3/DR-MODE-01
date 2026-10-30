from pathlib import Path
import csv,json,hashlib,datetime

p=Path('outputs/S2_uncertainty')
def readcsv(f):
    with open(f,newline='') as h:return list(csv.DictReader(h))
summary=readcsv(p/'S2_1_summary_CI.csv');qa=json.loads((p/'provenance/analysis_QA.json').read_text())
numeric_qa=json.loads((p/'provenance/final_numerical_QA.json').read_text());assert numeric_qa['status']=='PASS'
ci={(r['endpoint'],r['scale'],r['scenario'],r['statistic']):r for r in summary}
nci=readcsv(p/'provenance/NCI_all_scenario_status.csv');elig=readcsv(p/'S2_0_calcium_eligibility.csv')
def fmt(v,d=4):return '不可计算' if v in ['NA','',None] else f'{float(v):.{d}f}'
def interval(r,d=4):return 'NO_VALID_RESULT' if r['CI_status']!='COMPLETE' else f'[{fmt(r["ci_low"],d)}, {fmt(r["ci_high"],d)}]'
def yesno(v):return {'TRUE':'是','FALSE':'否','NA':'不可判定'}.get(v,'不可判定')
refs={'original':'原始','control_mean':'对照均值参照','linear_extrapolation':'线性外推参照'}
table=[]
for endpoint,scale,stat,d in [('energy','kcal','mean',2),('energy','log1p_kcal','mean',6),('calcium','percent','prevalence',4)]:
    label={'energy':'第一天能量','calcium':'钙不足比例'}[endpoint]
    table+=['',f'| {label}；单位 {scale} | 点估计 | 95% CI | 有效重复 / 预定重复 |','|---|---:|---|---:|']
    for sc in refs:
        r=ci[(endpoint,scale,sc,stat)];labelref=refs[sc]+('（仅附表，依赖参照）' if endpoint=='calcium' and sc=='linear_extrapolation' else '');table.append(f'| {labelref} | {fmt(r["estimate"],d)} | {interval(r,d)} | {r["valid_replicates"]}/200 |')
    for sc in ['control_mean','linear_extrapolation']:
        diffscale='percentage_points' if endpoint=='calcium' else scale
        r=ci[(endpoint,diffscale,sc,'corrected_minus_original')]
        labelref=refs[sc]+('（仅附表，依赖参照）' if endpoint=='calcium' and sc=='linear_extrapolation' else '')
        table.append(f'| 校正−原始：{labelref} | {fmt(r["estimate"],d)} | {interval(r,d)} | {r["valid_replicates"]}/200 |')
cross=['','| 差值（校正−原始） | CI 跨 0 | CI 跨 −2 个百分点 | 等价下降量 CI 跨 +2 个百分点 |','|---|---|---|---|']
for r in summary:
    if r['statistic']!='corrected_minus_original':continue
    label=f'{r["endpoint"]} / {r["scale"]} / {refs[r["scenario"]]}'
    cross.append(f'| {label} | {yesno(r["CI_includes_zero"])} | {yesno(r["CI_includes_minus_2_pp"]) if r["endpoint"]=="calcium" else "不适用"} | {yesno(r["reduction_CI_includes_plus_2_pp"]) if r["endpoint"]=="calcium" else "不适用"} |')

assert json.loads(Path('outputs/DR-MODE-01/status.json').read_text())['verdict']=='GO'
runtime=json.loads((p/'provenance/runtime_control.json').read_text())
elapsed_hours=(datetime.datetime.now(datetime.timezone.utc).timestamp()-runtime['start_unix'])/3600
snap=json.loads((p/'provenance/input_snapshot.json').read_text());bad=[]
for path,h in snap['files'].items():
    f=Path(path)
    if not f.exists() or hashlib.sha256(f.read_bytes()).hexdigest()!=h:bad.append(path)
new=[]
for root in [Path('outputs/DR-MODE-01'),Path('outputs/S1_writing')]:
    new.extend(str(f) for f in root.rglob('*') if f.is_file() and str(f) not in snap['files'])
assert not bad and not new
seal={'verified_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'protected_files_verified':len(snap['files']),'changed_or_missing':bad,'new_files_in_protected_trees':new,'v1_verdict':'GO_UNCHANGED','S1_unchanged':True}
(p/'provenance/final_integrity_QA.json').write_text(json.dumps(seal,ensure_ascii=False,indent=2)+'\n')
negative=[r for r in nci if int(r['replicate'])>0 and 'NEGATIVE_CORRECTED_AMOUNT' in r['reason']]
negative_ids=sorted({int(r['replicate']) for r in negative})
completed_scenarios=sum(int(r['replicate'])>0 and r['status']=='COMPLETE' for r in nci)
failed_scenarios=sum(int(r['replicate'])>0 and r['status']!='COMPLETE' for r in nci)
negcal=sum(int(r['negative_calcium_persons'])>0 for r in negative)
negiron=sum(int(r['negative_iron_persons'])>0 for r in negative)
rc=ci[('calcium','percentage_points','control_mean','corrected_minus_original')]
methodstatus='PARTIAL_VALID_INFERENCE' if any(r['CI_status']!='COMPLETE' for r in summary) else 'COMPLETE'
status={'task':'DR-MODE-01 S2','status':methodstatus,'version_change':False,'v1_verdict':'GO_UNCHANGED','S1_unchanged':True,'S2_0':'COMPLETE_CONTROL_MEAN_MAIN_TEXT_ONLY','method':'Rao-Wu stratified PSU bootstrap','replicates':200,'energy_CI':'COMPLETE','calcium_original_CI':ci[('calcium','percent','original','prevalence')]['CI_status'],'calcium_control_mean_CI':rc['CI_status'],'calcium_linear_extrapolation_CI':ci[('calcium','percentage_points','linear_extrapolation','corrected_minus_original')]['CI_status'],'iron':'NO_VALID_RESULT_CARRIED','negative_input_replicates':negative_ids,'original_protected_files_verified':len(snap['files']),'gates_reassessed':False,'elapsed_hours_at_report':elapsed_hours,'budget_hours':36,'within_budget':elapsed_hours<=36}
(p/'status_S2.json').write_text(json.dumps(status,ensure_ascii=False,indent=2)+'\n')

report=f'''# DR-MODE-01 S2：不确定性传播与钙资格核对

**v1.0 GO 不变；S1 不变；本次不是 v1.1。状态：{methodstatus}。**

## 工程

- 本次记录至报告生成的总用时 {elapsed_hours:.2f} 小时；预算 36 小时。
- S2-0 在重复估计前完成。200 次联合重复均保留，未减少次数、替换种子或删除失败重复。主表第 0 行为完整样本，随后为 1–200 次 bootstrap。200×3=600 个情形中，{completed_scenarios} 个完整完成，{failed_scenarios} 个没有有效全链估计；后者不计作已完成的 NCI 拟合。
- 原 v1.0 与 S1 共 {len(snap['files'])} 个受保护文件通过 SHA-256 复核，无改动、遗漏或新增写入。
- 独立 Python 核对全部重复的 DiD、输入域失败记录、配对差值方差和 CI 阈值标记；SE 与 R 汇总的最大绝对差异为 {numeric_qa['max_independent_SE_recalculation_difference']:.3g}。
- 合并公开设计有 74 个层、151 个 PSU，设计 df=77；71 层含 2 个 PSU，3 层含 3 个 PSU。32 次 Fay BRR 不足以平衡 74 层，普通成对 BRR 也不适合这些 3-PSU 层。因此使用用户已预先允许的分层 PSU bootstrap，未合并层或更换周期。NCHS 指南说明 BRR 的重复数需随合并层数增加。[NCHS 2018 方法指南](https://www.cdc.gov/nchs/data/series/sr_02/sr02_178.pdf)
- 具体为 Rao–Wu rescaled bootstrap：每层 n_h 个 PSU 中有放回抽 n_h−1 个，乘以 n_h/(n_h−1)。固定种子 2026102902，200 次。整组 PSU 内每个人共用同一乘数。方差沿用 survey::subbootweights 的 scale=1/199、rscales=1，mse=TRUE，以完整样本点估计为中心；95% CI=点估计±相应设计自由度的 t 临界值×SE，不截断。原始 L 单周期均值/比例 df=15；校正值及差值含跨周期 DiD，使用合并 df=77。[survey 方法文档](https://r-survey.r-forge.r-project.org/pkgdown/docs/reference/bootweights.html)
- 每次重复重新估计固定协变量下的两种 DiD，再逐人校正第一天；对输入有效的情形，再重新估计 Box–Cox、最小摄入量、NCI 联合模型和钙 EAR 比例。原始与校正后使用同一重复权重，差值直接由配对重复计算，包含 DiD 与均值/分布之间的协方差。
- 完整样本沿用 S1：4 链×12,000 次迭代，burn-in=2,000，thin=25。重复模型采用4 链×3,000，burn-in=1,000，thin=5；不满足 R̂<1.05 者以 S1 完整链长重跑，短链诊断保留。已完成模型最大 R̂={qa['max_Rhat_completed']:.6f}，最小 ESS={qa['min_ESS_completed']:.2f}；完整链长修复 {qa['full_length_repairs']} 个重复情形。ESS 和模拟抽样数不是研究人数。
- 三个完整样本比例与 S1 的最大差异为 {qa['full_sample_max_S1_prevalence_difference_pp']:.3g} 个百分点。NCI 包版本 1.1.2 未改；只把模拟的逐人周末积分改为等价向量求和并保留汇总，逐模拟验证最大差异 <5×10⁻¹⁴ 个百分点。
- 原始成人两天可靠人数 G/H/I/J/L=4,309/4,479/4,204/4,139/4,285；DiD 固定协变量完整样本 N=20,875，L NCI 完整样本 N=4,041。重复中 PSU 权重为零者不贡献估计，各重复正权重人数见 CSV；没有新增资格排除或插补。

## 结果

### S2-0：钙资格和 S1 校正来源

| 参照 | 钙自身 DiD，log(mg+1) | p | BH-FDR q | 发表位置 |
|---|---:|---:|---:|---|
| 对照均值 | {float(elig[0]['DiD']):.9f} | {float(elig[0]['p']):.9f} | {float(elig[0]['q_BH']):.9f} | 正文可报告 |
| 线性外推 | {float(elig[1]['DiD']):.9f} | {float(elig[1]['p']):.9f} | {float(elig[1]['q_BH']):.9f} | 仅附表，依赖参照 |

S1 两种情形均使用**钙自身、对应参照的 DiD**，没有从能量 DiD 推导。按本次预定规则，正文仅报告对照均值参照；S1 外推参照的 −6.4447 个百分点只作附表的依赖参照结果。钙没有接受 B 前趋势检验；S2 不改变这一识别限制。

### S2-1：完整样本点估计及联合重复 CI

以下“校正−原始”为带符号差值，钙负值表示不足比例下降。钙仍为食物/饮料来源、固定年龄性别 EAR 800/1,000 mg/天，不是临床缺钙患病率。能量 kcal 采用逐人 expm1(log1p(kcal)+DiD) 后加权求均值。
{chr(10).join(table)}

{chr(10).join(cross)}

钙对照均值参照的下降量为 {fmt(rc['reduction_estimate_pp'])} 个百分点，95% CI [{fmt(rc['reduction_ci_low_pp'])}, {fmt(rc['reduction_ci_high_pp'])}]。跨 0：{yesno(rc['CI_includes_zero'])}；下降量区间跨 2 个百分点：{yesno(rc['reduction_CI_includes_plus_2_pp'])}。这些区间判断不构成新的 GO/STOP 门。

### 线性外推的输入域失败

固定的 200 次重复中，{len(negative_ids)} 次外推情形产生负的校正后摄入量：钙涉及 {negcal} 次，联合模型中的铁涉及 {negiron} 次。钙发生于重复 140 和 158，DiD 分别为 −0.00180478 和 −0.00561872；各有 1 名被抽到的原始第一天钙摄入为 0 的参与者，校正后为 −0.00180315 和 −0.00560296 mg。

S1 使用铁/钙联合 NCI 模型，其另一变量铁仍是该固定模型的组成部分；没有新增铁结局、换用概率法或改变铁的 NO_VALID_RESULT 状态。这些负输入不满足相同 NCI 预处理的输入域。未把负值裁为零、删掉回顾记录或改为单变量模型。所有失败重复保留。**外推钙校正值及其差值的全链 CI 为 NO_VALID_RESULT；未用剩余有效重复计算缩减版 CI。** 这不是阴性结果，也不是区间跨 0 或跨 2 个百分点的结论。

## 与 v1.0/S1 的偏离

1. 本次按 S2 授权，用联合分层 PSU bootstrap 传播不确定性，取代 S1 未执行的抽样方差估计；没有重新判定 v1.0 的门。32 次 Fay BRR 改用 200 次 bootstrap 的原因是已核验的合并层/PSU 结构，未更改权重来源、分层标识、周期或人群定义。
2. 重复模型缩短 MCMC 链并强制核验 R̂<1.05，完整样本保留 S1 完整设置；不满足者以完整链长修复。保留的 NCI 模型、校正符号、参照定义、营养素及 EAR 切点均未改变。
3. 铁作为原联合模型的内部输入随同原链路重估，未报告新的铁患病率。铁的 NO_VALID_RESULT 解释保持不变。负摄入输入导致外推钙 CI 无有效结果，不能在冻结规则内通过删除重复或裁剪数值来补成结果。
4. 在 CI 汇总计算前，自由度核验修正了初版执行说明中一律使用 df=77 的简化：原始 L 单周期估计按 30 PSU−15 层使用 df=15，涉及跨周期 DiD 的估计用 df=77；初版说明及核验记录保留。此为计算实现核验，不改任何门、参照或重复抽样。[NHANES 子域自由度指南](https://wwwn.cdc.gov/nchs/nhanes/tutorials/varianceestimation.aspx)
5. 正文仍只以 Y2 为主结论，Y1 仅为支持性证据；钙正文仅采用对照均值参照。模式包不可拆、完成两天意愿与报告质量的交互、顺序效应稳定假设等 v1.0/S1 局限保留。

复现脚本、固定乘数矩阵、每组 DiD/NCI 输入、链诊断及失败原因均在本目录。完整链并不意味着解决模式识别假设或公开数据未观测的无应答机制。

`S2_tables_and_report.zip` 提供表格、报告、脚本和轻量溯源文件；完整链、模型及 RDS 输入保留在本地 S2 目录，由 `MANIFEST_SHA256.csv` 覆盖。压缩包范围和哈希见 `PACKAGE_SHA256.json`。
'''
(p/'REPORT_S2.md').write_text(report)
print(json.dumps(status,ensure_ascii=False,indent=2))
