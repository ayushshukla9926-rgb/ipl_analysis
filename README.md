# 🏏 IPL Cricket Analytics & Match Intelligence Engine (2024 - 2026)

Welcome to my end-to-end sports analytics portfolio project. This repository contains a production-grade data pipeline analyzing delivery-level Indian Premier League (IPL) data across the 2024–2026 seasons. It models match-phase dynamics, boundary dependency profiles, venue par thresholds, and historical playoff qualification pathways.

---

## 🛠️ Tech Stack

* **Database Engine:** MySQL Workbench 8.0
* **Data Processing & Validation:** Python (pandas, custom reconciliation scripts)
* **Business Intelligence:** Power BI Desktop (Star Schema Modeling, Direct Context Filtering, Dynamic Slicer Isolation)
* **Version Control & Large Assets:** Git, Git LFS (Large File Storage for `.pbix`), GitHub, VS Code

---

## 🖥️ Executive Dashboard Overview

<p align="center">
  <img src="assets/ipl_analyze.gif" alt="IPL Analytics Dashboard Live Walkthrough" width="100%" />
</p>

> **Interactive Highlights Demonstrated Above:**
> - Multi-season dynamic cross-filtering across 2024, 2025, and 2026 tournaments.
> - Over-by-over scoring velocity tracking (Overs 1–20) identifying scoring acceleration phases.
> - Boundary reliance analysis (share of total score from 4s, 6s, and running).
> - Dynamic playoff qualification matrix featuring position-aware ranking (1st to 4th place finishes).

---

## 📁 Project Structure & Modules Index

* 📂 [assets/](assets/)
  * 🎞️ [`ipl_analyze.gif`](assets/ipl_analyze.gif) — High-resolution walkthrough demo of the interactive Power BI dashboard
* 📂 [data/](data/)
  * 📄 [`dim_matches.csv`](data/dim_matches.csv) — Match-level dimension (season, venue, toss, teams, match_type)
  * 📄 [`fact_deliveries.csv`](data/fact_deliveries.csv) — Transactional ball-by-ball fact table (runs, extras, wickets, roles)
* 📂 [scripts/](scripts/)
  * 🐍 [`get_and_build_dataset.py`](scripts/get_and_build_dataset.py) — Automated ingestion & transformation pipeline preparing dimensional datasets
  * 🐍 [`validate.py`](scripts/validate.py) — Data reconciliation script verifying ball counts, extras, and run tallies
* 📂 [sql/](sql/)
  * 🗄️ [`IPL ANALYTICS DATABASE SETUP & ANALYTICAL VIEWS (2024 - 2026).sql`](<sql/IPL ANALYTICS DATABASE SETUP & ANALYTICAL VIEWS (2024 - 2026).sql>) — DDL schema setup, relational constraints, and pre-aggregated analytical views
* ⚙️ [`.gitattributes`](.gitattributes) — Git LFS tracking configuration for large binary and data assets
* ⚙️ [`.gitignore`](.gitignore) — Git exclusion rules for temporary files and local caches
* 📊 [`ipl_analysis.pbix`](ipl_analysis.pbix) — Power BI production file featuring complete star schema and custom visuals

---

## 🎯 Key Analytics Highlights

* **Automated Data Processing & Validation:** Built Python scripts (`get_and_build_dataset.py`, `validate.py`) to extract, clean, and mathematically reconcile ball-by-ball delivery facts against match scorecards with zero run leakage.
* **Relational Schema & Analytical SQL Views:** Implemented a star schema in MySQL, backed by analytical SQL views that pre-aggregate venue scoring baselines, phase run rates, and high-pressure death-overs leverage.
* **Match Phase Inflection Points:** Segmented matches into Powerplay (Overs 1–6), Middle Overs (Overs 7–15), and Death Overs (Overs 16–20) to evaluate acceleration trends and resource conservation.
* **Boundary Dependency Index:** Deconstructed team totals into boundary contributions (fours and sixes) versus active strike rotation (running between wickets) using a 100% stacked decomposition.
* **Venue Intelligence & Ground Bias:** Mapped 1st innings versus 2nd innings average scoring thresholds across stadiums to identify ground-specific chasing advantages.
* **Playoff Qualification & Knockout Performance:** Modeled a multi-season playoff standings matrix and isolated knockout-only statistics (runs and dismissals) using DAX virtual context isolation (`TREATAS`).

---

