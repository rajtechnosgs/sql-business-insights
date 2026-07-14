
# SQL Business Insights — Task 1

A 10-query business analytics SQL project built on a 10,000-customer / 40,000-order / 100,000-session e-commerce dataset (`ecom` schema). Each query answers a real business question (from CEO-level revenue summaries to marketing attribution), is sanity-checked, and interpreted in [`INTERPRETATIONS.md`](INTERPRETATIONS.md).

Full write-up with 5 key insights: **[What 10 SQL Queries Told Me About This Business](https://app.notion.com/p/What-10-SQL-Queries-Told-Me-About-This-Business-39ddb0c6f8c280fc8010cc98517001c3?source=copy_link)**

Connect with me: www.linkedin.com/in/raj-dev-63963a22b

## Repo Structure

queries/ — 10 numbered .sql files, one per business question
notes/ecom_schema.md — schema recon: tables, relationships, data-quality findings
INTERPRETATIONS.md — what each query found and why it matters

## How to Run

All 10 queries run against the `ecom` schema on the internal Metabase server used for this program. To run any query: open Metabase, connect to the `ecom` database, and paste the contents of any file from `queries/` into the SQL editor. Each file has a header comment with the business question and the sanity-check assertion used to verify its correctness.

## Reflection

This task pushed me to actually understand a database before writing any business logic — Day 1 schema recon caught two real data-quality issues (mixed-case status values, inconsistent NULL representations) that would otherwise have silently broken later queries. Window functions (`LAG`, `ROW_NUMBER`, `PERCENTILE_CONT`) were the biggest new skill — they let me keep row-level detail while still comparing across time or ranking within groups. If I did this again, I'd write the sanity-check query alongside the main query from the start, rather than as an afterthought, since a couple of my early queries needed rework once I ran the check.
