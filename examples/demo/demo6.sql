\timing

/** Create the room */
INSERT INTO room (name) VALUES ('CHIPUG Virtual');

/** Look at initial calendar on May 30, 2018 */
SELECT *
FROM calendar
WHERE calendar_date = date_trunc('week', CURRENT_DATE)::date + 10
ORDER BY lower(calendar_range);

/** CHIPUG Virtual only allows bookings from 8am - 1pm, and 4pm to 10pm on Mon - Fri */
INSERT INTO availability_rule
    (room_id, days_of_week, start_time, end_time, generate_weeks_into_future)
SELECT
    room.id, ARRAY[1,2,3,4,5]::int[], times.start_time::time, times.end_time::time, 52
FROM room,
    LATERAL (
        VALUES ('8:00', '13:00'), ('16:00', '22:00')
    ) times(start_time, end_time)
WHERE room.name = 'CHIPUG Virtual';

SELECT *
FROM calendar
WHERE calendar_date = date_trunc('week', CURRENT_DATE)::date + 10
ORDER BY lower(calendar_range);

/** What happens if we remove all the rules? */
DELETE FROM availability_rule;

SELECT *
FROM calendar
WHERE calendar_date = date_trunc('week', CURRENT_DATE)::date + 10
ORDER BY lower(calendar_range);

/** What happens if we remove the room? */
DELETE FROM room;

SELECT *
FROM calendar
WHERE calendar_date = date_trunc('week', CURRENT_DATE)::date + 10
ORDER BY lower(calendar_range);

/** OK, restore us back to our original sample set */

INSERT INTO room (name) VALUES ('CHIPUG Virtual');

INSERT INTO availability_rule (room_id, days_of_week, start_time, end_time, generate_weeks_into_future)
SELECT room.id, ARRAY[1,2,3,4,5]::int[], '8:00', '12:00', 52
FROM room
WHERE room.name = 'CHIPUG Virtual';

INSERT INTO availability_rule (room_id, days_of_week, start_time, end_time, generate_weeks_into_future)
SELECT room.id, ARRAY[1,2,3,4,5]::int[], '16:00', '22:00', 52
FROM room
WHERE room.name = 'CHIPUG Virtual';

SELECT *
FROM calendar
WHERE calendar_date = date_trunc('week', CURRENT_DATE)::date + 10
ORDER BY lower(calendar_range);

/** CHIPUG Virtual books an event from 9am to 12pm */

INSERT INTO unavailability (room_id, unavailable_date, unavailable_range)
SELECT
    room.id, date_trunc('week', CURRENT_DATE)::date + 10, tstzrange('2021-10-28 9:00', '2021-10-28 12:00')
FROM room
WHERE room.name = 'CHIPUG Virtual';

SELECT *
FROM calendar
WHERE calendar_date = date_trunc('week', CURRENT_DATE)::date + 10
ORDER BY lower(calendar_range);

/** workbench books a second event */
INSERT INTO unavailability (room_id, unavailable_date, unavailable_range)
SELECT
    room.id, date_trunc('week', CURRENT_DATE)::date + 10, tstzrange('2021-10-28 18:00', '2021-10-28 20:00')
FROM room
WHERE room.name = 'CHIPUG Virtual';

SELECT *
FROM calendar
WHERE calendar_date = date_trunc('week', CURRENT_DATE)::date + 10
ORDER BY lower(calendar_range);

/** The second event needs to start one hour earlier */
UPDATE unavailability
SET unavailable_range = tstzrange('2021-10-28 17:00', '2021-10-28 20:00')
FROM room
WHERE
    room.name = 'CHIPUG Virtual' AND
    unavailability.room_id = room.id AND
    lower(unavailability.unavailable_range) = '2021-10-28 18:00';

SELECT *
FROM calendar
WHERE calendar_date = date_trunc('week', CURRENT_DATE)::date + 10
ORDER BY lower(calendar_range);

/** The first event cancels */
DELETE FROM unavailability
USING room
WHERE
    room.name = 'CHIPUG Virtual' AND
    unavailability.room_id = room.id AND
    lower(unavailability.unavailable_range) = '2021-10-28 9:00';

SELECT *
FROM calendar
WHERE calendar_date = date_trunc('week', CURRENT_DATE)::date + 10
ORDER BY lower(calendar_range);
