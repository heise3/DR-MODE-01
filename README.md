# DR-MODE-01: NHANES dietary-recall mode-change analysis

Version **v1.1.1** restores verbatim CSV line endings after the v1.1.0 GitHub text-import conversion. The v1.1.0 extension adds the post hoc food-level extension to the original **v1.0.0** release (2026-10-30). Both public releases followed their respective analyses; neither is external prospective registration. This repository archives code, locally frozen protocols, survey-bootstrap multipliers, aggregate results, diagnostics and the claim-to-source ledger for NHANES 2011–2018 and August 2021–August 2023. This public release is **not** a claim of prospective public registration. The original local freeze records and their hashes are preserved.

## Scope and provenance

The analysis uses only publicly available, de-identified NHANES files. No RDC data were used. Manuscripts, author contact information, submission documents, participant-level input/cache files and third-party software binaries are excluded. Public NHANES inputs are downloaded from CDC and checked against the original SHA-256 manifest; they are not redistributed here.

All files listed in `archive/verbatim_source_manifest.csv` are byte-for-byte copies of the recorded analysis files. The separately listed files in `archive/path_normalization_manifest.csv` only remove the local project-root prefix from source-path fields; their numerical values are unchanged, and original/published hashes are recorded. New archive helpers are separate and do not change analysis methods. Historical reports and scripts retain their original names and terminal/unrun states. The archive does not reopen the original decision or introduce analyses.

| Location | Contents |
|---|---|
| `outputs/DR-MODE-01/config/` | Original contract, execution specification and freeze state |
| `outputs/DR-MODE-01/{A_access,B_pretrend,C_main}/` | Original code, calibration, pretrend and main aggregate estimates |
| `outputs/S1_writing/` | Sign-corrected formula documentation, usual-intake code and diagnostics, descriptive comparisons |
| `outputs/S2_uncertainty/` | Joint uncertainty code, full 200-replicate results, NCI diagnostics and PSU multiplier matrix |
| `DR-MODE-01/W0_audit/` | Implementation audit, official-number reconciliation and `claims_ledger.csv` |
| `DR-MODE-01/X1/` | Separately frozen fast-food analysis and its NOT_IDENTIFIED result |
| `descriptive_table/` | Code and specification for descriptive participant characteristics |
| `publication_figdata/` | Aggregate publication figure/table source data |

The original contract SHA-256 is `902328b9d98817f6982f0ee169bb1809f20e55e9a0178c7c15d1cfb495d76d27`. S1 preserves the format-only comparison with the subsequently pasted contract and records the correction of the sign typo: day 1 is corrected by **adding DiD**; mode effect is **−DiD**. These are not new analyses. The original weekend definition (Saturday/Sunday) and 5/7 versus 2/7 integration are preserved.

Only log energy passed the original primary pretrend criterion; raw food-item counts remain supportive. The post hoc extension tested all ten nutrient pre-trends: sugars, alcohol and protein energy percentage met the criterion, whereas calcium did not. Calcium's control-mean usual-intake estimate is illustrative and reference dependent. Original uncertainty outputs still record invalid negative-amount replicates and supply no calcium extrapolation CI based on a reduced set. Iron inadequacy remains NO_VALID_RESULT; fast-food correction remains NOT_IDENTIFIED.

The post hoc extension is in `DR-MODE-01/s2/`; see `post_hoc_extension/README.md` for its timing, conditional interpretation, the E01 engineering correction, exact reproduction instructions, and the updated source ledger. Run `python3 post_hoc_extension/verify_extension.py` to verify its frozen source hashes and aggregate algebra without fitting models. The v1.0.0 tag and original files are preserved.

## Verify and reproduce

Requirements: Python 3 standard library; R with `haven`, `survey`, `jsonlite`, `coda`, `digest`; official `ncimultivar` 1.1.2. Executed versions and platform are recorded in the archived sessionInfo files. NCI download URL and package-source hash are in `outputs/S1_writing/software/source.json`. Third-party software retains its original license and is not bundled.

Verify the release and recorded algebra without fitting models:

```sh
python3 archive/verify_release.py
```

