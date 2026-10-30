# DR-MODE-01 / X1 下游趋势复核：执行合同 v1.0

冻结于任何 X1 个体快餐结局读取、计算或检验之前。原 v1.0/S1/S2/W0 只读，原 GO 不重新判定。所有新增文件仅位于 X1/。

## 用户指定对象与顺序

- 唯一结局：成人 ≥20 岁快餐供能比。每人每天 DRxIFF 中 DRxFS=3（Restaurant fast food/pizza）的 DRxIKCAL 之和，除以该人当天 DRxTKCAL，再乘 100。单位为 %；差值、DiD 和校正量单位为百分点（pp）。
- 校准：DB533 第一天、WTDRD1、成人定义；H、I、P、L，官方均值分别 14.1、13.1、13.4、11.7%。每周期绝对误差 ≤0.3 pp，否则 CALIBRATION_FAIL 并停止。
- 校准通过后：两天 Reliable、非母乳成人，WTDR2D，G–J 对照与 L，个人内 D=第二天−第一天；含 v1.0 相同协变量，分别使用对照均值和线性外推参照。
- G–J 前趋势门同 v1.0 B：同一结局的异质性 Wald p>0.05，且外推至 L 的均值 95% CI 宽度 <2×|对照期加权 D 均值|，两项均满足才 PASS。
- 前趋势 FAIL：报告 DiD，标注“不可校正”，不计算模式校正值，不重估趋势，终局 NOT_IDENTIFIED。
- 前趋势 PASS：L 第一天加上 DiD，按 DB533 H、I、P、L 序列重估线性趋势，报告校正前后斜率、P、H→L 变化；两种参照分别报告。
- 不确定性：直接复用 S2 的 Rao–Wu 200 组 PSU 重复权重矩阵（种子 2026102902），联合重估整条链路，不重抽或减少重复数。
- 判定：与 DB533 的显著下降结论相比，校正后趋势显著性（α=.05）或方向不同为 CHANGES_CONCLUSION；相同为 ROBUST；前趋势 FAIL 为 NOT_IDENTIFIED。两种参照各有判定，不凭结果选择参照；若不同则同时列出并注明依赖参照，不增设合并门。
- 工程做不了为 NOT_RUN；数据不可执行为 NO_VALID_RESULT；均不作为阴性，不换结局、人群、周期、协变量或门槛。

## 在结果前明确的实现细节

1. 校准用第一天 Reliable、年龄≥20、正第一天权重、DR1TKCAL>0 的人群；P 使用 WTDRD1PP。主分析沿用 v1.0 adult 标志和完整协变量；两天分母须为正，有限结局单列人数。无快餐但有有效 IFF 的人贡献 0%；0/0 为缺失，不加伪计数，不插补。不因未知来源而排除整个人；只将确认为 FS=3 的食物计入分子。有效非零总能量而完全没有 IFF 记录视为数据错误。
2. 先按人汇总再用调查权重求个人比例均值，不用总快餐能量除总能量。文件以 cycle+SEQN 和回顾日对应；检查每条 IFF 的 SEQN+DRxILINE 唯一性、汇总总能量与 TOT 一致性。
3. B 为未调整的 survey::svyglm(D~cycle) Wald F 与 D~time 线性模型；采用残差自由度的 t 区间。周期时间沿用 G=2012,H=2014,I=2016,J=2018,L=2022.7，中心 2015；权重 WTDR2D/4。
4. DiD 为 survey::svyglm(D~is_L+固定协变量)，线性参照另加 time。权重 WTDR2D/5；按 cycle×SDMVSTRA 与 cycle×SDMVSTRA×SDMVPSU 唯一编码，Taylor 方差；单 PSU 报错。协变量精确复用 S1 analysis_input.rds 中 v1.0 的两天周末（周六/日）、间隔、语言、代答、年龄组、性别，不新增变量。报告双侧 t p 与对应 Taylor CI。DiD 即 is_L 系数；模式包效应为 −DiD；校正为 +DiD。
5. 同样报告 200 重复的 DiD；其结果只用于不确定性，不能推翻前趋势门。复用 S2 scale=1/199、rscales=1、mse=TRUE，以全样本估计为中心；跨周期 DiD 的 t 区间使用原合并设计自由度 77。Taylor 与 bootstrap 分行。任何失败重复单列原因；少于 200 个成功重复则完整重复推断 NOT_RUN，不用成功子集凑齐。
6. 只有 B PASS 才计算 DB533 人群校正均值：原始 WTDRD1 成人 L 均值 + 配对人群 DiD；这需要将配对人群平均模式偏移推广至 DB533 第一天成人的假设。对均值作 pp 平移，不逐人裁剪为 [0,100]；若均值超界则 NO_VALID_RESULT。
7. 只有 B PASS 才重新拟合 DB533 线性趋势：H/I/P/L，时间 2014/2016/2018.6/2022.7；P 为 3.2 年、其他各 2 年，权重按周期时长/9.2 合并（P 用 WTDRD1PP），y~time，无新增协变量。仅线性趋势，不根据结果改成二次趋势。DB533 原始方向基准为负、P<.05；原始 H→L 目标变化 −2.4 pp。原始、两校正方案使用同一定义。

## 结果前记录的工程覆盖限制

只读预检：S2 矩阵有 G/H/I/J/L 共 74 层、151 PSU、200 重复；没有 P。P 的公开 DEMO 设计为 24 层、49 PSU（含一层 3 PSU），与 J 的公开 SEQN 和掩蔽层编码没有直接交集。P 包含 J 受试者，不能将 P 当独立周期另抽后与 S2 拼接。

先执行可执行的校准、B 与 DiD。如果 B PASS，只能在有经验证的公开 P–J 设计对应、且完整覆盖 P 新 PSU 时，执行要求的联合趋势重复推断；不存在该对应则该项 NOT_RUN，校正趋势 P/CI 不用“把 DiD 当常数”的替代结果补足，也不据此判 ROBUST/CHANGES_CONCLUSION。该限制在任何 X1 结果前记录；不改变用户门槛。B FAIL 时按原规则 NOT_IDENTIFIED，不启动趋势重估。

## 冻结前官方来源（不是本项目结果）

- NCHS DB533：<https://www.cdc.gov/nchs/products/databriefs/db533.htm>，表5：H 14.1%（N=5045），I 13.1%（N=5015），P 13.4%（N=7705），L 11.7%（N=4792）；均值 N 和 SE 仅对账，不新增校准门。
- DR1IFF_L：<https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2021/DataFiles/DR1IFF_L.htm>。
- P_DR1IFF：<https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/P_DR1IFF.htm>。
- P_DEMO：<https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/P_DEMO.htm>。

contract_sha256 写入 status_X1.json 与 provenance/freeze.json。冻结文件、S2 矩阵和既有包的哈希在结束时核验。输出 REPORT_X1.md、status_X1.json、figdata/x1_trend.csv；后者在未允许校正时只保留校准原始均值，并明确校正/趋势为 NOT_RUN。
