# DR-MODE-01 写作期补充分析 S2：食物层面分解 + 营养素预趋势

任务编号：DR-MODE-01-S2
底稿：manuscript_v1.1_AJCN（含已完成的措辞修订版）及 v1.0.0 代码仓库
输出：`s2/` 新目录 + manuscript_v1.2_AJCN
目标：把论文从"首日能量少报了多少"升级为"电话首日回顾少报的是什么"，并补上"营养素预趋势未检验"这一自伤点。一轮内给出明确判定，不开 v1.1 式的多轮追加。

---

## 0. 总规则

1. **只读保护**：v1.0/v1.1 的全部分析文件、figdata、图表、bootstrap 乘数先做哈希（`provenance/s2_protected_before.json`），结束时复核（`s2_protected_after.json`），差异必须为 0。所有新结果只写入 `s2/`。
2. **冻结顺序**：
   - 冻结前只允许做结构核对：变量是否存在、编码表、文件行数、IFF 与 TOT 的合计一致性。**不得计算任何按周期汇总的结局均值或 DiD。**
   - 本说明第 2–4 节的全部定义（分组映射表、进食场合分类、判定规则）写成 `s2/protocol_S2.md`，连同 WWEIA 映射 CSV 一起 git commit，并把 **commit hash 和 UTC 时间戳**记入 `s2/freeze_record.json`。之后才能读取结局数据。
   - 冻结后发现定义错误时，按 v1.0 处理符号错误的方式办：如实修正，原定义和修正理由留在记录里，不静默覆盖。
3. **样本**：与主分析完全一致，即 20,875 名协变量完整的成人（control cycles G/H/I/J + L）。权重、strata/PSU 编码、协变量、两种参照（control mean / trend）、Taylor 推断全部沿用 v1.0 代码，不重写。
4. **Bootstrap**：复用 v1.0 冻结的 200 组 Rao–Wu PSU 乘数，**不重新抽样**。本任务只做 DiD 与比例，不拟合 NCI 模型。
5. **定性**：本任务所有分析标记为 *post hoc, specified after the primary results*，正文和补充材料都要写明。

---

## 1. Gate G0：数据与结构（失败即 STOP_DATA）

文件：每个周期的 DR1IFF / DR2IFF / DR1TOT / DR2TOT（G、H、I、J、L 后缀）。

变量（以各周期 codebook 为准，名称不同时记录映射）：SEQN、DRxILINE、DRxIFDCD（食物代码）、DRxIGRMS、DRxIKCAL、DRxI_020 或 DRx_020（进食时间）、DRx_030Z（进食场合名称）、DRxTNUMF、DRxTKCAL。

核对项：

| 检查 | 通过标准 |
|---|---|
| G0.1 变量齐全 | 5 个周期 × 2 天全部可得；缺任一核心变量 → STOP_DATA |
| G0.2 IFF 与 TOT 合计一致 | 每人每天 \|Σ IFF kcal − DRxTKCAL\| ≤ 1 kcal 的比例 ≥ 99.5%（每个周期、每天分别算），不达标需逐条解释 |
| G0.3 条目数一致 | IFF 行数 = 主分析使用的条目数变量（DRxTNUMF 或 v1.0 的定义），一致率 100%；不一致时先查清 v1.0 的定义，不得改动 v1.0 |
| G0.4 进食场合编码 | 列出每个周期 DRx_030Z 的完整编码表（含西班牙语场合 10–19 和 91）；L 周期与旧周期不一致时记录映射 |
| G0.5 WWEIA 映射覆盖 | 用各周期对应版本的 FNDDS（2011–12、2013–14、2015–16、2017–18、2021–23）把食物代码映射到 WWEIA 类别；未映射的能量占比 < 1%（每周期分别算） |

## 2. Gate G1：主结果复现（失败即 STOP_REPRO）

