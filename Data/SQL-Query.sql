-- Filter users who had more than 7 sessions after the given date
WITH filtered_users AS (
    SELECT
        user_id
    FROM
        sessions
    WHERE 
        session_start > '2023-01-04'
    GROUP BY
        user_id
    HAVING 
        COUNT(session_id) > 7
),

-- Combine user, session, hotel, and flight data with calculated fields
session_based AS (
    SELECT
        u.user_id, 
        s.session_id,
        s.trip_id,
        u.birthdate,
        EXTRACT(YEAR FROM AGE(u.birthdate)) AS age, -- Calculate user age
        u.gender,
        u.married,
        u.has_children,
        u.home_country,
        u.home_city,
        u.home_airport,
        u.home_airport_lat,
        u.home_airport_lon,
        u.sign_up_date,
        
        s.session_start,
        s.session_end,
        (EXTRACT(EPOCH FROM (s.session_end - s.session_start))) AS session_duration_in_seconds, -- Session duration in seconds
        s.flight_discount,
        s.hotel_discount,
        s.flight_discount_amount,
        s.hotel_discount_amount,
        s.flight_booked,
        s.hotel_booked,
        s.page_clicks,
        s.cancellation,
        
        h.hotel_name,
        -- Handle invalid hotel night data
        CASE 
            WHEN h.nights < 0 THEN ABS(h.nights)
            WHEN h.nights = 0 THEN 1
            ELSE h.nights
        END AS nights,
        h.rooms,
        -- Correct invalid check-in and check-out times
        CASE
            WHEN h.check_in_time > h.check_out_time THEN h.check_out_time
            ELSE h.check_in_time
        END AS check_in_time,  
        CASE 
            WHEN h.check_out_time < h.check_in_time THEN h.check_in_time
            ELSE h.check_out_time
        END AS check_out_time,
        h.hotel_per_room_usd,
        
        f.origin_airport,
        f.destination,
        f.destination_airport,
        f.seats,
        f.return_flight_booked,
        f.departure_time,
        EXTRACT(MONTH FROM departure_time) AS departure_month, -- Extract departure month
        f.return_time,
        f.checked_bags,
        f.trip_airline,
        f.destination_airport_lat,
        f.destination_airport_lon,
        f.base_fare_usd

    FROM 
        filtered_users AS fs
    JOIN 
        users AS u ON fs.user_id = u.user_id
    LEFT JOIN
        sessions AS s ON s.user_id = fs.user_id
    LEFT JOIN 
        hotels AS h ON s.trip_id = h.trip_id
    LEFT JOIN 
        flights AS f ON s.trip_id = f.trip_id

    ORDER BY 
        u.user_id ASC
),

-- Aggregate trip-level statistics for each user
trip_based AS (
    SELECT
        user_id,
        COUNT(trip_id) AS total_trips, -- Total trips
        SUM(CASE 
                WHEN flight_booked AND return_flight_booked THEN 2
                WHEN flight_booked THEN 1
                ELSE 0
            END) AS total_flight_booked, -- Count of booked flights
        COUNT(hotel_booked) FILTER (WHERE hotel_booked = 'true') AS total_hotel_booked, -- Count of booked hotels
        SUM(seats) AS total_seats, -- Total seats booked
        -- Calculate money spent on hotels
        SUM((hotel_per_room_usd * nights * rooms) * (1 - COALESCE(hotel_discount_amount, 0))) AS money_spent_hotel,
        -- Calculate money spent on flights
        SUM((base_fare_usd) * (1 - COALESCE(flight_discount_amount, 0))) AS money_spent_filght,
        -- Total money spent on bookings
        SUM((hotel_per_room_usd * nights * rooms) * (1 - COALESCE(hotel_discount_amount, 0))) 
            + SUM((base_fare_usd) * (1 - COALESCE(flight_discount_amount, 0))) AS money_spent_booking,
        SUM(EXTRACT(DAY FROM departure_time - session_end)) AS total_time_before_trip, -- Time before trips
        -- Total miles flown
        ROUND(SUM(haversine_distance(home_airport_lat, home_airport_lon, destination_airport_lat, destination_airport_lon))::NUMERIC, 2) AS miles_flown
    FROM 
        session_based
    WHERE 
        trip_id IS NOT NULL
        AND trip_id NOT IN (
            SELECT DISTINCT trip_id
            FROM session_based
            WHERE cancellation
        ) -- Exclude cancelled trips
    GROUP BY 
        user_id
),

