-- ============================================================
-- BELLABEAT / FITBIT CASE STUDY  |  COMBINED SQL (CLEANING + ANALYSIS)
-- Dialect: SQLite (runs on Postgres/MySQL with minor date-function tweaks)
-- Load fitbit_merged_daily.csv into a table named fitbit_daily first,
-- then run this whole file top to bottom.
--
-- PART A (below): data profiling, quality checks, and the fitbit_clean view
-- PART B (further down): 24 analysis queries, each preceded by "-- name:" / "-- title:"
-- ============================================================


-- ================= PART A : CLEANING ==========================
-- ============================================================
-- BELLABEAT / FITBIT CASE STUDY  |  01 - DATA CLEANING (SQL)
-- Dialect: SQLite (also runs on Postgres/MySQL with small notes)
-- Source table : fitbit_daily  (one row per user per day, 940 rows)
-- Output       : fitbit_clean  (view) used by 02_analysis.sql
-- ============================================================

-- 1. Basic profile of the raw table -------------------------
SELECT COUNT(*)                 AS total_rows,
       COUNT(DISTINCT Id)       AS total_users,
       MIN(Date)                AS first_date,
       MAX(Date)                AS last_date
FROM fitbit_daily;

-- 2. Duplicate check on (Id, Date) -> expect 0 ---------------
SELECT Id, Date, COUNT(*) AS n
FROM fitbit_daily
GROUP BY Id, Date
HAVING COUNT(*) > 1;

-- 3. NULL audit for key columns ------------------------------
SELECT SUM(CASE WHEN TotalSteps IS NULL THEN 1 ELSE 0 END)         AS null_steps,
       SUM(CASE WHEN Calories IS NULL THEN 1 ELSE 0 END)           AS null_calories,
       SUM(CASE WHEN TotalMinutesAsleep IS NULL THEN 1 ELSE 0 END) AS null_sleep,
       SUM(CASE WHEN WeightKg IS NULL THEN 1 ELSE 0 END)           AS null_weight,
       SUM(CASE WHEN HR_Avg IS NULL THEN 1 ELSE 0 END)             AS null_heart_rate
FROM fitbit_daily;

-- 4. Days where the tracker was (almost) not worn ------------
--    0 steps  OR  the full 1440 minutes sedentary
SELECT COUNT(*) AS suspect_rows
FROM fitbit_daily
WHERE TotalSteps = 0 OR SedentaryMinutes = 1440;

-- 5. Logical checks ------------------------------------------
-- 5a. Active + sedentary minutes cannot exceed 1440 in a day
SELECT COUNT(*) AS over_1440
FROM fitbit_daily
WHERE VeryActiveMinutes + FairlyActiveMinutes + LightlyActiveMinutes + SedentaryMinutes > 1440;

-- 5b. Time asleep cannot be greater than time in bed
SELECT COUNT(*) AS asleep_gt_bed
FROM fitbit_daily
WHERE TotalMinutesAsleep > TotalTimeInBed;

-- 5c. Days with implausibly low calories (< 500)
SELECT COUNT(*) AS low_calorie_rows FROM fitbit_daily WHERE Calories < 500;

