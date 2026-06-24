-- ============================================================
-- UPI Bank Reliability Scorecard — SQL Queries
-- Database: upi_reliability.db
-- Tables: bank_performance, bank_mapping, monthly_totals
-- ============================================================
-- Qualification rule applied in every query:
--   Average monthly remitter volume > 100 Mn
--   AND present in at least 12 of 24 months
-- ============================================================


-- ============================================================
-- QUERY 1: Bank Profile Ranked
-- Ranks all 22 qualified banks by average TD (worst to best)
-- ============================================================

WITH bank_stats AS (
    SELECT 
        bm.Standard_Name as Bank_Name,
        ROUND(AVG(bp.Total_Volume_Mn), 2) as Avg_Volume_Mn,
        ROUND(AVG(bp.TD_Pct), 4) as Avg_TD_Pct,
        ROUND(MIN(bp.TD_Pct), 4) as Best_TD_Pct,
        ROUND(MAX(bp.TD_Pct), 4) as Worst_TD_Pct,
        ROUND(AVG((bp.TD_Pct - sub.avg_td) * (bp.TD_Pct - sub.avg_td)), 4) as TD_Variance
    FROM bank_performance bp
    JOIN bank_mapping bm ON bp.Bank_Name = bm.Raw_Name
    JOIN (
        SELECT bm2.Standard_Name, AVG(TD_Pct) as avg_td
        FROM bank_performance bp2
        JOIN bank_mapping bm2 ON bp2.Bank_Name = bm2.Raw_Name
        WHERE bp2.Role = 'Remitter'
        GROUP BY bm2.Standard_Name
    ) sub ON bm.Standard_Name = sub.Standard_Name
    WHERE bp.Role = 'Remitter'
    GROUP BY bm.Standard_Name
    HAVING AVG(bp.Total_Volume_Mn) >= 100
    AND COUNT(*) >= 12
)
SELECT 
    Bank_Name,
    Avg_Volume_Mn,
    Avg_TD_Pct,
    Best_TD_Pct,
    Worst_TD_Pct,
    TD_Variance,
    RANK() OVER (ORDER BY Avg_TD_Pct DESC) as TD_Rank
FROM bank_stats
ORDER BY TD_Rank;


-- ============================================================
-- QUERY 2: Monthly Trend
-- Month-over-month TD change for each bank using LAG()
-- ============================================================

WITH qualified_banks AS (
    SELECT bm.Standard_Name
    FROM bank_performance bp
    JOIN bank_mapping bm ON bp.Bank_Name = bm.Raw_Name
    WHERE bp.Role = 'Remitter'
    GROUP BY bm.Standard_Name
    HAVING AVG(bp.Total_Volume_Mn) >= 100
    AND COUNT(*) >= 12
)
SELECT 
    bm.Standard_Name as Bank_Name,
    bp.Year,
    bp.Month,
    bp.TD_Pct as Current_TD,
    LAG(bp.TD_Pct) OVER (
        PARTITION BY bm.Standard_Name 
        ORDER BY bp.Year, bp.Month
    ) as Previous_TD,
    ROUND(bp.TD_Pct - LAG(bp.TD_Pct) OVER (
        PARTITION BY bm.Standard_Name 
        ORDER BY bp.Year, bp.Month
    ), 4) as TD_Change
FROM bank_performance bp
JOIN bank_mapping bm ON bp.Bank_Name = bm.Raw_Name
JOIN qualified_banks qb ON bm.Standard_Name = qb.Standard_Name
WHERE bp.Role = 'Remitter'
ORDER BY bm.Standard_Name, bp.Year, bp.Month;


-- ============================================================
-- QUERY 3: Anomaly Flags
-- Flags months where a bank's TD exceeded its own mean + 2 SD
-- ============================================================

WITH qualified_banks AS (
    SELECT bm.Standard_Name
    FROM bank_performance bp
    JOIN bank_mapping bm ON bp.Bank_Name = bm.Raw_Name
    WHERE bp.Role = 'Remitter'
    GROUP BY bm.Standard_Name
    HAVING AVG(bp.Total_Volume_Mn) >= 100
    AND COUNT(*) >= 12
),
bank_stats AS (
    SELECT 
        bm.Standard_Name as Bank_Name,
        AVG(bp.TD_Pct) as Avg_TD,
        AVG((bp.TD_Pct - sub.avg_td) * (bp.TD_Pct - sub.avg_td)) as Variance
    FROM bank_performance bp
    JOIN bank_mapping bm ON bp.Bank_Name = bm.Raw_Name
    JOIN qualified_banks qb ON bm.Standard_Name = qb.Standard_Name
    JOIN (
        SELECT bm2.Standard_Name, AVG(TD_Pct) as avg_td
        FROM bank_performance bp2
        JOIN bank_mapping bm2 ON bp2.Bank_Name = bm2.Raw_Name
        WHERE bp2.Role = 'Remitter'
        GROUP BY bm2.Standard_Name
    ) sub ON bm.Standard_Name = sub.Standard_Name
    WHERE bp.Role = 'Remitter'
    GROUP BY bm.Standard_Name
)
SELECT 
    bm.Standard_Name as Bank_Name,
    bp.Year,
    bp.Month,
    bp.TD_Pct,
    ROUND(bs.Avg_TD, 4) as Bank_Avg_TD,
    ROUND(bs.Avg_TD + 2 * SQRT(bs.Variance), 4) as Anomaly_Threshold,
    CASE 
        WHEN bp.TD_Pct > bs.Avg_TD + 2 * SQRT(bs.Variance) 
        THEN 'SPIKE' 
        ELSE 'Normal' 
    END as Flag
