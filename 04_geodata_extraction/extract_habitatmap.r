# ==============================================================================
# Script: extract_habitatmap.r
# Purpose: Extract point-level habitat type variables for each BDM plot.
#          Extracts the exact habitat polygon values for each plot coordinate.
#
# Output: bdm/processed/env_extracted/plot_habitatmap.rds
# ==============================================================================

# 1. Setup ---------------------------------------------------------------------
library(sf)
source("_config.r")

# 2. Load Data -----------------------------------------------------------------
habitat_gdb <- file.path(DATA_ROOT, "env/habitat_biotic/processed/habitat_map_v1_2/habitatmap_cropped.gpkg")

# Read the plot coordinates
plots <- sf::st_read(PATH_PLOT_COORDS_SHP)

# Load the habitat map from the geodatabase
habitat_layers <- sf::st_layers(habitat_gdb)
layer_name <- habitat_layers$name[1] # Taking the first layer
habitat_sf <- sf::st_read(habitat_gdb, layer = layer_name)

# 3. Data Extraction -----------------------------------------------------------
# Check if CRS projection matches
if (sf::st_crs(plots) != sf::st_crs(habitat_sf)) {
  stop(paste("CRS mismatch between plots and raster for:", habitat_sf))
}

# Check if extents overlap
p_ext <- sf::st_bbox(plots)
h_ext <- sf::st_bbox(habitat_sf)
if (p_ext["xmax"] < h_ext["xmin"] || p_ext["xmin"] > h_ext["xmax"] || p_ext["ymax"] < h_ext["ymin"] || p_ext["ymin"] > h_ext["ymax"]) {
  warning("Plot coordinates do not overlap with the habitat map extent.")
}

# Extract habitat attributes for each point using spatial intersection
extracted_vals <- sf::st_intersection(plots, habitat_sf)

# Print the amount of extracted values and check for duplicates
cat("Number of extracted habitat values:", nrow(extracted_vals), "\n")

# Check for NA values after extraction
na_count <- sum(is.na(extracted_vals$TypoCH_NUM)) # Adjust column name as needed
if (na_count > 0) {
  warning(sprintf("Extracted %d NA values for habitat map", na_count))
}

# Assign the extracted habitat type to the plots object
plots$TypoCH_NUM <- extracted_vals$TypoCH_NUM

# Convert to dataframe without geometry for export
plots_df <- sf::st_drop_geometry(plots)
cat("Successfully extracted habitat types.\n")

# Load the Typo_CH lookup table
lookup_path <- "../data/env/habitat_biotic/habitat_map_v1_2/typoch_num_lookuptable_26112025.csv"
lookup_table <- read.csv(lookup_path)

# Extract the first digit (1st level classification) and first two digits (2nd level classification)
plots_df$TypoCH_1st_code <- as.numeric(substr(plots_df$TypoCH_NUM, 1, 1))

# Extract the first two digits (2nd level) - will be NA if only 1 digit available
plots_df$TypoCH_2nd_code <- ifelse(nchar(plots_df$TypoCH_NUM) >= 2, 
                                     as.numeric(substr(plots_df$TypoCH_NUM, 1, 2)), 
                                     NA)
plots_df

# Subset lookup table to get TypoCH_DE based on TypoCH_NUM
lookup_de <- lookup_table[, c("TypoCH_NUM", "TypoCH_DE")]
cat("Number of rows in lookup_de:", nrow(lookup_de), "\n") # 334 rows

# Print the ones which are duplicated in the lookup table
duplicated_rows <- lookup_de[duplicated(lookup_de$TypoCH_NUM) | duplicated(lookup_de$TypoCH_NUM, fromLast = TRUE), ]
cat("Number of duplicated rows in lookup_de:", nrow(duplicated_rows), "\n") # 5 duplicates

# Remove any duplicate IDs to prevent row multiplication during merge
lookup_de <- lookup_de[!duplicated(lookup_de$TypoCH_NUM), ]
cat("Number of rows in lookup_de after removing duplicates:", nrow(lookup_de), "\n") # 331

# Merge to get TypoCH_DE for the 1st level
plots_df <- merge(plots_df, lookup_de,
                  by.x = "TypoCH_1st_code",
                  by.y = "TypoCH_NUM",
                  all.x = TRUE)
colnames(plots_df)[colnames(plots_df) == "TypoCH_DE"] <- "TypoCH_DE_1st"

# Merge to get TypoCH_DE for the 2nd level
plots_df <- merge(plots_df, lookup_de,
                  by.x = "TypoCH_2nd_code",
                  by.y = "TypoCH_NUM",
                  all.x = TRUE)
colnames(plots_df)[colnames(plots_df) == "TypoCH_DE"] <- "TypoCH_DE_2nd"

# 4. Data Export ---------------------------------------------------------------
# Save the extracted habitat data as an RDS file
saveRDS(plots_df, PATH_ENV_HABITAT)

cat("Saved extracted habitat data to:", PATH_ENV_HABITAT, "\n")