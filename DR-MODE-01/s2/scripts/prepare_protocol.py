from pathlib import Path
import json,csv,datetime
OUT=Path(__file__).resolve().parents[1]
src=(OUT/'user_request_verbatim.md').read_text()
replacements={
 '底稿：manuscript_v1.1_AJCN（含已完成的措辞修订版）及 v1.0.0 代码仓库':'底稿：manuscript_v1.5_AJCN（已核对的措辞修订版）及 v1.0.0 代码仓库',
 '- **YES**：H‑omit 合并组的 R 的 95% CI 下限 > 1，**或**至少一个场合/食物组在 control-mean 参照下 BH q < 0.05 且 trend 参照下方向一致':
 '- **YES**：H‑omit 合并组的 R 的 95% CI 下限 > 1（保持不变），**或**至少一个场合/食物组在 control-mean 参照下的 R_g 显著偏离 1：用 bootstrap SE(R_g) 计算 t = (R_g − 1)/SE(R_g)，按 t(77) 得到双侧 P 值，在3个场合、10个食物组两个家族内分别作 BH 校正，q < 0.05；且 trend 参照下 (R_g − 1) 的符号相同。两种参照分别计算 R 的检验及 q。kcal DiD 本身的 P/q 不参与这一判定。',
 '连同 WWEIA 映射 CSV 一起 git commit':'连同 WWEIA 映射 CSV、analyze.R 及其依赖的全部分析/辅助脚本一起 git commit',
}
for old,new in replacements.items():
    assert src.count(old)==1,old
    src=src.replace(old,new)
