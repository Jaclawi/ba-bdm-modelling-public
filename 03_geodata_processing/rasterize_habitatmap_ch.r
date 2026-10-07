# ==============================================================================
# Script: rasterize_habitatmap_ch.r
# Purpose: Rasterize the full Switzerland habitat map for RF model prediction.
#          Unlike rasterize_habitatmap.r (which only covers plot buffers), this
#          script covers the entire country.
#          Only level 1 (1-digit) habitat codes are rasterized — that is the
#          only level used in the prediction model.
#          Background / outside-habitat = 255 (NA flag).
# Note:    Tiles are processed sequentially; all cores work on the same tile
#          via terra's OpenMP threading (terraOptions(threads)).
#          Peak RAM ≈ total_RAM / n_tiles^2  (only one tile in memory at once).
# ==============================================================================

# 1. Setup ---------------------------------------------------------------------
library(terra)
source("_config.r")

# Paths
hab_dir    <- file.path(DATA_ROOT, "env/habitat_biotic")
hab_gdb    <- file.path(hab_dir, "raw/habitat_map_v1_2/N2025_HabitatMap_CH_v1_2_20251211.gdb")
out_dir    <- file.path(hab_dir, "processed/habitat_map_v1_2")
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

n_cores    <- 16  # all cores work together on each tile via terra OpenMP
n_tiles    <- 10  # n_tiles x n_tiles grid — increase if RAM is still tight
target_res <- 10  # metres

out_level1 <- file.path(out_dir, sprintf("habitatmap_ch_level1_%dm.tif", target_res))

# All terra operations (rasterize, writeRaster, etc.) use n_cores threads
terraOptions(threads = n_cores)
cat(sprintf("terra using %d threads; %d x %d = %d tiles sequentially\n",
            n_cores, n_tiles, n_tiles, n_tiles^2))

# 2. Detect layer name (reads GDB metadata only, no features loaded) -----------
cat("Detecting layers in GDB...\n")
layer_name <- terra::vector_layers(hab_gdb)[1]
cat("Using layer:", layer_name, "\n")

# 3. Build template from hardcoded Swiss LV95 extent ---------------------------
# Standard CH bounding box in EPSG:2056 — avoids loading the full vector just
# for extent. The habitat map covers the whole country within these bounds.
ch_ext     <- terra::ext(2480000, 2840000, 1070000, 1300000)
r_template <- terra::rast(ch_ext, resolution = target_res, crs = "EPSG:2056")
cat(sprintf("Template: %d cols x %d rows at %d m\n",
            ncol(r_template), nrow(r_template), target_res))

# 4. Build tile grid -----------------------------------------------------------
e        <- as.vector(ch_ext)
x_breaks <- seq(e[1], e[2], length.out = n_tiles + 1)
y_breaks <- seq(e[3], e[4], length.out = n_tiles + 1)

tile_extents <- vector("list", n_tiles * n_tiles)
k <- 1L
for (xi in seq_len(n_tiles)) {
  for (yi in seq_len(n_tiles)) {
    tile_extents[[k]] <- c(x_breaks[xi], x_breaks[xi + 1],
                           y_breaks[yi], y_breaks[yi + 1])
    k <- k + 1L
  }
}

# 5. Sequential tile rasterization ---------------------------------------------
# One tile at a time -> only one tile's polygons + raster in RAM at once.
# terra uses all n_cores threads internally for each rasterize() call.
n_total    <- length(tile_extents)
tile_files <- character(n_total)

for (i in seq_len(n_total)) {
  tile_e  <- tile_extents[[i]]
  te      <- terra::ext(tile_e[1], tile_e[2], tile_e[3], tile_e[4])

  cat(sprintf("Tile %d/%d...\n", i, n_total))

  hab_sub <- terra::vect(hab_gdb, layer = layer_name, extent = te)
  r_tile  <- terra::rast(te, resolution = target_res, crs = "EPSG:2056")

  if (nrow(hab_sub) == 0) {
    r_tile[] <- 255L
  } else {
    typo_str              <- as.character(hab_sub$TypoCH_NUM)
    level_1               <- as.integer(substr(typo_str, 1, 1))
    level_1[is.na(level_1)] <- 255L
    hab_sub$first_level   <- level_1
    r_tile <- terra::rasterize(hab_sub, r_tile, field = "first_level", background = 255L)
  }

  out_tmp <- file.path(out_dir, sprintf("tmp_tile_%04d.tif", i))
  terra::writeRaster(r_tile, out_tmp, datatype = "INT1U", NAflag = 255L, overwrite = TRUE)
  tile_files[i] <- out_tmp

  rm(hab_sub, r_tile); gc()
}

# 6. Assemble tiles via VRT and write output -----------------------------------
# VRT reads tiles on demand — no need to load all tiles into RAM at once.
cat("Assembling tiles and writing output...\n")
vrt_file <- file.path(out_dir, "tmp_mosaic.vrt")
r_vrt <- terra::vrt(tile_files, filename = vrt_file)
terra::writeRaster(r_vrt, out_level1, overwrite = TRUE, datatype = "INT1U", NAflag = 255)
unlink(c(tile_files, vrt_file))
cat("Saved:", out_level1, "\n\nDone.\n")