FROM bank_performance bp
JOIN bank_mapping bm ON bp.Bank_Name = bm.Raw_Name
JOIN bank_stats bs ON bm.Standard_Name = bs.Bank_Name
JOIN qualified_banks qb ON bm.Standard_Name = qb.Standard_Name
WHERE bp.Role = 'Remitter'
ORDER BY bp.Year, bp.Month, bm.Standard_Name;


-- ============================================================
-- QUERY 4: Estimated Failed Throughput Value
-- Estimated rupee value stuck in technical failures per bank per month
-- Formula: Volume_Mn x (TD_Pct/100) x Avg_Txn_Value_Rs x 1000000 / 10000000
-- NOTE: Uses system-wide average transaction value (bank-specific not published)
-- ============================================================

WITH qualified_banks AS (
    SELECT bm.Standard_Name
    FROM bank_performance bp
    JOIN bank_mapping bm ON bp.Bank_Name = bm.Raw_Name
    WHERE bp.Role = 'Remitter'
    GROUP BY bm.Standard_Name
    HAVING AVG(bp.Total_Volume_Mn) >= 100
    AND COUNT(*) >= 12
)
SELECT 
    bm.Standard_Name as Bank_Name,
    bp.Year,
    bp.Month,
    bp.Total_Volume_Mn,
    bp.TD_Pct,
    mt.Avg_Txn_Value_Rs,
    ROUND(bp.Total_Volume_Mn * (bp.TD_Pct / 100), 4) as Failed_Txns_Mn,
    ROUND(
        bp.Total_Volume_Mn * (bp.TD_Pct / 100) * mt.Avg_Txn_Value_Rs * 1000000 / 10000000
    , 2) as Failed_Throughput_Value_Cr
FROM bank_performance bp
JOIN bank_mapping bm ON bp.Bank_Name = bm.Raw_Name
JOIN monthly_totals mt ON bp.Month = mt.Month AND bp.Year = mt.Year
JOIN qualified_banks qb ON bm.Standard_Name = qb.Standard_Name
WHERE bp.Role = 'Remitter'
ORDER BY Failed_Throughput_Value_Cr DESC;


-- ============================================================
-- QUERY 5: Sender vs Receiver Comparison
-- Compares each bank's TD as Remitter vs Beneficiary
-- ============================================================

WITH qualified_banks AS (
    SELECT bm.Standard_Name
    FROM bank_performance bp
    JOIN bank_mapping bm ON bp.Bank_Name = bm.Raw_Name
    WHERE bp.Role = 'Remitter'
    GROUP BY bm.Standard_Name
    HAVING AVG(bp.Total_Volume_Mn) >= 100
    AND COUNT(*) >= 12
)
SELECT 
    bm.Standard_Name as Bank_Name,
    ROUND(AVG(CASE WHEN bp.Role = 'Remitter' THEN bp.TD_Pct END), 4) as Remitter_Avg_TD,
    ROUND(AVG(CASE WHEN bp.Role = 'Beneficiary' THEN bp.TD_Pct END), 4) as Beneficiary_Avg_TD,
    ROUND(AVG(CASE WHEN bp.Role = 'Remitter' THEN bp.TD_Pct END) - 
          AVG(CASE WHEN bp.Role = 'Beneficiary' THEN bp.TD_Pct END), 4) as Difference,
    CASE 
        WHEN AVG(CASE WHEN bp.Role = 'Remitter' THEN bp.TD_Pct END) > 0.3
        AND AVG(CASE WHEN bp.Role = 'Beneficiary' THEN bp.TD_Pct END) > 0.3
        THEN 'Bad Both Sides'
        WHEN AVG(CASE WHEN bp.Role = 'Remitter' THEN bp.TD_Pct END) > 0.3
        THEN 'Bad Sender Only'
        WHEN AVG(CASE WHEN bp.Role = 'Beneficiary' THEN bp.TD_Pct END) > 0.3
        THEN 'Bad Receiver Only'
        ELSE 'Acceptable Both Sides'
    END as Classification
FROM bank_performance bp
JOIN bank_mapping bm ON bp.Bank_Name = bm.Raw_Name
JOIN qualified_banks qb ON bm.Standard_Name = qb.Standard_Name
GROUP BY bm.Standard_Name
ORDER BY Remitter_Avg_TD DESC;


-- ============================================================
-- QUERY 6: System Average TD by Month
-- System-wide average TD across all 22 banks per month
-- Used to build the Policy Chart in Excel
-- ============================================================

WITH qualified_banks AS (
    SELECT bm.Standard_Name
    FROM bank_performance bp
    JOIN bank_mapping bm ON bp.Bank_Name = bm.Raw_Name
    WHERE bp.Role = 'Remitter'
    GROUP BY bm.Standard_Name
    HAVING AVG(bp.Total_Volume_Mn) >= 100
    AND COUNT(*) >= 12
)
SELECT 
    bp.Year,
    bp.Month,
    ROUND(AVG(bp.TD_Pct), 4) as System_Avg_TD,
    COUNT(DISTINCT bm.Standard_Name) as Banks_Reporting
FROM bank_performance bp
JOIN bank_mapping bm ON bp.Bank_Name = bm.Raw_Name
JOIN qualified_banks qb ON bm.Standard_Name = qb.Standard_Name
WHERE bp.Role = 'Remitter'
GROUP BY bp.Year, bp.Month
ORDER BY bp.Year, bp.Month;
