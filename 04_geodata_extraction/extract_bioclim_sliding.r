# ==============================================================================
# Script: extract_bioclim_sliding.r
# Purpose: Extract BIO1–BIO19 at each BDM plot location from the 30-year
#          sliding-window bioclim GeoTIFFs (one 19-band file per end year).
#
# Output: one row per plot × end_year (long-format panel) saved as RDS
# ==============================================================================

# 1. Setup ---------------------------------------------------------------------
library(terra)
library(dplyr)
source("_config.r")

bioclim_dir <- file.path(DATA_ROOT, "env/climatic/processed/meteoswiss/bioclim_sliding")
plots       <- vect(PATH_PLOT_COORDS_SHP)

# 2. Find all bioclim GeoTIFFs and sort by end year ---------------------------
tif_files <- list.files(bioclim_dir, pattern = "bioclim_30yr_ending_\\d{4}_lv95\\.tif$", full.names = TRUE)
end_years <- as.integer(sub(".*ending_(\\d{4})_lv95\\.tif$", "\\1", basename(tif_files)))
tif_files <- tif_files[order(end_years)]
end_years <- sort(end_years)

cat("Found", length(tif_files), "bioclim snapshots:",
    min(end_years), "-", max(end_years), "\n")

# 3. Extract BIO1–BIO19 at plot locations for each snapshot -------------------
panel <- lapply(seq_along(tif_files), function(i) {
  # Extract raster values at plot locations
  vals          <- terra::extract(rast(tif_files[i]), plots, ID = FALSE)
  vals$aID_STAO <- as.character(plots$aID_STAO)
  vals$end_year <- end_years[i]
  vals
})

# 4. Combine into a single long-format panel ----------------------------------
panel_df <- bind_rows(panel) |>
  select(aID_STAO, end_year, everything())

cat("Panel dimensions:", nrow(panel_df), "rows x", ncol(panel_df), "columns\n")
cat("NA values per variable:\n")
print(colSums(is.na(panel_df)))

# 5. Save ---------------------------------------------------------------------
saveRDS(panel_df, PATH_BIOCLIM_PANEL)
cat("Saved to:", PATH_BIOCLIM_PANEL, "\n")
