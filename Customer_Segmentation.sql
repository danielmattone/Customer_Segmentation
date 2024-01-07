-- Link for the database: postgres://Test:bQNxVzJL4g6u@ep-noisy-flower-846766.us-east-2.aws.neon.tech/TravelTide

-- Creation of the cohort, considering the dates we want and one line per user
WITH table_distance
     AS (SELECT u.user_id,
                f.trip_id,
                6371 * 2 * Asin(Sqrt(Power(Sin(
                                     Radians(( f.destination_airport_lat -
                                               u.home_airport_lat ) /
                                                        2)),
                                           2) +
        Cos(Radians(u.home_airport_lat)) * Cos
        (
        Radians(f.destination_airport_lat)) *
        Power
        (Sin(
        Radians(( f.destination_airport_lon -
        u.home_airport_lon ) / 2)), 2))) AS
        distance_in_km
         FROM   users u
                join sessions s
                  ON u.user_id = s.user_id
                join flights f
                  ON s.trip_id = f.trip_id
         WHERE  session_start >= '2023-01-04' :: DATE),
     kilometers
     AS (SELECT user_id,
                SUM(distance_in_km) AS sum_distance_in_km,
                Avg(distance_in_km) AS avg_distance_in_km
         FROM   table_distance
         GROUP  BY user_id)
SELECT u.user_id,
       u.gender,
       u.married,
       u.has_children,
       u.home_country,
       u.home_city,
       u.home_airport,
       Round(Avg(Extract(year FROM Age(s.session_start, u.birthdate))), 1)
       AS
       age_at_first_session,
       Round(Avg(Extract(month FROM Age(s.session_start, u.sign_up_date))), 1)
       AS
       time_account_creation_in_month,
       Count(DISTINCT s.session_id)
       AS total_sessions,
       SUM(CASE
             WHEN s.flight_booked = TRUE
                  AND s.cancellation = FALSE THEN 1
             ELSE 0
           END)
       AS total_flights_booked,
       SUM(CASE
             WHEN s.flight_discount = TRUE THEN 1
             ELSE 0
           END)
       AS total_discount_flights_offer,
       SUM(CASE
             WHEN s.flight_booked = TRUE
                  AND s.cancellation = FALSE
                  AND s.flight_discount = TRUE THEN 1
             ELSE 0
           END)
       AS total_flights_discount_accepted,
       SUM(CASE
             WHEN s.flight_discount THEN 1
             ELSE 0
           END) :: FLOAT / Count(*)
       AS discount_flight_proportion,
       Avg(s.flight_discount_amount)
       AS avg_discount_flight,
       Avg(s.flight_discount_amount * f.base_fare_usd)
       AS ADS_flight,
       SUM(s.flight_discount_amount * f.base_fare_usd) / k.sum_distance_in_km
       AS
       ADS_flight_per_km,
       SUM(f.seats)
       AS total_seats,
       SUM(CASE
             WHEN s.hotel_booked = TRUE
                  AND s.cancellation = FALSE THEN 1
             ELSE 0
           END)
       AS total_hotels_booked,
       SUM(CASE
             WHEN s.hotel_discount = TRUE THEN 1
             ELSE 0
           END)
       AS total_discount_hotel_offer,
       SUM(CASE
             WHEN s.hotel_booked = TRUE
                  AND s.cancellation = FALSE
                  AND s.hotel_discount = TRUE THEN 1
             ELSE 0
           END)
       AS hotels_booked_with_discount,
       SUM(CASE
             WHEN s.hotel_discount THEN 1
             ELSE 0
           END) :: FLOAT / Count(*)
       AS discount_hotel_proportion,
       Avg(s.hotel_discount_amount)
       AS avg_discount_hotel,
       Avg(s.hotel_discount_amount * h.hotel_per_room_usd)
       AS ADS_hotel,
       SUM(CASE
             WHEN s.cancellation = TRUE THEN 1
             ELSE 0
           END)
       AS total_cancellations,
       SUM(CASE
             WHEN f.checked_bags > 0 THEN f.checked_bags
             ELSE 0
           END)
       AS total_checked_bags,
       SUM(h.rooms)
       AS total_rooms_booked,
       SUM(h.nights)
       AS total_nights_booked,
       SUM(s.page_clicks) / Count(DISTINCT s.session_id)
       AS avg_clicks_per_session,
       ( SUM(Extract(epoch FROM ( s.session_end -
       s.session_start ))) ) / ( Count(DISTINCT s.session_id) )
       AS avg_session_length,
       Avg(h.hotel_per_room_usd)
       AS avg_room_price_pre_discount,
       Avg(f.base_fare_usd)
       AS avg_seat_price_pre_discount,
       k.avg_distance_in_km
FROM   users u
       left join sessions s
              ON u.user_id = s.user_id
       left join flights f
              ON s.trip_id = f.trip_id
       left join hotels h
              ON s.trip_id = h.trip_id
       left join kilometers k
              ON u.user_id = k.user_id
WHERE  session_start >= '2023-01-04' :: DATE
GROUP  BY u.user_id,
          u.gender,
          u.married,
          u.has_children,
          u.home_country,
          u.home_city,
          u.home_airport,
          k.sum_distance_in_km,
          k.avg_distance_in_km
HAVING Count(s.session_id) > 7
ORDER  BY u.user_id 