在 S2 管线里重算主结局 log(energy+1) 的 DiD，必须与 v1.0 一致：control mean 0.095（0.075, 0.116），trend 0.098（0.054, 0.142），第三位小数一致。另外在 kcal 尺度上算总能量 DiD（D 以 kcal 计），作为第 3 节加性分解的分母，并报告其 Taylor CI。

---

## 3. 模块 A：食物层面分解（核心）

### A1. 广延边际与集约边际的精确分解（log 尺度）

对每人每天，在 E > 0 且 N > 0 的人中：
- N = 报告条目数，E = 总 kcal，P = E/N（每条食物的平均能量）
- log E = log N + log P（精确恒等式）

因为 DiD 对 Y 是线性的（同一样本、同样的权重和协变量），所以 DiD(log E) = DiD(log N) + DiD(log P)，误差只来自浮点运算，需核对误差 < 1e‑10。

- E = 0 或 N = 0 的人数逐周期报告；正常应接近 0。若 > 0.5%，另报一个把他们排除在外的说明。
- 报告：DiD(log E)、DiD(log N)、DiD(log P)，两种参照，Taylor CI。
- **share_N = DiD(log N) / DiD(log E)**，用 bootstrap 给 CI（200 组乘数，t 分布，df 与 v1.0 跨周期量一致取 77）。
- 补充一个克重版本：DiD(log 克重/条目)，作为份量边际的另一种口径，只做描述。
- **每个分量都要跑预趋势**：沿用 Table S6 的方法（无调整 Wald 检验 + 外推 CI 宽度 < 2×|control 期 D 均值|）。已知条目数没通过（P = 0.018），log N 很可能也不通过，这必须如实报告，判定规则见第 5 节。

### A2. 按进食场合分解（kcal 尺度，加性）

冻结的分类（若 G0.4 发现编码不同，在冻结前调整）：
- **正餐**：1 Breakfast、2 Lunch、3 Dinner、4 Supper、5 Brunch、10 Desayuno、11 Almuerzo、12 Comida、14 Cena
- **零食/饮品**：6 Snack、7 Drink、9 Extended consumption、13 Merienda、15 Entre comida、16 Botana、17 Bocadillo、18 Tentempié、19 Bebida
- **其他**：8 Infant feeding、91 Other、缺失

每人每天的结局：
- 每个场合类别的 kcal：三类之和 = 总 kcal，DiD 严格可加
- 每个场合类别的条目数：三类之和 = N
- 正餐场合数、零食/饮品场合数（同一场合名称 + 同一时间计为一个场合）

报告：每个分量的 kcal DiD 及其占总 kcal DiD 的比例（bootstrap CI）；条目数 DiD；场合数 DiD。两种参照都报。

### A3. 按 WWEIA 食物大组分解（kcal 尺度，加性）

冻结 10 个分析组（由 Codex 依据 USDA 公布的 WWEIA 类别主标题生成映射 CSV，冻结前人工核对）：

| 组 | 内容 |
|---|---|
| G1 非酒精饮料 | 软饮、果汁、咖啡/茶、运动/能量饮料等（不含奶、不含白水） |
| G2 酒精饮料 | 啤酒、葡萄酒、烈酒 |
| G3 零食与甜食 | 薯片/饼干类零食、糖果、甜点、烘焙甜食 |
| G4 添加物 | 调味品/酱料、油脂、糖和甜味剂 |
| G5 奶及奶制品 | |
| G6 混合菜 | |
| G7 蛋白质食物 | |
| G8 谷物 | |
| G9 水果与蔬菜 | |
| G10 其他 | 白水（只计条目，0 kcal）、婴儿配方、未映射 |

预先指定的"遗漏假设组" **H‑omit = G1 + G2 + G3 + G4**。

报告：
- 每组 kcal DiD（两种参照，Taylor CI）；control-mean 参照下 10 组内做 BH 校正，trend 参照另做一套
- 每组占总 kcal DiD 的份额（bootstrap CI）
- 每组在 control 周期第一天能量中的占比 s_g（加权）
- **过度代表比 R_g = 份额_g / s_g**；H‑omit 合并组的 R 及其 bootstrap CI 是本模块的预先指定检验
- 每组条目数 DiD
- 探索性：每组在两天都有报告的人中，log(克重/条目) 的 DiD。这里有选择偏倚，只做描述。

