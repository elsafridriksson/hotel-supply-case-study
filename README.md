# Hotel supply partner case study (synthetic data)

A small commercial analytics case study: which hotel supply partners to grow, what to negotiate, and where inventory is thin.

All data is invented. Nothing here describes a real company.

## Files

- `generate_data.py` builds 10,000 synthetic offers (`offers.csv`, `offers.db`). Seeded, so results reproduce.
- `analysis.sql` holds the queries. Written in SQLite, easy to port to Snowflake.
- `run_analysis.py` runs each query and saves `results/*.csv`.
- `summary.md` is the findings and recommendations.

## Run it

    python3 generate_data.py
    python3 run_analysis.py

## Reporting workflow

The SQL outputs are the source of truth. The written summary is drafted by an AI assistant from the validated CSVs only, then checked line by line against them. The same step could run on a schedule for recurring partner questions.
