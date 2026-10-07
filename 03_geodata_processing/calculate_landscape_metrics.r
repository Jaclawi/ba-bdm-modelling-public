# ==============================================================================
# Script: calculate_landscape_metrics.r
# Purpose: Calculate Shannon diversity index and edge density for habitat 
#          within different buffer zones (500m, 250m, 100m) and plot level
# Uses: landscapemetrics package for standardized landscape ecology metrics
# ==============================================================================

# 1. Setup ---------------------------------------------------------------------
library(sf)
library(terra)
library(landscapemetrics)
library(dplyr)
library(tidyr)
source("_config.r")

# 2. Load Data -----------------------------------------------------------------
cat("Loading data...\n")
plots <- sf::st_read(PATH_PLOT_COORDS_SHP)
habitat <- terra::rast(file.path(DATA_ROOT, "env/habitat_biotic/processed/habitat_map_v1_2/habitatmap_level1_2m.tif"))

buffer_distances <- c(500, 250, 100, 50, 25)
results <- list()
counter <- 1

# Plots for which edge boundary rasters are saved for validation/visualization
validation_ids <- c(677218, 677222, 683218, 683222, 689218, 689222)
dir_edges <- file.path(DATA_ROOT, "env/habitat_biotic/processed/habitat_map_v1_2/")
if (!dir.exists(dir_edges)) dir.create(dir_edges, recursive = TRUE)

# 3. Calculate Metrics ---------------------------------------------------------
cat("Calculating landscape metrics...\n")
for (i in 1:nrow(plots)) {
  plot_geom <- sf::st_geometry(plots)[i]
  aID_STAO <- plots$aID_STAO[i]
  
  for (dist in buffer_distances) {
    # a. Create buffer and crop raster
    buf <- sf::st_buffer(plot_geom, dist = dist)
    hab_buf <- tryCatch({
      terra::crop(habitat, terra::vect(buf), mask = TRUE)
    }, error = function(e) NULL)
    
    # b. Default NA values
    shdi_val <- NA_real_
    ed_val <- NA_real_
    richness <- NA_integer_
    
    # c. Calculate metrics if data exists
    if (!is.null(hab_buf)) {
      # Identify if the entire buffer is empty.
      # (Note: any(is.na()) will always be TRUE because mask=TRUE creates NA corners when cropping a circle out of a square raster grid!)
      if (all(is.na(terra::values(hab_buf)))) {
        warning(sprintf("Entire raster selection is NA for plot ID: %s (buffer: %s).", aID_STAO, dist))
      }
      
      check_landscape(hab_buf)
      metrics <- calculate_lsm(hab_buf, what = c("lsm_l_shdi", "lsm_l_ed"))
      
      shdi_val <- as.numeric(metrics$value[metrics$metric == "shdi"][1])
      ed_val <- as.numeric(metrics$value[metrics$metric == "ed"][1])

      # Save edge boundary raster for selected validation plots
      if (aID_STAO %in% validation_ids) {
        edges <- landscapemetrics::get_boundaries(hab_buf, consider_boundary = TRUE)
        edge_path <- file.path(dir_edges, sprintf("edges_%s_%sm.tif", aID_STAO, dist))
        terra::writeRaster(edges[[1]], edge_path, overwrite = TRUE)
      }

      freq_table <- terra::freq(hab_buf)
      richness <- if(nrow(freq_table) > 0) as.integer(nrow(freq_table)) else NA_integer_
    }
    
    # Format distance label
    dist_label <- as.character(as.integer(dist))
    
    # Append to results
    results[[counter]] <- data.frame(
      aID_STAO = as.character(aID_STAO),
      buffer_m = dist_label,
      shannon_diversity = shdi_val,
      edge_density = ed_val,
      class_richness = richness,
      stringsAsFactors = FALSE
    )
    counter <- counter + 1
    # Progress update every 100 iterations
    if (counter %% 100 == 0) {
      cat(sprintf("Processed %d plot-buffer combinations...\n", counter))
    }
  }
}

# Combine results into one dataframe
metrics_long <- bind_rows(results)

# Check for NAs/NaNs in the final calculated dataframe
na_count <- sum(is.na(metrics_long$shannon_diversity) | is.na(metrics_long$edge_density))
if (na_count > 0) {
  cat(sprintf("Found %d occurrences of missing metrics (NA/NaN) in the final combined data.\n", na_count))
}

# Pivot to wide format
metrics_wide <- metrics_long %>%
  pivot_wider(
    names_from = buffer_m,
    values_from = c(shannon_diversity, edge_density, class_richness),
    names_sep = "_"
  )

# 4. Save results --------------------------------------------------------------
cat("Saving results...\n")
if (!dir.exists(DIR_ENV_EXTRACTED)) dir.create(DIR_ENV_EXTRACTED, recursive = TRUE)

saveRDS(metrics_wide, PATH_ENV_HAB_WIDE_2M)

cat("Results saved successfully\n")