src=src.replace('manuscript_v1.2_AJCN','manuscript_v1.6_AJCN')
src=src.replace('### 5.2 组成判定 `composition_signal`','### 5.2 组成判定 `composition_signal`\n\n冻结前修订：2026-11-04作者指令替换第二条判据；原稿保留在provenance/pre_freeze_drafts。此时尚未冻结，也未计算新增结局。均匀按比例分摊的显著kcal DiD不能单独构成组成信号。')
notes='''

---

## 执行字典：冻结前定案，包含2026-11-04作者修订

### 项目和版本

- 本任务为 DR-MODE-01-S2 食物分解，与既有 outputs/S2_uncertainty 不同。
- 作者已确认：以 manuscript_v1.5_AJCN 的已核对文字及作者资料为底稿；新稿只写 s2/manuscript_v1.6_AJCN，旧版本一律保留。
- 冻结授权状态：作者已确认修订后的协议并解除HOLD；按最新确认，提交Git冻结后先运行两项校准和G1，通过后继续模块A/B及v1.6改稿。此前HOLD指令与修订稿保留在provenance中。
- 不向期刊系统写入，不重开 v1.0 GO/STOP；不拟合 NCI；不运行旧 X2 草案中的选择模型或第二天偏移分析。
- 本任务全部是 post hoc, specified after the primary results。期刊路由词表按本任务使用，不等于对录用概率的验证。

### 唯一样本、设计和估计

- 从 S1 已与 v1.0 数据逐值一致的 analysis_input.rds 读取既有设计对象、原始顺序、完整病例标记与协变量字符串；成人且 cov_complete，预期20,875人。任何人数差异先 STOP_REPRO，不补人、不插补。
- 所有 S2 主表、未调整前趋势及 B2 都使用这个完整病例样本。原 v1.0 阶段B的较大成人域不改；S2 前趋势是相同未调整检验程序在本任务明确指定的完整病例域中的事后复用。
- B2 的2021–2023和2017–2018均值也用该域；不直接把原 S1/S2 更大成人域的点估计与新差值混用。另在复现记录说明人口域差别。
- 因子水平、cycle×stratum×PSU、WTDR2D/5、time={2012,2014,2016,2018,2022.7}−2015全部沿用；两种模型的公式及 svyglm 调用以封存 v1.0 模型为模板，不重新选协变量。
- D=第二天−第一天，模式效应=−DiD，校正第一天加DiD。Taylor双侧95% CI及P使用封存模型的残余df。Bootstrap比例及B2使用封存200组Rao–Wu乘数、原scale/rscales、围绕全样本点估计的MSE和t(77)区间；不重新抽样、不删除失败重复。
- 每一分量的前趋势：G–J内未调整 D~cycle Wald P>0.05，并且D~time在2022.7外推的双侧95% CI宽度<2×|加权对照期D均值|。S2重写了该程序；须先按下述步骤校准，不能称为直接调用原stage_b.R。分量不通过只改变限定，不重开原GO。
- 冻结后，在任何成分预趋势之前，用同一S2函数、v1.0原成人域（不限协变量完整）重算Y1与Y2。Wald P与外推CI宽度、上下限必须与封存B_pretrend/gate_results.csv的全精度值相差<1e−8，人数一致。显示P约0.0180/0.7720只用于阅读，不以四位小数作为误差比较目标。失败记STOP_REPRO，成分分析NOT_RUN。
- 每个结局与参照都用与bootstrap相同的模型矩阵、WTDR2D/5和单位PSU乘数运行lm.wfit；其is_L系数须与svyglm点估计相差<1e−8。G1包含主结局校核；全部分量在进入200组重复前再次汇总核对，不通过则STOP_REPRO，不生成bootstrap CI。
- G1先复现log1p能量的两种DiD和Taylor CI，到三位小数须相同；同时与完整精度封存结果比对。原始kcal总DiD作A2/A3分母。

### IFF、场合和零值

- G0能量合计和条目数校核以每日DRxDRSTZ=1的全部人进行；Reliable零条目、没有IFF行者按0行/0kcal匹配TOT，不记成缺档。
- 时间变量各周期均为DRx_020；完整场合代码表见 metadata/occasion_codebook_map.csv，各周期两天均保留全部定义，包括无观察的91及缺失。
- 场合按上文三类；每人每日同一原始场合代码+同一时间值算一场合。缺失/未指明的时间按其原始缺失标记组成一个未知时间键；未知键人数另列，不能视为精确已知时间。
- E和N来自TOT并以IFF合计精确核验。A1只在两天E>0且N>0的共同域估计logE/logN/logP，三式必须用同一域；剔除人数逐周期报告。克重/条目分析另要求两天总克重>0，数量如实列出。
- A2/A3每人每日未报告该类别记0（不是剔除），全部类别总和必须等于TOT。按组log(克重/条目)只在该组两天均有条目且克重>0者计算，标记条件选择后的描述性分析。
- kcal DiD百分比=−100×DiD(kcal)/对照期第一天加权平均kcal，描述性比较主结果−9.1%，不要求相同。

### 官方分类映射及边界处理

- G/H/I/J使用对应USDA WWEIA食品代码映射表；L使用2021–2023 FNDDS At A Glance Foods and Beverages，均逐食品代码查表。wweia_group_map.csv含37,359行及每个来源哈希；绝不从8位食品代码首位推类别。
- 10组按官方主标题合并。奶替代物/植物奶与植物酸奶按官方MILK AND DAIRY标题归G5；冰淇淋、布丁等按SNACKS AND SWEETS归G3；奶油/奶油奶酪等按FATS AND OILS归G4；官方旧类别6422 vegetable mixed dishes按VEGETABLES归G9，新类别3104按MIXED DISHES归G6，不跨版本重编USDA定义。
- 只把白水7702/7704归G10；调味/增强水7802/7804归G1（非酒精饮料），与任务“排除白水”一致。营养饮料7208及奶谷饮7220归G1；营养/蛋白粉9802按官方OTHER归G10。
- 稿件Methods须明写：“Flavored and enhanced waters (WWEIA categories 7802 and 7804) were included among non-alcoholic beverages; plain water was assigned to Other.”
- 按周期保留官方字典的分组变迁，不回编食物代码。尤其G6/G7/G9单组的跨周期分解可能受USDA重分类影响；同一周期两天用同一字典并不保证此影响完全抵消。迁移代码和是否跨H-omit边界列于metadata/cross_cycle_group_migrations.csv。
- 婴儿食品、配方、人乳及9999官方未分类归G10；人乳成人排除规则不变。9999是已找到官方映射但未细分食物类，另报其能量比例。G0.5缺映射指食品代码在对应官方字典中找不到，按周期合并两天Reliable的能量占比<1%；同时列出9999能量占比，不能藏在已映射比例中。
- 所有组的s_g为G–J第一天加权总组能量/加权总能量（比率，非逐人比率的平均）。H-omit合并G1–G4；R=(组kcal DiD/总kcal DiD)/s_g。每次bootstrap同时重估DiD分子分母和s_g。
- 保留A3各参照10个食物组、A2各参照3个场合的kcal DiD描述性BH q，但该q不用于组成判定。组成判定另用R_g的bootstrap SE计算相对1的双侧t(77)检验；每个参照分别在3场合、10食物组内做BH，不合并13项，H-omit不加入任何BH家族。即便某项检验无效，家族大小也保留3/10。输出R_t、R_p、R_q_BH、R_df、R_family/R_family_size及状态，明确与Taylor DiD的p/q_BH区分。SE非正或非有限时记NO_VALID_RESULT，不构造假P/q。

### 判定与失败

- 5.1按给定顺序先OMISSION_DOMINANT、再PORTION_DOMINANT、再MIXED、否则INDETERMINATE；恰好各0.5时按顺序处理。PORTION的trend方向一致指trend DiD(logP)>0。component_pretrend逐项列PASS/FAIL；任一不通过则分类标conditional。
- 分类只是报告条目/条目平均能量的统计分解。报告条目包括配料拆分及水，不能把类别名等同于已证实的记忆遗漏机制；电话、辅助工具、时机三部分仍不可单独识别。
- G0或G1失败则按原说明停止新结局与改稿，后续NOT_RUN；比率无有限定义或重复拟合失败记NO_VALID_RESULT，不写为阴性，不重抽样或换CI算法。
- 本协议、完整映射和场合映射、analyze.R、s2_inference_helpers.R及其他脚本须在新s2 Git库提交并写freeze_record，提交前只做G0结构核验和合成数据逻辑测试；每个提交源文件都记录SHA256并在运行时验证。当前冻结暂缓指令解除前不提交、不计算新增均值或DiD。

### 来源和时间证明

- v1.0内部冻结记录：outputs/DR-MODE-01/config/status_at_freeze.json，时间2026-10-29T14:02:42.692515+00:00，合同SHA256 902328b9d98817f6982f0ee169bb1809f20e55e9a0178c7c15d1cfb495d76d27。
- 公开代码归档提交cb1b15fe27e52c9f0d86f20576cb7e4a6d9dceb0，时间2026-10-30T03:13:41−07:00。它发生在原分析之后，不能用来声称原分析前外部注册；稿件写internally frozen，归档可核验协议和版本历史。
- S2提交时间将实时写入freeze_record；不得将其声称在主结果产生前预设。
'''
(OUT/'protocol_S2.md').write_text(src+notes)
print('Prepared revised complete protocol; HOLD per latest author request; NOT FROZEN')
