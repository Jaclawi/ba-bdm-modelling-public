# ==============================================================================
# Script: calculations_dem25.r
# Purpose: Read DHM25 DEM, reproject to LV95 (EPSG:2056), and calculate terrain 
#          characteristics (slope, aspect, TPI). Also reprojects the DEM to LV95.
#
# Output: GeoTIFFs of elevation, slope, aspect, and TPI at 25m
# ==============================================================================

# 1. Setup ---------------------------------------------------------------------
library(terra)
source("_config.r")

# 2. Data Loading & Preprocessing ----------------------------------------------
dem_path <- file.path(DATA_ROOT, "env/landscape_topography/raw/dhm25/dhm25_mm_ascii_grid/dhm25_grid_raster.asc")
dem <- rast(dem_path)

# Assign original CRS (EPSG:21781) accordingly to metadata
crs(dem) <- "epsg:21781"

# Transform to LV95 (EPSG:2056)
dem_lv95 <- project(dem, "epsg:2056")

# 3. Terrain Calculations ------------------------------------------------------
cat("Calculating terrain characteristics (slope, aspect, TPI)...\n")
# Calculate terrain characteristics (slope, aspect, and TPI)
# Output units for slope and aspect are in degrees
terrain_vars <- terrain(dem_lv95, v = c("slope", "aspect", "TPI"), unit = "degrees")

# 4. Export Outputs ------------------------------------------------------------
# Save projected elevation
out_dir <- file.path(DATA_ROOT, "env/landscape_topography/processed/dhm25")
elev_path <- file.path(out_dir, "dhm25_elevation_lv95.tif")
writeRaster(dem_lv95, elev_path, overwrite = TRUE)
cat("Saved elevation to:", elev_path, "\n")

# Save the computed terrain variables (slope, aspect, TPI)
for (layer_name in names(terrain_vars)) {
  output_path <- file.path(out_dir, paste0("dhm25_", tolower(layer_name), "_lv95.tif"))
  writeRaster(terrain_vars[[layer_name]], output_path, overwrite = TRUE)
  cat("Saved layer", tolower(layer_name), "to:", output_path, "\n")
}
