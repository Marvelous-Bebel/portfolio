--Задача 1
WITH filtered AS (
	SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_qty,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_qty,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats),
clear_data AS (
	SELECT *
	FROM real_estate.flats f 
	WHERE id IN (
	    SELECT id
	    FROM real_estate.flats  
	    WHERE 
	        total_area < (SELECT total_area FROM filtered)
	        AND (rooms < (SELECT rooms_qty FROM filtered) OR rooms IS NULL)
	        AND (balcony < (SELECT balcony_qty FROM filtered) OR balcony IS NULL)
	        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM filtered)
	        AND ceiling_height > (SELECT ceiling_height_limit_l FROM filtered)) OR ceiling_height IS NULL))),
categories AS (
	SELECT 
		DISTINCT cd.id,
		CASE 
			WHEN city='Санкт-Петербург' 
				THEN 'Санкт-Петербург'
			ELSE 'ЛенОбл'
		END AS Регион, 
		CASE 
			WHEN a.days_exposition >= 1 AND a.days_exposition <= 30
				THEN 'до месяца'
			WHEN a.days_exposition >= 31 AND a.days_exposition <= 90
				THEN 'до квартала'
			WHEN a.days_exposition >= 91 AND a.days_exposition <= 180
				THEN 'до полугода'
			WHEN a.days_exposition >=181 THEN 'более полугода'
			ELSE 'не учитывается'
		END AS Активность_объявлений,
		last_price/total_area::real AS one_sq_meter_cost,
		last_price,
		total_area,
		balcony,
		floors_total,
		rooms
	FROM clear_data cd
	JOIN real_estate.city c ON cd.city_id = c.city_id
	JOIN real_estate.advertisement a ON cd.id = a.id
	JOIN real_estate.type t ON cd.type_id = t.type_id
	WHERE t.type = 'город')
--Таблица с сегментацией объявлений и средних значений по городам и времени продажи объектов
SELECT Регион,
	Активность_объявлений,
	count(DISTINCT id) AS qty_exp,
	avg(last_price) AS avg_cost,
	avg(one_sq_meter_cost) AS avg_one_sq_meter_cost,
	avg(total_area) AS avg_area,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS rooms_median,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS balcony_median,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floors_total) AS floors_total_median
FROM categories cs
GROUP BY Регион, Активность_объявлений
ORDER BY Регион DESC;

--Задача 2

--Публикации по продаже
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
first_month AS ( 
	SELECT 
		extract(MONTH FROM first_day_exposition::timestamp) AS f_month_exp,
		CASE 
			WHEN extract(MONTH FROM first_day_exposition::timestamp) = 1 THEN 'Январь'
			WHEN extract(MONTH FROM first_day_exposition::timestamp) = 2 THEN 'Февраль'
			WHEN extract(MONTH FROM first_day_exposition::timestamp) = 3 THEN 'Март'
			WHEN extract(MONTH FROM first_day_exposition::timestamp) = 4 THEN 'Апрель'
			WHEN extract(MONTH FROM first_day_exposition::timestamp) = 5 THEN 'Май'
			WHEN extract(MONTH FROM first_day_exposition::timestamp) = 6 THEN 'Июнь'
			WHEN extract(MONTH FROM first_day_exposition::timestamp) = 7 THEN 'Июль'
			WHEN extract(MONTH FROM first_day_exposition::timestamp) = 8 THEN 'Август'
			WHEN extract(MONTH FROM first_day_exposition::timestamp) = 9 THEN 'Сентябрь'
			WHEN extract(MONTH FROM first_day_exposition::timestamp) = 10 THEN 'Октябрь'
			WHEN extract(MONTH FROM first_day_exposition::timestamp) = 11 THEN 'Ноябрь'
			WHEN extract(MONTH FROM first_day_exposition::timestamp) = 12 THEN 'Декабрь'
		ELSE 'Нет данных'
		END AS month_name,
		count(DISTINCT a.id) AS qty_exps,
		round(avg(last_price/total_area)::numeric,2) AS avg_sq_meter_cost,
		round(avg(a.last_price)::numeric,2) AS avg_total_price,
		sum(last_price) AS total_last_price,
		round(avg(total_area)::numeric,2) AS avg_total_area
	FROM  real_estate.advertisement a
	LEFT JOIN real_estate.flats f ON a.id = f.id 
	LEFT JOIN real_estate.city c ON f.city_id = c.city_id
	WHERE f.id IN (SELECT * FROM filtered_id) 
		AND type_id = 'F8EM'
	GROUP BY extract(MONTH FROM first_day_exposition::timestamp)
	ORDER BY f_month_exp),
