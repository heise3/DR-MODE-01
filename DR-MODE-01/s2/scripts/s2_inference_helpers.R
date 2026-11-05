# Pure summary-level helpers: no file reads, NHANES loading, fitting, or side effects.
add_R_tests <- function(shares, endpoint_metadata, df=77) {
  x <- shares
  idx <- match(paste(x$endpoint,x$reference),paste(endpoint_metadata$endpoint,endpoint_metadata$reference))
  x$module <- endpoint_metadata$module[idx]
  x$group <- endpoint_metadata$group[idx]
  x$metric <- endpoint_metadata$metric[idx]
  x$R_df <- df
  x$R_t <- x$R_p <- x$R_q_BH <- NA_real_
  x$R_family <- NA_character_
  x$R_family_size <- NA_integer_
  x$R_test_status <- 'NOT_APPLICABLE'
  applicable <- x$metric=='kcal' & x$module %in% c('A2','A3')
  applicable[is.na(applicable)] <- FALSE
  good <- applicable & is.finite(x$R_g) & is.finite(x$R_se) & x$R_se>0
  x$R_test_status[applicable] <- 'NO_VALID_RESULT'
  x$R_test_status[good] <- 'COMPLETE'
  x$R_t[good] <- (x$R_g[good]-1)/x$R_se[good]
  x$R_p[good] <- 2*pt(-abs(x$R_t[good]),df=df)
  for (ref in unique(x$reference)) for (module in c('A2','A3')) {
    ii <- which(x$reference==ref & x$module==module & x$metric=='kcal' & x$group!='H_omit')
    expected <- if(module=='A2')3L else 10L
    stopifnot(length(ii)==expected,!anyDuplicated(x$group[ii]))
    x$R_family[ii] <- if(module=='A2')'occasion_3' else 'food_10'
    x$R_family_size[ii] <- expected
    # Keep the prespecified family size even if one member has an invalid SE.
    x$R_q_BH[ii] <- p.adjust(x$R_p[ii],method='BH',n=expected)
  }
  x
}

composition_from_R <- function(x) {
  h <- x[x$endpoint=='food_H_omit_kcal' & x$reference=='control_mean',,drop=FALSE]
  stopifnot(nrow(h)==1)
  h_pass <- is.finite(h$R_ci_low) && h$R_ci_low>1
  eligible <- which(x$reference=='control_mean' & x$module %in% c('A2','A3') &
                    x$metric=='kcal' & x$group!='H_omit' &
                    is.finite(x$R_q_BH) & x$R_q_BH<.05)
  sig <- x[eligible,,drop=FALSE]
  trend <- x[x$reference=='linear_extrapolation',,drop=FALSE]
  ti <- match(sig$endpoint,trend$endpoint)
  sig$trend_R_g <- trend$R_g[ti]
  sig$trend_same_sign <- is.finite(sig$R_g) & is.finite(sig$trend_R_g) &
    sign(sig$R_g-1)==sign(sig$trend_R_g-1)
  # kcal DiD, its P/q, and its trend sign are not inputs to this gate.
  list(composition_signal=if(h_pass||any(sig$trend_same_sign))'YES' else 'NO',
       H_omit_lower_CI_gt_1=h_pass,significant_R_components=sig)
}
