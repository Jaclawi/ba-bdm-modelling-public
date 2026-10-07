# ==============================================================================
# Script: reproject_mowing_intensity.r
# Purpose: Reproject the mowing intensity raster layers to LV95 (EPSG:2056)
#          using nearest-neighbour interpolation to preserve the ordinal values 
#
# Output: A new GeoTIFF file with the reprojected mowing intensity raster
# ==============================================================================

library(terra)
source("_config.r")

lv95 <- "EPSG:2056"

# Mowing intensity (EPSG:32632 to EPSG:2056 (LV95) -----------------------------
out_mow <- file.path(DATA_ROOT,
  "env/land_use/processed/grassland_intensity/grassland-use_intensity_2021_ch_10m_lv95.tif")
dir.create(dirname(out_mow), recursive = TRUE, showWarnings = FALSE)

# Load the original mowing intensity raster (in WGS84 / UTM zone 32N)
cat("Loading mowing intensity raster...\n")
r_mow <- terra::rast(file.path(DATA_ROOT,
  "env/land_use/raw/grassland_intensity/grassland-use_intensity_2021_ch_10m_32632_v1_0.tif"))

# Reproject to LV95 using nearest-neighbour interpolation to preserve ordinal values
cat("Reprojecting mowing intensity...\n")
r_mow <- terra::project(r_mow, lv95, method = "near")

# Write the reprojected raster to a new GeoTIFF with compression and tiling for efficient storage and access
terra::writeRaster(r_mow, out_mow, overwrite = TRUE, gdal = c("COMPRESS=DEFLATE", "TILED=YES"))
cat("  Saved:", out_mow, "\n")

cat("Done.\n")
