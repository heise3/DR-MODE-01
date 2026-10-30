# Implementation audit

- Initial Stage A run halted at its required-field assertion before any estimates were calculated or saved. G/H use DRxMNRSP, whereas I/J/L use DRxMRESP. The proxy covariate remains unchanged; only the source-name mapping was corrected.
- Metadata showed language codes 5/6 in earlier cycles. These are harmonized into other languages; no covariate was added or removed.
- Initial implementation draft contained an extra C2 two-reference eligibility restriction not present in the user contract. It was removed before any estimates; C2 uses the main control-mean reference and BH across the fixed 10 endpoints. The original draft and its hash are retained for audit.
- C1 effect-size gate is applied to the main control-mean reference; alternate-reference size is reported. No additional threshold is imposed.
- CONTRACT_v1.0.md and its SHA-256 are unchanged. These are code/mapping corrections, not a v1.1 contract or result-driven change.
