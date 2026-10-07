# ==============================================================================
# Script: interpolate_kobo_soil.r
# Purpose: Gap-fill missing values in the KoBo soil raster extraction
#          (plot_soil_kobo.rds) by assigning each missing plot the value of
#          its nearest valid raster pixel (parameter-free, handles any gap size).
#          Reads the RDS produced by extract_raster.r and overwrites it with
#          imputed values ready for modelling.
#
# Strategy: For each variable, load the raster once (per worker process). Then,
#           for each missing plot, crop a small bounding box around that plot and
#           call as.points() on only that tiny window to find the nearest valid
#           pixel. The box doubles in radius if no valid pixel is found within
#           it. Variables are processed in parallel via furrr/future
#           (multisession; works on both Linux/HPC and Windows).
#
# Input:   bdm/processed/env_extracted/plot_soil_kobo.rds  (may contain NAs)
#          env/soil/raw/kobo/**/*.tif                       (KoBo rasters)
#          bdm/processed/plot_coordinates.shp               (plot locations)
#          04_geodata_extraction/raster_sources.csv         (variable → path map)
#
# Output:  bdm/processed/env_extracted/plot_soil_kobo_interp.rds  (NAs filled)
# ==============================================================================

# 1. Setup ---------------------------------------------------------------------
library(terra)
library(future)
library(furrr)
source("_config.r")

plan(multisession, workers = 32)

# 2. Data Loading --------------------------------------------------------------
cat("Loading data...\n")

plots_vect <- terra::vect(PATH_PLOT_COORDS_SHP)
soil_df    <- readRDS(PATH_ENV_SOIL_KOBO)

# Align plot vector order to soil_df rows (by aID_STAO)
plots_vect <- plots_vect[match(soil_df$aID_STAO, plots_vect$aID_STAO), ]

# Extract coordinates as a plain matrix so workers receive a lightweight object
plot_xy <- terra::crds(plots_vect)   # n × 2 numeric matrix (x, y)

# Load raster source configuration
raster_sources <- read.csv(
  "04_geodata_extraction/raster_sources.csv",
  stringsAsFactors = FALSE,
  comment.char     = "#"
)

# Build variable-name → raster-path map for KoBo soil group
soil_rows       <- raster_sources[raster_sources$group == "soil", ]
kobo_raster_map <- setNames(
  file.path(DATA_ROOT, soil_rows$raster_path),
  soil_rows$var_name
)

cat("Plots loaded       :", nrow(soil_df), "\n")
cat("KoBo variables     :", length(kobo_raster_map), "\n")
cat("Cores used         :", N_CORES, "\n")

# Initial missing-value summary
missing_before <- sapply(soil_df[, names(kobo_raster_map), drop = FALSE],
                         function(x) sum(is.na(x)))
cat("\nMissing values before imputation:\n")
print(missing_before[missing_before > 0])

# 3. Nearest-pixel Imputation --------------------------------------------------
# Worker function: given one variable, loads the raster once, then for each
# missing plot crops a small box and finds the nearest valid pixel inside it.
# The box starts at 3× the raster resolution and doubles until a valid pixel
# is found keeping the materialised point cloud tiny at all times.

impute_one_var <- function(var, raster_path, missing_xy) {
  r     <- terra::rast(raster_path)
  r_crs <- terra::crs(r)
  r_res <- max(terra::res(r))

  vals <- rep(NA_real_, nrow(missing_xy))

  # Loop over each missing plot and find the nearest valid pixel
  for (i in seq_len(nrow(missing_xy))) {
    x <- missing_xy[i, 1]
    y <- missing_xy[i, 2]

    radius <- r_res * 3   # start: 3-pixel half-width

    # Loop until a valid pixel is found or the radius exceeds a reasonable limit
    while (is.na(vals[i]) && radius <= r_res * 4096) {
      r_crop    <- terra::crop(r, terra::ext(x - radius, x + radius,
                                              y - radius, y + radius))
      valid_pts <- terra::as.points(r_crop, na.rm = TRUE)

      # If there are valid points, find the nearest one and assign its value
      if (length(valid_pts) > 0) {
        pt      <- terra::vect(matrix(c(x, y), nrow = 1L), type = "points",
                               crs = r_crs)
        nn      <- terra::nearest(pt, valid_pts)
        vals[i] <- terra::values(valid_pts)[nn$to_id, 1L]
      }

      radius <- radius * 2
    }
  }

  vals
}

cat("\nStarting parallel nearest-pixel imputation...\n")

vars_with_na <- names(kobo_raster_map)[
  sapply(names(kobo_raster_map), function(v) any(is.na(soil_df[[v]])))
]

# Run the imputation in parallel using furrr/future
# Each worker loads its own raster and processes all missing plots for that variable.
results <- furrr::future_map(
  vars_with_na,
  function(var) {
    na_idx <- which(is.na(soil_df[[var]]))
    vals <- impute_one_var(var, kobo_raster_map[[var]], plot_xy[na_idx, , drop = FALSE])
    list(var = var, na_idx = na_idx, vals = vals)
  },
  .options = furrr_options(packages = "terra"),
  .progress = TRUE
)

# Write imputed values back into soil_df (single-threaded)
for (res in results) {
  soil_df[[res$var]][res$na_idx] <- res$vals
  n_remaining <- sum(is.na(soil_df[[res$var]]))
  if (n_remaining > 0)
    warning(sprintf("%d value(s) for '%s' could not be imputed.", n_remaining, res$var))
}

# 4. Summary and Export --------------------------------------------------------
missing_after <- sapply(soil_df[, names(kobo_raster_map), drop = FALSE],
                        function(x) sum(is.na(x)))
cat("\nMissing values after imputation:\n")
remaining <- missing_after[missing_after > 0]
if (length(remaining) == 0) {
  cat("  None — all values imputed successfully.\n")
} else {
  print(remaining)
}

saveRDS(soil_df, PATH_ENV_SOIL_KOBO_INTERP)
cat("\nSaved imputed soil data to:", PATH_ENV_SOIL_KOBO_INTERP, "\n")
