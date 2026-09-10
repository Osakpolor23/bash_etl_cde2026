# Bash Data Engineering Scripts: NZ Enterprise Survey ETL & File Migration Utility
 
A small collection of bash scripts built to practice core data engineering
concepts such as idempotent pipelines, file-state logic, and safe file handling
using shell scripting. The repo currently contains two independent scripts:
 
1. **`etl.sh`** — Extracts NZ Stats' Annual Enterprise Survey data, transforms
   it, and loads it into a Gold layer, following a medallion architecture.

2. **`migrate.sh`** — A standalone utility that scans a source folder and
   moves `.json` and `.csv` files into a separate destination folder,
   leaving everything else untouched.

## Folder structure

```
.
├── raw/                          # Extraction layer — untouched source data
│   ├── raw_csv.csv
│   └── raw_csv.csv.bckup         # pre-transform backup, created once by sed
├── Transformed/                  # Transformation layer — cleaned, column-pruned
│   └── 2023_year_finance.csv
├── Gold/                         # Load layer — final output, ready for consumption
│   └── 2023_year_finance.csv
├── etl.sh                        # NZ Enterprise Survey ETL pipeline script
├── source/                       # Input folder for migrate.sh — mixed file types
|   └── languages.json            # Sample file to be moved
├── json_and_CSV/                 # Output folder for migrate.sh — only .json/.csv files
|   └── orders2018jan.csv         # Example moved file (json or csv)
├── migrate.sh                    # JSON/CSV file migration utility script
├── log_file.log                  # timestamped run log for etl.sh, appended every run
└── README.md
```

## Project Workflow

### `etl.sh` — Extract, Transform, Load
The bash script was carefully written to achieve three things specifically:

