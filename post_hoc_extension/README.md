# Post hoc food-level extension (v1.1.0)

This extension was specified after the primary results and frozen before its own outcome estimation. It is not prospective external registration. It does not alter the original primary decision. No individual NHANES data, manuscripts, author contact sheets, submission files, or third-party binaries are included.

Frozen source commit: 7f6e1f2cef106e202c0e25494dc8c1ac63314da3, 2026-11-04 10:58:29 UTC. The original freeze record and all 19 frozen files are preserved byte-for-byte. The public release occurs after the extension analyses. The E01 correction handles singleton-response lm.wfit vector coefficients; the frozen original code is retained. All Taylor estimates were unchanged by this engineering correction.

Food and occasion components use the original fixed population, covariates and two reference models. The exact log-energy decomposition uses 20,850 positive-energy/count adults; complete-case models use 20,875. The item-count component failed the extrapolation-width pre-trend criterion, so its interpretation is conditional. Three nutrient pre-trends met the criterion: total sugars, alcohol and protein energy percentage. Calcium failed it and its usual-intake illustration is reference dependent. No NCI models were refitted for this extension. Original iron inadequacy remains invalid; fast-food correction remains not identified. Do not treat unrun/invalid estimates as negative results.

All 200 original Rao–Wu multiplier sets were reused. No new PSU draws were made. Other occasions had undefined R in 97 replicates; no R CI/P/q is supplied for that category. All DiD fits completed. Frozen numeric aggregates reside in DR-MODE-01/s2/*.csv. The claim ledger is in post_hoc_extension/claims_map_v1.7.csv; publication-only contact identifiers were omitted.

## Reproduction in a separate directory

Use the original v1.0.0 repository structure and the source-download manifest. Obtain public DR1TOT, DR2TOT and DEMO files for G/H/I/J/L in outputs/DR-MODE-01/A_access/data/, and DR1IFF/DR2IFF for the same cycles in DR-MODE-01/X1/data/. Do not overwrite an archived analysis workspace.

With R packages survey, haven, jsonlite and digest, run:

    Rscript DR-MODE-01/s2/scripts/prepare_clean_replay_inputs.R
    Rscript DR-MODE-01/s2/provenance/engineering_E01/analyze_E01.R

The first command recreates input caches and Y2 templates from public data and the exact saved PSU matrix without NCI modeling or new random sampling. It refuses an existing cache. The second verifies frozen hashes, calibrates pre-trends, reproduces the primary estimate, checks unit multipliers and runs the post hoc extension. The frozen source output paths must be used in the separate reproduction directory.

To verify archived hashes and algebra without fitting any model:

    python3 post_hoc_extension/verify_extension.py

The main README records how to reproduce the original primary, S1/S2 uncertainty, and X1 analyses. The original v1.0.0 tag and release remain intact.
