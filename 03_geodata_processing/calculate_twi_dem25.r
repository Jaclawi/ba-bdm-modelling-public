# ==============================================================================
# Script: calculate_twi_dem25.r
# Purpose: Calculate Topographic Wetness Index (TWI) using the D-Infinity
#          algorithm based on the DHM25 elevation raster.
#
# Output: A GeoTIFF of TWI values at 25m resolution, aligned with the input DEM.
# ==============================================================================

# 1. Setup ---------------------------------------------------------------------
library(whitebox)
library(terra)

source("_config.r")

# 2. Paths ---------------------------------------------------------------------
data_dir         <- file.path(DATA_ROOT, "env/landscape_topography/processed/dhm25")
dem_path         <- file.path(data_dir, "dhm25_elevation_lv95.tif")
twi_path         <- file.path(data_dir, "dhm25_twi_lv95.tif")

# Intermediate files (temp, deleted after use)
dem_sinkfree_path <- file.path(tempdir(), "dhm25_sinkfree.tif")
slope_tmp_path    <- file.path(tempdir(), "dhm25_slope_tmp.tif")
sca_path          <- file.path(tempdir(), "dhm25_sca.tif")

# 3. Fix flow sinks ------------------------------------------------------------
cat("Fixing flow sinks in DEM...\n")
# Carves minimal channels through artificial sinks so flow can route downhill.
wbt_breach_depressions_least_cost(
  dem    = dem_path,
  output = dem_sinkfree_path,
  dist   = 10,    # max search radius in cells for a channel path
  fill   = TRUE   # fill any sinks that could not be breached
)

# 4. Slope from sink-free DEM --------------------------------------------------
cat("Calculating slope...\n")
# Slope must come from the same DEM thus it is recalculated temporaryly
wbt_slope(dem = dem_sinkfree_path, output = slope_tmp_path, units = "degrees")

# Calculate slope 
slope_r <- rast(slope_tmp_path)

# Calculated slope is clamped to a minimum of 0.001 deg to prevent TWI = Inf in flat cells
slope_r <- ifel(slope_r < 0.001, 0.001, slope_r)
writeRaster(slope_r, slope_tmp_path, overwrite = TRUE)
rm(slope_r)

# 5. Specific Catchment Area ---------------------------------------------------
cat("Calculating Specific Catchment Area (D-Infinity)...\n")
wbt_d_inf_flow_accumulation(
  input    = dem_sinkfree_path,
  output   = sca_path,
  out_type = "Specific Catchment Area"
)

# 6. TWI -----------------------------------------------------------------------
cat("Calculating Topographic Wetness Index...\n")
wbt_wetness_index(sca = sca_path, slope = slope_tmp_path, output = twi_path)

# 7. Clean up ------------------------------------------------------------------
unlink(c(dem_sinkfree_path, slope_tmp_path, sca_path))

cat("Saved Topographic Wetness Index to:", twi_path, "\n")
