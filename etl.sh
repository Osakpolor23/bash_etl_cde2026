#!/usr/bin/bash

# set pipeline failure
set -e


URL="https://www.stats.govt.nz/assets/Uploads/Annual-enterprise-survey/Annual-enterprise-survey-2023-financial-year-provisional/Download-data/annual-enterprise-survey-2023-financial-year-provisional.csv"
RAW="./raw/"
RAW_CSV="./raw/raw_csv.csv"
LOG_FILE="./log_file.log"

#######################################################################################################
                                     # EXTRACTION
#######################################################################################################

# check if log file exists
echo "$(date): Checking if log file $LOG_FILE exists..."
if [[ -f "$LOG_FILE" ]]; then
    echo "$(date): The log file exists, moving on to extraction..."
else
    echo "$(date): The log file does not exist, creating the log file..."
    touch "$LOG_FILE"
    echo "$(date): The $LOG_FILE file creation completed, moving on to extraction..."
fi;

# check if raw folder exists
echo "$(date): Checking if the raw folder exists in the current directory..." | tee -a "$LOG_FILE"
if [[ ! -d "$RAW" ]]; then
    echo "$(date): The raw folder does not exist. Creating Folder $RAW...." | tee -a "$LOG_FILE"
    mkdir "$RAW"
else
    echo "The raw folder $RAW exists." | tee -a "$LOG_FILE"
fi;


# check if the file exists inside the folder and it is not empty
echo "$(date): Checking if the $RAW_CSV file exists in the folder and not empty..." | tee -a "$LOG_FILE"
if
    [[ -f "$RAW_CSV" && -s "$RAW_CSV" ]]; then
    echo "$(date): The $RAW_CSV file exists in the folder and not empty. Skipping Download" | tee -a "$LOG_FILE"
else
    # create the file and download the csv
    echo "$(date): Creating the file $RAW_CSV..."  | tee -a "$LOG_FILE"
    touch "$RAW_CSV"
    echo "$(date): The file creation complete. Proceeding to download..."  | tee -a "$LOG_FILE"
    curl -f -o "$RAW_CSV" "$URL"
    echo "The csv file downloaded and output to $RAW_CSV" | tee -a "$LOG_FILE"
fi;

echo "Extraction process complete. Proceeding to Transformation..." | tee -a "$LOG_FILE"

######################################################################################################
                                        # TRANSFORMATION
######################################################################################################