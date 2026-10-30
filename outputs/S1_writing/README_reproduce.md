# S1 reproduction

Run commands from the project root, which contains `outputs/DR-MODE-01/` and `outputs/S1_writing/`. The sealed v1.0 directory is read-only input. Do not run its original scripts in place; they write original result files.

Requirements: R 4.6.1 (the executed version), `haven`, `survey`, `jsonlite`, `coda`; Python 3 standard library. NCI package source 1.1.2 is bundled under `software/`, with the official download URL and source hash. No substitute method was used.

```sh
mkdir -p outputs/S1_writing/software/Rlib
R CMD INSTALL -l outputs/S1_writing/software/Rlib outputs/S1_writing/software/ncimultivar_1.1.2.tar.gz
Rscript outputs/S1_writing/scripts/S1_prepare_inputs.R
Rscript outputs/S1_writing/scripts/S1_acd.R
Rscript outputs/S1_writing/scripts/S1b_nci.R original
Rscript outputs/S1_writing/scripts/S1b_nci.R control_mean
Rscript outputs/S1_writing/scripts/S1b_nci.R linear_extrapolation
python3 outputs/S1_writing/scripts/S1_finalize.py
```

These commands overwrite only generated S1 files. To preserve this completed S1 snapshot while reproducing, copy the project inputs and S1 scripts into a new working directory first.

`S1_prepare_inputs.R` reconstructs the analytic inputs directly from all 15 sealed public XPT files using the sealed mappings. In the executed audit, its complete data frame was `identical()` to the v1.0 cached data. The NCI fits initially read that cache; the delivered script reads the verified compact S1 reconstruction. This path relocation changes no data or model. The exact executed cache-input script is retained in `S1b_C3c_usual_intake/engineering_attempts/`.

`S1b_nci.R` fixes four seeds, 12,000 iterations, 2,000 burn-in, and thinning 25; it saves full chain objects, retained traces, diagnostics, and pooled model objects. The distribution simulation uses 2,000 random-effect draws per person. `simulation_replicates.csv` contains aggregate Monte Carlo replicates, not additional people. Survey prevalence sampling uncertainty and DiD uncertainty are not calculated.

Raw second-day intake vectors receive no mode correction. NCI transforms and applies its documented minimum-amount preprocessing separately in each scenario; zeros below its estimated minimum are handled by the package. Per-scenario minima are recorded. All 4,041 model participants retain both recalls. Foods/beverages only; supplements are outside the frozen input.

`provenance/contract_line_diff.patch` is the actual comparison against the latest pasted contract. The older preflight JSON and report remain historical pending-state records; `contract_comparison_result.json`, `status_S1.json`, and `REPORT_S1.md` contain the final state.

`S1_finalize.py` verifies the 127 original files (including their manifest), original ZIP hash, exact carried raking fields, descriptive DiD identity, and model output aggregation. `SHA256SUMS_S1.txt` inventories the delivered S1 files.
