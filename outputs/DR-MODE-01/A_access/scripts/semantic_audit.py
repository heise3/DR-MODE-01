from pathlib import Path
import json
root=Path('outputs/DR-MODE-01')
out=[]; md=['# A1 语义原文核验','', '来源为下载并保留 SHA-256 的 CDC 公开 codebook。每个文件分别核验。','']
for cy,yr in [('G',2011),('H',2013),('I',2015),('J',2017),('L',2021)]:
 for day in [1,2]:
  stem=f'DR{day}TOT_{cy}'; lines=(root/f'A_access/codebooks/{stem}.txt').read_text().splitlines()
  def section(var):
   inds=[i for i,s in enumerate(lines) if s.startswith(var+' - ')]
   i=inds[-1]; j=lines.index('English Text:',i)+1
   return lines[j],j+1
  db,dbline=section(f'DR{day}DBIH'); nf,nfline=section(f'DR{day}TNUMF')
  mode=[(i+1,s) for i,s in enumerate(lines) if 'first dietary recall interview' in s and ('in-person' in s or 'telephone' in s)]
  water=[(i+1,s) for i,s in enumerate(lines) if 'including all types of water' in s]
  supp=[(i+1,s) for i,s in enumerate(lines) if 'do not include nutrients obtained from dietary supplement' in s]
  if not supp: supp=[(i+1,s) for i,s in enumerate(lines) if 'dietary supplements' in s and 'foods/beverages' in s]
  allowed_nf=['Total number of foods/beverages reported in the individual foods file','Total number of foods reported in the individual foods file']
  ok=(db=='Number of days between intake day and the day of family questionnaire administered in the household.' and nf in allowed_nf and bool(mode) and bool(water) and bool(supp))
  out.append({'cycle':cy,'day':day,'file':stem,'DBIH_definition':db,'TNUMF_definition':nf,'mode_present':bool(mode),'water_included':bool(water),'supplement_separation_documented':bool(supp),'pass':ok})
  md += [f'## {stem}', '',f'[CDC source](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/{yr}/DataFiles/{stem}.htm)', '',f'- DBIH，提取文本第 {dbline} 行：{db}',f'- TNUMF，提取文本第 {nfline} 行：{nf}']
  for typ,entries in [('访谈方式',mode),('饮水范围',water),('补充剂边界',supp)]:
   for line,s in entries[:1]:md += ['',f'{typ}，提取文本第 {line} 行：','',f'> {s}']
  md += ['',f'判定：{"PASS" if ok else "FAIL"}','']
(root/'A_access/semantic_audit.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
md += ['## 补充核对','', '- DRABF 指婴儿在任一回顾日摄入母乳；它不是“哺乳母亲”指标。本合同筛选按 DRABF=1 执行，未额外排除哺乳母亲。', '- G/H 的代答字段是 DRxMNRSP；I/J/L 为 DRxMRESP。自答均为代码 1，可一致映射为是否代答。', '- DBIH 衡量摄入日与家庭问卷日的距离，并不是直接提供的两次访谈日期。依合同取两字段差的绝对值；两个摄入日均对应访谈前一日。成人已观测记录的有符号间隔均为正，且间隔模 7 与两天星期差完全一致。缺失不插补。', '- 白皮书 p6 对间隔分析使用受限数据的表述保留为来源差异；本项目只使用公开 DBIH 派生量，不声称重现该受限数据分析。', '- DRxTNUMF 是 individual foods 文件中的记录条数，包含水；不是唯一食物种数，也不是进食次数。作为补充剂分类的产品不纳入；被分类为食品或饮料的蛋白粉等仍可纳入。','']
md += ['- G 周期 TNUMF 的文字为 foods，H–L 为 foods/beverages；G 的 component description 同样包含食品、饮料、各类水，且 water-only 注释明确水记录计入条数。因此判为文字更新、变量范围一致；没有把逐字相同当作语义一致的必要条件。','']
(root/'A_access/A1_semantic_verification.md').write_text('\n'.join(md))
print(json.dumps({'n_file_semantic_checks':len(out),'all_pass':all(r['pass'] for r in out)}))