To protect the archived estimates, first create a **separate, non-existing** reproduction directory:

```sh
python3 archive/prepare_reproduction.py /absolute/path/to/new-reproduction
cd /absolute/path/to/new-reproduction
python3 archive/fetch_inputs.py --stage main
# Optional, for X1 only (approximately 0.9 GB):
python3 archive/fetch_inputs.py --stage x1
# Official NCI package, with source hash verification:
python3 archive/fetch_inputs.py --stage nci
mkdir -p outputs/S1_writing/software/Rlib
R CMD INSTALL -l outputs/S1_writing/software/Rlib outputs/S1_writing/software/ncimultivar_1.1.2.tar.gz
```

The preparation helper preserves all archived scripts, creates missing output directories, removes copied S2 completion markers/diagnostics **in the new working copy only**, and records a fresh 36-hour S2 execution deadline. Start a new S2 deadline in that copy immediately before a long S2 run if other reproduction stages have used the initial budget. Do not change seeds, thresholds or endpoints. Historical integrity-packaging scripts assume the full original private working directory and are preserved as provenance, not advertised as standalone release commands.

Run the analytical scripts from that reproduction directory. Main stages:

```sh
Rscript outputs/DR-MODE-01/A_access/scripts/stage_a.R
Rscript outputs/DR-MODE-01/B_pretrend/stage_b.R
Rscript outputs/DR-MODE-01/C_main/stage_c12.R
Rscript outputs/DR-MODE-01/C_main/stage_c3ab.R
Rscript outputs/DR-MODE-01/C_main/sensitivities.R
Rscript outputs/DR-MODE-01/C_main/joint_raking_audit.R
Rscript outputs/DR-MODE-01/C_main/verify_primary_sandwich.R
Rscript outputs/S1_writing/scripts/S1_prepare_inputs.R
Rscript outputs/S1_writing/scripts/S1_acd.R
Rscript outputs/S1_writing/scripts/S1b_nci.R original
Rscript outputs/S1_writing/scripts/S1b_nci.R control_mean
Rscript outputs/S1_writing/scripts/S1b_nci.R linear_extrapolation
Rscript outputs/S2_uncertainty/scripts/prepare_replicates.R
Rscript outputs/S2_uncertainty/scripts/run_nci_replicates.R 0
Rscript outputs/S2_uncertainty/scripts/run_nci_replicates.R 1 4
Rscript outputs/S2_uncertainty/scripts/run_nci_replicates.R 2 4
Rscript outputs/S2_uncertainty/scripts/run_nci_replicates.R 3 4
Rscript outputs/S2_uncertainty/scripts/run_nci_replicates.R 4 4
Rscript outputs/S2_uncertainty/scripts/summarize_S2.R
```

The last four worker commands can run sequentially or in parallel; they retain the same 200 replicate IDs and seeds. Read `outputs/S2_uncertainty/IMPLEMENTATION_S2.md` for convergence, invalid-input and budget rules. Do not replace failed replicates. X1 additionally expects the exact reconstructed S1 input and S2 bootstrap RDS hashes bound in its freeze record; platform serialization differences may require a separately documented reproduction binding, never silent changes to the archived freeze. `analyze.R` is intended to stop at its original failed identification gate.

To render the existing figures in a working copy, install numpy, pandas, scipy and matplotlib, create `visualization/figures/`, and run `python3 visualization/scripts/make_figures.py DR-MODE-01/W0_audit visualization/figures` followed by `python3 visualization/scripts/make_figure1.py`. These commands read only the archived aggregate data.

The release was checked for original-file hashes, parseable scripts, aggregate identities, all 200 replicate IDs and exact PSU-matrix dimensions. The public-download helper was checked against a CDC file. **A full new 200-replicate MCMC rerun was not performed for the act of publication.** Archived results are the previously completed analyses, not freshly fitted estimates.

## Citation and access

Use the versioned release at https://github.com/heise3/DR-MODE-01/releases/tag/v1.0.0 and cite the commit and SHA-256 manifest when reproducing results. The code and original documentation are distributed under the MIT license; external data and referenced material remain subject to their own terms. No access request or registration is needed to download this archive.
