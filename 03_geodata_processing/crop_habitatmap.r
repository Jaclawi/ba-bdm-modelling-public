# ==============================================================================
# Script: crop_habitatmap.r
# Purpose: Disk-to-disk streaming approach in PARALLEL to crop the habitat map 
#          using 500m buffers around BDM plots safely without exhausting RAM.
#          This script was run on HPC and will likely not work on a local machine.
# ==============================================================================

# 1. Setup ---------------------------------------------------------------------
library(sf)
library(dplyr)
library(future)
library(furrr)
source("_config.r")

# Setup parallel processing
plan(multisession, workers = 32) # Adjust according to your CPU cores

habitat_gdb <- file.path(DATA_ROOT, "env/habitat_biotic/raw/habitat_map_v1_2/N2025_HabitatMap_CH_v1_2_20251211.gdb")
output_dir  <- file.path(DATA_ROOT, "env/habitat_biotic/processed/habitat_map_v1_2")
output_path <- file.path(output_dir, "habitatmap_cropped.gpkg")

# Create a temporary directory for parallel workers to write isolated files
temp_dir <- file.path(output_dir, "temp_tiles")
if (!dir.exists(temp_dir)) dir.create(temp_dir)

# 2. Load Plots and Create Buffers ---------------------------------------------
cat("Loading plot coordinates and creating 500m buffers...\n")
plots_sf <- st_read(PATH_PLOT_COORDS_SHP)
plots_buffered <- st_buffer(plots_sf, dist = 500)

habitat_layers <- st_layers(habitat_gdb)
layer_name <- habitat_layers$name[1]

# Safely split plots to ensure they behave right across parallel sessions
plots_df <- sf::st_as_sf(as.data.frame(plots_buffered))
plots_list <- lapply(seq_len(nrow(plots_df)), function(i) plots_df[i, ])

# 3. Parallel Processing -------------------------------------------------------
cat("Starting parallel disk-to-disk extraction for", length(plots_list), "plots...\n")
cat("Each worker will query the DB and save an independent temporary file.\n")

future_iwalk(plots_list, function(current_buffer, i) {
  
  wkt <- sf::st_as_text(sf::st_geometry(current_buffer))
  
  # A: Read pre-filtered data from GDB
  subset_sf <- sf::st_read(habitat_gdb, layer = layer_name, wkt_filter = wkt)
  
  # Check if any data was returned for this buffer
  if (nrow(subset_sf) == 0) {
    stop(paste("Data issue: No habitat data found within bounding box of plot index", i))
  }
  
  # B: Exact intersection
  cropped_sf <- sf::st_intersection(subset_sf, current_buffer)
  
  # Check if intersection resulted in any features
  if (nrow(cropped_sf) == 0) {
    stop(paste("Data issue: Exact intersection resulted in 0 features for plot index", i))
  }
  
  # C: Cast all geometries to MULTIPOLYGON to conform to GeoPackage spec
  cropped_sf <- sf::st_collection_extract(cropped_sf, "POLYGON")
  cropped_sf <- sf::st_cast(cropped_sf, "MULTIPOLYGON")
  temp_path <- file.path(temp_dir, paste0("plot_", i, ".gpkg"))
  sf::st_write(cropped_sf, temp_path, layer = "habitat_cropped")
  
}, .progress = TRUE, .options = furrr_options(packages = c("sf", "dplyr")))

# 4. Merge Temporary Tiles -----------------------------------------------------
cat("Parallel processing complete. Merging temporary files into final Geopackage...\n")

temp_files <- list.files(temp_dir, pattern = "\\.gpkg$", full.names = TRUE)

# We use a sequential loop here because SQLite geopackages can only handle one write at a time
pb <- txtProgressBar(min = 0, max = length(temp_files), style = 3)
for (i in seq_along(temp_files)) {
  tf <- temp_files[i]
  temp_sf <- sf::st_read(tf)
  
  sf::st_write(temp_sf, output_path, layer = "habitat_cropped", append = TRUE)
  setTxtProgressBar(pb, i)
}
close(pb)

cat("\nCleaning up temporary files...\n")
unlink(temp_dir, recursive = TRUE)

cat("Success! Combined output saved to:", output_path, "\n")