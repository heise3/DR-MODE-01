"""Figures for DR-MODE-01 manuscript. Inputs: W0_audit/figdata + W0_audit/checks (read-only).
Usage: python make_figures.py <W0_audit_dir> <out_dir>"""
import sys, os, numpy as np, pandas as pd
import matplotlib as mpl
mpl.use("Agg")  # Preserve exact physical dimensions without native-window pixel rounding.
import matplotlib.pyplot as plt
from scipy import stats

W0, OUT = sys.argv[1], sys.argv[2]
FD = os.path.join(W0, "figdata"); CK = os.path.join(W0, "checks")
mpl.rcParams.update({
    "xtick.direction": "out", "ytick.direction": "out", "text.color": "#0b0b0b",
    "axes.labelcolor": "#0b0b0b", "xtick.color": "#0b0b0b", "ytick.color": "#0b0b0b",
    "font.family": "DejaVu Sans", "font.size": 8, "axes.titlesize": 8,
    "axes.labelsize": 8, "xtick.labelsize": 7.5, "ytick.labelsize": 7.5,
    "axes.spines.top": False, "axes.spines.right": False, "axes.linewidth": 0.6,
    "xtick.major.width": 0.6, "ytick.major.width": 0.6, "xtick.major.size": 3,
    "ytick.major.size": 3, "legend.frameon": False, "legend.fontsize": 7.5,
    "pdf.fonttype": 42, "svg.fonttype": "none", "savefig.dpi": 600,
})
INK, INK2, GRID = "#0b0b0b", "#52514e", "#d9d8d4"
CTRL, TREAT, REF2 = "#52514e", "#eb6834", "#2a78d6"   # control cycles / 2021-23 / second reference
MID = {"G": 2012, "H": 2014, "I": 2016, "J": 2018, "L": 2022.7}
LAB = {"G": "2011–\n2012", "H": "2013–\n2014", "I": "2015–\n2016", "J": "2017–\n2018", "L": "2021–\n2023"}

def panel_tag(ax, t):
    ax.text(-0.13, 1.04, t, transform=ax.transAxes, fontsize=10, fontweight="bold", va="bottom", color=INK)

def save(fig, name):
    if name == "Figure2_within_person_differences": fig.subplots_adjust(left=.09,right=.985,bottom=.19,top=.87,wspace=.42)
    elif name == "Figure3_correction_impact": fig.subplots_adjust(left=.23,right=.985,bottom=.19,top=.88,wspace=.70)
    elif name == "FigureS1_secondary_panel": fig.subplots_adjust(left=.13,right=.99,bottom=.18,top=.82,wspace=.76)
    elif name == "FigureS2_items_pretrend": fig.subplots_adjust(left=.23,right=.97,bottom=.19,top=.88)
    for ext in ("pdf", "png", "svg"):
        fig.savefig(os.path.join(OUT, f"{name}.{ext}"), bbox_inches=None, dpi=600, facecolor="white")
    plt.close(fig)

# ---------------- Figure 1 ----------------
f1 = pd.read_csv(os.path.join(FD, "fig1_pretrend.csv"))
pd_ = pd.read_csv(os.path.join(CK, "paired_differences.csv"))

def trend_panel(ax, outcome, ylab, yfmt=None):
    cm = f1[(f1.record_type == "cycle_mean") & (f1.outcome == outcome)].set_index("cycle")
    sl = f1[(f1.record_type == "control_linear_slope") & (f1.outcome == outcome)].iloc[0]
    ex = f1[(f1.record_type == "L_linear_extrapolation") & (f1.outcome == outcome)].iloc[0]
    ax.axhline(0, color=INK2, lw=0.6, zorder=1)
    xs = np.array([2011.4, 2023.3])
    ax.plot(xs, ex.estimate + sl.estimate * (xs - MID["L"]), ls=(0, (3, 2)), color=CTRL, lw=1, zorder=2,
            label="Linear trend in 2011–2018, extrapolated")
    # extrapolated point
    xe = MID["L"] - 0.55
    ax.errorbar(xe, ex.estimate, yerr=[[ex.estimate - ex.ci_low], [ex.ci_high - ex.estimate]], fmt="o",
                mfc="white", mec=CTRL, ecolor=CTRL, ms=5.5, mew=1.1, elinewidth=1, capsize=0, zorder=4)
    for c in "GHIJL":
        r = cm.loc[c]; col = TREAT if c == "L" else CTRL
        ax.errorbar(MID[c], r.estimate, yerr=[[r.estimate - r.ci_low], [r.ci_high - r.estimate]], fmt="o",
                    color=col, ms=6, elinewidth=1.4, capsize=0, zorder=5, mec="white", mew=0.6)
    ax.set_xticks([MID[c] for c in "GHIJL"]); ax.set_xticklabels([LAB[c] for c in "GHIJL"])
    ax.set_xlim(2011, 2023.7); ax.set_ylabel(ylab)
    ax.yaxis.grid(True, color=GRID, lw=0.5); ax.set_axisbelow(True)
    return cm, ex

