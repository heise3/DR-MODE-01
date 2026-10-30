"""P1b schematic: shared proportional time axis. No participant outcome data."""
from pathlib import Path
import json
import matplotlib as mpl
mpl.use('Agg')
import matplotlib.pyplot as plt
O=Path(__file__).resolve().parents[1]
spec=json.loads((O/'config/P1b_descriptive_spec.json').read_text())['figure1']
GRAY,ORANGE,INK,GRID='#52514e','#eb6834','#0b0b0b','#d9d8d4'
mpl.rcParams.update({'font.family':'DejaVu Sans','font.size':8,'axes.labelsize':8,'xtick.labelsize':7.5,'pdf.fonttype':42,'svg.fonttype':'none','axes.linewidth':.6})
fig,ax=plt.subplots(figsize=(180/25.4,96/25.4))
fig.subplots_adjust(left=.22,right=.98,bottom=.27,top=.94)
ax.set_xlim(-.4,17.8);ax.set_ylim(-.38,1.80)
for side in ['left','right','top']:ax.spines[side].set_visible(False)
ax.spines['bottom'].set_color(INK)
ax.set_yticks([]);ax.set_xticks(spec['ticks']);ax.set_xlabel(spec['time_axis'],labelpad=6,color=INK)
ax.tick_params(axis='x',width=.6,length=3,color=INK)
ax.xaxis.grid(True,color=GRID,lw=.45);ax.set_axisbelow(True)
y1,y2=1.15,.15
for y in [y1,y2]:ax.hlines(y,0,17,color=GRAY,alpha=.32,lw=.65,zorder=1)
ax.text(-.075,y1,'2011–2018',transform=ax.get_yaxis_transform(),ha='right',va='center',fontweight='bold',color=GRAY,fontsize=8)
ax.text(-.075,y2,'2021–2023',transform=ax.get_yaxis_transform(),ha='right',va='center',fontweight='bold',color=GRAY,fontsize=8)
def point(x,y,color):ax.plot(x,y,'o',mfc=color,mec='white',mew=.6,ms=5.6,zorder=5)
def window(lo,hi,mid,y,color):
    ax.hlines(y,lo,hi,color=color,alpha=.23,lw=6,zorder=2)
    point(mid,y,color)
point(0,y1,GRAY);point(0,y2,GRAY)
window(3,10,6.5,y1,GRAY);window(3,7,5,y2+.025,ORANGE);window(6,17,11.5,y2-.025,GRAY)
ax.text(0,y1+.22,'MEC examination\nFirst recall in person',ha='center',va='bottom',fontsize=7.3,color=INK)
ax.text(6.5,y1+.22,'Second recall\nTelephone',ha='center',va='bottom',fontsize=7.3,color=INK)
ax.text(6.5,y1-.18,'6.5 days (3–10)',ha='center',va='top',fontsize=7.3,color=INK)
ax.text(0,y2+.22,'MEC\nexamination',ha='center',va='bottom',fontsize=7.3,color=INK)
ax.text(5,y2+.22,'First recall\nTelephone',ha='center',va='bottom',fontsize=7.3,color=INK)
ax.text(11.5,y2+.22,'Second recall\nTelephone',ha='center',va='bottom',fontsize=7.3,color=INK)
ax.text(5,y2-.18,'5 days (3–7)',ha='center',va='top',fontsize=7.3,color=INK)
ax.text(11.5,y2-.18,'11.5 days (6–17)',ha='center',va='top',fontsize=7.3,color=INK)
formula='D = Y(day 2) − Y(day 1)     DiD = E[D | 2021–2023] − E[D | control reference]'
fig.text(.5,.080,formula,ha='center',va='center',fontsize=7.3,color=INK)
fig.text(.5,.030,'Mode effect = −DiD',ha='center',va='center',fontsize=7.5,color=INK)
for ext in ['pdf','svg','png']:fig.savefig(O/'figures'/f'Figure1_study_design.{ext}',dpi=600,facecolor='white')
plt.close(fig)
(O/'qa/figure1_geometry.json').write_text(json.dumps(dict(width_mm=180,height_mm=96,axis_ticks=spec['ticks'],axis_label=spec['time_axis'],points=[{'period':'2011–2018','event':'first_recall','day':0},{'period':'2011–2018','event':'second_recall','day':6.5,'range':[3,10]},{'period':'2021–2023','event':'MEC','day':0},{'period':'2021–2023','event':'first_recall','day':5,'range':[3,7]},{'period':'2021–2023','event':'second_recall','day':11.5,'range':[6,17]}],formula='Mode effect = −DiD'),ensure_ascii=False,indent=2)+'\n')
print('Figure 1: shared linear day axis; complete')
