# ==============================================================================
# Script: predict_richness_ch.r
# Purpose: Apply the finalised Random Forest richness models (attempt 3) to
#          the full Swiss raster grid to produce countrywide prediction maps
#          for bryophyte (moss) and vascular plant richness.
#
# Approach:
#   A single shared predictor stack (20 variables, 100 m LV95) is assembled
#   once. Both models are applied independently using terra::predict().
#   Factor variables (aspect_factor, mow_int_cat, LU_4, TypoCH_1st_code) are
#   stored as integer-coded rasters and restored to proper R factors , with
#   the exact levels from the training data , inside the prediction function.
#
# Predictors used by both models (20 variables):
#   LU_4, slope, tpi, twi, TypoCH_1st_code, bio3, bio4, bio10, bio11, bio18,
#   bio19, radiation_y_15yr, soc_stock_0_120, humus_0_30, kak_0_30, ph_0_30,
#   sand_0_30, veg_height, aspect_factor, mow_int_cat
#
# Inputs:
#   - rf_moss_final_model.rds   (DIR_MDL3_OUT/moss_richness/)
#   - rf_plant_final_model.rds  (DIR_MDL3_OUT/plant_richness/)
#   - PATH_MDL3_MOSS_DATA / PATH_MDL3_PLANT_DATA  (factor level metadata)
#   - All predictor rasters (all pre-reprojected to LV95)
#
# Outputs:
#   - DIR_MDL3_OUT/moss_richness/prediction_ch_100m.tif   (mean)
#   - DIR_MDL3_OUT/moss_richness/prediction_ch_100m_se.tif (SE)
#   - DIR_MDL3_OUT/plant_richness/prediction_ch_100m.tif
#   - DIR_MDL3_OUT/plant_richness/prediction_ch_100m_se.tif
# ==============================================================================

# 1. Setup ---------------------------------------------------------------------
library(terra)
library(ranger)
library(dplyr)
source("_config.r")

# Model paths
moss_model_path  <- file.path(DIR_MDL3_OUT, "moss_richness/rf_moss_final_model.rds")
plant_model_path <- file.path(DIR_MDL3_OUT, "plant_richness/rf_plant_final_model.rds")

# Output paths
moss_out_path     <- file.path(DIR_MDL3_OUT, "moss_richness/prediction_ch_100m.tif")
moss_out_se_path  <- file.path(DIR_MDL3_OUT, "moss_richness/prediction_ch_100m_se.tif")
plant_out_path    <- file.path(DIR_MDL3_OUT, "plant_richness/prediction_ch_100m.tif")
plant_out_se_path <- file.path(DIR_MDL3_OUT, "plant_richness/prediction_ch_100m_se.tif")

# 2. Load models and extract factor metadata -----------------------------------
cat("Loading models and training data...\n")
rf_moss  <- readRDS(moss_model_path)
rf_plant <- readRDS(plant_model_path)

# Load training data (needed only for factor level metadata)
moss_data  <- readRDS(PATH_MDL3_MOSS_DATA)  |> dplyr::select(-yearMoos, -aID_STAO)
plant_data <- readRDS(PATH_MDL3_PLANT_DATA) |> dplyr::select(-yearPl,   -aID_STAO)

# Extract factor levels from each training dataset
get_factor_levels <- function(data) {
  cols <- names(data)[sapply(data, is.factor)]
  lvls <- lapply(cols, function(col) levels(data[[col]]))
  names(lvls) <- cols
  lvls
}
moss_factor_levels  <- get_factor_levels(moss_data)
plant_factor_levels <- get_factor_levels(plant_data)

cat("Factor columns (moss):",  paste(names(moss_factor_levels),  collapse = ", "), "\n")
cat("Factor columns (plant):", paste(names(plant_factor_levels), collapse = ", "), "\n")

# Fixed label vectors for integer-coded factors
# aspect_factor: 1 = N, 2 = NE, ..., 8 = NW  (matches preprocessing script)
aspect_labels      <- c("N", "NE", "E", "SE", "S", "SW", "W", "NW")
# mow_int_cat: 1 = No Mowing, 2 = Low, 3 = Medium, 4 = High
mow_int_cat_labels <- c("No Mowing", "Low", "Medium", "High")

