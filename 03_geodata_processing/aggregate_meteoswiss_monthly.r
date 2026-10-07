# ==============================================================================
# Script: aggregate_meteoswiss_monthly.r
# Purpose: For variables tabs, tmax, tmin, rhires, srel: read annual .nc files
#          where each file contains 12 bands (one per month), and compute a mean
#          raster per variable x month x time window (5, 10, 15, 20, 30 years).
#          Preserves the seasonal signal and output is month-specific.
#
# Output: One .tif per variable x month x time window
#         e.g. tabs_avg_month_07_last_10_years_2012_2021.tif
# ==============================================================================

# 1. Setup ---------------------------------------------------------------------
library(terra)
library(dplyr)
library(stringr)
library(purrr)

source("_config.r")

# Base directory for climatic data
climatic_base_dir <- file.path(DATA_ROOT, "env/climatic/raw/meteoswiss")
processed_base_dir <- file.path(DATA_ROOT, "env/climatic/processed/meteoswiss")

# Map variable names to their corresponding source directories
climatic_vars <- list(
  tabs = file.path(climatic_base_dir, "tabs/monthly"),
  tmax = file.path(climatic_base_dir, "tmax/monthly"),
  tmin = file.path(climatic_base_dir, "tmin/monthly"),
  rhires = file.path(climatic_base_dir, "rhires/monthly"),
  srel = file.path(climatic_base_dir, "srel/monthly")
)

# Define aggregation periods relative to the target year (2021)
max_year <- 2021
time_windows <- c(5, 10, 15, 20, 30)

# 2. Aggregation Logic ---------------------------------------------------------
process_variable <- function(var_name, data_dir) {
  cat("\n==================================\n")
  cat("Processing variable:", var_name, "\n")
  cat("==================================\n")

  # Create output directory for this variable's aggregated rasters
  out_dir <- file.path(processed_base_dir, var_name, "monthly")
  
  # Fetch all monthly netCDF files for this variable
  nc_files <- list.files(
    data_dir,
    pattern = "\\.nc$",
    full.names = TRUE,
    recursive = TRUE
  )
  
  # Parse the year from the filename to allow temporal filtering
  # e.g., "TmaxM_ch01..._202001010000_202012010000.nc" -> 2020
  metadata <- tibble(file = nc_files) %>%
    mutate(
      basename = basename(file),
      date_str = str_extract(basename, "\\d{8,}"),
      year = as.integer(substr(date_str, 1, 4))
    ) %>%
    filter(!is.na(year))
  
  # Loop over the different time windows
  for (window in time_windows) {
    target_start_year <- max_year - window + 1
    
    # Filter files to the specific rolling window
    window_files <- metadata %>%
      filter(year >= target_start_year & year <= max_year)
    
    cat("  Processing", window, "years window (", 
        target_start_year, "-", max_year, ")...\n")
      
      # 3. Monthly Means Computation -------------------------------------------
      for (m in 1:12) {
        
        r_list <- list()
        
        # Extract the m-th band (month) from each annual file
        for (i in seq_along(window_files$file)) {
          f <- window_files$file[i]
          { r <- terra::rast(f) }
          
          r_list[[i]] <- r[[m]]
        }
        
        if (length(r_list) < window) {
          warning(sprintf(
            "Variable '%s', window %d years, month %02d: expected %d files but found %d.",
            var_name, window, m, window, length(r_list)
          ))
        }
        
        # Calculate the temporal mean across the specified window
        r_stack <- terra::rast(r_list)
          r_mean <- terra::mean(r_stack, na.rm = TRUE)
          
          # 4. Data Export -----------------------------------------------------
          out_filename <- sprintf(
            "%s_avg_month_%02d_last_%d_years_%d_%d.tif", 
            var_name, m, window, target_start_year, max_year
          )
          out_path <- file.path(out_dir, out_filename)
          writeRaster(r_mean, out_path, overwrite = TRUE)
          
          cat("    Saved month", sprintf("%02d", m), "-", out_filename, "\n")
      }
  }
}

# 5. Execution -----------------------------------------------------------------
walk2(names(climatic_vars), climatic_vars, process_variable)

cat("\nAll aggregations complete.\n")