last_month AS ( 
	SELECT 
		extract('month' FROM first_day_exposition + days_exposition::int) AS l_month_exp,
		CASE 
			WHEN extract('month' FROM first_day_exposition + days_exposition::int) = 1 THEN 'Январь'
			WHEN extract('month' FROM first_day_exposition + days_exposition::int) = 2 THEN 'Февраль'
			WHEN extract('month' FROM first_day_exposition + days_exposition::int) = 3 THEN 'Март'
			WHEN extract('month' FROM first_day_exposition + days_exposition::int) = 4 THEN 'Апрель'
			WHEN extract('month' FROM first_day_exposition + days_exposition::int) = 5 THEN 'Май'
			WHEN extract('month' FROM first_day_exposition + days_exposition::int) = 6 THEN 'Июнь'
			WHEN extract('month' FROM first_day_exposition + days_exposition::int) = 7 THEN 'Июль'
			WHEN extract('month' FROM first_day_exposition + days_exposition::int) = 8 THEN 'Август'
			WHEN extract('month' FROM first_day_exposition + days_exposition::int) = 9 THEN 'Сентябрь'
			WHEN extract('month' FROM first_day_exposition + days_exposition::int) = 10 THEN 'Октябрь'
			WHEN extract('month' FROM first_day_exposition + days_exposition::int) = 11 THEN 'Ноябрь'
			WHEN extract('month' FROM first_day_exposition + days_exposition::int) = 12 THEN 'Декабрь'
		ELSE 'Нет данных'
		END AS month_name,
		count(DISTINCT a.id) AS qty_exps,
		round(avg(last_price/total_area)::numeric,2) AS avg_sq_meter_cost,
		round(avg(a.last_price)::numeric,2) AS avg_total_price,
		sum(last_price) AS total_last_price,
		round(avg(total_area)::numeric,2) AS avg_total_area
	FROM real_estate.advertisement a
	LEFT JOIN real_estate.flats f ON a.id = f.id 
	LEFT JOIN real_estate.city c ON f.city_id = c.city_id
	WHERE f.id IN (SELECT * FROM filtered_id) 
		AND type_id = 'F8EM'
	GROUP BY extract('month' FROM first_day_exposition + days_exposition::int)
	ORDER BY l_month_exp)
SELECT 'публикация' AS exp, *
FROM first_month
	UNION ALL 
SELECT 'снятие' AS exp, *
FROM last_month;

--Задача 3
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
sold AS (
	SELECT 
		count(DISTINCT f.id ) AS sold_exp_qty,
		city,
		avg(days_exposition) AS avg_days_exp,
		avg(last_price)::numeric AS avg_cost,
		avg(total_area)::numeric AS avg_area,
		avg(last_price/total_area::numeric) AS avg_sq_meter_cost
	FROM real_estate.advertisement a
	LEFT JOIN real_estate.flats f ON a.id = f.id 
	LEFT JOIN real_estate.city c ON f.city_id = c.city_id
	WHERE f.id IN (SELECT * FROM filtered_id)
		AND city<>'Санкт-Петербург'
		AND days_exposition IS NOT NULL
	GROUP BY city
),
overall AS (
	SELECT
		city,
	    count(a.id) AS overall_exp
	FROM real_estate.advertisement a
	LEFT JOIN real_estate.flats f ON f.id=a.id
	LEFT JOIN real_estate.city c ON c.city_id=f.city_id
	WHERE f.id IN (SELECT * FROM filtered_id)
		AND city <> 'Санкт-Петербург'
	GROUP BY city
)
SELECT
	s.city,
	sold_exp_qty,
	overall_exp,
	sold_exp_qty/overall_exp::real AS share_sold,
	round(avg_days_exp::numeric) AS avg_days_exp,
	round(avg_cost, 2) AS avg_cost,
	round(avg_sq_meter_cost::numeric, 2) AS avg_aq_meter_cost,
	round(avg_area, 2) AS avg_area
FROM sold s
LEFT JOIN overall o ON s.city = o.city
WHERE s.city <> 'Санкт-Петербург'
ORDER BY overall_exp DESC, share_sold DESC
LIMIT 15;