-- 6. CLEAN VIEW ----------------------------------------------
--    * standard column names
--    * derived features (weekday, sleep hours, active minutes, flags)
--    * tracker-not-worn days are flagged (kept in the table, excluded in analysis)
DROP VIEW IF EXISTS fitbit_clean;
CREATE VIEW fitbit_clean AS
SELECT
    Id                                                         AS user_id,
    DATE(Date)                                                 AS activity_date,
    CASE CAST(STRFTIME('%w', Date) AS INTEGER)
         WHEN 0 THEN 'Sunday'   WHEN 1 THEN 'Monday'
         WHEN 2 THEN 'Tuesday'  WHEN 3 THEN 'Wednesday'
         WHEN 4 THEN 'Thursday' WHEN 5 THEN 'Friday'
         ELSE 'Saturday' END                                   AS weekday,
    CAST(STRFTIME('%w', Date) AS INTEGER)                      AS weekday_no,   -- 0 = Sunday
    CASE WHEN CAST(STRFTIME('%w', Date) AS INTEGER) IN (0,6)
         THEN 'Weekend' ELSE 'Weekday' END                     AS day_type,
    TotalSteps                                                 AS total_steps,
    ROUND(TotalDistance, 2)                                    AS total_distance_km,
    VeryActiveMinutes                                          AS very_active_min,
    FairlyActiveMinutes                                        AS fairly_active_min,
    LightlyActiveMinutes                                       AS lightly_active_min,
    SedentaryMinutes                                           AS sedentary_min,
    VeryActiveMinutes + FairlyActiveMinutes + LightlyActiveMinutes AS total_active_min,
    ROUND(SedentaryMinutes / 60.0, 2)                          AS sedentary_hours,
    Calories                                                   AS calories,
    TotalSleepRecords                                          AS sleep_records,
    TotalMinutesAsleep                                         AS minutes_asleep,
    TotalTimeInBed                                             AS minutes_in_bed,
    ROUND(TotalMinutesAsleep / 60.0, 2)                        AS sleep_hours,
    CASE WHEN TotalTimeInBed > 0
         THEN ROUND(100.0 * TotalMinutesAsleep / TotalTimeInBed, 1) END AS sleep_efficiency_pct,
    WeightKg                                                   AS weight_kg,
    BMI                                                        AS bmi,
    HR_Avg                                                     AS hr_avg,
    HR_Min                                                     AS hr_min,
    HR_Max                                                     AS hr_max,
    CASE WHEN TotalSteps >= 10000 THEN 1 ELSE 0 END            AS met_10k_steps,
    CASE WHEN TotalSteps = 0 OR SedentaryMinutes = 1440
         THEN 0 ELSE 1 END                                     AS is_worn_day,
    CASE WHEN TotalSteps < 5000  THEN '1. Sedentary (<5k)'
         WHEN TotalSteps < 7500  THEN '2. Low active (5k-7.5k)'
         WHEN TotalSteps < 10000 THEN '3. Somewhat active (7.5k-10k)'
         WHEN TotalSteps < 12500 THEN '4. Active (10k-12.5k)'
         ELSE '5. Highly active (12.5k+)' END                  AS step_category
FROM fitbit_daily;

-- 7. Rows removed by the analysis filter ---------------------
SELECT is_worn_day, COUNT(*) AS row_count FROM fitbit_clean GROUP BY is_worn_day;


-- ================= PART B : ANALYSIS ==========================
-- ============================================================
-- BELLABEAT / FITBIT CASE STUDY  |  02 - SQL ANALYSIS
-- Run 01_cleaning.sql first (creates the fitbit_clean view).
-- Every query starts with "-- name:" / "-- title:" so the Streamlit
-- app can read this file and run each query live.
-- All analysis uses is_worn_day = 1 (tracker actually worn).
-- ============================================================


-- name: Q01_overview
-- title: Dataset overview - headline KPIs
SELECT COUNT(DISTINCT user_id)                 AS users,
       COUNT(*)                                AS worn_days,
       ROUND(AVG(total_steps), 0)              AS avg_daily_steps,
       ROUND(AVG(calories), 0)                 AS avg_daily_calories,
       ROUND(AVG(sedentary_min) / 60.0, 1)     AS avg_sedentary_hours,
       ROUND(AVG(total_active_min), 0)         AS avg_active_minutes,
       ROUND(100.0 * AVG(met_10k_steps), 1)    AS pct_days_10k_steps
FROM fitbit_clean
WHERE is_worn_day = 1;


-- name: Q02_weekday_activity
-- title: Average steps, calories and sedentary time by weekday
SELECT weekday,
       COUNT(*)                          AS days,
       ROUND(AVG(total_steps), 0)        AS avg_steps,
       ROUND(AVG(calories), 0)           AS avg_calories,
       ROUND(AVG(total_active_min), 1)   AS avg_active_min,
       ROUND(AVG(sedentary_min), 1)      AS avg_sedentary_min
FROM fitbit_clean
WHERE is_worn_day = 1
GROUP BY weekday, weekday_no
ORDER BY (weekday_no + 6) % 7;          -- Monday first


-- name: Q03_weekday_vs_weekend
-- title: Weekday vs weekend behaviour
SELECT day_type,
       COUNT(*)                          AS days,
       ROUND(AVG(total_steps), 0)        AS avg_steps,
       ROUND(AVG(calories), 0)           AS avg_calories,
       ROUND(AVG(very_active_min), 1)    AS avg_very_active_min,
       ROUND(AVG(sedentary_min) / 60.0, 1) AS avg_sedentary_hours,
       ROUND(AVG(sleep_hours), 2)        AS avg_sleep_hours
