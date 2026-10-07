# ==============================================================================
# Script:  extract_meteoswiss.r
# Purpose: Extract point-level climatic variables from MeteoSwiss aggregated. 
#          Does NOT create a buffer, extracts the center point values for each plot.
# ==============================================================================

# 1. Setup ---------------------------------------------------------------------
library(terra)
library(sf)
source("_config.r")

# 2. Load Data -----------------------------------------------------------------
clim_dir <- file.path(DATA_ROOT, "env/climatic/processed/meteoswiss")

# Read the plot coordinates (as SpatVector)
plots <- vect(PATH_PLOT_COORDS_SHP)

# 3. Define MeteoSwiss Aggregated Rasters --------------------------------------
# Find all aggregated .tif files in the directory (e.g. tabs, tmin, tmax, rhires, srel)
meteoswiss_files <- list.files(
  path = clim_dir,
  pattern = "last_.*_years_.*\\.tif$",
  recursive = TRUE,
  full.names = TRUE
)

cat("Found", length(meteoswiss_files), "MeteoSwiss aggregated rasters to extract.\n")

# 4. Data extraction -----------------------------------------------------------
# Loop through each raster and extract exact point values
for (raster_path in meteoswiss_files) {
  # Clean up filename to create variable name
  file_base <- tools::file_path_sans_ext(basename(raster_path))
  if (grepl("month", file_base)) {
    clean_col_name <- sub(".*(tabs|tmin|tmax|rhires|srel|radiation).+month_([0-9]{2})_last_([0-9]+)_years.*", "\\1_m\\2_\\3yr", file_base)
  } else if (grepl("yearly", file_base)) {
    clean_col_name <- sub(".*(tabs|tmin|tmax|rhires|srel|radiation).+yearly_last_([0-9]+)_years.*", "\\1_y_\\2yr", file_base)
  } else {
    clean_col_name <- file_base
  }
  
  # Load the raster
  r <- rast(raster_path)
  
  # Check if CRS projection matches
  if (crs(plots) != crs(r)) {
    stop(paste("CRS mismatch between plots and raster for:", raster_path))
  }
  
  # Check if extents overlap
  p_ext <- ext(plots)
  r_ext <- ext(r)
  if (p_ext[2] < r_ext[1] || p_ext[1] > r_ext[2] || p_ext[4] < r_ext[3] || p_ext[3] > r_ext[4]) {
    warning(paste("Plot coordinates do not overlap with the raster extent for:", raster_path))
  }

  # Extracting exact point values
  extracted_vals <- terra::extract(r, plots, ID = FALSE)
  
  # Check for NA values after extraction
  na_count <- sum(is.na(extracted_vals[, 1]))
  if (na_count > 0) {
    warning(sprintf("Extracted %d NA values for %s", na_count, raster_path))
  }

  # Assign extracted values to the plots object
  plots[[clean_col_name]] <- extracted_vals[, 1]
  
  cat("Successfully extracted", clean_col_name, "\n")
}

# 5. Data Export ---------------------------------------------------------------
# Save the extracted topography data as a pure dataframe
plots_df <- as.data.frame(plots)

saveRDS(plots_df, PATH_ENV_CLIMATE)

cat("Saved MeteoSwiss climatic data to:", PATH_ENV_CLIMATE, "\n")
