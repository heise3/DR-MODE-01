# DR-MODE-01 v1.0 复现入口

终局与局部 NOT_RUN 以 status.json、REPORT.md 为准。本文件不授权更改冻结规则或生成 v1.1。

目录内包含 18 个 CDC 公开 XPT（主分析 15、P 敏感性 3）、对应 codebook、来源与 SHA-256、冻结合同、分析代码及聚合结果。没有 RDC 文件。

分析单位为 cycle + SEQN 的个人；所有结果表中的 n_persons 为人数。NCI 预处理采用长表，但审计数量按不同 SEQN 报告。

依赖：Python 3 标准库；R、haven、survey、jsonlite。确切版本见 A_access/R_sessionInfo.txt。NCI 官方包为 ncimultivar 1.1.2，仅安装和输入审计已执行。

复现时先复制完整目录，避免覆盖这份终局。工作目录需包含 outputs/DR-MODE-01 和 work。执行顺序：

```bash
mkdir -p work
python3 outputs/DR-MODE-01/A_access/scripts/extract_codebooks.py
python3 outputs/DR-MODE-01/A_access/scripts/semantic_audit.py
Rscript outputs/DR-MODE-01/A_access/scripts/stage_a.R
Rscript outputs/DR-MODE-01/B_pretrend/stage_b.R
Rscript outputs/DR-MODE-01/C_main/stage_c12.R
Rscript outputs/DR-MODE-01/C_main/stage_c3ab.R
Rscript outputs/DR-MODE-01/C_main/sensitivities.R
Rscript outputs/DR-MODE-01/C_main/joint_raking_audit.R
Rscript outputs/DR-MODE-01/C_main/verify_primary_sandwich.R
```

上述代码在 B/C 入口读取已封存的先决门状态，并会在先决门未通过时中止。结果审核还应重新核对先前阶段是否仍与已封存状态相同；不能把状态文件中的 PASS 当作新数据版本已校准的证据。

如需重新下载同版本输入，download_public.py 下载主分析文件，添加 --P 下载 P 文件；下载记录包含原始 URL、最终 URL、HTTP、字节数与 SHA-256。现有文件不覆盖。核验新下载内容必须与清单一致，文件更新不能不加说明地替换本次输入。

NCI 安装来源与哈希见 C_main/NCI_software_provenance.json。将官方 ZIP 解压后的 tar.gz 用 R CMD INSTALL 安装到 work/Rlib，然后运行 C_main/nci_input_audit.R 可复现预处理审计。没有 MCMC、常规摄入或 EAR 患病率结果，不能用预处理输出代替。

权重、时间点、变量变换、缺失规则和模型公式见 config/execution_spec.json。初始映射草稿及修正原因保留在 config/implementation_audit.md。主 DiD 的 Taylor SE 另以矩阵 WLS + 分层 PSU sandwich 独立复算，见 C_main/independent_primary_QA.csv。

完整四维联合人口目标出现结构零，联合 raking 未产生效应结果；四个边际的 raking 是另列的补充计算，不能冒充联合分布已匹配。
