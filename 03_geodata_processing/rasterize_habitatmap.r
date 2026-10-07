# ==============================================================================
# Script: rasterize_habitatmap.r
# Purpose: Rasterize the cropped habitat map vector data to a grid.
# ==============================================================================

# 1. Setup ---------------------------------------------------------------------
library(terra)

source("_config.r")

# Define paths
data_dir <- file.path(DATA_ROOT, "env/habitat_biotic/processed/habitat_map_v1_2")
input_gpkg <- file.path(data_dir, "habitatmap_cropped.gpkg")

# Output resolution (can be adjusted depending on your modeling constraints, e.g., 10m or 100m)
target_res <- 2 
out_tif_1 <- file.path(data_dir, sprintf("habitatmap_level1_%dm.tif", target_res))
out_tif_2 <- file.path(data_dir, sprintf("habitatmap_level2_%dm.tif", target_res))

# 2. Data Loading & Preprocessing ----------------------------------------------
cat("Loading cropped habitat map...\n")
# Load the vector data from the layer saved in crop_habitatmap.r
hab_vect <- terra::vect(input_gpkg, layer = "habitat_cropped")
hab_vect

cat(sprintf("Creating template raster (%dm resolution, EPSG:2056)...\n", target_res))
r_template <- terra::rast(ext(hab_vect), resolution = target_res, crs = crs(hab_vect))

# 3. Rasterization -------------------------------------------------------------
cat("Extracting hierarchical levels from TypoCH_NUM...\n")
typo_str <- as.character(hab_vect$TypoCH_NUM)

# 1st level: 1st digit
level_1 <- as.integer(substr(typo_str, 1, 1))
level_1[is.na(level_1)] <- 255

# 2nd level: 1st and 2nd digits (if available)
level_2 <- as.integer(substr(typo_str, 1, 2))
level_2[nchar(typo_str) < 2 | is.na(level_2)] <- 255

# Assign new columns to SpatVector
hab_vect$first_level <- level_1
hab_vect$second_level <- level_2

cat("Rasterizing habitat map into 2 separate rasters...\n")
r_hab_1 <- terra::rasterize(hab_vect, r_template, field = "first_level", background = 255)
r_hab_2 <- terra::rasterize(hab_vect, r_template, field = "second_level", background = 255)

# 4. Data Export ---------------------------------------------------------------
# Saving as INT1U (unsigned 8-bit integer, 0-255) to minimize file size
terra::writeRaster(r_hab_1, out_tif_1, overwrite = TRUE, datatype="INT1U", NAflag=255)
cat("Saved Level 1 Habitat Map to:", out_tif_1, "\n")

terra::writeRaster(r_hab_2, out_tif_2, overwrite = TRUE, datatype="INT1U", NAflag=255)
cat("Saved Level 2 Habitat Map to:", out_tif_2, "\n")