FROM fitbit_clean
WHERE is_worn_day = 1
GROUP BY day_type;


-- name: Q04_time_split
-- title: How the 24 hours are spent (share of tracked minutes)
SELECT 'Sedentary'      AS activity_level, ROUND(AVG(sedentary_min), 1)      AS avg_minutes,
       ROUND(100.0 * SUM(sedentary_min)      / SUM(sedentary_min + lightly_active_min + fairly_active_min + very_active_min), 1) AS pct_of_day
FROM fitbit_clean WHERE is_worn_day = 1
UNION ALL
SELECT 'Lightly active', ROUND(AVG(lightly_active_min), 1),
       ROUND(100.0 * SUM(lightly_active_min) / SUM(sedentary_min + lightly_active_min + fairly_active_min + very_active_min), 1)
FROM fitbit_clean WHERE is_worn_day = 1
UNION ALL
SELECT 'Fairly active', ROUND(AVG(fairly_active_min), 1),
       ROUND(100.0 * SUM(fairly_active_min)  / SUM(sedentary_min + lightly_active_min + fairly_active_min + very_active_min), 1)
FROM fitbit_clean WHERE is_worn_day = 1
UNION ALL
SELECT 'Very active', ROUND(AVG(very_active_min), 1),
       ROUND(100.0 * SUM(very_active_min)    / SUM(sedentary_min + lightly_active_min + fairly_active_min + very_active_min), 1)
FROM fitbit_clean WHERE is_worn_day = 1;


-- name: Q05_step_categories
-- title: Distribution of days by step category
SELECT step_category,
       COUNT(*)                                            AS days,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)  AS pct_of_days,
       ROUND(AVG(calories), 0)                             AS avg_calories
FROM fitbit_clean
WHERE is_worn_day = 1
GROUP BY step_category
ORDER BY step_category;


-- name: Q06_user_summary
-- title: One row per user - activity, sleep and engagement
SELECT user_id,
       COUNT(*)                          AS days_worn,
       ROUND(AVG(total_steps), 0)        AS avg_steps,
       ROUND(AVG(calories), 0)           AS avg_calories,
       ROUND(AVG(total_active_min), 0)   AS avg_active_min,
       ROUND(AVG(sedentary_min) / 60.0, 1) AS avg_sedentary_hours,
       ROUND(AVG(sleep_hours), 2)        AS avg_sleep_hours,
       COUNT(sleep_hours)                AS nights_with_sleep_data
FROM fitbit_clean
WHERE is_worn_day = 1
GROUP BY user_id
ORDER BY avg_steps DESC;


-- name: Q07_user_segments
-- title: User segmentation by average daily steps (Fitbit-style lifestyle types)
WITH per_user AS (
    SELECT user_id, AVG(total_steps) AS avg_steps, AVG(calories) AS avg_cal
    FROM fitbit_clean WHERE is_worn_day = 1
    GROUP BY user_id
)
SELECT CASE WHEN avg_steps < 5000  THEN '1. Sedentary (<5k)'
            WHEN avg_steps < 7500  THEN '2. Lightly active (5k-7.5k)'
            WHEN avg_steps < 10000 THEN '3. Fairly active (7.5k-10k)'
            ELSE '4. Very active (10k+)' END       AS user_segment,
       COUNT(*)                                     AS users,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_users,
       ROUND(AVG(avg_steps), 0)                     AS avg_steps,
       ROUND(AVG(avg_cal), 0)                       AS avg_calories
FROM per_user
GROUP BY user_segment
ORDER BY user_segment;


-- name: Q08_top_bottom_users
-- title: Top 5 and bottom 5 users by average steps
WITH ranked AS (
    SELECT user_id, ROUND(AVG(total_steps), 0) AS avg_steps,
           RANK() OVER (ORDER BY AVG(total_steps) DESC) AS rank_desc,
           RANK() OVER (ORDER BY AVG(total_steps) ASC)  AS rank_asc
    FROM fitbit_clean WHERE is_worn_day = 1
    GROUP BY user_id
)
SELECT CASE WHEN rank_desc <= 5 THEN 'Top 5' ELSE 'Bottom 5' END AS grp,
       user_id, avg_steps
