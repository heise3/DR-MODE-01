from pathlib import Path
import csv,json,hashlib
from openpyxl import load_workbook
from lxml import html
OUT=Path(__file__).resolve().parents[1];PROJECT=OUT.parents[1]
SRC=Path('/Volumes/RESCUE_5TB/DR-MODE-01_S2_food_decomposition')
cycles={'G':('2011-2012','WWEIA1112_foodcat_FNDDS.xlsx'),'H':('2013-2014','WWEIA1314_foodcat_FNDDS.xlsx'),
        'I':('2015-2016','WWEIA1516_foodcat_FNDDS.xlsx'),'J':('2017-2018','WWEIA1718_foodcat_FNDDS.xlsx'),
        'L':('2021-2023','2021-2023 FNDDS At A Glance - Foods and Beverages.xlsx')}
names={1:'Non-alcoholic beverages',2:'Alcoholic beverages',3:'Snacks and sweets',4:'Additions: fats, condiments and sugars',5:'Milk and dairy',6:'Mixed dishes',7:'Protein foods',8:'Grains',9:'Fruits and vegetables',10:'Other'}
def group(c):
    # These are official WWEIA category identifiers, never food-code leading digits.
    if 1000<=c<2000:return 5,'MILK AND DAIRY','Includes plant-based dairy in its official major heading'
    if 2000<=c<3000:return 7,'PROTEIN FOODS','Official major heading'
    if 3000<=c<4000:return 6,'MIXED DISHES','Official major heading'
    if 4000<=c<5000:return 8,'GRAINS','Official major heading'
    if 5000<=c<6000:return 3,'SNACKS AND SWEETS','Official major heading, including dairy desserts'
    if 6000<=c<7000:return 9,'FRUIT / VEGETABLES','Includes vegetable mixed dishes within this official heading'
    if 7500<=c<7600:return 2,'ALCOHOLIC BEVERAGES','Official major heading'
    if c in (7702,7704):return 10,'WATER: Plain Water','Plain water assigned to Other as requested'
    if 7800<=c<7900:return 1,'WATER: Flavored or Enhanced Water','Included among non-alcoholic beverages; only plain water excluded'
    if 7000<=c<7500:return 1,'BEVERAGES','Includes nutritional beverages; excludes milk and plain water'
    if 8000<=c<9000:return 4,'FATS AND OILS / CONDIMENTS AND SAUCES / SUGARS','Official headings pooled as prespecified additions'
    if c>=9000:return 10,'BABY FOODS AND FORMULAS / OTHER','Includes powders and official category 9999, not classified'
    raise ValueError(f'Unreviewed category {c}')
rows=[];cats={}
for cy,(ver,name) in cycles.items():
    p=SRC/name;w=load_workbook(p,read_only=True,data_only=True)
    vals=list(w.worksheets[0].values)
    if cy!='L':
        vals=vals[1:];idx=(0,1,2,3)
    else:vals=vals[2:];idx=(0,1,3,4)
    seen=set()
    for r in vals:
        if not r[0] or not isinstance(r[0],(int,float)):continue
        fc=int(r[idx[0]]);c=int(r[idx[2]]);g,head,reason=group(c)
        assert fc not in seen;seen.add(fc)
        z=dict(cycle=cy,FNDDS_version=ver,food_code=fc,food_description=r[idx[1]],wweia_category=c,
               category_description=r[idx[3]],official_major_heading=head,analysis_group=f'G{g}',group_label=names[g],
               H_omit=int(g<=4),coverage_unclassified=int(c==9999),mapping_reason=reason,source_file=name,
               source_sha256=hashlib.sha256(p.read_bytes()).hexdigest())
        rows.append(z);cats[(cy,c)]=dict((k,z[k]) for k in ['cycle','FNDDS_version','wweia_category','category_description','official_major_heading','analysis_group','group_label','H_omit','mapping_reason'])
with (OUT/'wweia_group_map.csv').open('w') as f:
    wr=csv.DictWriter(f,fieldnames=list(rows[0]));wr.writeheader();wr.writerows(rows)
with (OUT/'metadata/category_review.csv').open('w') as f:
    wr=csv.DictWriter(f,fieldnames=list(next(iter(cats.values()))));wr.writeheader();wr.writerows(cats.values())
occs=[]
for cy in cycles:
    for day in [1,2]:
        p=PROJECT/f'DR-MODE-01/X1/provenance/DR{day}IFF_{cy}.htm'
        doc=html.fromstring(p.read_bytes())
        h=doc.xpath(f'//*[@id="DR{day}_030Z"]')[0]
        # Codebook variable anchor is in a div; use the first frequency table after it.
        tables=h.xpath('following::table')
        selected=None
        for t in tables[:2]:
            tr=t.xpath('.//tr')
            if tr and 'Code or Value' in t.text_content():selected=t;break
        assert selected is not None,(cy,day)
        for tr in selected.xpath('.//tr')[1:]:
            cells=[' '.join(t.text_content().split()) for t in tr.xpath('./td')]
            if not cells:continue
            code=cells[0]
            if code=='.':grp='Other'
            elif code.isdigit():grp='Meals' if int(code) in [1,2,3,4,5,10,11,12,14] else 'Snacks_drinks' if int(code) in [6,7,9,13,15,16,17,18,19] else 'Other'
            else:continue
            occs.append(dict(cycle=cy,day=day,code=code,label=cells[1],analysis_group=grp,source=str(p.relative_to(PROJECT))))
with (OUT/'metadata/occasion_codebook_map.csv').open('w') as f:
    wr=csv.DictWriter(f,fieldnames=list(occs[0]));wr.writeheader();wr.writerows(occs)
print(json.dumps({'food_mapping_rows':len(rows),'reviewed_cycle_categories':len(cats),'occasion_codebook_rows':len(occs)}))
