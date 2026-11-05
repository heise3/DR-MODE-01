from pathlib import Path
import ast,csv,datetime,difflib,hashlib,json,subprocess,sys
from setup import snapshot,digest

OUT=Path(__file__).resolve().parents[1]
PROJECT=OUT.parents[1]
OLD=OUT/'provenance/pre_freeze_drafts/20261104_before_author_amendment'
def stamp():return datetime.datetime.now(datetime.timezone.utc).isoformat()
def line(path,fragment):
    lines=(OUT/path).read_text().splitlines()
    return next(i for i,s in enumerate(lines,1) if fragment in s)
def evidence(path,fragment):return f'{path}:{line(path,fragment)}'
def load_csv(path):
    with (OUT/path).open()as f:return list(csv.DictReader(f))

assert not(OUT/'.git').exists() and not(OUT/'freeze_record.json').exists()
assert not(OUT/'G1_repro.json').exists() and not(OUT/'verdict.json').exists()
assert json.loads((OUT/'provenance/freeze_control.json').read_text())['status']=='HOLD'
for p in (OUT/'scripts').glob('*.py'):ast.parse(p.read_text())
# Parse R syntax; parsing evaluates no R expressions.
for p in (OUT/'scripts').glob('*.R'):
    result=subprocess.run(['Rscript','-e',f'invisible(parse(file={json.dumps(str(p))}))'],capture_output=True,text=True)
    assert result.returncode==0,(p.name,result.stderr)
synthetic=json.loads((OUT/'provenance/composition_synthetic_QA.json').read_text())
assert synthetic['status']=='PASS' and synthetic['NHANES_loaded'] is False
migration=load_csv('metadata/cross_cycle_migration_summary.csv')
assert all(r['match_author_counts']=='True' for r in migration)
oldmap=digest(OUT/'wweia_group_map.csv')
before=json.loads((OUT/'provenance/s2_protected_before.json').read_text())
after=snapshot()
b={r['path']:r['sha256']for r in before['files']};a={r['path']:r['sha256']for r in after['files']}
differences=[{'path':p,'before':b.get(p),'after':a.get(p)}for p in sorted(set(a)|set(b))if b.get(p)!=a.get(p)]
(OUT/'provenance/s2_protected_after.json').write_text(json.dumps(after,indent=2))
readonly={'status':'PASS'if not differences else'FAIL','phase':'author pre-freeze amendment completed; still HOLD','protected_before':len(b),'protected_after':len(a),'differences':differences}
(OUT/'provenance/protected_QA.json').write_text(json.dumps(readonly,indent=2));assert not differences

paths=['protocol_S2.md','scripts/analyze.R','scripts/freeze.py','scripts/prepare_protocol.py','scripts/setup.py']
diff=''
for p in paths:
    diff+=''.join(difflib.unified_diff((OLD/p).read_text().splitlines(keepends=True),(OUT/p).read_text().splitlines(keepends=True),fromfile='before/'+p,tofile='after/'+p))
(OUT/'provenance/author_prefreeze_amendment.diff').write_text(diff)
checks=[
 {'id':'PF-01','status':'PASS','change':'Composition second branch tests bootstrap R_g against 1; separate BH families of 3 and 10; trend sign uses R_g-1; H-omit CI branch unchanged',
  'evidence':[evidence('protocol_S2.md','- **YES**：H‑omit'),evidence('scripts/s2_inference_helpers.R','x$R_t[good]'),evidence('scripts/s2_inference_helpers.R','x$R_q_BH[ii]'),evidence('scripts/s2_inference_helpers.R','sign(sig$R_g-1)'),evidence('scripts/analyze.R','composition_result<-composition_from_R')]},
 {'id':'PF-02','status':'PASS','change':'Post-freeze original-adult-domain pre-trend calibration precedes component calls; absolute error below 1e-8 against full-precision sealed targets; shared unit-multiplier model matrix checked before replicate fitting',
  'evidence':[evidence('scripts/analyze.R',"pretrend_targets<-read.csv"),evidence('scripts/analyze.R','max(a$wald_p_absolute_error'),evidence('scripts/analyze.R',"add_endpoint('log1p_energy'"),evidence('scripts/analyze.R','unit_multipliers<-rep(1'),evidence('scripts/analyze.R',"csv(unitqa,'unit_multiplier_calibration.csv')")]},
 {'id':'PF-03','status':'PASS','change':'Freeze manifest and commit include analyze.R, helpers and all current R/Python scripts; execution verifies source hashes; current author HOLD blocks all Git commands',
  'evidence':[evidence('scripts/freeze.py',"control['status']=='AUTHORIZED'"),evidence('scripts/freeze.py','paths+=sorted'),evidence('scripts/freeze.py',"run('git','add',*paths"),evidence('scripts/analyze.R','for(p in names(fr$hashes))')]},
 {'id':'PF-04','status':'PASS','change':'Protocol base v1.5 and target s2/manuscript_v1.6_AJCN; historical v1.2 references retained only in preserved original request/history',
  'evidence':[evidence('protocol_S2.md','底稿：manuscript_v1.5_AJCN'),evidence('protocol_S2.md','新稿只写 s2/manuscript_v1.6_AJCN'),evidence('scripts/freeze.py',"manuscript_base='manuscript_v1.5_AJCN'")]},
]
record={'task':'DR-MODE-01-S2','draft_revision':'AUTHOR_PREFREEZE_AMENDMENT_20261104','recorded_utc':stamp(),
        'status':'HOLD_NOT_FROZEN','G0':'PASS_CARRIED_UNCHANGED','mapping_review':'AUTHOR_CONFIRMED',
        'implementation_checks':checks,'synthetic_summary_tests':synthetic,'migration_metadata_check':'PASS',
        'real_data_pretrend_calibration':'NOT_RUN_PENDING_FREEZE','real_data_unit_multiplier_calibration':'NOT_RUN_PENDING_FREEZE',
        'G1':'NOT_RUN','module_A':'NOT_RUN','module_B':'NOT_RUN','new_manuscript':'NOT_RUN',
        'new_manuscript_base':'manuscript_v1.5_AJCN','new_manuscript_target':'s2/manuscript_v1.6_AJCN',
        'git_commit_created':False,'freeze_record_created':False,'new_outcome_means_or_DiD_computed':False,
        'protected_files':len(b),'protected_differences':0,'original_v1_verdict':'GO_UNCHANGED',
        'retained_author_decision':'First-author CRediT Supervision',
        'source_hashes':{str(p.relative_to(OUT)):digest(p) for p in [OUT/'protocol_S2.md',OUT/'wweia_group_map.csv',*sorted((OUT/'scripts').glob('*.R')),*sorted((OUT/'scripts').glob('*.py'))]}}
