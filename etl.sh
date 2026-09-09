#!/usr/bin/bash

# set pipeline failure
set -e


URL="https://www.stats.govt.nz/assets/Uploads/Annual-enterprise-survey/Annual-enterprise-survey-2023-financial-year-provisional/Download-data/annual-enterprise-survey-2023-financial-year-provisional.csv"
RAW="./raw/"
TRANSFORMED="./Transformed/"
RAW_CSV="./raw/raw_csv.csv"
RAW_CSV_BCKUP="./raw/raw_csv.csv.bckup"
TRANSFORMED_CSV="./Transformed/2023_year_finance.csv"
GOLD="./Gold/"
GOLD_CSV="./Gold/2023_year_finance.csv"
LOG_FILE="./log_file.log"

#######################################################################################################
                                     # EXTRACTION
#######################################################################################################

# check if raw folder exists
echo "$(date): The Extraction Phase started..." | tee -a "$LOG_FILE"
echo "$(date): Checking if the raw folder exists in the current directory..." | tee -a "$LOG_FILE"
if [[ ! -d "$RAW" ]]; then
    echo "$(date): The raw folder does not exist. Creating Folder $RAW...." | tee -a "$LOG_FILE"
    mkdir "$RAW"
    echo "$(date): The raw folder $RAW created." | tee -a "$LOG_FILE"
else
    echo "$(date): The raw folder $RAW exists." | tee -a "$LOG_FILE"
fi;


# check if the file exists inside the folder and it is not empty
echo "$(date): Checking if the $RAW_CSV file exists in the folder and not empty..." | tee -a "$LOG_FILE"
if
    [[ -f "$RAW_CSV" && -s "$RAW_CSV" ]]; then
    echo "$(date): The $RAW_CSV file exists in the folder and not empty. Skipping Download and proceeding to the Transform Phase" | tee -a "$LOG_FILE"
else
    # create the file and download the csv
    echo "$(date): Creating the file $RAW_CSV..."  | tee -a "$LOG_FILE"
    touch "$RAW_CSV"
    echo "$(date): The file creation complete. Proceeding to download..."  | tee -a "$LOG_FILE"
    curl -f -o "$RAW_CSV" "$URL"
    echo "The csv file downloaded and output redirected to $RAW_CSV" | tee -a "$LOG_FILE"
fi;

 echo "Extraction process complete. Proceeding to Transformation..." | tee -a "$LOG_FILE"


######################################################################################################
                                        # TRANSFORMATION
######################################################################################################

echo "$(date): The Transformation phase started..." | tee -a "$LOG_FILE"

# Ensure the raw_csv backup file doesn't already exist
if [[ ! -f "$RAW_CSV_BCKUP" ]]; then
    # Rename the column Variable_code to variable_code, but keep a backup of the original
    echo "$(date): Renaming the column Variable_code to variable_code" | tee -a "$LOG_FILE"
    sed -i.bckup 's/Variable_code/variable_code/g' "$RAW_CSV" 
    echo "$(date): Column Variable_code renamed to variable_code and backup of original saved as $RAW_CSV_BCKUP" | tee -a "$LOG_FILE"
fi;

# create the Transformed directory if not exists
if [[ ! -d "$TRANSFORMED" ]]; then
    mkdir -p "$TRANSFORMED"
fi;

# Check if the 2023_year_finance.csv exists and not empty
echo "$(date): Checking if the $TRANSFORMED_CSV already exist and not empty..." | tee -a "$LOG_FILE"
if [[ -f "$TRANSFORMED_CSV" && -s "$TRANSFORMED_CSV" && "$TRANSFORMED_CSV" -nt "$RAW_CSV" ]]; then
    echo "$(date): The $TRANSFORMED_CSV already exist, not empty and up to date. Proceeding to the Load Phase" | tee -a "$LOG_FILE"
else
    echo "$(date): The file does not exist. Creating file..." | tee -a "$LOG_FILE"
    touch "$TRANSFORMED_CSV"
    echo "$(date): File $TRANSFORMED_CSV created. Proceeding to extracting the necessary columns..." | tee -a "$LOG_FILE"
    # extract necessary columns
    awk -F',' 'BEGIN {OFS=","} {print $1,$9,$5,$6}' "$RAW_CSV" > "$TRANSFORMED_CSV"
    echo "$(date): Columns extracted and saved as 2023_year_finance.csv in the $TRANSFORMED folder" | tee -a "$LOG_FILE"

    echo "$(date): The Transformation phase complete. Proceeding to the Load Phase..." | tee -a "$LOG_FILE"
fi;


######################################################################################################
                                        # LOAD
######################################################################################################

echo "$(date): The Load Phase started..." | tee -a "$LOG_FILE"

# Check if the Gold Folder exists, if not, creates it
echo "$(date): Checking if the Gold folder $GOLD exists..." | tee -a "$LOG_FILE"
if [[ -d "$GOLD" ]]; then
    echo "$(date): The Gold folder $GOLD exist." | tee -a "$LOG_FILE"
else
    echo "$(date): The Gold folder $GOLD doesn't exist. Creating folder..." | tee -a "$LOG_FILE"
    mkdir -p "$GOLD"
    echo "$(date): The Gold folder $GOLD created" | tee -a "$LOG_FILE"
fi;

# Check if the file 2023_year_finance.csv already exists in the Gold folder
echo "$(date): Checking if the file 2023_year_finance.csv already exists in the Gold folder..." | tee -a "$LOG_FILE"
if [[ -f "$GOLD_CSV" && -s "$GOLD_CSV" && "$GOLD_CSV" -nt "$TRANSFORMED_CSV" ]]; then
    echo "$(date): The file 2023_year_finance.csv already exists in the Gold folder,not empty and up to date. Aborting Load...." | tee -a "$LOG_FILE"
else
    echo "$(date): The Gold folder is empty. Loading...." | tee -a "$LOG_FILE"
    cp "$TRANSFORMED_CSV" "$GOLD_CSV"
    echo "$(date): The file 2023_year_finance.csv successfully Loaded to the Gold $GOLD folder" | tee -a "$LOG_FILE"
fi;

echo "$(date): The ETL Process Successfully completed" | tee -a "$LOG_FILE"


