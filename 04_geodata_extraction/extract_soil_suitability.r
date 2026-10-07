# ==============================================================================
# Script: extract_soil_suitability.r
# Purpose: Extract point-level soil suitability attributes for each BDM plot
#          via spatial intersection. All attributes are columns on a single
#          polygon layer — one intersection extracts all of them at once.
# ==============================================================================

# 1. Setup ---------------------------------------------------------------------
library(sf)
source("_config.r")

# 2. Define column mapping -----------------------------------------------------
# GDB column name -> output column name in the result dataframe
cols_to_extract <- c(
  "GRUNDIGKEI" = "rooting_depth",
  "SKELETT"      = "skeleton_content",
  "WASSERSPEI"  = "water_storage",
  "NAHRSTOFF"    = "nutrient_storage",
  "WASSERDURC"   = "water_permeability",
  "VERNASS"      = "waterlogging"
)

# 3. Load data -----------------------------------------------------------------
bek_path <- file.path(DATA_ROOT, "env/soil/raw/Bodeneignungskarte_Landwirtschaft_D/Bodeneignungskarte der Schweiz LV95.gdb/Bodeneignungskarte_LV95.gdb")

# Read the Bodeneignungskarte layer (as sf object)
bek_layer <- sf::st_read(bek_path, layer = "Bodeneignungskarte_20120601", quiet = TRUE)

# Read the plot coordinates (as sf object)
plots <- sf::st_read(PATH_PLOT_COORDS_SHP, quiet = TRUE)

# Check CRS match
if (sf::st_crs(plots) != sf::st_crs(bek_layer))
  stop("CRS mismatch between plots and Bodeneignungskarte layer.")

# 4. Extract -------------------------------------------------------------------
# Keep only the needed columns from bek_layer before intersecting
bek_layer <- bek_layer[, names(cols_to_extract)]

# Perform spatial intersection to get the attributes for each plot
extracted <- sf::st_intersection(plots, bek_layer)
plots_df  <- sf::st_drop_geometry(plots)

for (gdb_col in names(cols_to_extract)) {
  out_col <- cols_to_extract[[gdb_col]]
  value   <- extracted[[gdb_col]]
  value[value %in% c(-9999, 0)] <- NA

  if (any(is.na(value)))
    warning(sum(is.na(value)), " NA value(s) for: ", gdb_col)

  plots_df[[out_col]] <- value
  cat("Extracted:", gdb_col, "->", out_col, "\n")
}

# 5. Export --------------------------------------------------------------------
saveRDS(plots_df, PATH_ENV_SOIL)

cat("\nSaved soil suitability data to:", PATH_ENV_SOIL, "\n")