fig, axes = plt.subplots(1, 2, figsize=(180/25.4, 80/25.4), gridspec_kw={"wspace": 0.42})
ax = axes[0]
cm, ex = trend_panel(ax, "Y2", "Day 2 − Day 1, log energy")
ax.set_ylim(-0.135, 0.045)
ax.annotate("Recall 1 in person\nRecall 2 by phone", xy=(2015, -0.125), ha="center", color=CTRL, fontsize=7)
ax.annotate("Both recalls\nby phone", xy=(MID["L"] - 0.65, 0.027), ha="right", va="center", color=TREAT, fontsize=7)
ax.text(MID["L"] - 0.55 - 0.3, ex.ci_low + 0.004, "Extrapolated\nfrom trend", ha="right", va="bottom", fontsize=7, color=CTRL)
ax.set_title("Signed within-person difference", loc="left", color=INK)
panel_tag(ax, "a")

ax = axes[1]
e = pd_[pd_.outcome == "energy_kcal"].set_index("cycle")
for c in "GHIJL":
    r = e.loc[c]; t = stats.t.ppf(0.975, r.df); col = TREAT if c == "L" else CTRL
    m, s = r.mean_absolute_individual_D, r.mean_absolute_individual_D_se
    ax.errorbar(MID[c], m, yerr=t * s, fmt="o", color=col, ms=6, elinewidth=1.4, capsize=0, mec="white", mew=0.6, zorder=5)
ax.set_xticks([MID[c] for c in "GHIJL"]); ax.set_xticklabels([LAB[c] for c in "GHIJL"])
ax.set_xlim(2011, 2023.7); ax.set_ylim(0, 800)
ax.set_ylabel("Mean |Day 2 − Day 1|, kcal")
ax.yaxis.grid(True, color=GRID, lw=0.5); ax.set_axisbelow(True)
ax.set_title("Absolute within-person difference", loc="left", color=INK)
panel_tag(ax, "b")
for a in axes:
    plt.setp(a.get_xticklabels(), rotation=0)
save(fig, "Figure2_within_person_differences")

# ---------------- Figure 2 ----------------
f2 = pd.read_csv(os.path.join(FD, "fig2_correction.csv"))
J = pd_[(pd_.cycle == "J") & (pd_.outcome == "energy_kcal")].iloc[0]
fig, axes = plt.subplots(1, 2, figsize=(180/25.4, 80/25.4), gridspec_kw={"wspace": 0.55, "width_ratios": [1.25, 1]})
ax = axes[0]
en = f2[(f2.endpoint == "energy") & (f2.scale == "kcal") & (f2.statistic == "mean")].set_index("scenario")
rows = [("original", "As reported (phone)", INK2), ("control_mean", "Mode-corrected:\ncontrol-mean reference", TREAT),
        ("linear_extrapolation", "Mode-corrected:\ntrend reference", REF2)]
tJ = stats.t.ppf(0.975, J.df)
ax.axvspan(J.day1_mean - tJ * J.day1_se, J.day1_mean + tJ * J.day1_se, color="#ecebe8", lw=0, zorder=0)
ax.axvline(J.day1_mean, color=INK2, lw=0.8, ls=(0, (3, 2)), zorder=1)
ax.text(J.day1_mean, 2.62, "2017–18 mean\n(in person)", ha="center", va="bottom", fontsize=7, color=INK2, bbox=dict(fc="white", ec="none", pad=0.6))
for i, (k, lab, col) in enumerate(rows):
    r = en.loc[k]; y = 2 - i
    ax.errorbar(r.estimate, y, xerr=[[r.estimate - r.ci_low], [r.ci_high - r.estimate]], fmt="o", color=col,
                ms=5.5, elinewidth=1.4, capsize=0, mec="white", mew=0.6, zorder=5)
    ax.text(r.ci_high + 8, y, f"{r.estimate:,.0f}", va="center", fontsize=7, color=INK)
ax.set_yticks([2, 1, 0]); ax.set_yticklabels([r[1] for r in rows])
ax.set_ylim(-0.6, 3.2); ax.set_xlim(1950, 2400)
ax.set_xlabel("Mean day-1 energy (kcal/d)")
ax.set_xticks([2000, 2200, 2400])
ax.xaxis.grid(True, color=GRID, lw=0.5); ax.set_axisbelow(True)
ax.spines["left"].set_visible(False); ax.tick_params(axis="y", length=0)
panel_tag(ax, "a")

