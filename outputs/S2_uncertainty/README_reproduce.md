# S2 reproduction

Run from the project root. Original inputs in `outputs/DR-MODE-01/` and `outputs/S1_writing/` are read only. All scripts write within `outputs/S2_uncertainty/`.

Requirements: R with survey, jsonlite, coda, and the official ncimultivar 1.1.2 package installed as in S1; Python 3 standard library. No substitute usual-intake method or new nutrient outcome is used. Iron remains NO_VALID_RESULT and appears only as the unchanged S1 joint-model nuisance input.

1. Read `IMPLEMENTATION_S2.md` and `S2_0_calcium_eligibility.csv`.
2. Generate the fixed 200 PSU bootstrap replicates and re-estimate all DiDs and energy means:

```sh
Rscript outputs/S2_uncertainty/scripts/prepare_replicates.R
```

3. Reproduce the full sample at S1 settings, then run four worker processes (the same commands may be run sequentially):

```sh
Rscript outputs/S2_uncertainty/scripts/run_nci_replicates.R 0
Rscript outputs/S2_uncertainty/scripts/run_nci_replicates.R 1 4
Rscript outputs/S2_uncertainty/scripts/run_nci_replicates.R 2 4
Rscript outputs/S2_uncertainty/scripts/run_nci_replicates.R 3 4
Rscript outputs/S2_uncertainty/scripts/run_nci_replicates.R 4 4
```

`runtime_control.json` contains the original 36-hour deadline. For a later independent reproduction, use a separate project copy with the same relative input paths, an empty `outputs/S2_uncertainty/replicates/` directory, and a newly recorded execution start/deadline in that copy. Do not overwrite this completed package or reset its deadline. Workers skip folders with COMPLETE.json, making interruptions resumable within the original budget.

4. Require all 200 replicate attempt folders, then produce combined estimates and CIs:

```sh
Rscript outputs/S2_uncertainty/scripts/summarize_S2.R
python3 outputs/S2_uncertainty/scripts/final_numerical_QA.py
python3 outputs/S2_uncertainty/scripts/write_report_S2.py
```

The main replicate CSV has 201 rows: full sample (replicate 0) and exactly 200 bootstrap replicates. Each original/corrected/difference is paired within the same replicate. Negative amounts are recorded before NCI fitting and are not clipped or silently deleted. No CI is calculated from a reduced set of successful replicates.

`nci_streaming.R` retains official NCI initialization, bivariate random effects and calcium backtransformation, vectorizes the nuisance integration, and stores aggregate Monte Carlo draws. Its numerical equivalence with all saved S1 simulations was verified before the replicate run. This is a computation optimization, not a method substitution.

Full-sample chain objects and all retained replicate chains, Rhat/ESS, Box-Cox estimates, minimum amounts, covariate encodings and simulation aggregates are under `replicates/`. Study N is people; chain draws and simulated records do not increase N.

The report distinguishes the main-text control-mean calcium result from the supplementary, reference-dependent extrapolation result. Original v1.0 GO and S1 files remain unchanged. Hash snapshots and final integrity checks are in `provenance/`.
