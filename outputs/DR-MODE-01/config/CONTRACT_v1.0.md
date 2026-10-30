# DR-MODE-01 任务说明 v1.0（冻结合同）

**一句话**：NHANES 2021–2023 把第一天 24 小时膳食回顾从 MEC 现场面访改成电话（第二天一直是电话）。用"同一个人第二天减第一天"的差值，在 2011–2018 各周期与 2021–2023 之间做双重差分，把模式效应与长期趋势、疫情、无应答、食物成分库变化分开；再量化它对总体均值、趋势和摄入不足患病率的影响。

**冻结日期**：2026-10-29。sha256 写入 `status.json` 后，任何阈值、结局、协变量、周期列表的改动都必须升版本号，旧结果保留。**阶段 C 结束即终局，只出 GO / STOP，不开 v1.1 改规则。**

---

## 1. 执行纪律

1. 只用 NHANES 公开文件（无需签字，可由 AI 工具处理）。不使用 RDC 受限数据。
2. 分析单位是**个人**；主估计量来自个人内两天差值。所有 N 按人报告。
3. 规则在看结果前冻结；看结果后换结局、换周期、换人群、换协变量来"通过"一律禁止。
4. 做不了写 `NOT_RUN`（写原因）；数据不可执行写 `NO_VALID_RESULT`；都不写成阴性。
5. 失败分层：工程 / 数据不可执行 / 校准失败 / 科学结果不支持 / 增量不足，分开写。
6. 只报告数字和判定，不写故事、不评估期刊。

---

## 2. 冻结对象

| 项目                  | 内容                                                                                                                                   |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| 周期                  | 对照期：2011–2012 (G)、2013–2014 (H)、2015–2016 (I)、2017–2018 (J)，第一天现场、第二天电话。处理期：2021–2023 (L)，两天都电话。2017–2020.3 (P) 不纳入主分析，只作敏感性（与 J 重叠） |
| 人群                  | 主分析：≥20 岁，两天回顾状态均为 Reliable（DR1DRSTZ=1 且 DR2DRSTZ=1），排除母乳喂养（DRABF=1）。次要：2–19 岁                                                       |
| 主要结局（2 个）           | Y1 = 报告食物/饮料条数（DRxTNUMF）；Y2 = log(能量 kcal + 1)（DRxTKCAL）                                                                             |
| 次要结局面板（10 个，FDR 校正） | 总糖、酒精、咖啡因、水分（moisture）、铁、钙、钠、蛋白质能量比、脂肪能量比、膳食纤维；按 log(x+1) 或能量比                                                                       |
| 个人内差值               | D = Y(第二天) − Y(第一天)                                                                                                                  |
| 估计量                 | DiD = E[D │ L] − E[D │ G–J]。在"顺序效应各周期稳定"的假设下，−DiD = 第一天由现场改为电话的模式效应                                                                  |
| 协变量（固定）             | 两天是否周末（各一个）、两天间隔天数（DR1DBIH − DR2DBIH 的绝对值）、访谈语言、是否代答、年龄组、性别                                                                          |
| 设计                  | 两天权重 WTDR2D；多周期合并按 NHANES 权重指南；SDMVSTRA/SDMVPSU；Taylor 线性化 SE                                                                        |

---

## 3. 竞争解释 → 对应分析

| 竞争解释                                       | 区分它的分析                                                    |
| ------------------------------------------ | --------------------------------------------------------- |
| 长期饮食变化、疫情、食物成分库（FNDDS）更新                   | 个人内差值：这些因素同时作用于两天，差值中相互抵消                                 |
| 2021–2023 无应答更高、样本构成不同                     | 个人内差值 + 协变量；敏感性：按 2017–2018 人口构成重新加权（年龄×性别×种族×教育的 raking） |
| 第二天的"顺序效应"本身随时间漂移                          | 阶段 B 前趋势门；主 DiD 同时报告"对照期均值"和"对照期线性外推"两种参照                 |
| 两天间隔变长（2021–2023 均值 9.3 天 vs 以往 6.4–8.7 天） | 协变量；敏感性：限定间隔 3–10 天                                       |
| 第一天也换了份量辅助工具（食物模型手册）                       | 不可分离；作为"模式包"的一部分报告，在结论中写明                                 |
| 第一天时间从体检当天变为体检后 3–7 天                      | 不可分离；同上                                                   |

---

## 4. 数据清单（阶段 A 逐项核验）

- 文件：各周期 `DR1TOT_x`、`DR2TOT_x`、`DEMO_x`（x = G, H, I, J, L；敏感性加 P）。来源：CDC NHANES 公开下载，无需注册。
- 必须核验的语义：&#x20;
  - 每个周期 codebook 中第一天、第二天的访谈方式原文（L 周期文本已确认："both dietary recall interviews were administered via telephone"；第一天在 MEC 后 3–7 天，第二天在第一天后 3–10 天）。
  - DR1DBIH / DR2DBIH 在各周期都存在且含义一致（"Days between intake and household interview"）。
  - DRxTNUMF 在各周期定义一致（是否含饮用水、补充剂）。
  - 每周期 Reliable 两天人数（未插补）。

---

## 5. 分层任务

### 阶段 A：可执行性与校准（预算 ≤1 天）

