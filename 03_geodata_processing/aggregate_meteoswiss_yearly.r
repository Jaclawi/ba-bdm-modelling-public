# ==============================================================================
# Script: aggregate_meteoswiss_yearly.r
# Purpose: For variables tabs, tmax, tmin, rhires, srel: read yearly .nc files
#          (one file = one year, one band) and compute a mean raster per
#          variable x time window (5, 10, 15, 20, 30 years), collapsing all
#          months into a single long term annual mean.
#          For radiation: monthly .nc files are first averaged to yearly means,
#          then aggregated across time windows to get same output structure.
# Note:   Use aggregate_meteoswiss_monthly.r instead to preserve monthly detail.
#
# Output: One .tif per variable x time window
#         e.g. tabs_avg_yearly_last_10_years_2012_2021.tif
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

# Map variable names to their corresponding source directories (yearly)
climatic_vars <- list(
  tabs = file.path(climatic_base_dir, "tabs/yearly"),
  tmax = file.path(climatic_base_dir, "tmax/yearly"),
  tmin = file.path(climatic_base_dir, "tmin/yearly"),
  rhires = file.path(climatic_base_dir, "rhires/yearly"),
  srel = file.path(climatic_base_dir, "srel/yearly")
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
  out_dir <- file.path(processed_base_dir, var_name, "yearly")
  
  # Fetch all yearly netCDF files for this variable
  nc_files <- list.files(
    data_dir,
    pattern = "\\.nc$",
    full.names = TRUE,
    recursive = TRUE
  )
  
  # Parse the year from the filename to allow temporal filtering
  # e.g., "TabsY_ch01..._20200101_20201231.nc" -> 2020
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
    
    # 3. Extract raster and compute yearly mean ----------------------------------
    r_list <- list()
    # Extract the raster from each yearly file
    for (i in seq_along(window_files$file)) {
      f <- window_files$file[i]
      r <- terra::rast(f)
      r_list[[i]] <- r
    }
    # Check if the number of rasters matches the window size
    if (length(r_list) != window) {
      warning(sprintf(
        "Variable '%s', window %d years: expected %d files but found %d.",
        var_name, window, window, length(r_list)
      ))
    }
    # Calculate the temporal mean across the specified window
    r_stack <- terra::rast(r_list)
    r_mean_window <- terra::mean(r_stack, na.rm = TRUE)
    
    # 4. Data Export -----------------------------------------------------------
    out_filename <- sprintf(
      "%s_avg_yearly_last_%d_years_%d_%d.tif", 
      var_name, window, target_start_year, max_year
    )
    out_path <- file.path(out_dir, out_filename)
    writeRaster(r_mean_window, out_path, overwrite = TRUE)
    cat("    Saved -", out_filename, "\n")
  }
}

# 5. Execution -----------------------------------------------------------------
walk2(names(climatic_vars), climatic_vars, process_variable)

# 6. Radiation Data Aggregation (monthly to yearly) ----------------------------
radiation_data_dir <- file.path(DATA_ROOT, "env/climatic/raw/meteoswiss/radiation/monthly/SISDIRM/MSG.SIDIR.M_ch02.lonlat_2004_2024")

# Create output directory for aggregated radiation rasters
radiation_out_dir <- file.path(DATA_ROOT, "env/climatic/processed/meteoswiss/radiation/yearly")

# Fetch all monthly netCDF files for radiation
nc_files_rad <- list.files(
  radiation_data_dir,
  pattern = "\\.nc$",
  full.names = TRUE,
  recursive = TRUE
)

# Parse the year and month from the filename
# e.g., "MSG.SIDIR.M_ch02.lonlat_2004_202401010000.nc" -> year: 2004, month: 01
metadata_rad <- tibble(file = nc_files_rad) %>%
  mutate(
    basename = basename(file),
    date_str = str_extract(basename, "\\d{14}"),
    year = as.integer(substr(date_str, 1, 4)),
    month = as.integer(substr(date_str, 5, 6))
  ) %>%
  filter(!is.na(year), !is.na(month))

cat("\n==================================\n")
cat("Processing radiation (monthly aggregated to yearly)\n")
cat("==================================\n")

# Loop over the different time windows
for (window in time_windows) {
  target_start_year <- max_year - window + 1
  
  # Filter files to the specific rolling window
  window_files_rad <- metadata_rad %>%
    filter(year >= target_start_year & year <= max_year)
  
  if (nrow(window_files_rad) != (window * 12)) {
    cat("  WARNING: Expected", window * 12, "radiation files but found", nrow(window_files_rad),
        "for", window, "years window (", target_start_year, "-", max_year, ") - skipping\n")
    next
  }
  
  cat("  Processing", window, "years window (", 
      target_start_year, "-", max_year, ")...\n")
  
  # 7. Yearly aggregation from monthly files -----------------------------------
  r_list <- list()

  # For each year, aggregate all monthly files
  for (yr in sort(unique(window_files_rad$year))) {
    year_files <- window_files_rad %>%
      filter(year == yr) %>%
      pull(file)
    r_list_monthly <- list()
    # Read each monthly file for the year
    for (f in year_files) {
      r <- terra::rast(f)
      r_list_monthly[[length(r_list_monthly) + 1]] <- r
    }

    # Compute yearly mean from all monthly files
    r_stack_monthly <- terra::rast(r_list_monthly)
    r_mean_yearly <- terra::mean(r_stack_monthly, na.rm = TRUE)

    # Project to lv95 (EPSG:2056)
    r_mean_yearly <- terra::project(r_mean_yearly, "EPSG:2056")
    r_list[[length(r_list) + 1]] <- r_mean_yearly
  }
  
  # Compute the temporal mean across the specified window
  r_stack_window <- terra::rast(r_list)
  r_mean_window <- terra::mean(r_stack_window, na.rm = TRUE)
  
  # 8. Data Export -----------------------------------------------------------
  out_filename <- sprintf(
    "radiation_avg_yearly_last_%d_years_%d_%d.tif", 
    window, target_start_year, max_year
  )
  
  out_path <- file.path(radiation_out_dir, out_filename)
  writeRaster(r_mean_window, out_path, overwrite = TRUE)
  
  cat("    Saved -", out_filename, "\n")
}

cat("\nAll yearly aggregations complete.\n")
