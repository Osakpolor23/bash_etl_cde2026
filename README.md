# NZ Annual Enterprise Survey ETL Pipeline Using Bash Scripting
This is a small but yet efficient idempotent bash ETL pipeline that extracts NZ Stats' Annual
Enterprise Survey data into a Raw folder, transforms it and outputs into a Transformed layer, and then loads it into a Gold layer. The aim is to clearly mirror a medallion architecture of moving data from a Raw layer, to Silver and then to Gold.

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
├── etl.sh                        # the entire ETL pipeline script file
├── log_file.log                  # timestamped run log, appended on every run
└── README.md
```

## Project Workflow
The bash script was carefully written to achieve three things specifically:

- **Extract:** Download the  NZ Annual Enterprise CSV file using this [url](https://www.stats.govt.nz/assets/Uploads/Annual-enterprise-survey/Annual-enterprise-survey-2023-financial-year-provisional/Download-data/annual-enterprise-survey-2023-financial-year-provisional.csv). However, before this download is done, some few checks are first carried out. Firstly, a check to see if the Raw folder already exists, and if not, creates that directly. Futhermore, the existence of the target csv file to write out the downloaded csv file to is also checked, as well as checking if the file is empty or not. It is only when these two things are not in place, before etl logic proceeds to download the csv file from the url. This is to avoid downloading the csv file everytime the etl bash script is executed, even though the raw file is already persisted locally. One thing to note in the download process is the use of the -f option on the curl command. This is intentional and deliberate in case the dowload curl errors due to an HTTP, this error message won't be written to the raw csv file instead. This is helped with the `set -e` command at the top of the script to end the bash process on any error instead of continuing to run.

- **Transform:** The transformation process simply involves renaming a column in the raw file 'Variable_code' to lower-cased 'variable_code' in place. However, before this is done, the script keeps a backup of the original csv file in case there is a need to rollback to the initial state of the raw file. Also, to keep the script idempotent and avoid altering the state of the backup file with an already-transformed raw csv, it first checks for the existence of the backup csv file also before running the sed command and keeping a backup. Also, just like in the Extract phase, it checks for the existence of the Transformed folder, as well as the expected target transformed csv file before selecting the necessary columns and the output redirected to the target file and folder. The idea is to keep the process idempotent and maintain data quality.

- **Load:** Finally, the transformed file is copied to `Gold` folder, but not before making the necessary checks such as folder existence, file existence, as well as file freshness using the built-in shell comparison options like -nt (newer than).

The script ensures that the whole process is properly logged so as to keep track of each execution process and to have a means of debugging pipeline failure i.e a means to know what broke and why.

Finally, I created a cron job in the crontab by by opening the crontab editor using the command `crontab -e` and appending the command 0 0 * * * bash /path_to/etl.sh. *The purpose of this cronjob is to run the bash script called *"etl.sh"* at 12 midnight daily.*

## Design decisions & logic

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

## Quickstart

```bash
git clone <this-repo>
cd <this-repo>
bash etl.sh
```

That's it. Re-running `bash etl.sh` is safe. it will detect
what's already been done and skip straight to whatever's actually
missing or stale.

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
- **`cut` was considered and rejected** for column selection —
  worth noting because it's a natural first instinct for this task,
  but `cut -f` silently reorders fields ascending regardless of the
  order you list them, so it can't produce `$1, $9, $5, $6` in that
  order. `awk` was necessary.
- **No CSV-quoting awareness.** Both `sed` and `awk` here split on raw
  commas. If a field in the source data were ever quoted text
  containing a literal comma, column parsing would break. The NZ Stats
  source data used here doesn't have this issue, but this script would
  need a proper CSV parser (or a tool like `csvkit`) to be safe against
  arbitrary CSV input.
- **This is a single-file, single-host bash script**, not a scheduled
  or orchestrated pipeline — no retries, no alerting, no parallelism.
  It's a deliberately minimal foundation before reaching for something
  like Airflow.