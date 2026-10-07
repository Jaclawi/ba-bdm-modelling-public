# ==============================================================================
# Script: rasterize_arealstatistik.r
# Purpose: Rasterize Swiss Arealstatistik point data to 100m resolution grids.
#
# Output: One .tif per selected nomenclature column (e.g., LU_4, LU_10, AS_4)
# ==============================================================================

# 1. Setup ---------------------------------------------------------------------
library(terra)

source("_config.r")

# 2. Data Loading & Preprocessing ----------------------------------------------
data_dir <- file.path(DATA_ROOT, "env/land_use/raw/arealstatistik")
out_dir  <- file.path(DATA_ROOT, "env/land_use/processed")
input_gpkg <- file.path(data_dir, "arealstatistik_2056.gpkg")

cat("Loading Arealstatistik points...\n")
as_points <- vect(input_gpkg)

# The survey grid for Swiss Arealstatistik is exactly 100x100m.
# According to the methodology, points lie on the intersections of the 100m coordinates.
# This means the points are the geometric CENTERS of the 100m raster cells.
# The extent must be expanded by 50m (half resolution) so the points don't fall on cell edges.
pts_ext <- ext(as_points)
cat("Creating template raster (100m resolution, EPSG:2056)...\n")
r_template <- rast(ext(pts_ext[1] - 50, pts_ext[2] + 50, 
                       pts_ext[3] - 50, pts_ext[4] + 50), 
                   resolution = 100, crs = "EPSG:2056")

# 3. Rasterization -------------------------------------------------------------
# Determine which specific nomenclature columns to extract (e.g., LU_4).
target_columns <- c("LU_4", "LU_10", "AS_4")

for (col_name in target_columns) {
    cat("Rasterizing category:", col_name, "...\n")
    
    r_out <- rasterize(as_points, r_template, field = col_name)
    out_tif <- file.path(out_dir, paste0("arealstatistik_", col_name, "_100m.tif"))
    
    writeRaster(r_out, out_tif, overwrite = TRUE)
    cat("Saved Arealstatistik Raster to:", out_tif, "\n")
}
