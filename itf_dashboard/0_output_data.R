# Code that uses existing R functions to output CSVs for ITF Power BI Dashboard

library(readr)
library(dplyr)
library(data.table)
library(SaviR)

# Path to all local R functions
rfunctions.dir <- "R/"

# Root for this project
root.dir <- "itf_dashboard/"

# Output directory to write data
output.dir <- paste0(root.dir, "output/")

source(file.path(rfunctions.dir, "packages_for_Power_BI.R"))

# country data ----
# BUG: Data source is gone. This needs to be offloaded to SaviR
# where the metadata is present in onetable and updated automtically
# because it differs from that process, and thus all the routine reports.
fun_country <- dget(paste0(rfunctions.dir, "get_country.R"))
df_country <- fun_country(rfunctions.dir)
write_csv(df_country, paste0(output.dir, "country_data.csv"), na = "")


# Correcting Namibia's ISO code
df_country$iso2code[df_country$country == "Namibia"] <- "NA"


# commenting old case/death data step out for now to test pulling SaviR source data instead of the ITF_Power_BI/ functions

# index country and date
fun_country_date <- dget(paste0(rfunctions.dir, "get_country_date.R"))
df_country_date <- fun_country_date(rfunctions.dir, df_country)
fwrite(df_country_date, paste0(output.dir, "index_data.csv"), na = "")



# OneTable -------
onetable1 <- onetable %>%
  select(-geometry, -who_region_desc) %>%
  rename(Country = who_country) %>%
  mutate(
    state_region = case_when(is.na(state_region) ~ "Non-State Region", TRUE ~ as.character(state_region)),
    who_region = case_when(is.na(who_region) ~ "Other", TRUE ~ as.character(who_region)),
    Country = case_when(Country == "" ~ "Other", TRUE ~ Country),
    map_iso = case_when(Country == "Kosovo" ~ "CS-KM", TRUE ~ id)
  ) %>%
  # add classifications for "Summary"/Epi dashboard
  mutate(
    WHO_R_Order = case_when(
      who_region == "AMRO" ~ 101,
      who_region == "EMRO" ~ 104,
      who_region == "AFRO" ~ 105,
      who_region == "EURO" ~ 102,
      who_region == "WPRO" ~ 106,
      who_region == "SEARO" ~ 103,
      TRUE ~ 109
    ),
    STATE_R_Order = case_when(
      state_region == "South and Central Asia" ~ 4,
      state_region == "Sub-Saharan Africa" ~ 5,
      state_region == "Europe and Eurasia" ~ 2,
      state_region == "Near East (Middle East and Northern Africa)" ~ 3,
      state_region == "Western Hemisphere" ~ 6,
      state_region == "Non-State Region" ~ 9,
      state_region == "East Asia and the Pacific" ~ 1,
      state_region == "US" ~ 7,
      TRUE ~ 8
    ),
    Income_L_Order = case_when(
      incomelevel_value == "High income" ~ 201,
      incomelevel_value == "Low income" ~ 204,
      incomelevel_value == "Lower middle income" ~ 203,
      incomelevel_value == "Upper middle income" ~ 202,
      incomelevel_value == "Not classified" ~ 209,
      TRUE ~ 205
    )
  ) %>%
  distinct()

# create row for "Other"--------
otherdf <- data.frame(
  id = "OTH",
  iso2code = "OT",
  state_region = "Other",
  who_region = "Other",
  Country = "Other",
  incomelevel_value = "Other",
  population = NA,
  eighteenplus = NA,
  WHO_R_Order = 109,
  STATE_R_Order = 8,
  Income_L_Order = 205
)

onetable2 <- bind_rows(onetable1, otherdf)

fwrite(onetable2, paste0(output.dir, "onetable.csv"), na = "", row.names = FALSE)

# Case/Death data ---------------------------
savi_coviddf <- get_covid_df("WHO+JHU") %>%
  # replace Other with JG to link to Onetable
  mutate(
    iso2code = case_when(country == "Other" ~ "OT", TRUE ~ iso2code),
    country = case_when(
      country %in% c("China", "Hong Kong", "Taiwan", "Macau") & source == "JHU" ~ paste0(country, "-JHU"),
      country %in% c("China") & source == "WHO" ~ paste0(country, "-WHO"),
      TRUE ~ country
    )
  ) %>%
  left_join(select(onetable2, iso2code, id), by = "iso2code") %>%
  mutate(ou_date_match = paste(id, date, sep = "_")) %>%
  select(-id)

