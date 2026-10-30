# DR-MODE-01 / W0 写作前终审

| 判定 | 值 |
|---|---|
| writing_gate | **OPEN** |
| 对账 | **RECONCILED** |
| v1.0 GO | 不变 |
| 受保护文件 | 4739；改动0；新增0 |
| S2c | 未触发；未运行 |
| 新增结局/周期/主分析人群/协变量 | 0/0/0/0 |

## W0.1 实现终审

| 项目 | 判定 | 核对数字 | 证据行号 |
|---|---|---|---|
| a | PASS | B=WTDR2D/4；C全G-H-I-J-L=WTDR2D/5；74层/151PSU；周期复合编码 | [stage_b.R:L13](outputs/DR-MODE-01/B_pretrend/stage_b.R:13)<br>[stage_c12.R:L26](outputs/DR-MODE-01/C_main/stage_c12.R:26)<br>[weighting_tutorial.txt:L424](outputs/DR-MODE-01/A_access/codebooks/weighting_tutorial.txt:424)<br>[overview_L.txt:L338](outputs/DR-MODE-01/A_access/codebooks/overview_L.txt:338) |
| b | PASS | 成人4309/4479/4204/4139/4285；完整病例4296/4443/4105/3990/4041 | [stage_a.R:L33](outputs/DR-MODE-01/A_access/scripts/stage_a.R:33)<br>[stage_c12.R:L30](outputs/DR-MODE-01/C_main/stage_c12.R:30)<br>`outputs/DR-MODE-01/status.json` key `n_adults_by_cycle,n_complete_covariates_adults_by_cycle` |
| c | PASS | D=Day2-Day1；模式效应=-DiD；S1校正=+DiD；24个DiD复算最大误差2.66e-15 | [stage_c12.R:L21](outputs/DR-MODE-01/C_main/stage_c12.R:21)<br>[S1_acd.R:L11](outputs/S1_writing/scripts/S1_acd.R:11)<br>[S1b_nci.R:L28](outputs/S1_writing/scripts/S1b_nci.R:28) |
| d | PASS | abs(DR1DBIH-DR2DBIH)；缺失13/36/99/149/244；其他协变量缺失0/0/0/0/0 | [stage_a.R:L36](outputs/DR-MODE-01/A_access/scripts/stage_a.R:36)<br>[stage_c12.R:L30](outputs/DR-MODE-01/C_main/stage_c12.R:30) |
| e | PASS | Day2=I(DAY=2)；分布Day2=0；周末六/日；5/7与2/7；组合25/10/10/4；钙EAR800/1000 | [execution_spec.json:L49](outputs/DR-MODE-01/config/execution_spec.json:49)<br>[IMPLEMENTATION.md:L4](outputs/S1_writing/S1b_C3c_usual_intake/IMPLEMENTATION.md:4)<br>[S1b_nci.R:L20](outputs/S1_writing/scripts/S1b_nci.R:20)<br>[nci_streaming.R:L22](outputs/S2_uncertainty/scripts/nci_streaming.R:22) |
| f | PASS | Rao-Wu：层内抽n_h-1个PSU；乘n_h/(n_h-1)；200组；seed2026102902；矩阵完全相同 | [prepare_replicates.R:L4](outputs/S2_uncertainty/scripts/prepare_replicates.R:4)<br>[survey_subbootstratum_source.txt:L3](DR-MODE-01/W0_audit/provenance/survey_subbootstratum_source.txt:3) |
| g | PASS | 原始失败0/200；均值参照0/200；外推30/200=15%；钙2、铁28；170组未用于CI | [run_nci_replicates.R:L70](outputs/S2_uncertainty/scripts/run_nci_replicates.R:70)<br>[summarize_S2.R:L58](outputs/S2_uncertainty/scripts/summarize_S2.R:58) |