### A4. 对 log(x+1) 尺度的一致性说明

主分析用的是 log(energy+1)。A1 用 log E（E > 0），A2/A3 用 kcal 尺度。补充材料里要用一句话说明三种尺度各自的用途，并报告 kcal 尺度总 DiD 换算成百分比后与 −9.1% 是否吻合，不要求完全一致。

---

## 4. 模块 B：补齐预趋势与校正后趋势

### B1. 10 个次要结局的预趋势（post hoc）

对 Table S2 的 10 个结局，按 Table S6 的同一程序做无调整 Wald 检验、线性趋势和外推 CI 宽度判据，输出一张新表（拟编为 Table S6 的续表或新 S9）。

后果规则（冻结）：
- **钙未通过** → 钙不足率的结果从摘要 Results 中删除；正文保留，改称"illustrative"，Figure 3b 的图注加一句说明。
- **钙通过** → 删除正文、表注、图注中关于钙的 "pre-trends were not tested" 表述，改为报告检验结果。
- 其他营养素：在 Table S2 增加一列 "Pre-trend criterion"，Results 中只报告通过的数量和名称。

### B2. 校正后与 2017–18 年的直接比较

用 v1.0 的 200 组乘数，在同一组 bootstrap 复制里同时计算：
- 2021–23 年校正后的第一天能量均值（control mean 参照和 trend 参照各一个）
- 2017–18 年第一天能量均值（原始值）
- 两者之差及 CI

这个数字用来替换"155.8%/160.0%"的比例表述。预期大致在 +68 kcal 左右，以实际计算为准。

---

## 5. 判定（输出到 `s2/verdict.json`，词表固定）

### 5.1 机制分类 `mechanism_class`

以 control-mean 参照为主判，trend 参照做一致性核对：

- **OMISSION_DOMINANT**：share_N ≥ 0.5 且 DiD(log N) 的 95% CI 下限 > 0；同时 trend 参照下 share_N ≥ 0.5（点估计即可）
- **PORTION_DOMINANT**：1 − share_N ≥ 0.5 且 DiD(log P) 的 CI 下限 > 0；trend 参照方向一致
- **MIXED**：DiD(log N) 和 DiD(log P) 的 CI 都不含 0，且不满足以上两条
- **INDETERMINATE**：其余情况

附加标签 `component_pretrend`：log N 和 log P 是否通过预趋势判据。未通过时机制分类照常给出，但标记为 `conditional`，正文必须写明。

### 5.2 组成判定 `composition_signal`

- **YES**：H‑omit 合并组的 R 的 95% CI 下限 > 1，**或**至少一个场合/食物组在 control-mean 参照下 BH q < 0.05 且 trend 参照下方向一致
- **NO**：其余情况

### 5.3 故事升级判定 `story_verdict`

- **UPGRADE_AJCN**：`mechanism_class` ≠ INDETERMINATE 且 `composition_signal` = YES → 进入第 6 节改稿，投 AJCN
- **NO_UPGRADE_SWITCH**：其余情况 → 不把模块 A 写进正文（只放补充材料作为探索性分解），只执行第 6 节中与机制无关的修订（6.1–6.4、6.6–6.8），改投 J Nutr

无论哪种结果，模块 B 都写入稿件。

---

## 6. 改稿（G0/G1 通过并给出 verdict 之后执行）

正文和补充材料只做以下修改；claims_map、DOCX/MD 数字序列、表格顺序、三线表等 QA 全部重跑。

6.1 **标题与正文语气统一**：保留标题中的 "lowered"；Discussion 第一句改为因果语气并点明识别假设，例如 "Under the stable-order-effect assumption, telephone administration of the first recall lowered reported energy by an estimated 9.1%."

