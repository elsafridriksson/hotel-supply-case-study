-- Supply partner case study. Synthetic data. Dialect: SQLite here, written to port to Snowflake.
-- Grain: one row per supplier offer for a room group (hotel, stay week, rate type).

-- Q1. Price competitiveness by supplier: how often each supplier is cheapest, and the average gap to the best price.
-- name: q1_price_competitiveness
SELECT
  supplier,
  COUNT(*)                                                     AS offers,
  ROUND(100.0 * SUM(CASE WHEN price_rank = 1 THEN 1 ELSE 0 END) / COUNT(*), 1)   AS pct_cheapest,
  ROUND(100.0 * AVG(price_eur / group_best_price - 1), 2)      AS avg_gap_to_best_pct
FROM offers
WHERE group_size >= 3
GROUP BY supplier
ORDER BY pct_cheapest DESC;

-- Q2. Where is a supplier least competitive? Gap to best price by supplier and region.
-- name: q2_gap_by_region
SELECT
  region,
  supplier,
  COUNT(*)                                                     AS offers,
  ROUND(100.0 * AVG(price_eur / group_best_price - 1), 2)      AS avg_gap_to_best_pct
FROM offers
WHERE group_size >= 3
GROUP BY region, supplier
HAVING COUNT(*) >= 30
ORDER BY avg_gap_to_best_pct DESC
LIMIT 12;

-- Q3. Supplier economics: commission earned, confirmation, and contribution per 1,000 impressions.
-- Contribution = commission on confirmed bookings. Cancelled or unconfirmed bookings earn nothing.
-- name: q3_supplier_economics
SELECT
  supplier,
  supplier_type,
  ROUND(AVG(commission_rate) * 100, 1)                         AS commission_pct,
  SUM(bookings)                                                AS bookings,
  ROUND(100.0 * SUM(confirmed_bookings) / NULLIF(SUM(bookings), 0), 1) AS confirm_pct,
  ROUND(SUM(commission_eur))                                   AS commission_eur,
  ROUND(1000.0 * SUM(commission_eur) / SUM(impressions), 1)    AS commission_per_1k_impr,
  ROUND(SUM(commission_eur) / NULLIF(SUM(confirmed_bookings), 0), 1) AS commission_per_booking
FROM offers
GROUP BY supplier, supplier_type
ORDER BY commission_eur DESC;

-- Q4. Does a cheaper partner with lower commission beat a pricier partner with higher commission?
-- Compare where a lower commission supplier wins the room. Commission per booking vs share of wins.
-- name: q4_win_vs_commission
SELECT
  supplier,
  ROUND(AVG(commission_rate) * 100, 1)                         AS commission_pct,
  ROUND(100.0 * SUM(CASE WHEN price_rank = 1 THEN 1 ELSE 0 END) / COUNT(*), 1)   AS pct_cheapest,
  ROUND(100.0 * SUM(confirmed_bookings) / NULLIF(SUM(clicks), 0), 2)             AS confirmed_per_100_clicks
FROM offers
WHERE group_size >= 3
GROUP BY supplier
ORDER BY commission_pct;

-- Q5. Coverage: share of room groups each supplier is present in, by destination.
-- Denominator is every room group (hotel, stay week, rate type) in the destination.
-- name: q5_coverage_matrix
WITH groups_by_dest AS (
  SELECT destination, COUNT(DISTINCT hotel_id || '|' || stay_week || '|' || rate_type) AS total_groups
  FROM offers
  GROUP BY destination
)
SELECT
  o.destination,
  o.supplier,
  COUNT(*)                                                     AS offers,
  g.total_groups,
  ROUND(100.0 * COUNT(*) / g.total_groups, 1)                  AS coverage_pct
FROM offers o
JOIN groups_by_dest g USING (destination)
GROUP BY o.destination, o.supplier, g.total_groups
ORDER BY coverage_pct ASC
LIMIT 15;

-- Q6. Coverage by hotel segment: where are we thin? Number of suppliers per room group by segment.
-- name: q6_segment_depth
SELECT
  segment,
  ROUND(AVG(group_size), 2)                                    AS avg_suppliers_per_room,
  ROUND(100.0 * AVG(CASE WHEN group_size <= 3 THEN 1.0 ELSE 0 END), 1) AS pct_rooms_with_3_or_fewer
FROM (
  SELECT DISTINCT hotel_id, stay_week, rate_type, segment, group_size FROM offers
)
GROUP BY segment
ORDER BY avg_suppliers_per_room;