- **Extract:** Download the  NZ Annual Enterprise CSV file using this [url](https://www.stats.govt.nz/assets/Uploads/Annual-enterprise-survey/Annual-enterprise-survey-2023-financial-year-provisional/Download-data/annual-enterprise-survey-2023-financial-year-provisional.csv). However, before this download is done, some few checks are first carried out. Firstly, a check to see if the Raw folder already exists, and if not, creates that directly. Futhermore, the existence of the target csv file to write out the downloaded csv file to is also checked, as well as checking if the file is empty or not. It is only when these two things are not in place, before etl logic proceeds to download the csv file from the url. This is to avoid downloading the csv file everytime the etl bash script is executed, even though the raw file is already persisted locally. One thing to note in the download process is the use of the -f option on the curl command. This is intentional and deliberate in case the dowload curl errors due to an HTTP error code, this error message won't be written to the raw csv file instead. This is helped with the fact that the `set -e` command is written at the top of the script to end the bash process on any error instead of continuing to run.

- **Transform:** The transformation process simply involves renaming a column in the raw file i.e 'Variable_code' to a lower-cased 'variable_code' in place. However, before this is done, the script keeps a backup of the original csv file in case there is a need to rollback to the initial state of the raw file. Also, to keep the script idempotent and to avoid altering the state of the backup file with an already-transformed raw csv, it first checks for the existence of the backup csv file before running the sed command and keeping a backup. Also, just like in the Extract phase, it checks for the existence of the Transformed folder, as well as the expected target transformed csv file before selecting the necessary columns and the output redirected to the target file and folder. The idea is to keep the process idempotent and maintain data quality.

- **Load:** Finally, the transformed file is copied to `Gold` folder, but not before making the necessary checks such as folder existence, file existence, as well as file freshness using the built-in shell comparison options like -nt (newer than).

The script ensures that the whole process is properly logged so as to keep track of each execution process and to have a means of debugging pipeline failure i.e a means to know what broke and why.

Finally, I created a cron job in the crontab by by opening the crontab editor using the command `crontab -e` and appending the command 0 0 * * * bash /path_to/etl.sh. *The purpose of this cronjob is to run the bash script called *"etl.sh"* at 12 midnight daily.*

### `migrate.sh` — JSON/CSV file migration
This script specifically checks a folder if there are json or csv files and then moves them to another folder. However, it does a few validations in the course of doing that, which includes:

- Checks whether the destination folder (`json_and_CSV/`) exists, creating
  it if not.

- Loops through every file in `source/` using an **unquoted** glob
  (`"$SOURCE"/*`) as quoting the glob disables wildcard expansion entirely.

- Guards against an empty source folder: when the glob matches nothing,
  bash still enters the loop once with the literal unexpanded pattern as
  the value, so the script explicitly checks `[[ -e "$file" ]]` before
  doing anything, and prints a message before skipping:

```bash
  [[ -e "$file" ]] || { echo "No files found in $SOURCE, nothing to migrate"; continue; }
```

- Extracts the bare filename with `basename` before using it in any
  destination path or `mv` command as the loop variable itself holds the
  *full path* (e.g. `./source/data.json`), and using it directly for both
  the source and destination paths caused doubled, non-existent paths
  (`./source/./source/data.json`) in earlier versions.

- Moves `.json` and `.csv` files into the destination folder only if a
  file with the same name doesn't already exist there, and leaves every
  other file type untouched.

## Design decisions & logic

### etl.sh
**One script, three phases, guarded by file-existence and staleness
checks.** Rather than always re-downloading, re-transforming, and
re-loading on every run, each phase asks "has this already been done,
and is it still valid?" before doing any work:

- **Extraction** skips the download if `raw_csv.csv` already exists and
  is non-empty (`-f && -s`). `curl -f` is used so an HTTP error (e.g. a
  404 from a moved dataset) causes curl to exit non-zero and fail the
  script via `set -e`, instead of silently saving an HTML error page as
  if it were the CSV.

- **Transformation** renames the `Variable_code` column via `sed -i.bckup`
  exactly once, guarded by a simple "does the backup file already
  exist?" check.

  Column selection and reordering (`$1, $9, $5, $6`, in that specific
  order) is done with `awk -F',' 'BEGIN{OFS=","}'` rather than `cut`,
  because `cut -f` always emits fields in ascending numeric order and
  can't reorder them. So `awk` was the only option that respected the
  exact column order needed.
  This step uses `-nt` (bash's "newer than" file-test operator) to
  compare `Transformed/2023_year_finance.csv` against `raw/raw_csv.csv`. If the transformed file is missing, empty, or older than the raw
  source, it's regenerated; otherwise it's left alone.

- **Load** follows the same pattern i.e `Gold/2023_year_finance.csv` is
  only overwritten if it's missing, empty, or older than the
  transformed file it depends on.

- **Logging** uses `tee -a` (append), not `tee` (overwrite), so
  `log_file.log` accumulates a full history across runs instead of
  being wiped every time a line is logged.

- **`set -e` at the top** ensures any unexpected command failure (e.g a
  bad `curl`, a malformed `sed`) stops the whole pipeline immediately
  rather than continuing on top of a broken intermediate state.


### migrate.sh

**A single-pass file router, guarded by existence checks on both ends —
source and destination.** The goal is to sort mixed file types into a
dedicated folder without ever double-moving, overwriting, or silently
failing on a file that isn't there:

- **Destination folder creation*:* The destination folder is checked once up front (`[[ -d "$DEST" ]]`)
  and created with `mkdir -p` only if missing — the same "don't assume,
  check" pattern used throughout `etl.sh`.

- **The source loop uses an unquoted glob** (`for file in "$SOURCE"/*`):
  This was a deliberate fix after an earlier version quoted the glob
  pattern (`"$SOURCE/*"`), which disables wildcard expansion entirely and
  silently turns the loop into a single iteration over a literal string
  instead of the files inside the folder. Quoting the *variable* is still
  correct and necessary (`"$SOURCE"`) — it's specifically the `*` that
  must stay outside the quotes to remain a wildcard.

- **An explicit empty-folder guard** handles the case where the glob
  matches nothing. By default, bash doesn't drop an unmatched glob — it
  passes the literal, unexpanded pattern (`./source/*`) through as the
  loop variable's value instead of skipping the iteration. Left
  unhandled, the script would then try to process a nonexistent file
  named literally `*`. The guard catches this explicitly and exits the
  iteration with a clear message rather than failing further downstream
  with a confusing error:

```bash
  [[ -e "$file" ]] || { echo "No files found in $SOURCE, nothing to migrate"; continue; }
```

- **`basename` extracts the bare filename from the full glob path.**
  `$file` from the loop is always a full path (e.g. `./source/data.json`),
  not just a filename. An earlier version used `$file` directly when
  building destination paths and `mv` commands, which produced doubled,
  non-existent paths like `./source/./source/data.json` — `mv` failed on
  these silently (no `set -e`, no exit-code check), while the script's
  own log output still claimed the move succeeded. Extracting
  `FILENAME="$(basename "$file")"` once per iteration and using it
  consistently on both the `mv` source and destination sides fixed this.

- **Pattern matching against the extension is done with an unquoted glob
  inside `[[ ]]`** (`$file == *.json`), not a quoted string
  (`$file == "*.json"`). Inside `[[ ]]`, `==` only performs wildcard
  pattern matching when the right-hand side is unquoted; quoting it turns
  the comparison into a literal string match, which would never succeed
  since no filename is literally `*.json`.

- **Both branches (`.json` and `.csv`) check `! -e "$DEST/$FILENAME"`**
  before moving — this makes reruns idempotent. A file that's already
  been moved to `json_and_CSV/` won't attempt to move again if it somehow
  still exists in `source/`, and any file not matching `.json` or `.csv`
  falls through to the `else` branch and is left untouched.

## Quickstart

```bash
git clone <this-repo>
cd <this-repo>

# run the ETL pipeline
bash etl.sh

# run the file migration utility
bash migrate.sh
```

Both scripts are safe to re-run — `etl.sh` will skip stages that are
already up to date, and `migrate.sh` will skip files that have already
been moved.

## Limitations

- **The `sed` rename step doesn't check staleness, only existence.**
  If you delete and re-download `raw_csv.csv` with genuinely new data,
  a leftover `.bckup` file from a previous run will block the rename
  from re-running. I initially tried a timestamp-based (`-ot`) check
  for this, but discovered it was fundamentally broken: `sed -i`
  always writes the *original* file after creating its backup, so the
  original's mtime is permanently, unconditionally newer than its own
  backup — making any freshness check against that pair meaningless.
  I reverted to the simpler existence check rather than solve this
  properly (e.g. tracking a separate download-marker file, or checking
  file *content* instead of timestamps) — a known tradeoff, not an
  oversight.

- **Staleness detection is timestamp-based (`-nt`/`-ot`), not
  content-based.** Touching a file without changing its content will
  still trigger a reprocess. Fine for this use case; wouldn't scale to
  a system where mtimes get touched by unrelated processes (backups,
  syncs, etc.).
