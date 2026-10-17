# Page-load analysis

psql scripts for measuring how fast FreshPorts renders pages, using the
`page_load_detail` and `page_load_summary` tables. They were written to measure
the October 2026 performance work (bot traffic on search, the search gate, and
the database changes and release of 2026-10-17), and are meant to be re-run
after future releases.

## Where the numbers come from

Every fully rendered page inserts one row into `page_load_detail`:

| Column           | Contents                                                  |
|------------------|-----------------------------------------------------------|
| `date`, `time`   | when the page was rendered (database time zone, UTC on prod) |
| `page_name`      | `$_SERVER['SCRIPT_NAME']`, e.g. `/search.php`             |
| `user_id`        | the logged-in user, NULL if anonymous                     |
| `ip_address`     | `$_SERVER['REMOTE_ADDR']`                                 |
| `full_url`       | `$_SERVER['REQUEST_URI']`, including the query string     |
| `rendering_time` | from PHP start to the page footer                         |

The row is written by `PageLoadDetail::Save()` (`classes/page_load_detail.php`
in the website repo), called from the page footer in `include/freshports.php`,
and from `www/news.php` and `www/backend/commits-recent.php`.

`rendering_time` covers everything from PHP start to the footer: database
queries, PHP, and building the HTML. That makes it a different view from
`pg_stat_statements`, which only sees time inside the database.

### What is not recorded

Only pages that reach the footer get a row. These never do:

- login refusals (for example, search for anonymous users when `LOGIN_TO_SEARCH` is on)
- search-gate challenges
- requests refused by nginx
- single-result searches, which redirect to the port page

Counts are therefore lower than real traffic, and bot traffic that was refused
does not appear at all.

### How category and port pages appear

nginx sends any URL that is not a file to `/--/new-url-parsing.php`
(`try_files`). Category pages (`/<category>/`) and port pages
(`/<category>/<port>/`) therefore share that `page_name`. The scripts split
them by the depth of the path in `full_url`.

### Retention

A daily periodic job, `220.fp_daily_rendering_times`, runs
`daily_rendering_times.pl` (in the ingress-scripts repo) for yesterday. It:

1. calls `PageLoadSummaryUpdate(date)` (in `sp.txt`) to write one row per
   `page_name` per day into `page_load_summary`: count, logged-in count, and
   min/max/avg rendering time;
2. deletes `page_load_detail` rows older than 7 days.

**Detail is kept for about 8 days only.** For a before/after comparison,
run the queries (or export the detail with `08-detail-export.sql`) before the
days you need are deleted.

`page_load_summary` goes back to 2003, but it has no percentiles and cannot
separate category from port pages, or one search type from another. Use it for
long-run volume and rough trends only. Before 2018 it also holds one row per
URL per day, from when port pages were served through `/missing.php`; see
06 and 07.

## Running the scripts

```sh
psql -X -f 01-inventory.sql
psql -X -v since=2026-09-15 -v release='2026-10-17 07:57' -f 02-search.sql
```

The connection comes from your environment (`PGHOST`, `PGDATABASE`, `PGUSER`,
`~/.pg_service.conf` and so on). Variables passed with `-v` override the
defaults set at the top of each script. Every query filters on the indexed
`date` column; each script takes between 1 and 10 seconds on prod.

## Scripts

| Script | What it does | Changes data? |
|--------|--------------|---------------|
| `01-inventory.sql` | Time zone, table definitions, the source of `PageLoadSummaryUpdate`, sizes, insert/delete/vacuum stats, date ranges, rows per day in both tables, top page names | No |
| `02-search.sql` | Searches per day, per search type (`stype`/`method`) and logged-in status; before vs after a release; hourly from 2026-10-15; long-run from the summary. Variables: `since`, `release` | No |
| `03-pages.sql` | Category, port, front page, `ports-new`, `ports-broken`, `commit`, `vuxml`: before vs after a release, per day, and summary trend. Variables: `since`, `release` | No |
| `04-page-load-daily.sql` | **Proposal, not installed.** Adds `page_load_daily` (per day, page class and logged-in status: views, IPs, avg, p50, p95, p99, max), `page_load_class()` and `page_load_daily_update(date)` | Yes: creates a table and functions |
| `05-release-compare.sql` | N days before vs after a release, from `page_load_daily`. Variables: `release`, `days`. Needs 04 | No |
| `06-summary-export-pre2018.sql` | Exports `page_load_summary` rows before 2018 to a gzipped CSV on the client host. Reads the whole table; run off-peak | No (writes a local file) |
| `07-summary-truncate-pre2018.sql` | Keeps only rows from 2018 on in `page_load_summary` (copy aside, `TRUNCATE`, put back). Run only after checking 06's export | **Yes: deletes rows** |
| `08-detail-export.sql` | One-off copy of `page_load_detail` from a given date to a gzipped CSV on the client host, and how to load it back into a temp table so 02 and 03 run against it | No (writes a local file) |

## After a release

1. Note the release time in UTC.
2. Wait a few days for enough traffic, but no more than about 7, or the
   "before" days will have been deleted. Export with 08 if in doubt.
3. Run 02 and 03 with `-v release='YYYY-MM-DD HH:MM'` and a `since` that
   covers the days before.
4. Compare medians and 95th percentiles rather than averages: a few very slow
   pages pull the average far from the typical case.

## Personal data

`ip_address` and `full_url` identify visitors. The queries report
aggregates only (counts, distinct IPs, distinct /24 or /48 networks).
`08-detail-export.sql` writes raw rows, IP addresses included, and creates its
file readable only by its owner. Keep that file off shared storage and delete
it when the analysis is done. (`page_load_summary`, exported by 06, holds no
IP addresses or user ids.)