fwrite(savi_coviddf, paste0(output.dir, "cases_deaths.csv"), na = "", row.names = FALSE)

# prep for input to overlay function
df_ncov <- savi_coviddf %>%
  rename(data_source = source) %>%
  left_join(select(onetable, -geometry), by = "iso2code") %>%
  rename(country_code = id)



# confirm with team whether they want to switch to "preferred" method

# pulling directly from FIND data source
testing1 <- SaviR:::get_find_testing_long() %>%
  #  select(iso_code,date,positive_rate,new_tests,total_tests,new_tests_smoothed_per_thousand,new_tests_per_thousand,tests_per_case) %>%
  select(id, date, new_tests_original, total_tests_original, new_tests_daily7_per_1k) %>%
  rename(
    iso_code = id,
    new_tests = new_tests_original,
    total_tests = total_tests_original,
    new_tests_smoothed_per_thousand = new_tests_daily7_per_1k,
  )

fwrite(testing1, paste0(output.dir, "find_testing.csv"), na = "", row.names = FALSE)


# vaccine data for Summary page- Internal DB source  -----
vax <- get_vax()
all_dates <- seq.Date(from = as.Date(min(vax$date)), to = as.Date(max(vax$date)), by = "day")



owid_vax <- vax %>%
  # need to add missing dates
  tidyr::complete(id, date = all_dates) %>%
  # carry forward all indicators
  calc_vax_carryforward() %>%
  calc_vax_carryforward(c(
    "daily_vaccinations", "daily_vaccinations_per_million", "daily_people_vaccinated", "daily_people_vaccinated_per_hundred",
    "daily_vaccinations_per_hundred"
  )) %>%
  # add some more columns for dashboard - the Vaccination_Tracker query brings in population data, but I am not sure if that's necessary
  mutate(
    people_vaccinated_per100_bin = case_when(
      is.na(people_vaccinated_per_hundred) ~ "No data",
      people_vaccinated_per_hundred < 3 ~ "<3",
      people_vaccinated_per_hundred < 10 & people_vaccinated_per_hundred >= 3 ~ "3 - <10",
      people_vaccinated_per_hundred < 20 & people_vaccinated_per_hundred >= 10 ~ "10 - <20",
      people_vaccinated_per_hundred < 30 & people_vaccinated_per_hundred >= 20 ~ "20 - <30",
      people_vaccinated_per_hundred < 40 & people_vaccinated_per_hundred >= 30 ~ "30 - <40",
      people_vaccinated_per_hundred < 60 & people_vaccinated_per_hundred >= 40 ~ "40 - <60",
      people_vaccinated_per_hundred < 70 & people_vaccinated_per_hundred >= 60 ~ "60 - <70",
      people_vaccinated_per_hundred >= 70 ~ "70+"
    ),
    people_vaccinated_per100_binorder = case_when(
      is.na(people_vaccinated_per_hundred) ~ 0,
      people_vaccinated_per_hundred < 3 ~ 1,
      people_vaccinated_per_hundred < 10 & people_vaccinated_per_hundred >= 3 ~ 2,
      people_vaccinated_per_hundred < 20 & people_vaccinated_per_hundred >= 10 ~ 3,
      people_vaccinated_per_hundred < 30 & people_vaccinated_per_hundred >= 20 ~ 4,
      people_vaccinated_per_hundred < 40 & people_vaccinated_per_hundred >= 30 ~ 5,
      people_vaccinated_per_hundred < 60 & people_vaccinated_per_hundred >= 40 ~ 6,
      people_vaccinated_per_hundred < 70 & people_vaccinated_per_hundred >= 60 ~ 7,
      people_vaccinated_per_hundred >= 70 ~ 8
    ),
    people_fully_vaccinated_per100_bin = case_when(
      is.na(people_fully_vaccinated_per_hundred) ~ "No data",
      people_fully_vaccinated_per_hundred < 3 ~ "<3",
      people_fully_vaccinated_per_hundred < 10 & people_fully_vaccinated_per_hundred >= 3 ~ "3 - <10",
      people_fully_vaccinated_per_hundred < 20 & people_fully_vaccinated_per_hundred >= 10 ~ "10 - <20",
      people_fully_vaccinated_per_hundred < 30 & people_fully_vaccinated_per_hundred >= 20 ~ "20 - <30",
      people_fully_vaccinated_per_hundred < 40 & people_fully_vaccinated_per_hundred >= 30 ~ "30 - <40",
      people_fully_vaccinated_per_hundred < 60 & people_fully_vaccinated_per_hundred >= 40 ~ "40 - <60",
      people_fully_vaccinated_per_hundred < 70 & people_fully_vaccinated_per_hundred >= 60 ~ "60 - <70",
      people_fully_vaccinated_per_hundred >= 70 ~ "70+"
    ),
    people_fully_vaccinated_per100_binorder = case_when(
      is.na(people_fully_vaccinated_per_hundred) ~ 0,
      people_fully_vaccinated_per_hundred < 3 ~ 1,
      people_fully_vaccinated_per_hundred < 10 & people_fully_vaccinated_per_hundred >= 3 ~ 2,
      people_fully_vaccinated_per_hundred < 20 & people_fully_vaccinated_per_hundred >= 10 ~ 3,
      people_fully_vaccinated_per_hundred < 30 & people_fully_vaccinated_per_hundred >= 20 ~ 4,
      people_fully_vaccinated_per_hundred < 40 & people_fully_vaccinated_per_hundred >= 30 ~ 5,
      people_fully_vaccinated_per_hundred < 60 & people_fully_vaccinated_per_hundred >= 40 ~ 6,
      people_fully_vaccinated_per_hundred < 70 & people_fully_vaccinated_per_hundred >= 60 ~ 7,
      people_fully_vaccinated_per_hundred >= 70 ~ 8
    )
  )
