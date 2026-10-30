# A0 查重复核

检索日期：2026-10-29（America/Los_Angeles）。6 个检索式，达到合同上限；后续仅打开已命中的页面和合同给定的来源，没有追加查重检索。

| 次数 | 原始检索式 | 覆盖 |
|---|---|---|
| 1 | NHANES 2021 2023 dietary recall mode change usual intake inadequacy 2025 2026 | 模式效应、常规摄入、不足率 |
| 2 | site.cdc.gov OR site.ars.usda.gov NHANES 2021 2023 dietary telephone mode effect 2025 2026 | CDC/USDA 官方产出 |
| 3 | NHANES dietary mode change 2021 2023 preprint medrxiv 2025 2026 | 预印本 |
| 4 | NHANES 2021 2023 dietary "mode" "2026" journal usual intake | 2026 期刊 |
| 5 | NHANES dietary recall mode change 2025 2026 NUTRITION conference abstract telephone | 2025–2026 会议摘要 |
| 6 | DaDiet Dempsey Impacts Data Collection Changes NHANES GRAS Dietary Exposures Food Means 2025 | 已知博客复核 |

STOP_DUP 要求同一合格同行评议或官方产出同时满足：①以统计检验估计 L 第一天模式效应，采用个人内差值跨周期比较或等价设计；②量化该效应对常规摄入或摄入不足患病率的影响。

| 来源 | 已核验内容 | 条件① | 条件② | STOP_DUP |
|---|---|---|---|---|
| [Williams et al., NCHS 白皮书，March 2025](https://wwwn.cdc.gov/nchs/data/Nhanes/Public/2021/Whitepapers/Aug2023-What-We-Eat-In-America-Dietary-Data-Whitepaper.pdf) | p6–7、9、18–23：存在第一天均值的趋势/周期比较检验；个人内两天差值的跨周期比较为描述性，未检验；未做常规摄入或不足率校正 | 否 | 否 | 否 |
| [DaDiet / Dempsey, 2025-06-18](https://www.dadiet.com/articles/impacts-of-data-collection-changes-in-nhanes-on-gras-dietary-exposures-food-means/) | 成人、每周期两天配对设计检验和 BH；明确为博客而非同行评议；自报摄入“与平时相同”的筛选不是常规摄入分布模型 | 非合格产出，且不构成模式效应的跨周期交互检验 | 否 | 否 |
| [NCHS Data Brief 536, 2025](https://www.ncbi.nlm.nih.gov/books/NBK618449/pdf/Bookshelf_NBK618449.pdf) | 第一日超加工食品能量占比及周期比较；承认模式变化 | 否 | 否 | 否 |
| [NCHS Data Brief 568, 2026-09-02](https://stacks.cdc.gov/view/cdc/252466/cdc_252466_DS1.pdf) | 第一日非酒精饮料构成及趋势；方法注明模式变化 | 否 | 否 | 否 |
| [Murphy et al., Nutrition and Health, 2026-09-02](https://journals.sagepub.com/doi/10.1177/02601060261480196) | 公开摘要：含糖饮料摄入趋势，线性/logistic 回归；正文受限，未访问付费正文 | 公开摘要不符合 | 公开摘要未报告 | 未见触发证据 |
| [Modeling Usual Nutrient Intake Distribution, J Nutr 2026](https://doi.org/10.1016/j.tjnut.2026.101542) | 检索返回摘要为法国 INCA3 的常规摄入方法比较；直接打开出版社返回 403 | 否，非本次 NHANES 模式比较 | 非本题 | 否 |
| [NCHS 官方分析指南目录](https://wwwn.cdc.gov/nchs/nhanes/analyticguidelines.aspx) | 目录包含 2026 年指南；膳食模式条目仍链接上述白皮书。目录日期 February 2025，PDF 封面 March 2025，保留此日期差异 | 未见新增合格产出 | 未见 | 否 |

2025–2026 预印本和会议摘要定向检索未返回符合双条件的候选。USDA 定向检索未找到独立满足双条件的报告；不能据此认定所有未被索引的产出均不存在。

**判定：PASS（本次有界检索未发现 STOP_DUP 触发证据）。** 不是“证实无重复”或“证实创新性”。检索命中的部分论文仅核验公开摘要，已标明阅读边界。

合同背景中的“白皮书周期间无检验”仅适用于个人内两天差值的跨周期比较；白皮书对第一天均值做了趋势与周期检验，不能概括为所有分析均无检验。白皮书封面也注明其经历有限审阅，估计不是正式 NCHS 估计。C 阶段增量门保持必要条件。