ax = axes[1]
ca = f2[(f2.endpoint == "calcium") & (f2.scale == "percent") & (f2.scenario.isin(["original", "control_mean"]))].set_index("scenario")
dd = f2[(f2.endpoint == "calcium") & (f2.statistic == "corrected_minus_original") & (f2.scenario == "control_mean")].iloc[0]
for i, (k, lab, col) in enumerate([("original", "As reported", INK2), ("control_mean", "Mode-corrected", TREAT)]):
    r = ca.loc[k]
    ax.errorbar(i, r.estimate, yerr=[[r.estimate - r.ci_low], [r.ci_high - r.estimate]], fmt="o", color=col,
                ms=6.5, elinewidth=1.6, capsize=0, mec="white", mew=0.6, zorder=5)
    ax.text(i + 0.1, r.estimate, f"{r.estimate:.1f}%", va="center", fontsize=7, color=INK)
ax.set_xticks([0, 1]); ax.set_xticklabels(["As reported", "Mode-corrected"])
ax.set_xlim(-0.45, 1.6); ax.set_ylim(40, 58)
ax.set_ylabel("Usual calcium intake below EAR (%)")
ax.yaxis.grid(True, color=GRID, lw=0.5); ax.set_axisbelow(True)
ax.text(0.5, 56.6, f"Difference {dd.estimate:.1f} pp\n(95% CI: {dd.ci_low:.1f}, {dd.ci_high:.1f})".replace("-", "−"),
        ha="center", va="top", fontsize=7, color=INK)
panel_tag(ax, "b")
save(fig, "Figure3_correction_impact")

# ---------------- Supplementary Figure S1: secondary panel ----------------
sp = pd.read_csv(os.path.join(FD, "supp_panel.csv"))
NAMES = {"total_sugars": "Total sugars", "alcohol": "Alcohol", "caffeine": "Caffeine", "moisture": "Food moisture",
         "iron": "Iron", "calcium": "Calcium", "sodium": "Sodium", "fiber": "Dietary fiber",
         "protein_energy_pct": "Protein, % energy", "fat_energy_pct": "Fat, % energy"}
logv = ["caffeine", "alcohol", "total_sugars", "sodium", "moisture", "fiber", "calcium", "iron"]
pct = ["protein_energy_pct", "fat_energy_pct"]
fig, axes = plt.subplots(1, 2, figsize=(180/25.4, 85/25.4), gridspec_kw={"wspace": 0.6, "width_ratios": [1.6, 1]})
for ax, items, islog, xl in [(axes[0], logv, True, "Mode effect on day-1 report (%)"),
                             (axes[1], pct, False, "Mode effect (percentage points)")]:
    ax.axvline(0, color=INK2, lw=0.6)
    for j, it in enumerate(items):
        for k, (ref, col, off, mk) in enumerate([("control_mean", TREAT, 0.17, "o"), ("linear_extrapolation", REF2, -0.17, "s")]):
            r = sp[(sp.outcome == it) & (sp.reference == ref)].iloc[0]
            f = (lambda v: 100 * (np.exp(v) - 1)) if islog else (lambda v: v)
            est, lo, hi = f(r.mode_effect), f(r.mode_ci_low), f(r.mode_ci_high)
            y = len(items) - 1 - j + off
            filled = r.q_BH < 0.05
            ax.errorbar(est, y, xerr=[[est - lo], [hi - est]], fmt=mk, color=col, ms=5, elinewidth=1.2, capsize=0,
                        mfc=col if filled else "white", mec="white" if filled else col, mew=0.6 if filled else 1.1, zorder=5,
                        label=None if j else ("Control-mean reference" if k == 0 else "Trend reference"))
    ax.set_yticks(range(len(items))); ax.set_yticklabels([NAMES[i] for i in items][::-1])
    ax.set_xlabel(xl); ax.xaxis.grid(True, color=GRID, lw=0.5); ax.set_axisbelow(True)
    ax.spines["left"].set_visible(False); ax.tick_params(axis="y", length=0)
axes[0].legend(loc="lower left", bbox_to_anchor=(0, 1.0), ncol=2, handletextpad=0.3, columnspacing=1.2)
axes[1].set_ylim(-0.6, 1.6)
panel_tag(axes[0], "a"); panel_tag(axes[1], "b")
save(fig, "FigureS1_secondary_panel")

# ---------------- Supplementary Figure S2: Y1 pretrend ----------------
fig, ax = plt.subplots(figsize=(88/25.4, 80/25.4))
trend_panel(ax, "Y1", "Day 2 − Day 1, items reported")
ax.set_title("Number of items reported", loc="left", color=INK)
save(fig, "FigureS2_items_pretrend")
# Study design schematic: no outcome data, only previously reported schedules.
from pathlib import Path
import runpy
runpy.run_path(str(Path(__file__).with_name('make_figure1.py')), run_name='__main__')
