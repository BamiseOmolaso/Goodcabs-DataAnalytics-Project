SELECT
	dc.city_name as city_name, count(f.trip_id) as total_trips, 
	round(avg(f.fare_amount/f.distance_travelled_km),2) as avg_fare_per_km,
	round(avg(f.fare_amount),2) as avg_fare_per_trip,
	round((count(f.trip_id) / (select count(*) from fact_trips)) * 100, 2) as pct_contribution_to_total_trips 
FROM
	fact_trips as f
JOIN
	dim_city as dc using (city_id)
GROUP BY
	city_name;

SELECT 
    dc.city_name,
    DATE_FORMAT(f.date, '%Y-%m') AS month_name,
    COUNT(f.trip_id) AS actual_trips,
    m.total_target_trips AS target_trips,
    CASE 
        WHEN COUNT(f.trip_id) > m.total_target_trips THEN 'Above Target'
        ELSE 'Below Target'
    END AS performance_status,
    ROUND(((COUNT(f.trip_id) - m.total_target_trips) / m.total_target_trips) * 100, 2) AS pct_difference
FROM 
    trips_db.fact_trips f
JOIN 
    trips_db.dim_city dc ON f.city_id = dc.city_id
JOIN 
    targets_db.monthly_target_trips m ON f.city_id = m.city_id 
    and DATE_FORMAT(f.date, '%Y-%m') = DATE_FORMAT(m.month, '%Y-%m')
GROUP BY 
    dc.city_name, DATE_FORMAT(f.date, '%Y-%m')
ORDER BY 
    dc.city_name, month_name;

SELECT 
    dc.city_name,
    ROUND(SUM(CASE WHEN d.trip_count = 2 THEN d.repeat_passenger_count ELSE 0 END) / SUM(d.repeat_passenger_count) * 100, 2) AS `2-Trips`,
    ROUND(SUM(CASE WHEN d.trip_count = 3 THEN d.repeat_passenger_count ELSE 0 END) / SUM(d.repeat_passenger_count) * 100, 2) AS `3-Trips`,
    ROUND(SUM(CASE WHEN d.trip_count = 4 THEN d.repeat_passenger_count ELSE 0 END) / SUM(d.repeat_passenger_count) * 100, 2) AS `4-Trips`,
    ROUND(SUM(CASE WHEN d.trip_count = 5 THEN d.repeat_passenger_count ELSE 0 END) / SUM(d.repeat_passenger_count) * 100, 2) AS `5-Trips`,
    ROUND(SUM(CASE WHEN d.trip_count = 6 THEN d.repeat_passenger_count ELSE 0 END) / SUM(d.repeat_passenger_count) * 100, 2) AS `6-Trips`,
    ROUND(SUM(CASE WHEN d.trip_count = 7 THEN d.repeat_passenger_count ELSE 0 END) / SUM(d.repeat_passenger_count) * 100, 2) AS `7-Trips`,
    ROUND(SUM(CASE WHEN d.trip_count = 8 THEN d.repeat_passenger_count ELSE 0 END) / SUM(d.repeat_passenger_count) * 100, 2) AS `8-Trips`,
    ROUND(SUM(CASE WHEN d.trip_count = 9 THEN d.repeat_passenger_count ELSE 0 END) / SUM(d.repeat_passenger_count) * 100, 2) AS `9-Trips`,
    ROUND(SUM(CASE WHEN d.trip_count = 10 THEN d.repeat_passenger_count ELSE 0 END) / SUM(d.repeat_passenger_count) * 100, 2) AS `10-Trips`
FROM 
    trips_db.dim_repeat_trip_distribution d
JOIN 
    trips_db.dim_city dc ON d.city_id = dc.city_id
GROUP BY 
    dc.city_name
ORDER BY 
    dc.city_name;
    
WITH monthly_revenue AS (
    SELECT 
        dc.city_name,
        DATE_FORMAT(f.date, '%Y-%m') AS month_name,
        SUM(f.fare_amount) AS revenue
    FROM 
        trips_db.fact_trips f
    JOIN 
        trips_db.dim_city dc ON f.city_id = dc.city_id
    GROUP BY 
        dc.city_name, DATE_FORMAT(f.date, '%Y-%m')
),
highest_monthly_revenue AS (
    SELECT 
        city_name,
        month_name AS highest_revenue_month,
        revenue,
        revenue / SUM(revenue) OVER (PARTITION BY city_name) * 100 AS percentage_contribution,
        ROW_NUMBER() OVER (PARTITION BY city_name ORDER BY revenue DESC) AS revenue_rank
    FROM 
        monthly_revenue
)
SELECT 
    city_name,
    highest_revenue_month,
    revenue,
    ROUND(percentage_contribution, 2) AS pct_contribution
FROM 
    highest_monthly_revenue
WHERE 
    revenue_rank = 1
ORDER BY 
    city_name;
    
WITH monthly_repeat_rate AS (
    SELECT 
        dc.city_name,
        fps.month,
        fps.total_passengers,
        fps.repeat_passengers,
        ROUND((fps.repeat_passengers / NULLIF(fps.total_passengers, 0)) * 100, 2) AS monthly_repeat_passenger_rate
    FROM 
        trips_db.fact_passenger_summary fps
    JOIN 
        trips_db.dim_city dc ON fps.city_id = dc.city_id
),
city_wide_repeat_rate AS (
    SELECT 
        dc.city_name,
        SUM(fps.total_passengers) AS city_total_passengers,
        SUM(fps.repeat_passengers) AS city_total_repeat_passengers,
        ROUND((SUM(fps.repeat_passengers) / NULLIF(SUM(fps.total_passengers), 0)) * 100, 2) AS city_repeat_passenger_rate
    FROM 
        trips_db.fact_passenger_summary fps
    JOIN 
        trips_db.dim_city dc ON fps.city_id = dc.city_id
    GROUP BY 
        dc.city_name
)
SELECT 
    mrr.city_name,
    mrr.month,
    mrr.total_passengers,
    mrr.repeat_passengers,
    mrr.monthly_repeat_passenger_rate,
    crr.city_repeat_passenger_rate
FROM 
    monthly_repeat_rate mrr
JOIN 
    city_wide_repeat_rate crr ON mrr.city_name = crr.city_name
ORDER BY 
    mrr.city_name, mrr.month;