(OUT/'provenance/prefreeze_amendment_record.json').write_text(json.dumps(record,ensure_ascii=False,indent=2))
(OUT/'analysis_status.json').write_text(json.dumps({k:record[k]for k in ['task','status','G0','mapping_review','G1','module_A','module_B','new_manuscript','new_manuscript_base','new_manuscript_target','git_commit_created','freeze_record_created','new_outcome_means_or_DiD_computed','protected_files','protected_differences','original_v1_verdict']},ensure_ascii=False,indent=2))
lines=['# S2 冻结前修订核对','',f'记录UTC：{record["recorded_utc"]}。状态：**HOLD_NOT_FROZEN**。最新作者“先别冻结”指令优先；本轮没有Git提交、freeze_record、G1/成分结果或稿件修改。','',
 '原未冻结稿与代码保留于 `provenance/pre_freeze_drafts/20261104_before_author_amendment/`；逐行修改见 `provenance/author_prefreeze_amendment.diff`。原始任务文字不改，当前协议已合入作者修订。','',
 '| 项目 | 实现核对 | 证据 |','|---|---|---|']
for c in checks:lines.append(f'| {c["id"]} {c["change"]} | {c["status"]} | '+', '.join(f'`{s}`'for s in c['evidence'])+' |')
lines+=['','## 已完成的QA','',f'- 合成汇总逻辑：{synthetic["n_checks"]}项PASS，未载入NHANES。均匀R=1、即使所有DiD q=1e−20，也得到NO；R偏离且trend同向得到YES；trend的R−1反向得到NO；H-omit原CI条件、BH两个家族、零SE无有效P等均已核对。',
 '- R语法解析与Python语法解析通过。冻结HOLD保护测试通过，未创建`.git/`或`freeze_record.json`。',
 '- G0既有结果、分类映射及全部旧包保持原样。分类跨版本变更仅用映射元数据核对：','',
 '| 交界 | 换组代码数 | 跨H-omit边界 | 与作者汇报 |','|---|---:|---:|---|']
for r in migration:lines.append(f'| {r["from_cycle"]}→{r["to_cycle"]} | {r["changed_group_codes"]} | {r["crosses_H_omit_codes"]} | PASS |')
lines+=['', '- Methods待改稿时须明写调味/增强水7802/7804归非酒精饮料；保留官方逐周期分类，说明G6/G7/G9结果可能受重分类影响。不声称两天差值保证完全抵消。',
 f'- 旧文件哈希复核：{len(b):,}项，差异0。',
 '- 对失败重复的代码分支也落实原有纪律：记录NO_VALID_RESULT，不填成NO/NO_UPGRADE_SWITCH；这不是新增科学判据。','',
 '## 尚未运行','',
 '| 项目 | 状态 | 原因 |','|---|---|---|',
 '| 真实数据前趋势校准 | NOT_RUN | 依作者最新指令暂不冻结；代码已列为冻结后第一步 |',
 '| 真实数据单位乘数校准 | NOT_RUN | 与G1及后续各结局拟合同时核对，未运行 |',
 '| G1、模块A/B、200组重复 | NOT_RUN | 等待解除冻结暂缓；不得把合成测试当作真实数据校准 |',
 '| v1.6稿件、图4、DOCX/MD、STROBE与P2改稿QA | NOT_RUN | 必须在G0/G1通过且verdict产生后执行 |','',
 '第一作者CRediT中的Supervision仍为AUTHOR_DECISION。v1.0判定GO不变。']
(OUT/'PREFREEZE_REVISION_CHECK.md').write_text('\n'.join(lines)+'\n')
# Keep the former entry point current, preserving its original text in the draft snapshot.
(OUT/'PREFREEZE_CHECK.md').write_text('# 冻结前检查入口\n\n当前状态：HOLD_NOT_FROZEN。分类人工核对已完成，按作者最新指令暂缓冻结。\n\n四项修订、证据、合成测试及只读核对见 [PREFREEZE_REVISION_CHECK.md](PREFREEZE_REVISION_CHECK.md)。\n\n旧版检查原文保留于 provenance/pre_freeze_drafts/20261104_before_author_amendment/PREFREEZE_CHECK.md。\n')
print(json.dumps({'status':record['status'],'implementation_checks':len(checks),'synthetic_tests':synthetic['n_checks'],'protected_files':len(b),'protected_differences':len(differences),'real_data_calibration':'NOT_RUN'},ensure_ascii=False))
