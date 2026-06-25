# UPI Bank Reliability Scorecard

An operational analytics framework measuring technical reliability across 22 major Indian banks on UPI, built on 24 months of primary NPCI data (March 2024 – February 2026).

---

## What This Project Does

NPCI publishes monthly data showing how often each bank causes a technical failure (called a Technical Decline or TD) on UPI. This project takes that raw public data and builds a complete ops framework:

- **Ranks** all 22 major banks by reliability
- **Detects** anomaly spikes using bank-specific thresholds
- **Estimates** the rupee value stuck in failed transactions per bank per month
- **Grades** each bank A to F on a weighted scorecard
- **Optimises** a monitoring portfolio — which 12 banks to watch with 120 analyst hours/month to cover maximum rupee exposure

---

## Key Findings

| Finding | Number |
|--------|--------|
| Worst bank (India Post Payments Bank) | 1.26% avg TD |
| Best bank (Axis Bank) | 0.03% avg TD |
| Gap between worst and best | ~40x |
| Peak stress period | March–April 2024, 7 simultaneous spikes each |
| Total spikes detected | 32 across 24 months |
| SBI single-month peak exposure | Rs 10,215 Cr (Oct 2024) |
| Total estimated failed throughput | Rs 1,99,880 Cr |
| Top 8 banks concentration | 82.2% of total exposure |
| Optimisation result | 12 banks, 119.7 hrs, 90.8% coverage |

---

## Tools Used

| Task | Tool |
|------|------|
| Data analysis | SQL (SQLite via DB Browser) |
| Modelling, charts, scorecard | Excel for Mac with Solver |
| Interactive dashboard | Power BI Desktop |
Python was used only for file compilation and is not part of any deliverable. All analysis and optimisation is in SQL and Excel.

---

## Data Source

**NPCI UPI Ecosystem Statistics** — Top 50 Member Performance tab  
Source: [https://www.npci.org.in/what-we-do/upi/upi-ecosystem-statistics](https://www.npci.org.in/what-we-do/upi/upi-ecosystem-statistics)  
Coverage: March 2024 to February 2026 (48 files: 24 Remitter + 24 Beneficiary)

Raw files are not included in this repository. Download directly from NPCI using the link above.

---

## Repository Structure

```
upi-bank-reliability-scorecard/
│
├── README.md                    — This file
├── compile_fixed.py             — ETL pipeline with data quality fix
├── queries.sql                  — All 6 SQL queries with comments
├── UPI_Writeup_Final.md         — Full project write-up with findings
│
└── screenshots/
    ├── dashboard.png            — Monitoring Dashboard
    ├── heatmap.png              — Bank reliability heatmap
    ├── policy_chart.png         — System TD trend with event lines
    ├── pareto_chart.png         — Concentration analysis
    └── scorecard.png            — Bank grading scorecard
```

---

## Power BI Dashboard

An interactive dashboard built in Power BI Desktop visualising:
- Bank reliability rankings by average TD rate
- Estimated failed throughput concentration by bank
- System-wide TD trend from March 2024 to February 2026
- KPI cards: worst bank (1.26%), best bank (0.03%), 
  total exposure (Rs 1,99,880 Cr), total spikes (32)

View: Download `UPI_Bank_Reliability_Dashboard.pdf` for a static view  
Interact: Download `UPI_Bank_Reliability_Dashboard.pbix` and open in 
free Power BI Desktop

---

## Notable Data Quality Issue

NPCI changed the format of percentage columns mid-period. March–December 2024 and August 2025 onwards stored values as percentage strings (e.g. "0.32%"). January–July 2025 stored them as decimal fractions (e.g. 0.0032, meaning 0.32%). This was detected when system-wide TD showed an impossible 130x drop in a single month. The fix is in `compile_fixed.py` — the `clean_pct` function detects decimal fractions (values below 1.0) and multiplies them by 100. All downstream artifacts were rebuilt after the correction.

---

## How to Reproduce

1. Download all 48 NPCI files from the link above into `Remitter_Raw/` and `Beneficiary_Raw/` folders
2. Run `python3 compile_fixed.py` to generate `Master_Data.csv`
3. Import `Master_Data.csv` into SQLite as the `bank_performance` table
4. Run the six queries in `queries.sql` and export each result as a CSV
5. Open `UPI_Reliability_Scorecard.xlsx`, click Data → Refresh All, then re-run Solver

---

## Optimisation Model

A binary integer programming model in Excel Solver selects which banks to monitor given:
- Budget: 120 analyst hours/month
- Objective: maximise estimated failed throughput value covered
- Constraints: at least 1 payments bank, at least 40% public sector, total hours within budget

The model selected IDFC First Bank (Rs 420 Cr exposure, 4.1 hrs) over UCO Bank (Rs 2,194 Cr), ICICI Bank (Rs 2,033 Cr), and HDFC Bank (Rs 2,533 Cr) — because after allocating the top 11 banks, only 4.1 hours remained and IDFC First was the only bank that fit. This confirms the model is a genuine constrained optimisation, not a ranked list.

---

## Limitations

- Estimated failed throughput uses system-wide average transaction value (bank-specific values are not published by NPCI)
- Monitoring hours are modelled estimates, not based on actual ops staffing data
- Mean + 2SD anomaly threshold is a baseline; IQR or percentile methods would be more robust in production
- All findings are observational; causal relationships were not tested

