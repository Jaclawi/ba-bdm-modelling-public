# ==============================================================================
# Script: calculate_richness_slopes.r
# Purpose: For each BDM plot compute linear regression trends (species per year)
#          restricted to the 2001–2020 window for both bryophytes and vascular plants.
#          The resulting table is saved as RDS, CSV and shapefile.
#
# Output columns (per taxon group):
#   aID_STAO           — plot ID
#   richness_slope     — linear regression slope (species yr⁻¹)
#   baseline_richness  — richness at first survey in 2001–2020 window
#   total_change_pct   — total % change from fitted 2001 to fitted 2020
# ==============================================================================

# 1. Setup ---------------------------------------------------------------------
library(tidyverse)
library(sf)
source("_config.r")

# 2. Load data -----------------------------------------------------------------
moss_richness  <- readRDS(PATH_MOSS_RICHNESS)
plant_richness <- readRDS(PATH_PLANT_RICHNESS)

cat("  Moss:  ", dim(moss_richness), "\n") # 7105 x 3
cat("  Plant: ", dim(plant_richness), "\n") # 7137 x 3

# 3. Moss Linear regression slopes over 2001–2020 window -----------------------
cat("\n--- Moss: Computing slopes over 2001-2020 ---\n")

# Filter moss data to 2001–2020
moss_richness_filtered <- moss_richness |>
  filter(yearMoos >= 2001 & yearMoos <= 2020)

# Calculate linear regression slope per plot
moss_slopes <- moss_richness_filtered |>
  group_by(aID_STAO) |>
  
  # Only compute slopes for plots with at least 3 survey points
  filter(n() >= 3) |>
  summarise(
    # Fit linear model: richness ~ year
    # Extract slope (2nd coefficient) and intercept (1st coefficient)
    richness_slope    = coef(lm(richness_moss ~ yearMoos))[2],
    intercept         = coef(lm(richness_moss ~ yearMoos))[1],
    
    # Baseline richness at the first survey in this window
    baseline_richness = richness_moss[which.min(yearMoos)],
    
    # Mean richness across all surveys (for % change calculation)
    mean_richness     = mean(richness_moss),
    
    # Survey year range (for fitted value calculation)
    year_min          = min(yearMoos),
    year_max          = max(yearMoos),
    
    .groups           = "drop"
  ) |>
  mutate(
    # Fitted richness at start and end of the 2001–2020 window
    fitted_start     = intercept + richness_slope * year_min,
    fitted_end       = intercept + richness_slope * year_max,
    
    # Total change as percentage of mean richness
    # If mean richness is 0, set to 0 (no change possible from zero)
    total_change_pct = if_else(mean_richness == 0, 0, (fitted_end - fitted_start) / mean_richness * 100)
  ) |>
  # Keep only the key output columns
  select(aID_STAO, richness_slope, baseline_richness, total_change_pct)

# 4. Plant Linear regression slopes over 2001–2020 window ----------------------
cat("--- Plant: Computing slopes over 2001-2020 ---\n")

# Filter plant data to 2001–2020
plant_richness_filtered <- plant_richness |>
  filter(yearPl >= 2001 & yearPl <= 2020)

# Calculate linear regression slope per plot
plant_slopes <- plant_richness_filtered |>
  group_by(aID_STAO) |>

  # Only compute slopes for plots with at least 3 survey points
  filter(n() >= 3) |>
  summarise(
    # Fit linear model: richness ~ year
    # Extract slope (2nd coefficient) and intercept (1st coefficient)
    richness_slope    = coef(lm(richness_plant ~ yearPl))[2],
    intercept         = coef(lm(richness_plant ~ yearPl))[1],
    
    # Baseline richness at the first survey in this window
    baseline_richness = richness_plant[which.min(yearPl)],
    
    # Mean richness across all surveys (for % change calculation)
    mean_richness     = mean(richness_plant),
    
    # Survey year range (for fitted value calculation)
    year_min          = min(yearPl),
    year_max          = max(yearPl),
    
    .groups           = "drop"
  ) |>
  mutate(
    # Fitted richness at start and end of the 2001–2020 window
    fitted_start     = intercept + richness_slope * year_min,
    fitted_end       = intercept + richness_slope * year_max,
    
    # Total change as percentage of mean richness
    # If mean richness is 0, set to 0 (no change possible from zero)
    total_change_pct = if_else(mean_richness == 0, 0, (fitted_end - fitted_start) / mean_richness * 100)
  ) |>
  # Keep only the key output columns
  select(aID_STAO, richness_slope, baseline_richness, total_change_pct)

# 5. Summary statistics --------------------------------------------------------
cat("\n--- Summary ---\n")

n_moss_lost  <- n_distinct(moss_richness_filtered$aID_STAO)  - nrow(moss_slopes)
n_plant_lost <- n_distinct(plant_richness_filtered$aID_STAO) - nrow(plant_slopes)
cat("\nPlots lost due to insufficient visits (less than 3):\n")
cat("  Moss:  ", n_moss_lost, "\n") # 9
cat("  Plant: ", n_plant_lost, "\n") # 8

cat("\nNa values in the entire output tables:\n")
cat("  Moss:  ", sum(is.na(moss_slopes)), "\n") # 0
cat("  Plant: ", sum(is.na(plant_slopes)), "\n") # 0

# 6. Save RDS ------------------------------------------------------------------
cat("\n--- Saving RDS files ---\n")
saveRDS(moss_slopes,  PATH_MOSS_SLOPES_RDS)
saveRDS(plant_slopes, PATH_PLANT_SLOPES_RDS)
cat(" Saved to PATH_MOSS_SLOPES_RDS and PATH_PLANT_SLOPES_RDS\n")

# 7. Load plot coordinates and join for shapefile/CSV export -------------------
plot_coords    <- readRDS(PATH_PLOT_COORDS_RDS)  # aID_STAO, XKoord_LV95, YKoord_LV95, geometry

plot_coords_sf <- plot_coords |> 
  st_as_sf(coords = c("XKoord_LV95", "YKoord_LV95"), crs = 2056, remove = FALSE)

moss_sf  <- plot_coords_sf |>
  inner_join(moss_slopes,  by = "aID_STAO") |>
  st_as_sf()

plant_sf <- plot_coords_sf |>
  inner_join(plant_slopes, by = "aID_STAO") |>
  st_as_sf()

# 8. Save CSV ------------------------------------------------------------------
cat("\n--- Saving CSV files ---\n")
write_csv(st_drop_geometry(moss_sf),  PATH_MOSS_SLOPES_CSV)
write_csv(st_drop_geometry(plant_sf), PATH_PLANT_SLOPES_CSV)
cat("Saved to PATH_MOSS_SLOPES_CSV and PATH_PLANT_SLOPES_CSV\n")

# 9. Save shapefiles -----------------------------------------------------------
cat("\n--- Saving shapefiles ---\n")
st_write(moss_sf,  PATH_MOSS_SLOPES_SHP,  delete_dsn = TRUE, quiet = TRUE)
st_write(plant_sf, PATH_PLANT_SLOPES_SHP, delete_dsn = TRUE, quiet = TRUE)
cat("Saved to PATH_MOSS_SLOPES_SHP and PATH_PLANT_SLOPES_SHP\n")
