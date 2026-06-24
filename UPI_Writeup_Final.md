# UPI Bank Reliability Scorecard
## An Operational Analytics Framework for India's Digital Payment System

---

### Problem Statement

India's Unified Payments Interface processed over 20 billion transactions in August 2025, making bank-level technical reliability a critical operational concern. When a UPI transaction fails at the bank layer — on the sender side (remitter) or receiver side (beneficiary) — it creates friction for end users and represents real rupee value lost to the payments ecosystem. Despite NPCI publishing detailed monthly data on bank-level technical decline (TD) rates, no standardized framework exists to rank banks by reliability, detect anomalies systematically, or allocate limited monitoring resources optimally. This project builds that framework using 24 months of primary NPCI data.

All findings in this document are descriptive and observational unless explicitly stated otherwise. Causal relationships were not tested.

---

### Data and Methodology

Data was sourced directly from NPCI's UPI Ecosystem Statistics portal (npci.org.in) — the Top 50 Member Performance tab — covering March 2024 to February 2026. Separate Remitter and Beneficiary files were downloaded for each month, yielding 48 source files compiled into 2,400 rows.

A significant data quality issue was identified and resolved during ETL: NPCI changed its percentage column format mid-period. Values were stored as percentage strings (e.g., "0.32%") in March–December 2024 and August 2025 onwards, but as decimal fractions (e.g., 0.0032 for 0.32%) in January–July 2025. This was detected by cross-referencing raw files against expected value ranges and corrected at the pipeline level in compile.py. All downstream artifacts were rebuilt after the correction.

NPCI also inconsistently named the same banks across monthly files — India Post Payments Bank appeared in five different spellings. A bank_mapping table with 159 entries was built in SQLite to standardize all names before analysis, keeping raw data untouched.

Banks were qualified for analysis if their average monthly remitter volume exceeded 100 million transactions and they appeared in at least 12 of 24 months. Twenty-two banks qualified. All analysis was conducted in SQLite via DB Browser and Microsoft Excel for Mac with Solver enabled. Python was used only for initial file compilation and is not part of any deliverable.

---

### Key Findings

**1. Extreme reliability spread across banks**
India Post Payments Bank had the highest average remitter TD at 1.26%, approximately 40 times worse than Axis Bank at 0.03%. Public sector banks generally exhibit higher TD levels than leading private sector banks in this sample. SBI is a notable exception within the public sector.

**2. March–April 2024 was the peak stress period**
Using a bank-specific mean + 2 standard deviation anomaly threshold, both March and April 2024 recorded 7 simultaneous bank-level spikes — the highest concentration in the dataset, with no other month exceeding 3. 32 total spikes were recorded across 24 months.

**3. System-wide TD improved but did not stabilize**
System-wide average TD declined from a peak of 1.07% in March 2024 to the 0.20%–0.41% range through 2025, representing genuine operational improvement. However, TD did not return to zero and remained volatile for individual banks.

**4. August 2025 spike coincided with policy and volume changes**
System-wide TD increased from 0.33% in July 2025 to 0.58% in August 2025 — a 75% increase in one month — coinciding with new NPCI API governance rules effective August 1, 2025, and record transaction volumes of 20 billion transactions. This is a correlational observation; the data does not establish causation.

**5. April 2025 outage showed no bank-level TD spikes**
The April 2025 outage, which reduced system success rates to approximately 50% for two hours, showed no corresponding bank-level TD spikes in this monthly dataset. This is consistent with the outage being an infrastructure-layer event — specifically a flood of Check Transaction API calls congesting NPCI's switch — rather than individual bank failures. Note that a five-hour single-day outage would be diluted within a monthly TD average regardless of root cause, so the absence of a spike is consistent with but does not definitively confirm an infrastructure-layer origin.

**6. SBI's single-month exposure was the largest in the dataset**
SBI recorded Rs 10,215 crore in estimated failed throughput value in October 2024 — the highest bank-month figure in the dataset. Total estimated failed throughput across all 22 banks over 24 months was Rs 1,99,880 crore.

**7. Fino Payments Bank shows an asymmetric reliability profile**
Fino Payments Bank showed a materially weaker beneficiary-side performance profile than its remitter-side performance (beneficiary TD 0.82% vs remitter TD 0.55%) — the largest gap of this type in the dataset.

**8. Eight banks account for 82% of system exposure**
The top 8 banks by estimated failed throughput value account for 82.2% of the total. SBI alone accounts for 39.6%, making it the single most operationally critical bank for monitoring purposes.

---

### Optimization Output

A binary integer programming model was built in Excel Solver to address a real constraint: an ops team with 120 analyst hours per month cannot monitor all 22 banks equally. Monitoring hours per bank were modelled as a function of transaction volume (log-normalized) and TD volatility. The model maximizes estimated failed throughput value covered subject to three constraints: total hours within budget, at least one payments bank selected, and at least 40% of selected banks from the public sector.

The optimal portfolio selected 12 of 22 banks using 119.7 of 120 available hours, covering Rs 1,81,566 crore — 90.8% of total estimated failed throughput value. The model's non-trivial selection is demonstrated by IDFC First Bank (Rs 420 crore exposure, 4.1 hours) being included while UCO Bank (Rs 2,194 crore) and ICICI Bank (Rs 2,033 crore) were excluded — because at 4.1 hours, IDFC First was the only bank that fit within the remaining budget. This confirms the model is a genuine optimization and not a ranked pick.

---

### Limitations

1. Estimated failed throughput uses system-wide average transaction value rather than bank-specific values. This may overstate exposure for small-ticket banks and understate it for large-ticket banks.
2. Monitoring hours per bank are modelled estimates. No public data exists on actual ops staffing allocations for UPI monitoring.
3. The mean + 2 standard deviation anomaly threshold is a baseline approach. TD distributions are right-skewed and non-normal; IQR or percentile-based methods would be more statistically rigorous for production use.
4. Scorecard weights (50% average TD, 30% volatility, 20% trend) are documented judgement calls. Average TD is weighted highest because current reliability is the most direct measure of the problem. Volatility is weighted second because operational unpredictability is its own risk. Trend is weighted lowest because 24 months of directional data carries less statistical weight than 24 months of absolute performance.

---

### Recommendations

**1. Enhanced monitoring focus for the top 8 banks**
SBI, India Post, Bank of India, Union Bank, Canara Bank, Punjab National Bank, Bank of Baroda, and Central Bank of India collectively account for 82.2% of estimated failed throughput value. These banks may warrant enhanced monitoring frequency and more structured performance review given their concentration of estimated exposure relative to the rest of the system.

**2. Targeted intervention for India Post and Bank of India**
India Post has shown meaningful improvement in 2025 but retains the highest absolute TD in the system at 1.26%, warranting continued focus. Bank of India is the only high-volume public sector commercial bank in the dataset whose TD deteriorated from 2024 to 2025 (0.77% to 0.98%), moving against the broad system trend. Both banks warrant structured remediation plans with measurable TD targets.

**3. Investigate Fino Payments Bank's beneficiary infrastructure**
Fino's beneficiary TD (0.82%) is materially higher than its remitter TD (0.55%) — the largest such asymmetry in the dataset. This pattern suggests unequal operational performance across its two roles in the UPI ecosystem and warrants a targeted infrastructure review on the beneficiary side.