-- Q7. Partner prioritisation: which supplier x destination gaps are worth closing?
-- Only suppliers that are price competitive overall (average gap to best price under 7%) are candidates,
-- and only destinations where that supplier covers under 50% of room groups.
-- Opportunity (indicative, sample period) = missing room groups x the supplier's average commission per room group.
-- Commission per group is the supplier average in this sample, so treat the euro figure as a ranking aid, not a forecast.
-- name: q7_opportunity
WITH dest_groups AS (
  SELECT destination, COUNT(DISTINCT hotel_id || '|' || stay_week || '|' || rate_type) AS total_groups
  FROM offers GROUP BY destination
),
supplier_dest AS (
  SELECT supplier, destination, COUNT(*) AS present_groups
  FROM offers GROUP BY supplier, destination
),
supplier_stats AS (
  SELECT supplier,
         SUM(commission_eur) / COUNT(*)                         AS avg_commission_per_group,
         AVG(price_eur / group_best_price - 1)                  AS avg_gap
  FROM offers WHERE group_size >= 3
  GROUP BY supplier
),
supplier_comm AS (
  SELECT supplier, SUM(commission_eur) / COUNT(*) AS commission_per_group FROM offers GROUP BY supplier
)
SELECT
  sd.supplier,
  sd.destination,
  ROUND(100.0 * sd.present_groups / dg.total_groups, 1)        AS current_coverage_pct,
  dg.total_groups - sd.present_groups                          AS missing_groups,
  ROUND(100 * ss.avg_gap, 1)                                   AS avg_gap_to_best_pct,
  ROUND(sc.commission_per_group, 1)                            AS commission_per_group,
  ROUND((dg.total_groups - sd.present_groups) * sc.commission_per_group) AS opportunity_eur
FROM supplier_dest sd
JOIN dest_groups dg USING (destination)
JOIN supplier_stats ss USING (supplier)
JOIN supplier_comm sc USING (supplier)
WHERE ss.avg_gap < 0.07
  AND 1.0 * sd.present_groups / dg.total_groups < 0.50
ORDER BY opportunity_eur DESC
LIMIT 10;

-- Q8a. Conversion by price gap bucket (the evidence for a negotiation case).
-- name: q8a_conversion_by_gap
SELECT
  CASE WHEN price_eur / group_best_price - 1 < 0.02 THEN '0-2%'
       WHEN price_eur / group_best_price - 1 < 0.05 THEN '2-5%'
       WHEN price_eur / group_best_price - 1 < 0.10 THEN '5-10%'
       WHEN price_eur / group_best_price - 1 < 0.20 THEN '10-20%'
       ELSE '20%+' END                                         AS gap_bucket,
  COUNT(*)                                                     AS offers,
  SUM(clicks)                                                  AS clicks,
  ROUND(100.0 * SUM(confirmed_bookings) / SUM(clicks), 2)      AS confirmed_per_100_clicks
FROM offers
WHERE group_size >= 3
GROUP BY 1
ORDER BY MIN(price_eur / group_best_price - 1);

-- Q8b. Scenario: OTA Alpha (15% commission) in Southern Europe cuts its price gap to the best price by half.
-- Uplift uses the conversion by gap bucket from Q8a, applied to OTA Alpha's current clicks in that region.
-- The lower price also lowers commission per booking, so the scenario nets that out. Clicks are held constant (conservative).
-- name: q8b_scenario_ota_alpha
WITH bucket_cvr AS (
  SELECT
    CASE WHEN price_eur / group_best_price - 1 < 0.02 THEN 0
         WHEN price_eur / group_best_price - 1 < 0.05 THEN 1
         WHEN price_eur / group_best_price - 1 < 0.10 THEN 2
         WHEN price_eur / group_best_price - 1 < 0.20 THEN 3
         ELSE 4 END AS b,
    1.0 * SUM(confirmed_bookings) / SUM(clicks) AS cvr
  FROM offers WHERE group_size >= 3 GROUP BY 1
),
alpha AS (
  SELECT *,
    price_eur / group_best_price - 1 AS gap,
    CASE WHEN price_eur / group_best_price - 1 < 0.02 THEN 0
         WHEN price_eur / group_best_price - 1 < 0.05 THEN 1
         WHEN price_eur / group_best_price - 1 < 0.10 THEN 2
         WHEN price_eur / group_best_price - 1 < 0.20 THEN 3
         ELSE 4 END AS b_now
  FROM offers
  WHERE supplier = 'OTA Alpha' AND region = 'Southern Europe' AND group_size >= 3
)
SELECT
  COUNT(*)                                                     AS offers,
  ROUND(SUM(a.clicks * c_now.cvr * a.price_eur * a.nights * a.commission_rate)) AS modelled_commission_now_eur,
  ROUND(SUM(a.clicks * c_new.cvr * a.price_eur * (1 + a.gap / 2) / (1 + a.gap) * a.nights * a.commission_rate)) AS modelled_commission_half_gap_eur,
  ROUND(SUM(a.clicks * c_new.cvr * a.price_eur * (1 + a.gap / 2) / (1 + a.gap) * a.nights * a.commission_rate)
      - SUM(a.clicks * c_now.cvr * a.price_eur * a.nights * a.commission_rate)) AS uplift_eur
FROM alpha a
JOIN bucket_cvr c_now ON c_now.b = a.b_now
JOIN bucket_cvr c_new ON c_new.b = CASE WHEN a.gap / 2 < 0.02 THEN 0
                                        WHEN a.gap / 2 < 0.05 THEN 1
                                        WHEN a.gap / 2 < 0.10 THEN 2
                                        WHEN a.gap / 2 < 0.20 THEN 3
                                        ELSE 4 END;
