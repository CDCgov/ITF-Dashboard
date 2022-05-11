# =============================================================== #
# Upload ITF Dashboard data to Azure Data Lake                    #
# Sean Browning (sbrowning <a> cdc <punto> gov)                   #
# =============================================================== #
library(AzureRMR)
library(AzureStor)

# Web path to container in data lake
data_lake_path <- Sys.getenv("AZURE_DL_PATH")

# Container Path
dashboard_folder_path <- "DGHT/ITF-SAVI/Dashboard/External/"

# Internal CSV files to commit
files_to_update <- "covid_data_tracker/output/*.csv"

# === Azure Data Lake connection ================================
# Auth with Azure and connect to storage container
azure_token <- get_azure_token(
  "https://storage.azure.com",
  tenant = Sys.getenv("AZURE_TENANT_ID"),
  app = Sys.getenv("AZURE_APP_ID"),
  password = Sys.getenv("AZURE_APP_SECRET")
)

azure_container <- storage_container(data_lake_path, token = azure_token)

# === Upload data to ADLS ========================================
storage_multiupload(azure_container, files_to_update, dashboard_folder_path)