# 3. Reference grid (100 m, LV95) ---------------------------------------------
# Use the Arealstatistik LU_4 raster: covers full CH at 100 m in LV95
cat("Setting up 100 m LV95 reference grid...\n")
ref_grid <- terra::rast(
  file.path(DATA_ROOT, "env/land_use/processed/arealstatistik/arealstatistik_LU_4_100m.tif")
)
cat(sprintf("Reference grid: %d cols x %d rows\n", ncol(ref_grid), nrow(ref_grid)))

# Helper: load a raster, optionally select a band, and resample to ref_grid.
# All inputs are expected to be in LV95 already.
load_align <- function(path, method = "bilinear", band = 1) {
  r <- terra::rast(path)
  if (!is.null(band)) r <- r[[band]]
  terra::resample(r, ref_grid, method = method)
}

# 4. Load and align all predictor rasters -------------------------------------

## 4a. Topography (slope, tpi, twi , elevation excluded per variable selection)
cat("Loading topography...\n")
r_slope <- load_align(file.path(DATA_ROOT, "env/landscape_topography/processed/dhm25/dhm25_slope_lv95.tif"))
r_tpi   <- load_align(file.path(DATA_ROOT, "env/landscape_topography/processed/dhm25/dhm25_tpi_lv95.tif"))
r_twi   <- load_align(file.path(DATA_ROOT, "env/landscape_topography/processed/dhm25/dhm25_twi_lv95.tif"))
names(r_slope) <- "slope"
names(r_tpi)   <- "tpi"
names(r_twi)   <- "twi"

## 4b. Aspect to integer-coded factor (1 = N, 2 = NE, ..., 8 = NW)
cat("Deriving aspect_factor...\n")
r_aspect_raw <- load_align(
  file.path(DATA_ROOT, "env/landscape_topography/processed/dhm25/dhm25_aspect_lv95.tif"),
  method = "bilinear"
)
# Classify continuous aspect (°) into 8 cardinal directions; N spans 337.5–360 and 0–22.5
aspect_rcl <- matrix(c(
    0.0,  22.5, 1,   # N  (0 – 22.5)
   22.5,  67.5, 2,   # NE
   67.5, 112.5, 3,   # E
  112.5, 157.5, 4,   # SE
  157.5, 202.5, 5,   # S
  202.5, 247.5, 6,   # SW
  247.5, 292.5, 7,   # W
  292.5, 337.5, 8,   # NW
  337.5, 360.0, 1    # N  (337.5 – 360)
), ncol = 3, byrow = TRUE)
r_aspect_factor <- terra::classify(r_aspect_raw, aspect_rcl, right = FALSE)
names(r_aspect_factor) <- "aspect_factor"

## 4c. Land use, LU_4 (already loaded as ref_grid; re-assign name)
cat("Loading land use (LU_4)...\n")
r_lu4 <- ref_grid
names(r_lu4) <- "LU_4"

## 4d. Mowing intensity to integer-coded category
#     Raw pixel values = number of mowing events per year.
#     NA (non-grassland) to 0 events, same as training.
#     Category codes: 1 = No Mowing (0), 2 = Low (1–2), 3 = Medium (3–5), 4 = High (>5)
cat("Loading and categorising mowing intensity...\n")
r_mow_raw <- load_align(
  file.path(DATA_ROOT, "env/land_use/processed/grassland_intensity/grassland-use_intensity_2021_ch_10m_lv95.tif"),
  method = "near"
)
r_mow_raw[is.na(r_mow_raw)] <- 0L
mow_rcl <- matrix(c(
  0, 0,   1,   # No Mowing
  1, 2,   2,   # Low
  3, 5,   3,   # Medium
  6, Inf, 4    # High
), ncol = 3, byrow = TRUE)
r_mow_int_cat <- terra::classify(r_mow_raw, mow_rcl, right = TRUE, include.lowest = TRUE)
names(r_mow_int_cat) <- "mow_int_cat"

