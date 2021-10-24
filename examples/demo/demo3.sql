/*\timing*/

/** First, generate a bunch of rooms */
INSERT INTO room (name)
SELECT 'CHIPUG Virtual ' || x
FROM generate_series(1, 100) x;
/*
INSERT 0 100
Time: 374.398 ms (old: 446.654 ms)
*/

SELECT count(*) FROM calendar;
/*
count
--------
36500
(1 row)
*/


/** Generate a set of availability rules, will keep it simple */
INSERT INTO availability_rule (room_id, days_of_week, start_time, end_time)
SELECT room.id, ARRAY[1,2,3,4,5]::int[], '8:00', '20:00'
FROM room;

/*
INSERT 0 100
Time: 19257.509 ms (old: 57870.835 ms (00:57.871))
*/

SELECT count(*) FROM calendar;
/*
count
--------
89900
(1 row)
*/


/** Generate a bunch of unavailability */
INSERT INTO unavailability (room_id, unavailable_date, unavailable_range)
SELECT
    room.id, unavailable_date, tstzrange(unavailable_date + '11:00'::time, unavailable_date + '14:00'::time)
FROM room,
    LATERAL generate_series(CURRENT_DATE, CURRENT_DATE + 365, '1 day'::interval) unavailable_date;

/**
INSERT 0 36600
Time: 28293.777 ms (00:28.294) (old: 89086.539 ms (01:29.087))
**/

SELECT count(*) FROM calendar;
/*
count
--------
163100
(1 row)
*/

/** how fast are lookups? */
SELECT *
FROM calendar
JOIN room ON
    room.id = calendar.room_id AND
    room.name = 'CHIPUG Virtual 1'
WHERE
    calendar_date = '2021-10-28'
ORDER BY lower(calendar_range);

/** what about inserting new unavailability blocks? */
INSERT INTO unavailability (room_id, unavailable_date, unavailable_range)
SELECT
    room.id, '2021-10-28', tstzrange('2021-10-28 18:00', '2021-10-28 20:00')
FROM room
WHERE room.name = 'CHIPUG Virtual 1';

/** what about new rules? */
DELETE FROM availability_rule
USING room
WHERE
    availability_rule.room_id = room.id AND
    room.name = 'CHIPUG Virtual 1';

INSERT INTO availability_rule (room_id, days_of_week, start_time, end_time, generate_weeks_into_future)
SELECT room.id, ARRAY[1,2,3,4,5]::int[], '8:00', '20:00', 52
FROM room
WHERE room.name = 'CHIPUG Virtual 1';

SELECT *
FROM calendar
JOIN room ON
    room.id = calendar.room_id AND
    room.name = 'CHIPUG Virtual 1'
WHERE
    calendar_date = '2021-10-28'
ORDER BY lower(calendar_range);