FROM ranked
WHERE rank_desc <= 5 OR rank_asc <= 5
ORDER BY grp DESC, avg_steps DESC;


-- name: Q09_ten_k_goal
-- title: 10,000-step goal - users and days that reach it (CDC/WHO benchmark)
WITH per_user AS (
    SELECT user_id, COUNT(*) AS days, SUM(met_10k_steps) AS goal_days,
           ROUND(100.0 * SUM(met_10k_steps) / COUNT(*), 1) AS goal_rate
    FROM fitbit_clean WHERE is_worn_day = 1 GROUP BY user_id
)
SELECT CASE WHEN goal_rate = 0  THEN 'Never hit 10k'
            WHEN goal_rate < 25 THEN 'Rarely (<25% of days)'
            WHEN goal_rate < 50 THEN 'Sometimes (25-50%)'
            ELSE 'Often (50%+)' END AS goal_group,
       COUNT(*) AS users,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_users
FROM per_user
GROUP BY goal_group
ORDER BY MIN(goal_rate);


-- name: Q10_sleep_by_weekday
-- title: Sleep duration and efficiency by weekday
SELECT weekday,
       COUNT(sleep_hours)                 AS nights,
       ROUND(AVG(sleep_hours), 2)         AS avg_sleep_hours,
       ROUND(AVG(sleep_efficiency_pct), 1) AS avg_efficiency_pct,
       ROUND(AVG(minutes_in_bed - minutes_asleep), 0) AS avg_min_awake_in_bed
FROM fitbit_clean
WHERE sleep_hours IS NOT NULL
GROUP BY weekday, weekday_no
ORDER BY (weekday_no + 6) % 7;


-- name: Q11_sleep_buckets
-- title: How many nights meet the recommended 7-9 hours of sleep?
SELECT CASE WHEN sleep_hours < 6  THEN '1. Under 6h (severe)'
            WHEN sleep_hours < 7  THEN '2. 6-7h (short)'
            WHEN sleep_hours <= 9 THEN '3. 7-9h (recommended)'
            ELSE '4. Over 9h' END                           AS sleep_bucket,
       COUNT(*)                                             AS nights,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)   AS pct_of_nights
FROM fitbit_clean
WHERE sleep_hours IS NOT NULL
GROUP BY sleep_bucket
ORDER BY sleep_bucket;


-- name: Q12_sleep_vs_activity
-- title: Do more active days lead to better sleep? (same-day comparison)
SELECT step_category,
       COUNT(sleep_hours)                  AS nights,
       ROUND(AVG(sleep_hours), 2)          AS avg_sleep_hours,
       ROUND(AVG(sleep_efficiency_pct), 1) AS avg_efficiency_pct
FROM fitbit_clean
WHERE is_worn_day = 1 AND sleep_hours IS NOT NULL
GROUP BY step_category
ORDER BY step_category;


-- name: Q13_sedentary_vs_sleep
-- title: Sedentary hours vs sleep
SELECT CASE WHEN sedentary_hours < 12 THEN '1. Under 12h sedentary'
            WHEN sedentary_hours < 16 THEN '2. 12-16h sedentary'
            ELSE '3. 16h+ sedentary' END      AS sedentary_group,
       COUNT(*)                                AS nights,
       ROUND(AVG(sleep_hours), 2)              AS avg_sleep_hours,
       ROUND(AVG(sleep_efficiency_pct), 1)     AS avg_efficiency_pct
FROM fitbit_clean
WHERE is_worn_day = 1 AND sleep_hours IS NOT NULL
GROUP BY sedentary_group
ORDER BY sedentary_group;


-- name: Q14_calories_per_step
-- title: Calorie burn efficiency - calories per 1,000 steps and step category
SELECT step_category,
       COUNT(*)                                        AS days,
       ROUND(AVG(calories), 0)                         AS avg_calories,
       ROUND(1000.0 * SUM(calories) / SUM(total_steps), 1) AS calories_per_1000_steps
FROM fitbit_clean
WHERE is_worn_day = 1 AND total_steps > 0
GROUP BY step_category
ORDER BY step_category;