- **A0 查重复核**（≤6 次检索，含 2025–2026 期刊与预印本、CDC/USDA 报告、会议摘要）。已知母研究：NCHS 白皮书（描述性，周期间无检验，无常规摄入分析）、DaDiet 博客（均值配对 t 检验，非同行评议）。STOP_DUP 条件：已有同行评议或官方报告**以统计检验估计** 2021–2023 第一天模式效应（个人内差值跨周期对比或等价设计），**并且**量化其对常规摄入或摄入不足患病率的影响。只满足前半条不触发 STOP，但必须在 REPORT 写明，并把阶段 C 的增量门作为必要条件。
- **A1 数据**：5 个周期文件可下载，第 4 节语义全部核验通过。否则 STOP_DATA。
- **A2 校准**：复现 NCHS 白皮书的成人第一天平均食物条数（2017–2018 为 16.0，2021–2023 为 15.1），误差 ≤0.2；复现 L 周期 Reliable 第一天人数 6,694。否则 CALIBRATION_FAIL。
- **A3 样本量**：每个周期成人两天 Reliable ≥2,500 人。否则 STOP_DATA。

### 阶段 B：前趋势（预算 ≤半天）

- 在 G–J 四个周期内，分别对 Y1、Y2 的个人内差值 D 做周期异质性 Wald 检验，并估计线性趋势。
- **PASS**：两个主要结局中至少一个的 Wald p >0.05，且线性趋势外推到 L 周期的 95% CI 宽度小于对照期 D 均值绝对值的 2 倍。否则 STOP（顺序效应不稳定，设计不成立）。

### 阶段 C：主检验与影响量化（终局，预算 ≤2 天）

- C1 主估计：Y1、Y2 的 DiD（加权、含协变量），同时用"对照期均值"和"线性外推"两种参照。
- C2 次要面板：10 个营养素/食物指标的 DiD，BH-FDR。
- C3 影响量化（只对通过 C1 的结局及 C2 中 FDR<0.05 的指标）：&#x20;
  - (a) 2021–2023 成人第一天均值经模式校正（加回 −DiD）前后的差别；
  - (b) 2017–2018 → 2021–2023 的变化中，模式效应解释的比例；
  - (c) 用 NCI 方法（R 包 `ncimultivar`；运行失败则写 NOT_RUN）估计常规摄入后，铁、钙的摄入不足患病率（EAR 切点法）在校正前后的差别。
- **GO（全部满足）**：&#x20;
  1. Y1 或 Y2 的 DiD 在两种参照下都 p <0.01 且同号；
  2. 该 DiD 绝对值 > 对照期四个周期 D 均值标准差的 2 倍；
  3. C3(b) 中至少一个主要结局或 FDR 显著的次要指标，模式效应解释了 ≥30% 的 2017–2018 → 2021–2023 变化；或 C3(c) 中至少一个营养素的不足患病率变化 ≥2 个百分点。
- **STOP**：任一条不满足。其中满足 1–2 但不满足 3，记为"效应存在但影响不足（增量不足）"。

---

## 6. 输出
```bash
DR-MODE-01/
  config/          # 周期列表、变量映射、权重规则
  A_access/        # 下载记录、语义核验原文、查重记录、校准结果
  B_pretrend/
  C_main/          # DiD、次要面板、影响量化
  status.json
  REPORT.md        # 工程｜数据｜科学结果｜是否继续投入｜与合同的偏离

```

`status.json`：`{"version":"1.0","contract_sha256":"...","stage":"A|B|C","verdict":"PASS|STOP_DUP|STOP_DATA|CALIBRATION_FAIL|STOP|GO|NOT_RUN","gates":{"A0":..,"A1":..,"A2":..,"A3":..,"B":..,"C1":..,"C2":..,"C3":..},"n_adults_by_cycle":{..}}`

---

## 7. 已知风险

1. 顺序效应（第二天普遍报告更少）若随时间漂移，B 门会停；这是设计本身的退出点。
2. 模式包不可拆：电话 + 份量辅助工具改变 + 时间推迟三者同时发生，只能整体估计。
3. NCHS/USDA 表示会发布模式影响分析；A0 必须查他们 2025–2026 年的任何产出。
4. 2021–2023 第一天应答率大幅下降（白皮书：MEC 参与者中 76.2% vs 以往 87.8–91.2%）；个人内设计能处理构成差异，但不能处理"谁愿意完成两天"与报告质量的交互，需在结论中写明。

---

## 8. 参考

- NCHS. What We Eat in America Dietary Data, NHANES August 2021–August 2023 (white paper). [https://wwwn.cdc.gov/nchs/data/Nhanes/Public/2021/Whitepapers/Aug2023-What-We-Eat-In-America-Dietary-Data-Whitepaper.pdf](https://wwwn.cdc.gov/nchs/data/Nhanes/Public/2021/Whitepapers/Aug2023-What-We-Eat-In-America-Dietary-Data-Whitepaper.pdf)
- NCHS. Brief Overview of Sample Design, Nonresponse Bias Assessment, and Analytic Guidelines for NHANES August 2021–August 2023. [https://wwwn.cdc.gov/nchs/nhanes/continuousnhanes/overviewbrief.aspx?Cycle=2021-2023](https://wwwn.cdc.gov/nchs/nhanes/continuousnhanes/overviewbrief.aspx?Cycle=2021-2023)
- DR1TOT_L codebook. [https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2021/DataFiles/DR1TOT_L.htm](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2021/DataFiles/DR1TOT_L.htm)
- Dempsey P. Impacts of Data Collection Changes in NHANES on GRAS Dietary Exposures: Food Means. DaDiet, 2025-06-18.
