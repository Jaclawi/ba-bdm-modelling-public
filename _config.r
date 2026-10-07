DATA_ROOT   <- "../data"
PATH_ASSETS <- file.path(DATA_ROOT, "assets")

# ==============================================================================
# BDM data
# ==============================================================================
DIR_BDM           <- file.path(DATA_ROOT, "bdm/processed")
DIR_ENV_EXTRACTED <- file.path(DIR_BDM, "env_extracted")

# BDM richness
PATH_MOSS_RICHNESS   <- file.path(DIR_BDM, "moss_alpha_richness.rds") 
PATH_PLANT_RICHNESS  <- file.path(DIR_BDM, "plants_alpha_richness.rds")

# BDM Plot coordinates
PATH_PLOT_COORDS_RDS <- file.path(DIR_BDM, "plot_coordinates.rds")      
PATH_PLOT_COORDS_CSV <- file.path(DIR_BDM, "plot_coordinates.csv")     
PATH_PLOT_COORDS_SHP <- file.path(DIR_BDM, "plot_coordinates.shp")

# Per-plot richness slopes (species/year regression over entire survey duration)
PATH_MOSS_SLOPES_RDS  <- file.path(DIR_BDM, "moss_richness_slopes.rds")
PATH_MOSS_SLOPES_CSV  <- file.path(DIR_BDM, "moss_richness_slopes.csv")
PATH_MOSS_SLOPES_SHP  <- file.path(DIR_BDM, "moss_richness_slopes.shp")
PATH_PLANT_SLOPES_RDS <- file.path(DIR_BDM, "plant_richness_slopes.rds")
PATH_PLANT_SLOPES_CSV <- file.path(DIR_BDM, "plant_richness_slopes.csv")
PATH_PLANT_SLOPES_SHP <- file.path(DIR_BDM, "plant_richness_slopes.shp")

# ==============================================================================
# Extracted environmental predictors
# ==============================================================================
PATH_ENV_TOPO         <- file.path(DIR_ENV_EXTRACTED, "plot_dhm25.rds")
PATH_ENV_CLIMATE      <- file.path(DIR_ENV_EXTRACTED, "plot_meteoswiss.rds")
PATH_ENV_LANDUSE      <- file.path(DIR_ENV_EXTRACTED, "plot_arealstatistik.rds")
PATH_ENV_HABITAT      <- file.path(DIR_ENV_EXTRACTED, "plot_habitatmap.rds")
PATH_ENV_SOIL_SUIT    <- file.path(DIR_ENV_EXTRACTED, "plot_soil_suitability.rds")
PATH_ENV_SOIL_KOBO    <- file.path(DIR_ENV_EXTRACTED, "plot_soil_kobo.rds")
PATH_ENV_SOIL_KOBO_INTERP <- file.path(DIR_ENV_EXTRACTED, "plot_soil_kobo_interp.rds")
PATH_ENV_HAB_WIDE_2M  <- file.path(DIR_ENV_EXTRACTED, "landscape_habitat_metrics_wide_2m.rds")
PATH_ENV_HAB_WIDE_10M <- file.path(DIR_ENV_EXTRACTED, "landscape_habitat_metrics_wide_10m.rds")
PATH_VEG_HEIGHT         <- file.path(DIR_ENV_EXTRACTED, "plot_veg_height.rds")
PATH_MOWING_INTENSITY     <- file.path(DIR_ENV_EXTRACTED, "plot_mowing_int.rds")

# Per-year climate panel for panel/MERF modelling
PATH_CLIM_PANEL         <- file.path(DIR_ENV_EXTRACTED, "plot_meteoswiss_yearly_panel.rds")
PATH_CLIM_MONTHLY_PANEL <- file.path(DIR_ENV_EXTRACTED, "plot_meteoswiss_monthly_panel.rds")

# Bioclim sliding-window panel (one row per plot × end_year, BIO1–BIO19)
PATH_BIOCLIM_PANEL <- file.path(DIR_ENV_EXTRACTED, "plot_bioclim_sliding_panel.rds")

# ==============================================================================
# Modelling data — for modelling attempt 1, inputs produced by attempt_1_preprocessing)
# ==============================================================================
DIR_MDL1_IN      <- file.path(DATA_ROOT, "modelling/attempt_1/inputs")
DIR_MDL1_OUT     <- file.path(DATA_ROOT, "modelling/attempt_1/outputs")
DIR_MDL1_REPORTS <- file.path(DATA_ROOT, "modelling/attempt_1/reports")
DIR_MDL1_PLOTS   <- file.path(DATA_ROOT, "modelling/attempt_1/plots")

PATH_MDL1_MOSS_DATA  <- file.path(DIR_MDL1_IN, "data_attempt_1_moss.rds")
PATH_MDL1_PLANT_DATA <- file.path(DIR_MDL1_IN, "data_attempt_1_plant.rds")

# ==============================================================================
# Modelling data — attempt 2 (Richness Slopes / Climatic Slopes approach)
# ==============================================================================
DIR_MDL2_IN      <- file.path(DATA_ROOT, "modelling/attempt_2/inputs")
DIR_MDL2_OUT     <- file.path(DATA_ROOT, "modelling/attempt_2/outputs")
DIR_MDL2_REPORTS <- file.path(DATA_ROOT, "modelling/attempt_2/reports")
DIR_MDL2_PLOTS   <- file.path(DATA_ROOT, "modelling/attempt_2/plots")

PATH_MDL2_MOSS_DATA  <- file.path(DIR_MDL2_IN, "data_attempt_2_moss.rds")
PATH_MDL2_PLANT_DATA <- file.path(DIR_MDL2_IN, "data_attempt_2_plant.rds")

# ==============================================================================
# Modelling data — attempt 3 (Added Bioclimatic variables, mowing and vegetation height)
# ==============================================================================
DIR_MDL3_IN      <- file.path(DATA_ROOT, "modelling/attempt_3/inputs")
DIR_MDL3_OUT     <- file.path(DATA_ROOT, "modelling/attempt_3/outputs")
DIR_MDL3_REPORTS <- file.path(DATA_ROOT, "modelling/attempt_3/reports")
DIR_MDL3_PLOTS   <- file.path(DATA_ROOT, "modelling/attempt_3/plots")

PATH_MDL3_MOSS_DATA  <- file.path(DIR_MDL3_IN, "data_attempt_3_moss.rds")
PATH_MDL3_PLANT_DATA <- file.path(DIR_MDL3_IN, "data_attempt_3_plant.rds")

# Long-format panel (one row per plot × survey year), all years and bioclim matched by year.
PATH_MDL3_MOSS_PANEL  <- file.path(DIR_MDL3_IN, "data_attempt_3_moss_panel.rds")
PATH_MDL3_PLANT_PANEL <- file.path(DIR_MDL3_IN, "data_attempt_3_plant_panel.rds")

# Combined slope modelling datasets, bioclim trends + richness trends + static env, one row per plot.
PATH_MDL3_SLOPES_MOSS  <- file.path(DIR_MDL3_IN, "data_attempt_3_slopes_moss.rds")
PATH_MDL3_SLOPES_PLANT <- file.path(DIR_MDL3_IN, "data_attempt_3_slopes_plant.rds")