-- name: Q15_correlations
-- title: Pearson correlation of steps with calories, active minutes and sleep
WITH d AS (SELECT * FROM fitbit_clean WHERE is_worn_day = 1)
SELECT 'steps vs calories' AS pair,
       ROUND((COUNT(*) * SUM(total_steps * calories) - SUM(total_steps) * SUM(calories)) /
             (SQRT(COUNT(*) * SUM(total_steps * total_steps) - SUM(total_steps) * SUM(total_steps)) *
              SQRT(COUNT(*) * SUM(calories * calories) - SUM(calories) * SUM(calories))), 3) AS pearson_r
FROM d
UNION ALL
SELECT 'steps vs active minutes',
       ROUND((COUNT(*) * SUM(total_steps * total_active_min) - SUM(total_steps) * SUM(total_active_min)) /
             (SQRT(COUNT(*) * SUM(total_steps * total_steps) - SUM(total_steps) * SUM(total_steps)) *
              SQRT(COUNT(*) * SUM(total_active_min * total_active_min) - SUM(total_active_min) * SUM(total_active_min))), 3)
FROM d
UNION ALL
SELECT 'steps vs sedentary minutes',
       ROUND((COUNT(*) * SUM(total_steps * sedentary_min) - SUM(total_steps) * SUM(sedentary_min)) /
             (SQRT(COUNT(*) * SUM(total_steps * total_steps) - SUM(total_steps) * SUM(total_steps)) *
              SQRT(COUNT(*) * SUM(sedentary_min * sedentary_min) - SUM(sedentary_min) * SUM(sedentary_min))), 3)
FROM d
UNION ALL
SELECT 'steps vs sleep hours',
       ROUND((COUNT(*) * SUM(total_steps * sleep_hours) - SUM(total_steps) * SUM(sleep_hours)) /
             (SQRT(COUNT(*) * SUM(total_steps * total_steps) - SUM(total_steps) * SUM(total_steps)) *
              SQRT(COUNT(*) * SUM(sleep_hours * sleep_hours) - SUM(sleep_hours) * SUM(sleep_hours))), 3)
FROM d WHERE sleep_hours IS NOT NULL;


-- name: Q16_weekly_trend
-- title: Weekly trend of average steps (is engagement dropping over time?)
SELECT STRFTIME('%W', activity_date)            AS week_no,
       MIN(activity_date)                       AS week_start,
       COUNT(DISTINCT user_id)                  AS active_users,
       ROUND(AVG(total_steps), 0)               AS avg_steps,
       ROUND(AVG(calories), 0)                  AS avg_calories
FROM fitbit_clean
WHERE is_worn_day = 1
GROUP BY week_no
ORDER BY week_no;


-- name: Q17_tracker_engagement
-- title: Tracker usage - how consistently do users wear the device?
WITH usage AS (
    SELECT user_id,
           COUNT(*)                     AS logged_days,
           SUM(is_worn_day)             AS worn_days,
           ROUND(100.0 * SUM(is_worn_day) / 31, 0) AS pct_of_31_days
    FROM fitbit_clean
    GROUP BY user_id
)
SELECT CASE WHEN worn_days >= 28 THEN '1. Power users (28+ days)'
            WHEN worn_days >= 20 THEN '2. Regular (20-27 days)'
            ELSE '3. Casual (<20 days)' END AS usage_tier,
       COUNT(*)                                             AS users,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)   AS pct_of_users,
       ROUND(AVG(worn_days), 1)                             AS avg_worn_days
FROM usage
GROUP BY usage_tier
ORDER BY usage_tier;


-- name: Q18_feature_adoption
-- title: Feature adoption - how many users use sleep, weight and heart-rate tracking?
SELECT COUNT(DISTINCT user_id)                                              AS total_users,
       COUNT(DISTINCT CASE WHEN sleep_hours IS NOT NULL THEN user_id END)   AS sleep_users,
       COUNT(DISTINCT CASE WHEN weight_kg   IS NOT NULL THEN user_id END)   AS weight_users,
       COUNT(DISTINCT CASE WHEN hr_avg      IS NOT NULL THEN user_id END)   AS heart_rate_users,
       ROUND(100.0 * COUNT(DISTINCT CASE WHEN sleep_hours IS NOT NULL THEN user_id END) / COUNT(DISTINCT user_id), 1) AS pct_sleep,
       ROUND(100.0 * COUNT(DISTINCT CASE WHEN weight_kg   IS NOT NULL THEN user_id END) / COUNT(DISTINCT user_id), 1) AS pct_weight,
       ROUND(100.0 * COUNT(DISTINCT CASE WHEN hr_avg      IS NOT NULL THEN user_id END) / COUNT(DISTINCT user_id), 1) AS pct_heart_rate