| 限定/定义差异 | 数字或判定 |
|---|---|
| 周末冻结定义 | 周六/日；工作日5/7，周末2/7 |
| W0原括注定义 | 周五至日；工作日4/7，周末3/7；与冻结定义不同 |
| e项判定口径 | 用户确认按冻结方法；PASS；不改编码 |
| 四组合积分 | 25/49、10/49、10/49、4/49 |
| 回顾顺序 | 拟合Day2指示；分布Day2=0；第一天报告尺度 |
| 钙EAR | 男20–70/女20–50：800 mg；男>70/女>50：1000 mg |
| 铁不足率解释 | NO_VALID_RESULT；沿用S1 |
| 跨周期权重 | 每个二年周期同除5；非连续2011–2023总体平均；官方合并谨慎条款保留 |
| 成人间隔缺失 G/H/I/J/L | 13/36/99/149/244；不插补 |
| 审计脚本浮点比较修复 | CSV序列化误差≤5.21e−17；比较容差1e−12；原分析改动0 |

## W0.2 官方数字对账

### a. 成人两天差值

| 周期 | 指标 | N | D均值（SE） | 逐人绝对差均值（SE） | 相对差%（SE） |
|---|---|---:|---:|---:|---:|
| G | Y1 | 4309 | -0.3061（0.1647） | 4.6359（0.0918） | -1.8807（0.9936） |
| G | energy_kcal | 4309 | -160.9732（18.6191） | 715.4875（18.9680） | -7.3503（0.8161） |
| H | Y1 | 4479 | -0.3363（0.1646） | 4.7503（0.0972） | -2.0099（0.9754） |
| H | energy_kcal | 4479 | -118.9473（26.9756） | 707.5317（18.0954） | -5.5446（1.2548） |
| I | Y1 | 4204 | -0.0283（0.1759） | 4.4419（0.0853） | -0.1795（1.1162） |
| I | energy_kcal | 4204 | -105.2066（19.6159） | 698.7346（21.5819） | -5.0024（0.9298） |
| J | Y1 | 4139 | -0.7165（0.1298） | 4.4936（0.0993） | -4.4342（0.8174） |
| J | energy_kcal | 4139 | -166.1840（18.2498） | 716.5789（15.0092） | -7.6919（0.8314） |
| L | Y1 | 4285 | 0.3242（0.0911） | 4.0816（0.0855） | 2.1727（0.6140） |
| L | energy_kcal | 4285 | 33.8864（15.7868） | 694.7022（18.1668） | 1.6728（0.7865） |

D=Day2−Day1；相对差=E[D]/E[Day1]；SE=Taylor。

### b. 白皮书图9：Day1−Day2，按白皮书非禁食条件

| 周期 | 男：复现 / 图示 | 女：复现 / 图示 | 总体：复现 / 图示 | 判定 |
|---|---:|---:|---:|---|
| G | 0.3699 / 0.4 | 0.2254 / 0.2 | 0.2950 / 0.3 | PASS |
| H | 0.4937 / 0.5 | 0.1681 / 0.2 | 0.3243 / 0.3 | PASS |
| I | 0.0931 / 0.1 | -0.0420 / 0 | 0.0235 / 0 | PASS |
| J | 0.8171 / 0.82 | 0.6281 / 0.63 | 0.7184 / 0.72 | PASS |
| L | -0.1846 / -0.2 | -0.4442 / -0.4 | -0.3184 / -0.3 | PASS |

| 核对项 | 判定 |
|---|---|
| 图示精度一致 | 15/15 |
| L 男/女/总体 | 负/负/负 |
| G–J 总体 | 正/正/正/正 |
| I 女性 | −0.04198；图示0.0；小负值，非“所有对照性别均正” |
| 冻结主样本与白皮书样本 | 分列；白皮书另排任一天0 kcal；主样本未改 |

### c. Nutrients 13:2621 对账

| 定义 | 性别/天 | N / 目标N | 均值 / 目标 | SE / 目标 | 均值误差 kcal | 判定 |
|---|---|---:|---:|---:|---:|---|
| W0_as_written | Male/1 | 2601/2599 | 2423.3776 / 2425 | 26.6885 / 26 | -1.6224 | FAIL |
| W0_as_written | Male/2 | 2601/2599 | 2332.1988 / 2334 | 32.6295 / 32 | -1.8012 | FAIL |
| W0_as_written | Female/1 | 2624/2624 | 1831.9570 / 1832 | 17.8433 / 18 | -0.0430 | PASS |
| W0_as_written | Female/2 | 2624/2624 | 1775.3747 / 1775 | 26.4420 / 26 | 0.3747 | PASS |
| paper_nonfasting | Male/1 | 2599/2599 | 2425.1365 / 2425 | 26.0534 / 26 | 0.1365 | PASS |
| paper_nonfasting | Male/2 | 2599/2599 | 2334.2940 / 2334 | 31.9475 / 32 | 0.2940 | PASS |
| paper_nonfasting | Female/1 | 2624/2624 | 1831.9570 / 1832 | 17.8433 / 18 | -0.0430 | PASS |
| paper_nonfasting | Female/2 | 2624/2624 | 1775.3747 / 1775 | 26.4420 / 26 | 0.3747 | PASS |

