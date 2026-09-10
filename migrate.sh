#!/usr/bin/bash
set -e

SOURCE="./source"
DEST="./json_and_CSV"

# Check to see if json_and_CSV folder exists
echo "Checking to see if $DEST folder exists"
if [[ -d "$DEST" ]]; then
    echo "$DEST folder exists, proceeding to next phase"
else
    echo "$DEST folder doesn't exist, creating it..."
    mkdir -p "$DEST"
    echo "$DEST folder created, proceeding to next phase"
fi;

# Loop through the source folder
for file in "$SOURCE"/*
do

    # skip if nothing matched the glob (empty source folder)
    [[ -e "$file" ]] || { echo "No files found in $SOURCE, nothing to migrate"; continue; }

    # Strip the directory path off and just leave only the filename
    FILENAME="$(basename "$file")"

    # check if the file is a .json or .csv file and not in destination folder
    echo "Looping through $SOURCE and checking if $FILENAME is a json or csv file"
    if [[ $file == *.json && ! -e "$DEST/$FILENAME" ]]; then
        echo "$FILENAME is a json file"
        mv "$SOURCE/$FILENAME" "$DEST/$FILENAME"
        echo "$FILENAME is a json file and moved to $DEST"
    elif [[ $file == *.csv && ! -e "$DEST/$FILENAME" ]]; then
        echo "Checking to see if $FILENAME is a csv file"
        mv "$SOURCE/$FILENAME" "$DEST/$FILENAME"
        echo "$FILENAME is a csv file and moved to $DEST"
    else
        echo "$FILENAME is neither a json or csv file, moving aborted"
    fi;
done