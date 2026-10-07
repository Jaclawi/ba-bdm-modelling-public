# ==============================================================================
# Script: calculate_bioclim_sliding.r
# Purpose: Compute BIO1–BIO19 for a 30-year sliding window (2001–2021).
#          One 19-layer GeoTIFF is written per end year, producing a time series
#          that can be matched against BDM species richness change.
#
# Output: One 19-layer GeoTIFF per end year (2001–2021)
# ==============================================================================

# 1. Setup ---------------------------------------------------------------------
library(terra)
library(dismo)   # biovars(); requires raster
library(raster)
library(dplyr)
library(stringr)
library(purrr)
source("_config.r")

raw_base  <- file.path(DATA_ROOT, "env/climatic/raw/meteoswiss")
proc_base <- file.path(DATA_ROOT, "env/climatic/processed/meteoswiss")

raw_dirs <- list(
  tmax   = file.path(raw_base, "tmax",   "monthly", "TmaxM_71_23.ch01r.swiss.lv95"),
  tmin   = file.path(raw_base, "tmin",   "monthly", "TminM_71_23.ch01r.swiss.lv95"),
  rhires = file.path(raw_base, "rhires", "monthly", "RhiresM_61_23ch01r.swiss.lv95"))

out_dir <- file.path(proc_base, "bioclim_sliding")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

window_size <- 30         # 30-year window size (e.g. 1991–2020, 1992–2021, etc.)
end_years   <- 2001:2021  # 21 snapshots

# 2. Helper: index all .nc files in a directory by year -----------------------
# Parses the year from filenames like "TmaxM_..._199201010000_199212010000.nc"
index_nc_files <- function(nc_dir) {
  list.files(nc_dir, pattern = "\\.nc$", full.names = TRUE) |>  # find all .nc files
    tibble(file = _) |>                                          # put paths into a tibble
    mutate(year = as.integer(str_extract(basename(file), "(?<=_)\\d{4}(?=\\d{8})"))) |>  # parse year from filename
    filter(!is.na(year)) |>   # drop any files where year could not be parsed
    arrange(year)             # sort chronologically
}

# 3. Helper: compute 12 monthly means for a given year window -----------------
# Returns a 12-layer SpatRaster (one layer per month)
compute_monthly_means <- function(var_index, start_year, end_year) {
  # Keep only files that fall within the requested year window
  files <- var_index |> filter(year >= start_year, year <= end_year) |> pull(file)

  # Warn if fewer files were found than expected
  if (length(files) < end_year - start_year + 1)
    warning(sprintf("Only %d of %d expected files found for %d–%d.",
                    length(files), end_year - start_year + 1, start_year, end_year))

  # Loop over months 1–12
  monthly_means <- lapply(1:12, function(m) {
    all_years_month_m <- lapply(files, function(f) terra::rast(f)[[m]])  # extract band m from each annual file
    terra::mean(terra::rast(all_years_month_m), na.rm = TRUE)            # average across years
  })

  terra::rast(monthly_means)  # stack the 12 monthly means into one SpatRaster
}

# 4. Index raw files (once, reused for every window) --------------------------
cat("Indexing raw NetCDF files using the function above ...\n")
indices <- map(raw_dirs, index_nc_files)

for (nm in names(indices)) {
  idx <- indices[[nm]]
  cat(sprintf("  %-6s %d years (%d–%d)\n", nm, nrow(idx), min(idx$year), max(idx$year)))
}

# 5. Sliding-window loop -------------------------------------------------------
for (end_year in end_years) {
  # Define the start year for this window
  start_year <- end_year - window_size + 1
  cat(sprintf("\nWindow %d–%d ...\n", start_year, end_year))

  # Monthly means for this window
  tmax_stack   <- compute_monthly_means(indices$tmax,   start_year, end_year)
  tmin_stack   <- compute_monthly_means(indices$tmin,   start_year, end_year)
  rhires_stack <- compute_monthly_means(indices$rhires, start_year, end_year)

  # dismo::biovars() needs raster::RasterStack input
  bio_rs <- dismo::biovars(
    prec = raster::stack(rhires_stack),
    tmin = raster::stack(tmin_stack),
    tmax = raster::stack(tmax_stack)
  )

  # Convert result back to terra, restore CRS (lost in raster round-trip), and write
  bio_terra <- terra::rast(bio_rs)
  terra::crs(bio_terra) <- terra::crs(tmax_stack)
  names(bio_terra) <- paste0("bio", 1:19)

  out_file <- file.path(out_dir, sprintf("bioclim_30yr_ending_%d_lv95.tif", end_year))
  terra::writeRaster(bio_terra, out_file, overwrite = TRUE)
  cat(sprintf("  Saved: %s\n", basename(out_file)))
}

cat("\nDone. Outputs written to:", out_dir, "\n")
