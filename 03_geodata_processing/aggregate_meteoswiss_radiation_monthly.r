# ==============================================================================
# Script: aggregate_meteoswiss_radiation_monthly.r
# Purpose: For radiation (SISDIR) only: each source .nc file contains one month
#          (unlike the other variables which use annual files). Computes a mean
#          raster per month x time window (5, 10, 15 years only data starts
#          2004, so 20/30-year windows are not available).
#          Also reprojects from ch02 to LV95 (EPSG:2056), which the other
#          scripts do not need.
# Note:   For the non-radiation variables (tabs, tmax, etc.) use
#         aggregate_meteoswiss_monthly.r instead.
#
# Output: One .tif per month x time window
#         e.g. radiation_avg_month_07_last_10_years_2012_2021.tif
# ==============================================================================

# 1. Setup ---------------------------------------------------------------------
library(terra)
library(dplyr)
library(stringr)
library(purrr)

source("_config.r")

# Data directory
data_dir <- file.path(DATA_ROOT, "env/climatic/raw/meteoswiss/radiation/monthly/SISDIRM/MSG.SIDIR.M_ch02.lonlat_2004_2024")
out_dir <- file.path(DATA_ROOT, "env/climatic/processed/meteoswiss/radiation/monthly")

# Fetch all monthly netCDF files
nc_files <- list.files(
  data_dir,
  pattern = "\\.nc$",
  full.names = TRUE,
  recursive = TRUE
)

# Parse the year and month from the filename 
# e.g., "MSG.SIDIR.M_ch02.lonlat_2004_202401010000.nc" -> year: 2004, month: 01
metadata <- tibble(file = nc_files) |>
  mutate(
    basename = basename(file),
    date_str = str_extract(basename, "\\d{14}"),
    year = as.integer(substr(date_str, 1, 4)),
    month = as.integer(substr(date_str, 5, 6))
  ) |>
  filter(!is.na(year), !is.na(month))

# Define aggregation periods relative to the target year (2021).
max_year <- 2021
time_windows <- c(5, 10, 15)

cat("\n==================================\n")
cat("Processing variable: radiation (SISDIR)\n")
cat("==================================\n")

# 2. Aggregation Loop ----------------------------------------------------------
for (window in time_windows) {
  target_start_year <- max_year - window + 1
  
  # 3. Monthly Means Computation -------------------------------------------
  for (m in 1:12) {
    
    # Filter files for the specific month and rolling window
    window_month_files <- metadata |>
      filter(year >= target_start_year & year <= max_year & month == m)
    
    r_list <- list()
    for (i in seq_along(window_month_files$file)) {
      f <- window_month_files$file[i]
      r <- rast(f)
      r_list[[i]] <- r
    }
    
    cat("  Processing", window, "years window (", target_start_year, "-", max_year, ")...\n")

    # Calculate the temporal mean mapped across the specified window
    r_stack <- rast(r_list)

      # Check if the number of files for this month matches the window size
      if (length(r_list) != window) {
        warning(sprintf(
          "Expected %d files for month %02d but found %d. Check data consistency.",
          window, m, length(r_list)
        ))
      }

    # Compute the mean across the time dimension (layers) for the current month
    r_mean <- mean(r_stack, na.rm = TRUE)
    
    # Transform the crs from ch02 to lv95 (EPSG:2056)
    r_mean <- project(r_mean, "EPSG:2056")

    # 4. Data Export -----------------------------------------------------
    out_filename <- sprintf(
      "radiation_avg_month_%02d_last_%d_years_%d_%d.tif", 
      m, window, target_start_year, max_year
    )
    out_path <- file.path(out_dir, out_filename)
    writeRaster(r_mean, out_path, overwrite = TRUE)
  }
}

cat("Finished processing radiation data.\n")