6.2 **摘要 Results**：删除 "a 9.1% reduction"；用 B2 的结果新增一句（校正后的 2021–23 年均值与 2017–18 年之差及 CI）；按 B1 规则决定是否保留钙。UPGRADE 时加一句机制结果（share_N 及主要贡献组）。摘要 ≤ 300 词。

6.3 **摘要 Conclusions**：替换 "require explicit reporting-scale assumptions"，改为具体结论：校正后第一天能量的下降消失。UPGRADE 时再加一句"主要来自 X 的遗漏"。

6.4 **删除比例表述**：删掉正文中 "155.8% and 160.0%" 以及 Table 2 的 "Mode effect as % of observed change" 一行，用 B2 的差值替代。Methods 里对应的那句同步修改。

6.5 **新增内容（仅 UPGRADE）**：
- Methods 新增小节 "Food-level decomposition"（post hoc）
- Results 新增小节
- 新增 Figure 4：(a) log E 分解为 log N 与 log P；(b) 按场合和食物组的 kcal DiD 份额与第一天能量占比并列对照
- Discussion 第 3 段改写：删除 "We did not test omission at the food level" 和 "motivate food-level examination"，换成实际发现；仍须说明三项协议变化（电话、份量辅具、时间）不能完全拆开。如果 PORTION_DOMINANT，可以讨论份量辅具变化的作用，但不要写成已识别。

6.6 **预先设定**：Pre-specification 段加入 v1.0 冻结方案的 commit hash 与时间戳，以及 S2 的 freeze_record。v1.0 若没有可核验的时间戳，改写为 "internally frozen; the protocol file and its version history are in the archive"，不得声称外部注册。

6.7 **AI 使用说明位置**：把 Codex 用于编写和运行分析代码、数值核对、作图的描述移到 Methods 的 Statistical analysis 末尾（研究过程中的 AI 使用）。"Declaration of generative AI…" 一节只保留写作和语言方面的用途。把 "argument framing" 改为 "feedback on draft structure"。内容如实、不删减，只调整位置。

6.8 **待作者确认，不由 Codex 修改**：CRediT 中第一作者的 "Supervision"，在 QA 记录里标注 `AUTHOR_DECISION`。

6.9 **STROBE 与补充材料**：更新 12b（新增分解分析）、nut‑7.1（食物组定义）、nut‑8.2（FNDDS/WWEIA 版本映射），并刷新页码。

---

## 7. 交付物清单

- `s2/protocol_S2.md`、`s2/wweia_group_map.csv`、`s2/freeze_record.json`
- `s2/G0_checks.json`、`s2/G1_repro.json`
- `s2/A1_decomposition.csv`、`s2/A2_occasion.csv`、`s2/A3_foodgroup.csv`（DiD、CI、P、BH q、份额、份额 CI、s_g、R_g，两种参照），以及每个分量的预趋势表
- `s2/B1_nutrient_pretrend.csv`、`s2/B2_corrected_vs_2017.csv`
- `s2/verdict.json`：包含 mechanism_class、component_pretrend、composition_signal、story_verdict，以及支撑每项判定的数字
- Figure 4（仅 UPGRADE）：PDF/SVG/600 dpi PNG，规格同 Figure 1
- manuscript_v1.2_AJCN（DOCX + MD）、supplement、STROBE、`P2_check_record.md`（格式同 P1b 检查记录）
- 只读核对：`provenance/s2_protected_before/after.json`，差异为 0

## 8. 汇报格式（给 Claude 复核用）

只回传汇总数字，不回传个人层面数据：
1. G0/G1 各项的 PASS/STOP 结果
2. A1 三个 DiD（两种参照）+ share_N 及 CI + 各分量的预趋势结果
3. A2/A3 汇总表（每行：组、kcal DiD、CI、q、份额、s_g、R_g）
4. B1 表、B2 数字
5. verdict.json 全文
6. 稿件 diff 摘要与 QA 失败数