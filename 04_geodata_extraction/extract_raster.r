# ==============================================================================
# Script: extract_raster.r
# Purpose: Extract the raster pixel value at each BDM plot coordinate and save
#          the results as RDS files. All raster sources are defined in
#          raster_sources.csv
#
# Output: one RDS file per group (e.g. "soil", "mowing"), each containing a data
#         frame with one row per plot and one column per variable (e.g. soil_pH)
# ==============================================================================

# 1. Setup ---------------------------------------------------------------------
library(terra)
source("_config.r")

# 2. Helper: extract one raster and add values as a new column -----------------
extract_one <- function(plots, raster_path, col_name) {
    r <- rast(raster_path)

    # Extract raster values at plot locations
    vals <- terra::extract(r, plots, ID = FALSE)[, 1]

    # Check for NA values and warn if any are found
    if (any(is.na(vals)))
        warning(sum(is.na(vals)), " NA value(s) for: ", col_name)

    # Add values as a new column to the plots data frame
    plots[[col_name]] <- vals
    plots
}

# 3. Load inputs ---------------------------------------------------------------
sources <- read.csv(
  "04_geodata_extraction/raster_sources.csv",
  stringsAsFactors = FALSE,
  comment.char = "#"
)

plots_base <- vect(PATH_PLOT_COORDS_SHP)

cat("Loaded", nrow(sources), "raster source(s).\n")

# 4. Extract and save each group -----------------------------------------------
groups <- unique(sources[, c("group", "output_rds")])

for (i in seq_len(nrow(groups))) {

  grp_name <- groups$group[i]
  grp_rows <- sources[sources$group == grp_name, ]

  cat("\n--- Group:", grp_name, "---\n")
  plots <- plots_base

  for (j in seq_len(nrow(grp_rows))) {
    row   <- grp_rows[j, ]
    path  <- file.path(DATA_ROOT, row$raster_path)
    plots <- extract_one(plots, path, row$var_name)
    cat("  Extracted:", row$var_name, "\n")
  }

  out_path <- file.path(DATA_ROOT, groups$output_rds[i])
  saveRDS(as.data.frame(plots), out_path)
  cat("  Saved to:", out_path, "\n")
}

cat("\nDone.\n")
