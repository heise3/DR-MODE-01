from pathlib import Path
import csv
import json
import math

root = Path('outputs/S2_uncertainty')

def rows(path):
    with path.open(newline='') as f:
        return list(csv.DictReader(f))

estimates = rows(root / 'S2_1_replicate_estimates.csv')
summary = rows(root / 'S2_1_summary_CI.csv')
scenarios = rows(root / 'provenance/NCI_all_scenario_status.csv')
audit = rows(root / 'provenance/NCI_replicate_input_audit.csv')
assert [int(r['replicate']) for r in estimates] == list(range(201))
assert len(scenarios) == 603
lookup = {(int(r['replicate']), r['reference'], r['nutrient']): r for r in audit}
max_beta_error = 0.0
invalid_expected = set()
invalid_observed = set()
for r in scenarios:
    rep = int(r['replicate'])
    sc = r['scenario']
    if sc == 'original':
        assert r['status'] == 'COMPLETE'
        continue
    bad = False
    for nutrient, field in [('calcium', 'DiD_calcium'), ('iron', 'DiD_iron_nuisance')]:
        a = lookup[(rep, sc, nutrient)]
        max_beta_error = max(max_beta_error, abs(float(r[field]) - float(a['DiD'])))
        assert int(r[f'negative_{nutrient}_persons']) == int(a['negative_corrected_persons'])
        bad |= int(a['negative_corrected_persons']) > 0
    if bad:
        invalid_expected.add((rep, sc))
    if r['status'] != 'COMPLETE':
        invalid_observed.add((rep, sc))
        assert 'NEGATIVE_CORRECTED_AMOUNT' in r['reason']
    else:
        assert float(r['max_Rhat']) < 1.05
assert invalid_observed == invalid_expected
assert max_beta_error < 1e-12

variance_errors = []
for r in summary:
    endpoint, scale, sc = r['endpoint'], r['scale'], r['scenario']
    change = r['statistic'] == 'corrected_minus_original'
    if endpoint == 'energy':
        field = f'energy_{scale}_' + ('change_' if change else '') + sc
    else:
        field = 'calcium_' + ('change_' if change else '') + sc
    values = [float(x[field]) for x in estimates if x[field] != 'NA']
    point = float(estimates[0][field])
    assert abs(float(r['estimate']) - point) < 1e-10
    assert int(r['valid_replicates']) == len(values) - 1
    if len(values) != 201:
        assert r['se'] == r['ci_low'] == r['ci_high'] == 'NA'
        assert r['CI_status'].startswith('NO_VALID_RESULT')
        continue
    se = math.sqrt(math.fsum((v - point)**2 for v in values[1:]) / 199)
    variance_errors.append(abs(se - float(r['se'])))
    assert abs(se - float(r['se'])) < 1e-10
    lo, hi = float(r['ci_low']), float(r['ci_high'])
    assert abs((lo + hi) / 2 - point) < 1e-9
    assert int(r['df']) == (15 if sc == 'original' else 77)
    if change:
        assert (r['CI_includes_zero'] == 'TRUE') == (lo <= 0 <= hi)
        if endpoint == 'calcium':
            assert (r['CI_includes_minus_2_pp'] == 'TRUE') == (lo <= -2 <= hi)
            assert (r['reduction_CI_includes_plus_2_pp'] == 'TRUE') == (-hi <= 2 <= -lo)
            assert abs(float(r['reduction_ci_low_pp']) + hi) < 1e-10
            assert abs(float(r['reduction_ci_high_pp']) + lo) < 1e-10

out = {
    'status': 'PASS',
    'bootstrap_replicates': 200,
    'full_sample_rows': 1,
    'NCI_scenario_records_including_full_sample': len(scenarios),
    'max_worker_vs_precomputed_DiD_difference': max_beta_error,
    'unexpected_failed_scenarios': 0,
    'input_domain_failed_replicates': sorted(rep for rep, sc in invalid_observed),
    'max_independent_SE_recalculation_difference': max(variance_errors),
    'all_incomplete_CIs_left_uncomputed': True,
    'paired_difference_and_threshold_flags_verified': True,
    'original_L_df': 15,
    'pooled_correction_df': 77,
}
(root / 'provenance/final_numerical_QA.json').write_text(json.dumps(out, indent=2) + '\n')
print(json.dumps(out, indent=2))