fwrite(owid_vax, paste0(output.dir, "vax_wide.csv"), na = "", row.names = FALSE)

# vaccine data for TRACKER - eventually need to align this with interval Vax data, which pulls from SaviR  ----------------------
fun_vax <- dget(paste0(rfunctions.dir, "get_vax_data.R"))
vax_dict <- fun_vax(rfunctions.dir)

fwrite(vax_dict$all %>% filter(count_or_rate == "Count"), paste0(output.dir, "vaccinations_all_counts.csv"), na = "", row.names = FALSE)
fwrite(vax_dict$all %>% filter(count_or_rate == "Rate"), paste0(output.dir, "vaccinations_all_rates.csv"), na = "", row.names = FALSE)
fwrite(vax_dict$manufacturers, paste0(output.dir, "vaccinations_manufacturers.csv"), na = "", row.names = FALSE)
fwrite(vax_dict$rollout, paste0(output.dir, "vaccinations_rollout.csv"), na = "", row.names = FALSE)
fwrite(vax_dict$categories, paste0(output.dir, "vaccinations_categories.csv"), na = "", row.names = FALSE)
fwrite(vax_dict$age, paste0(output.dir, "vaccinations_by_age.csv"), na = "", row.names = FALSE)


# Run Testing Data Algorithms
testing <- get_testing()
testing_long <- get_testing_long()
preferred_tests14 <- get_preferred_tests14(testing_long)
preferred_testpos7 <- get_preferred_testpos7(testing_long)

fwrite(testing, paste0(output.dir, "testing.csv"), na = "", row.names = FALSE)
fwrite(testing_long, paste0(output.dir, "testing_long.csv"), na = "", row.names = FALSE)
fwrite(preferred_tests14, paste0(output.dir, "preferred_tests14.csv"), na = "", row.names = FALSE)
fwrite(preferred_testpos7, paste0(output.dir, "preferred_testpos7.csv"), na = "", row.names = FALSE)


# overlay data
fun_overlay <- dget(paste0(rfunctions.dir, "get_country_overlays.R"))
overlay_dict <- fun_overlay(rfunctions.dir, df_ncov)
fwrite(overlay_dict$cases_deaths, paste0(output.dir, "overlay_cases_deaths.csv"), na = "", row.names = FALSE)
fwrite(overlay_dict$stringency, paste0(output.dir, "overlay_stringency.csv"), na = "", row.names = FALSE)

# hospitalization data

source(paste0(rfunctions.dir, "get_hospital_data.R"))
hosp_list <- hospdata_combine()
hospdata <- hosp_list$hospdata
ecdc_indicators <- hosp_list$ecdc_indicators
owid_indicators <- hosp_list$owid_indicators

hospdata_recent <- cross_hosp(hospdata)
hospdata_long <- long_hosp_fill(hospdata, ecdc_indicators, owid_indicators)


fwrite(hospdata_long, paste0(output.dir, "hosp_data_long.csv"), row.names = FALSE)
fwrite(hospdata_recent, paste0(output.dir, "hosp_data_latest.csv"), row.names = FALSE)