## 4e. Habitat map , TypoCH_1st_code (integer codes, nearest-neighbour)
cat("Loading habitat map (TypoCH_1st_code)...\n")
r_habitat <- load_align(
  file.path(DATA_ROOT, "env/habitat_biotic/processed/habitat_map_v1_2/habitatmap_ch_level1_10m.tif"),
  method = "near"
)
r_habitat[r_habitat == 255] <- NA
names(r_habitat) <- "TypoCH_1st_code"

## 4f. Vegetation height (NA to 0, same as training)
cat("Loading vegetation height...\n")
r_veg <- load_align(
  file.path(DATA_ROOT, "env/habitat_biotic/raw/vegetation_height/landesforstinventar-vegetationshoehenmodell_2021_stereo_2056.tif"),
  method = "bilinear"
)
r_veg[is.na(r_veg)] <- 0
names(r_veg) <- "veg_height"

## 4g. Bioclim 2021 , only the 6 bands used by the model (bio3,4,10,11,18,19)
cat("Loading bioclim rasters...\n")
r_bioclim_all <- load_align(
  file.path(DATA_ROOT, "env/climatic/processed/meteoswiss/bioclim_sliding/bioclim_30yr_ending_2021_lv95.tif"),
  method = "bilinear",
  band   = NULL    # load all 19 bands, then subset
)
names(r_bioclim_all) <- paste0("bio", 1:19)
r_bioclim <- r_bioclim_all[[c("bio3", "bio4", "bio10", "bio11", "bio18", "bio19")]]

## 4h. Solar radiation , 15-year average (2007–2021)
cat("Loading radiation (15-yr average)...\n")
r_radiation <- load_align(
  file.path(DATA_ROOT, "env/climatic/processed/meteoswiss/radiation/yearly/radiation_avg_yearly_last_15_years_2007_2021.tif"),
  method = "bilinear"
)
names(r_radiation) <- "radiation_y_15yr"

## 4i. Soil , 5 variables used by the model
cat("Loading soil rasters...\n")
soil_vars <- list(
  soc_stock_0_120 = "env/soil/raw/kobo/Geodaten_SOC_CH/CH_SOCstock_0_120/CH_SOCstock_0_120.tif",
  humus_0_30      = "env/soil/raw/kobo/Geodaten_Humus_CH/CH_Humus_0_30/CH_humus_0_30.tif",
  kak_0_30        = "env/soil/raw/kobo/Geodaten_KAK_CH/CH_KAK_0_30/CH_KAK_0_30.tif",
  ph_0_30         = "env/soil/raw/kobo/Geodaten_pH_CH/CH_pH_0_30/CH_pH_0_30.tif",
  sand_0_30       = "env/soil/raw/kobo/Geodaten_Sand_CH/CH_Sand_0_30/CH_Sand_0_30.tif"
)
r_soil_stack <- terra::rast(lapply(names(soil_vars), function(var) {
  r <- load_align(file.path(DATA_ROOT, soil_vars[[var]]))
  names(r) <- var
  r
}))

# 5. Assemble predictor stack --------------------------------------------------
cat("Assembling predictor stack...\n")
r_stack <- c(
  r_lu4,
  r_slope,
  r_tpi,
  r_twi,
  r_habitat,
  r_bioclim,
  r_radiation,
  r_soil_stack,
  r_veg,
  r_aspect_factor,
  r_mow_int_cat
)
cat(sprintf("Stack: %d layers , %s\n", nlyr(r_stack), paste(names(r_stack), collapse = ", ")))

# 6. Factor-restoration helper -------------------------------------------------
# Restores integer-coded factor layers in a data.frame to proper R factors
# using the exact levels recorded from the training data.
restore_factors <- function(data, factor_levels) {
  # aspect_factor: integer 1–8 maps to N/NE/.../NW
  if ("aspect_factor" %in% names(data)) {
    data$aspect_factor <- factor(
      aspect_labels[data$aspect_factor],
      levels = factor_levels$aspect_factor
    )
  }
  # mow_int_cat: integer 1–4 maps to No Mowing/Low/Medium/High
  if ("mow_int_cat" %in% names(data)) {
    data$mow_int_cat <- factor(
      mow_int_cat_labels[data$mow_int_cat],
      levels = factor_levels$mow_int_cat
    )
  }
  # LU_4: integer land-use code to character factor
  if ("LU_4" %in% names(data)) {
    data$LU_4 <- factor(
      as.character(data$LU_4),
      levels = factor_levels$LU_4
    )
  }
  # TypoCH_1st_code: integer habitat code to character factor
  if ("TypoCH_1st_code" %in% names(data)) {
    data$TypoCH_1st_code <- factor(
      as.character(data$TypoCH_1st_code),
      levels = factor_levels$TypoCH_1st_code
    )
  }
  data
}