FROM fitbit_clean;


-- name: Q19_day_over_day
-- title: Day-over-day step change per user (LAG window function) - biggest drops
SELECT user_id, activity_date, total_steps, prev_steps,
       total_steps - prev_steps AS change_steps
FROM (
    SELECT user_id, activity_date, total_steps,
           LAG(total_steps) OVER (PARTITION BY user_id ORDER BY activity_date) AS prev_steps
    FROM fitbit_clean
    WHERE is_worn_day = 1
)
WHERE prev_steps IS NOT NULL
ORDER BY change_steps ASC
LIMIT 10;


-- name: Q20_rolling_7day
-- title: 7-day moving average of steps for the most active user
WITH best AS (
    SELECT user_id FROM fitbit_clean WHERE is_worn_day = 1
    GROUP BY user_id ORDER BY AVG(total_steps) DESC LIMIT 1
)
SELECT activity_date, total_steps,
       ROUND(AVG(total_steps) OVER (ORDER BY activity_date
             ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 0) AS steps_7day_avg
FROM fitbit_clean
WHERE user_id = (SELECT user_id FROM best) AND is_worn_day = 1
ORDER BY activity_date;


-- name: Q21_best_day_per_user
-- title: Each user's most active weekday (ROW_NUMBER)
WITH avg_by_day AS (
    SELECT user_id, weekday, AVG(total_steps) AS avg_steps
    FROM fitbit_clean WHERE is_worn_day = 1
    GROUP BY user_id, weekday
), ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY avg_steps DESC) AS rn
    FROM avg_by_day
)
SELECT weekday AS best_weekday, COUNT(*) AS users
FROM ranked WHERE rn = 1
GROUP BY weekday
ORDER BY users DESC;


-- name: Q22_heart_rate
-- title: Heart rate by weekday (only users who wear the device while awake and active)
SELECT weekday,
       COUNT(hr_avg)              AS days_with_hr,
       ROUND(AVG(hr_avg), 1)      AS avg_hr,
       ROUND(AVG(hr_max), 0)      AS avg_peak_hr
FROM fitbit_clean
WHERE hr_avg IS NOT NULL AND is_worn_day = 1
GROUP BY weekday, weekday_no
ORDER BY (weekday_no + 6) % 7;


-- name: Q23_bmi_groups
-- title: BMI groups from weight logs
SELECT CASE WHEN bmi < 18.5 THEN 'Underweight'
            WHEN bmi < 25   THEN 'Healthy'
            WHEN bmi < 30   THEN 'Overweight'
            ELSE 'Obese' END           AS bmi_group,
       COUNT(DISTINCT user_id)        AS users,
       COUNT(*)                       AS logs,
       ROUND(AVG(total_steps), 0)     AS avg_steps
FROM fitbit_clean
WHERE bmi IS NOT NULL
GROUP BY bmi_group
ORDER BY MIN(bmi);


-- name: Q24_marketing_insights
-- title: Recommendation table - where is the biggest opportunity for a Bellabeat app?
SELECT 'Days below 10k steps (%)'                                   AS insight,
       ROUND(100 - 100.0 * AVG(met_10k_steps), 1)                   AS value
FROM fitbit_clean WHERE is_worn_day = 1
UNION ALL
SELECT 'Share of the day spent sedentary (%)',
       ROUND(100.0 * SUM(sedentary_min) / SUM(sedentary_min + lightly_active_min + fairly_active_min + very_active_min), 1)
FROM fitbit_clean WHERE is_worn_day = 1
UNION ALL
SELECT 'Nights with less than 7h sleep (%)',
       ROUND(100.0 * AVG(CASE WHEN sleep_hours < 7 THEN 1.0 ELSE 0 END), 1)
FROM fitbit_clean WHERE sleep_hours IS NOT NULL
UNION ALL
SELECT 'Users who log weight (%)',
       ROUND(100.0 * COUNT(DISTINCT CASE WHEN weight_kg IS NOT NULL THEN user_id END) / COUNT(DISTINCT user_id), 1)
FROM fitbit_clean
UNION ALL
SELECT 'Days with tracker not worn (%)',
       ROUND(100.0 * AVG(1 - is_worn_day), 1)
FROM fitbit_clean;
