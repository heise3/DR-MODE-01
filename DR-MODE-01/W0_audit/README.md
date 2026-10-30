# W0 文件索引

| 文件 | 内容 |
|---|---|
| REPORT_W0.md | a–g 判定、证据行号、官方对账、差异清单 |
| status_W0.json | 机器可读判定；v1.0 GO 不变 |
| claims_ledger.csv | 主张、数字、推断方法、来源行或键及使用位置 |
| figdata/fig1_pretrend.csv | 10 个周期均值、2 个控制期斜率、2 个 L 外推值 |
| figdata/fig2_correction.csv | S2 能量与钙不足比例；S1 钙第一天均值点估计 |
| figdata/tab1_flow.csv | 每周期 7 步人数；逐步排除不重复计数 |
| figdata/tab2_main.csv | Y1/Y2 × 两参照；DiD Taylor 推断与(a)(b)点估计 |
| figdata/supp_panel.csv | 10 项 × 两参照；BH-FDR 三档 |
| figdata/supp_day2.csv | S1 的 J→L 第二天直接描述性对照 |
| checks/ | 独立复算、样本数、Rao–Wu、NCI、失败重复、对账 |
| provenance/ | 只读输入哈希、软件源码、用户确认、核验与审计工程记录 |
| official/ | 原文提取、论文XML和白皮书图9页面截取；未新制分析图 |
| corrections/ | 更正触发登记；S2c未触发 |

## 推断与缺失字段

- 原 GO、Taylor p、BH-FDR q 来自 v1.0。
- 能量和钙不足比例的校正 CI 来自 S2；bootstrap 行不附 Taylor p。
- fig1 周期均值来自原始 XPT 的 W0 描述性复算；数值与 v1.0 一致。CI 使用各周期设计自由度的 t 临界值。斜率及外推参数沿用 B 阶段文件，未加协变量。
- fig2 钙第一天摄入均值的 10 行为 S1 点估计；其 CI 在 S2 未运行，保留 `NOT_RUN` / `NA`。不能用钙不足比例的 CI 替代。
- fig2 外推钙不足比例及差值的 CI 保留 `NO_VALID_RESULT`；没有从 170 个成功重复重算 CI。
- 论文对账同时保留 W0 所列条件和原论文明确的非禁食条件；主分析资格不变。
- 周末按用户确认沿用冻结的周六/周日：5/7、2/7；W0 原括注4/7、3/7的定义差异另列。

## 复核脚本

在独立的项目副本中从项目根目录运行；原封存目录只读，避免覆盖本次已交付的 W0 文件。

```sh
Rscript DR-MODE-01/W0_audit/scripts/W0_numeric.R
Rscript DR-MODE-01/W0_audit/scripts/W0_model_audit.R
python3 DR-MODE-01/W0_audit/scripts/W0_deliverables.py
python3 DR-MODE-01/W0_audit/scripts/W0_final_QA.py
```

依赖：R survey、haven、jsonlite、ncimultivar 1.1.2；Python 3 标准库。原论文 XML、用户确认及输入快照保留在相应目录。