# ──────────────────────────────────────────────────────────────────────────────
# 7. MOSS prediction -----------------------------------------------------------
# ──────────────────────────────────────────────────────────────────────────────
moss_vars    <- rf_moss$forest$independent.variable.names
missing_moss <- setdiff(moss_vars, names(r_stack))
if (length(missing_moss) > 0) stop("Missing moss predictor layers: ", paste(missing_moss, collapse = ", "))
r_stack_moss <- r_stack[[moss_vars]]
cat(sprintf("Moss stack: %d predictor layers\n", nlyr(r_stack_moss)))

predict_moss_se <- function(model, data, ...) {
  data <- restore_factors(data, moss_factor_levels)
  p    <- predict(model, data = data, type = "se", num.threads = 1L)
  cbind(mean = p$predictions, se = p$se)
}

cat("Predicting moss richness across Switzerland...\n")
r_moss_pred <- terra::predict(r_stack_moss, rf_moss, fun = predict_moss_se, na.rm = TRUE, cores = 1)
names(r_moss_pred) <- c("moss_richness_predicted", "moss_richness_se")

cat("Saving moss prediction...\n")
dir.create(file.path(DIR_MDL3_OUT, "moss_richness"), showWarnings = FALSE, recursive = TRUE)
terra::writeRaster(r_moss_pred[[1]], moss_out_path,    overwrite = TRUE, datatype = "FLT4S")
terra::writeRaster(r_moss_pred[[2]], moss_out_se_path, overwrite = TRUE, datatype = "FLT4S")
cat("Saved:", moss_out_path, "\n")

# ──────────────────────────────────────────────────────────────────────────────
# 8. PLANT prediction ----------------------------------------------------------
# ──────────────────────────────────────────────────────────────────────────────
plant_vars    <- rf_plant$forest$independent.variable.names
missing_plant <- setdiff(plant_vars, names(r_stack))
if (length(missing_plant) > 0) stop("Missing plant predictor layers: ", paste(missing_plant, collapse = ", "))
r_stack_plant <- r_stack[[plant_vars]]
cat(sprintf("Plant stack: %d predictor layers\n", nlyr(r_stack_plant)))

predict_plant_se <- function(model, data, ...) {
  data <- restore_factors(data, plant_factor_levels)
  p    <- predict(model, data = data, type = "se", num.threads = 1L)
  cbind(mean = p$predictions, se = p$se)
}

cat("Predicting plant richness across Switzerland...\n")
r_plant_pred <- terra::predict(r_stack_plant, rf_plant, fun = predict_plant_se, na.rm = TRUE, cores = 1)
names(r_plant_pred) <- c("plant_richness_predicted", "plant_richness_se")

cat("Saving plant prediction...\n")
dir.create(file.path(DIR_MDL3_OUT, "plant_richness"), showWarnings = FALSE, recursive = TRUE)
terra::writeRaster(r_plant_pred[[1]], plant_out_path,    overwrite = TRUE, datatype = "FLT4S")
terra::writeRaster(r_plant_pred[[2]], plant_out_se_path, overwrite = TRUE, datatype = "FLT4S")
cat("Saved:", plant_out_path, "\n")

# 9. Summaries -----------------------------------------------------------------
cat("\n--- Prediction summaries ---\n")
for (nm in c("moss", "plant")) {
  r_pred <- if (nm == "moss") r_moss_pred else r_plant_pred
  pv <- terra::values(r_pred[[1]], na.rm = TRUE)
  sv <- terra::values(r_pred[[2]], na.rm = TRUE)
  cat(sprintf(
    "%s richness , mean: %.1f  median: %.1f  min: %.1f  max: %.1f | SE mean: %.3f\n",
    nm, mean(pv), median(pv), min(pv), max(pv), mean(sv)
  ))
}
cat("Done.\n")
