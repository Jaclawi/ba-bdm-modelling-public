# ==============================================================================
# Script: download_chelsa.r
# Purpose: Download CHELSA-Monthly data for Switzerland for a 30-year period 
#          spanning from 1992-01-01 to 2021-12-31.
# ==============================================================================

# 1. Setup ---------------------------------------------------------------------
library(Rchelsa)
library(terra)
library(geodata)
source("_config.r")

# 2. Define Extent -------------------------------------------------------------
cat("Loading Switzerland shapefile for extent...\n") # Using local swiss boundaries shapefile
che <- vect(file.path(DATA_ROOT, "assets/swissboundaries3d_2025-04_2056_5728.shp/swissBOUNDARIES3D_1_5_TLM_LANDESGEBIET.shp"))
che_wgs <- project(che, "EPSG:4326") # Put it in WGS84 for CHELSA
che_extent <- ext(che_wgs)

# Rchelsa expects extent as a numeric vector: xmin, xmax, ymin, ymax
extent_vec <- c(che_extent$xmin, che_extent$xmax, che_extent$ymin, che_extent$ymax)

# 3. Define Timeframe ----------------------------------------------------------
startdate <- as.Date("1992-01-01")
enddate   <- as.Date("2021-12-01") # CHELSA monthly uses the 1st of the month

# 4. Request Data --------------------------------------------------------------
cat("Downloading CHELSA-monthly data for Precipitation (pr)...\n")
pr <- getChelsa("pr", 
                extent = extent_vec, 
                startdate = startdate, 
                enddate = enddate,
                dataset = "chelsa-monthly")

cat("Downloading CHELSA-monthly data for Temperature (tas)...\n")
tas <- getChelsa("tas", 
                 extent = extent_vec, 
                 startdate = startdate, 
                 enddate = enddate,
                 dataset = "chelsa-monthly")

cat("Downloading CHELSA-monthly data for Max Temperature (tasmax)...\n")
tasmax <- getChelsa("tasmax", 
                    extent = extent_vec, 
                    startdate = startdate, 
                    enddate = enddate,
                    dataset = "chelsa-monthly")

cat("Downloading CHELSA-monthly data for Min Temperature (tasmin)...\n")
tasmin <- getChelsa("tasmin", 
                    extent = extent_vec, 
                    startdate = startdate, 
                    enddate = enddate,
                    dataset = "chelsa-monthly")

cat("Downloading CHELSA-monthly data for Surface Downwelling Shortwave Flux in Air (rsds)...\n")
rsds <- getChelsa("rsds", 
                    extent = extent_vec, 
                    startdate = startdate, 
                    enddate = enddate,
                    dataset = "chelsa-monthly")

# 5. Mask Data -----------------------------------------------------------------
cat("Masking rasters to Switzerland borders...\n")
tas_che <- mask(tas, che_wgs)
tasmax_che <- mask(tasmax, che_wgs)
tasmin_che <- mask(tasmin, che_wgs)
pr_che <- mask(pr, che_wgs)
rsds_che <- mask(rsds, che_wgs)

# 6. Data Export ---------------------------------------------------------------
out_dir <- file.path(DATA_ROOT, "env/climatic/raw/chelsa")

cat("Saving data to", out_dir, "...\n")
writeRaster(tas_che, file.path(out_dir, "chelsa_monthly_tas_che_1992_2021.tif"), overwrite = TRUE)
writeRaster(tasmax_che, file.path(out_dir, "chelsa_monthly_tasmax_che_1992_2021.tif"), overwrite = TRUE)
writeRaster(tasmin_che, file.path(out_dir, "chelsa_monthly_tasmin_che_1992_2021.tif"), overwrite = TRUE)
writeRaster(pr_che, file.path(out_dir, "chelsa_monthly_pr_che_1992_2021.tif"), overwrite = TRUE)
writeRaster(rsds_che, file.path(out_dir, "chelsa_monthly_rsds_che_1992_2021.tif"), overwrite = TRUE)
cat("Download and processing complete!\n")