| 差异定位 | 结果 |
|---|---|
| W0所列条件 vs 论文完整条件 | 男性多2人；任一天0 kcal |
| 论文非禁食条件 | 正文Methods明确；主分析不变 |
| 论文完整条件复现 | 男2599；女2624；均值4/4、SE4/4整数一致 |
| 论文作者标识 | Steinfeldt等；Martin为通讯作者；DOI 10.3390/nu13082621 |

### d. 对账判定

| 项目 | 数字/判定 |
|---|---|
| 总判定 | **RECONCILED** |
| 冻结成人总体Y1与能量D方向 | G–J均<0；L均>0 |
| Y1 E(abs(D)) | 4.0816–4.7503 条 |
| Y1 abs(E[D]) | 0.0283–0.7165 条 |
| 能量 E(abs(D)) | 694.7022–716.5789 kcal |
| 官方图9 | 带符号Day1−Day2；不是逐人E(abs(D)) |
| “绝对差异相似”与方向反转 | 统计量区分后相容；未运行相似性/等效性检验 |

## W0.3–4 台账与出图数据

| 文件 | 行数 | 状态 |
|---|---:|---|
| claims_ledger.csv | 76 | PASS；无Taylor p与bootstrap CI同一行 |
| figdata/fig1_pretrend.csv | 14 | COMPLETE |
| figdata/fig2_correction.csv | 25 | COMPLETE |
| figdata/tab1_flow.csv | 35 | COMPLETE |
| figdata/tab2_main.csv | 4 | COMPLETE |
| figdata/supp_panel.csv | 20 | COMPLETE |
| figdata/supp_day2.csv | 2 | COMPLETE |

| 未运行/无有效结果 | 状态 | 原因 |
|---|---|---|
| S2c重新bootstrap | NOT_RUN（未触发） | S2已是Rao–Wu；200组矩阵相同 |
| 钙第一天摄入均值CI | NOT_RUN | S2仅给出钙不足比例CI；fig2保留S1点估计与NA |
| 外推钙不足比例CI | NO_VALID_RESULT | 30/200输入域失败；未用170组计算CI |
| 铁不足患病率 | NO_VALID_RESULT | 沿用S1；不换方法/人群 |
| 四维联合raking | NOT_RUN | 沿用结构零记录 |

## 更正记录清单

| 包/项目 | 数值更正 | 判定 |
|---|---:|---|
| v1.0/S1/S2 | 0 | 保持只读 |
| S2c | 0 | 未触发 |
| W0周末括注 | 0 | 用户确认按冻结5/7、2/7核验 |
| W0论文对账定义 | 0项主分析改动 | 两套定义并列；论文非禁食条件解释2名男性差异 |
| W0审计数值容差 | 0项科学结果改动 | 保留初次审计日志；CSV浮点序列化比较修复 |

## 来源

- [NHANES权重指南](https://wwwn.cdc.gov/nchs/nhanes/tutorials/weighting.aspx)：合并二年周期除数。
- [L周期分析指南](https://wwwn.cdc.gov/nchs/nhanes/continuousnhanes/overviewbrief.aspx?Cycle=2021-2023)：二年周期及跨疫情合并限制。
- [NCHS白皮书](https://wwwn.cdc.gov/nchs/data/Nhanes/Public/2021/Whitepapers/Aug2023-What-We-Eat-In-America-Dietary-Data-Whitepaper.pdf)：第6–7、18页；图9。
- [Steinfeldt/Martin等2021](https://doi.org/10.3390/nu13082621)：Methods、Table4；全文XML及提取文本存official/。