-- User-level statistics based on sessions
session_user_level AS (
    SELECT
        user_id,
        age,
        gender,
        married,
        has_children,
        home_country,
        home_city,
        home_airport,
        home_airport_lat,
        home_airport_lon,
        sign_up_date,
        SUM(page_clicks) AS total_clicks, -- Total page clicks
        SUM(nights) AS total_nights, -- Total nights booked
        SUM(rooms) AS total_rooms, -- Total rooms booked
        ROUND(AVG(hotel_per_room_usd), 2) AS avg_hotel_per_room_usd, -- Average hotel price
        ROUND(AVG(base_fare_usd), 2) AS avg_base_fare_usd, -- Average flight fare
        COUNT(DISTINCT session_id) AS session_count, -- Total sessions
        ROUND(AVG(session_duration_in_seconds), 0) AS avg_session_duration_in_seconds, -- Avg session duration
        -- Booking behavior and activity levels
        COUNT(cancellation) FILTER (WHERE cancellation = 'true') AS total_cancellation,
        COUNT(flight_discount) FILTER (WHERE flight_discount = 'true') AS total_flight_with_discount,
        COUNT(hotel_discount) FILTER (WHERE hotel_discount = 'true') AS total_hotel_with_discount,
        ROUND(AVG(flight_discount_amount), 2) AS avg_flight_discount,
        ROUND(AVG(hotel_discount_amount), 2) AS avg_hotel_discount,
        -- Conversion rates
        ROUND(COUNT(flight_booked) FILTER (WHERE flight_booked = 'true') / COUNT(DISTINCT session_id)::NUMERIC, 2) AS con_rate_flights,
        ROUND(COUNT(hotel_booked) FILTER (WHERE hotel_booked = 'true') / COUNT(DISTINCT session_id)::NUMERIC, 2) AS con_rate_hotels,
        ROUND((COUNT(flight_booked) FILTER (WHERE flight_booked = 'true') 
              + COUNT(hotel_booked) FILTER (WHERE hotel_booked = 'true')) / COUNT(DISTINCT session_id)::NUMERIC, 2) AS con_rate_combined,
        COUNT(return_flight_booked) FILTER (WHERE return_flight_booked = 'true') AS total_return_flight_booked,
        -- Categorize users into segments
        CASE 
            WHEN age BETWEEN 17 AND 25 THEN '17-25'
            WHEN age BETWEEN 26 AND 35 THEN '26-35'
            WHEN age BETWEEN 36 AND 50 THEN '36-50'
            ELSE '50+'
        END AS age_bucket,
        -- Additional categorization
        CASE 
            WHEN married = 'true' AND has_children = 'true' THEN 'Married With Children'
            WHEN married = 'true' AND has_children = 'false' THEN 'Married With No Children'
            WHEN married = 'false' AND has_children = 'true' THEN 'Single With Children'
            WHEN married = 'false' AND has_children = 'false' THEN 'Single With No Children'
            ELSE 'Unknown'
        END AS family_status,
        -- Activity level segmentation
        CASE 
            WHEN SUM(page_clicks) BETWEEN 7 AND 20 THEN 'Low Activity'
            WHEN SUM(page_clicks) BETWEEN 21 AND 66 THEN 'Medium Activity'
            WHEN SUM(page_clicks) > 66 THEN 'High Activity'
            ELSE 'Unknown'
        END AS activity_level,
        -- Cancellation behavior
        CASE 
            WHEN COUNT(cancellation) FILTER (WHERE cancellation = 'true') / NULLIF(COUNT(trip_id), 0) <= 0.1 THEN 'Low Cancellation'
            WHEN COUNT(cancellation) FILTER (WHERE cancellation = 'true') / NULLIF(COUNT(trip_id), 0) BETWEEN 0.1 AND 0.3 THEN 'Medium Cancellation'
            WHEN COUNT(cancellation) FILTER (WHERE cancellation = 'true') / NULLIF(COUNT(trip_id), 0) > 0.3 THEN 'High Cancellation'
            ELSE 'No Flights Booked'
        END AS cancellation_behavior,
        -- Discount usage behavior
        CASE 
            WHEN (COUNT(flight_discount) FILTER (WHERE flight_discount = 'true') 
                + COUNT(hotel_discount) FILTER (WHERE hotel_discount = 'true')) >= 5 THEN 'Frequent Discount User'
            WHEN (COUNT(flight_discount) FILTER (WHERE flight_discount = 'true') 
                + COUNT(hotel_discount) FILTER (WHERE hotel_discount = 'true')) BETWEEN 1 AND 4 THEN 'Occasional Discount User'
            WHEN (COUNT(flight_discount) FILTER (WHERE flight_discount = 'true') 
                + COUNT(hotel_discount) FILTER (WHERE hotel_discount = 'true')) = 0 THEN 'Non-Discount User'
            ELSE 'Unknown'
        END AS discount_usage_behavior,
        -- Booking type preference
        CASE 
            WHEN COUNT(hotel_booked) FILTER (WHERE hotel_booked = 'true') = 0 AND COUNT(flight_booked) FILTER (WHERE flight_booked = 'true') > 0 THEN 'Flight Only'
            WHEN COUNT(flight_booked) FILTER (WHERE flight_booked = 'true') = 0 AND COUNT(hotel_booked) FILTER (WHERE hotel_booked = 'true') > 0 THEN 'Hotel Only'
            WHEN COUNT(flight_booked) FILTER (WHERE flight_booked = 'true') > 0 AND COUNT(hotel_booked) FILTER (WHERE hotel_booked = 'true') > 0 THEN 'Both Flight and Hotel'
            ELSE 'No Bookings'
        END AS booking_type_preference,
        -- Interaction duration categorization
        CASE 
            WHEN ROUND(AVG(session_duration_in_seconds), 0) <= 230 THEN 'Short Sessions'
            WHEN ROUND(AVG(session_duration_in_seconds), 0) BETWEEN 231 AND 1200 THEN 'Moderate Sessions'
            WHEN ROUND(AVG(session_duration_in_seconds), 0) > 1200 THEN 'Long Sessions'
            ELSE 'Unknown'
        END AS interaction_duration,
        -- Loyalty level
        CASE 
            WHEN (COUNT(flight_booked) FILTER (WHERE flight_booked = 'true') 
                + COUNT(hotel_booked) FILTER (WHERE hotel_booked = 'true')) = 0 THEN 'No Bookings'
            WHEN (COUNT(flight_booked) FILTER (WHERE flight_booked = 'true') 
                + COUNT(hotel_booked) FILTER (WHERE hotel_booked = 'true')) BETWEEN 1 AND 2 THEN 'Infrequent Traveler'
            WHEN (COUNT(flight_booked) FILTER (WHERE flight_booked = 'true') 
                + COUNT(hotel_booked) FILTER (WHERE hotel_booked = 'true')) BETWEEN 3 AND 5 THEN 'Occasional Traveler'
            WHEN (COUNT(flight_booked) FILTER (WHERE flight_booked = 'true') 
                + COUNT(hotel_booked) FILTER (WHERE hotel_booked = 'true')) >= 6 THEN 'Frequent Traveler'
        END AS loyalty_level,
        -- Hotel price category
        CASE 
            WHEN ROUND(AVG(hotel_per_room_usd), 2) <= 100 THEN 'Budget'
            WHEN ROUND(AVG(hotel_per_room_usd), 2) BETWEEN 101 AND 300 THEN 'Mid-Range'
            WHEN ROUND(AVG(hotel_per_room_usd), 2) > 300 THEN 'Luxury'
            ELSE 'Unknown'
        END AS hotel_price_category,
        -- Flight fare category
        CASE 
            WHEN ROUND(AVG(base_fare_usd), 2) <= 200 THEN 'Budget'
            WHEN ROUND(AVG(base_fare_usd), 2) BETWEEN 201 AND 1000 THEN 'Mid-Range'
            WHEN ROUND(AVG(base_fare_usd), 2) > 1000 THEN 'Luxury'
            ELSE 'Unknown'
        END AS flight_fare_category
    FROM
        session_based
    GROUP BY 
        user_id,
        age,
        gender,
        married,
        has_children,
        home_country,
        home_city,
        home_airport,
        home_airport_lat,
        home_airport_lon,
        sign_up_date,
        age_bucket,
        family_status
)

-- Final selection combining user-level and trip-level metrics
SELECT
    ul.*,
    tb.total_trips,
    tb.total_flight_booked,
    tb.total_hotel_booked,
    tb.total_seats,
    tb.money_spent_hotel,
    tb.money_spent_filght,
    tb.money_spent_booking,
    tb.total_time_before_trip,
    tb.miles_flown
FROM
    session_user_level AS ul
LEFT JOIN
    trip_based AS tb
ON ul.user_id = tb.user_id
;

