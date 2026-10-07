# ==============================================================================
# Script: extract_coordinates_bdm.r
# Purpose: Extract coordinates of all plots from the species richness data 
#          and save them as a csv, rds, and shapefile.
#
# Output columns:
#   aID_STAO       — plot ID
#   XKoord_LV95    — X coordinate in LV95
#   YKoord_LV95    — Y coordinate in LV95
# ==============================================================================

# 1. Setup ---------------------------------------------------------------------
library(tidyverse)
library(sf)
library(readxl)
source("_config.r")

# 2. Load Data -----------------------------------------------------------------
# Load the header data and extract distinct coordinates
header <- readxl::read_excel(file.path(DATA_ROOT, "bdm/raw/2050_Z9_Kopfdaten_V3.xlsx"), sheet = 1)

header_coords <- header |>
  select(aID_STAO, XKoord_LV95, YKoord_LV95) |>
  distinct()

plants_richness <- readRDS(PATH_PLANT_RICHNESS) |>
  left_join(header_coords, by = "aID_STAO")

moss_richness <- readRDS(PATH_MOSS_RICHNESS) |>
  left_join(header_coords, by = "aID_STAO")

# 3. Extract Coordinates -------------------------------------------------------
plants_coords <- plants_richness |>
  select(aID_STAO, XKoord_LV95, YKoord_LV95) |>
  distinct()
cat("Plants: ", dim(plants_coords), "\n") # 1445 x 3

moss_coords <- moss_richness |>
  select(aID_STAO, XKoord_LV95, YKoord_LV95) |>
  distinct()
cat("Moss: ", dim(moss_coords), "\n") # 1442 x 3

# 4. Compare Datasets ----------------------------------------------------------
plants_only <- anti_join(plants_coords, moss_coords, by = "aID_STAO")
moss_only <- anti_join(moss_coords, plants_coords, by = "aID_STAO")
cat("Plots only in plants dataset: ", dim(plants_only), "\n") # 3
cat("Plots only in moss dataset: ", dim(moss_only), "\n") # 0

# 5. Combine Coordinates -------------------------------------------------------
all_coords <- bind_rows(plants_coords, moss_coords) |>
  distinct()
cat("All unique plots: ", dim(all_coords), "\n") # 1445

# 6. Data Export -------------------------------------------------------
# Save the coordinates as a csv file
write.csv(all_coords, file = PATH_PLOT_COORDS_CSV, row.names = FALSE)

# Save the coordinates as an rds file
saveRDS(all_coords, file = PATH_PLOT_COORDS_RDS)

# Convert the coordinates to a spatial object
all_coords_sf <- st_as_sf(all_coords, coords = c("XKoord_LV95", "YKoord_LV95"), crs = 2056)

# Save the coordinates as a shapefile
st_write(all_coords_sf, PATH_PLOT_COORDS_SHP, delete_layer = TRUE)
