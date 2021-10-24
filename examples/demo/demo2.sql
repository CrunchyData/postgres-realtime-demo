\timing

/** Create the room */
\echo
\prompt 'Create the room' _
\echo INSERT INTO room (name) VALUES ('CHIPUG Virtual');
INSERT INTO room (name) VALUES ('CHIPUG Virtual');

\echo
/** Look at initial calendar on May 30, 2018 */
\prompt 'Look at initial calendar on May 30, 2018' _
\echo SELECT *
\echo FROM calendar
\echo WHERE calendar_date = '2021-10-28'
\echo ORDER BY lower(calendar_range);$$

SELECT *
FROM calendar
WHERE calendar_date = '2021-10-28'
ORDER BY lower(calendar_range);

\prompt 'Hit Enter to continue...' _

/** CHIPUG Virtual only allows bookings from 8am - 12pm, and 4pm to 10pm on Mon - Fri */
\echo
\prompt 'CHIPUG Virtual only allows bookings from 8am - 1pm, and 4pm to 10pm on Mon - Fri' _
\echo INSERT INTO availability_rule
\echo     (room_id, days_of_week, start_time, end_time, generate_weeks_into_future)
\echo SELECT
\echo     room.id, ARRAY[1,2,3,4,5]::int[], times.start_time::time, times.end_time::time, 52
\echo FROM room,
\echo     LATERAL (
\echo         VALUES ('8:00', '13:00'), ('16:00', '22:00')
\echo     ) times(start_time, end_time)
\echo WHERE room.name = 'CHIPUG Virtual';

INSERT INTO availability_rule
    (room_id, days_of_week, start_time, end_time, generate_weeks_into_future)
SELECT
    room.id, ARRAY[1,2,3,4,5]::int[], times.start_time::time, times.end_time::time, 52
FROM room,
    LATERAL (
        VALUES ('8:00', '13:00'), ('16:00', '22:00')
    ) times(start_time, end_time)
WHERE room.name = 'CHIPUG Virtual';

\echo
\echo SELECT *
\echo FROM calendar
\echo WHERE calendar_date = '2021-10-28'
\echo ORDER BY lower(calendar_range);

SELECT *
FROM calendar
WHERE calendar_date = '2021-10-28'
ORDER BY lower(calendar_range);

\prompt 'Hit Enter to continue...' _

/** what happens if we extend the end time to 11pm? */
\echo
\prompt 'What happens if we extend the end time to 11pm?' _
\echo
\echo UPDATE availability_rule
\echo SET end_time = '23:00'
\echo FROM room
\echo WHERE
\echo    availability_rule.end_time = '22:00' AND
\echo    availability_rule.room_id = room.id AND
\echo    room.name = 'CHIPUG Virtual';

UPDATE availability_rule
SET end_time = '23:00'
FROM room
WHERE
    availability_rule.end_time = '22:00' AND
    availability_rule.room_id = room.id AND
    room.name = 'CHIPUG Virtual';

\echo
\echo SELECT *
\echo FROM calendar
\echo WHERE calendar_date = '2021-10-28'
\echo ORDER BY lower(calendar_range);

SELECT *
FROM calendar
WHERE calendar_date = '2021-10-28'
ORDER BY lower(calendar_range);

\prompt 'Hit Enter to continue...' _

/** What happens if we remove all the rules? */
\prompt 'What happens if we remove all the rules?' _
\echo DELETE FROM availability_rule;
DELETE FROM availability_rule;

\echo
\echo SELECT *
\echo FROM calendar
\echo WHERE calendar_date = '2021-10-28'
\echo ORDER BY lower(calendar_range);
SELECT *
FROM calendar
WHERE calendar_date = '2021-10-28'
ORDER BY lower(calendar_range);

\prompt 'Hit Enter to continue...' _

/** What happens if we remove the room? */
\prompt 'What happens if we remove the room?' _
\echo DELETE FROM room;
DELETE FROM room;

\echo
\echo SELECT *
\echo FROM calendar
\echo WHERE calendar_date = '2021-10-28'
\echo ORDER BY lower(calendar_range);
SELECT *
FROM calendar
WHERE calendar_date = '2021-10-28'
ORDER BY lower(calendar_range);

\prompt 'Hit Enter to continue...' _

/** OK, restore us back to our original sample set */

\prompt 'OK, restore us back to our original sample set' _

INSERT INTO room (name) VALUES ('CHIPUG Virtual');

INSERT INTO availability_rule (room_id, days_of_week, start_time, end_time, generate_weeks_into_future)
SELECT room.id, ARRAY[1,2,3,4,5]::int[], '8:00', '13:00', 52
FROM room
WHERE room.name = 'CHIPUG Virtual';

INSERT INTO availability_rule (room_id, days_of_week, start_time, end_time, generate_weeks_into_future)
SELECT room.id, ARRAY[1,2,3,4,5]::int[], '16:00', '22:00', 52
FROM room
WHERE room.name = 'CHIPUG Virtual';

SELECT *
FROM calendar
WHERE calendar_date = '2021-10-28'
ORDER BY lower(calendar_range);

/** CHIPUG Virtual books an event from 9am to 12pm */
\echo
\prompt 'CHIPUG Virtual books an event from 9am to 12pm' _
\echo
\echo INSERT INTO unavailability (room_id, unavailable_date, unavailable_range)
\echo SELECT
\echo    room.id, '2021-10-28', tstzrange('2021-10-28 9:00', '2021-10-28 11:00')
\echo FROM room
\echo WHERE room.name = 'CHIPUG Virtual';
INSERT INTO unavailability (room_id, unavailable_date, unavailable_range)
SELECT
    room.id, '2021-10-28', tstzrange('2021-10-28 9:00', '2021-10-28 12:00')
FROM room
WHERE room.name = 'CHIPUG Virtual';

\echo
\echo SELECT *
\echo FROM calendar
\echo WHERE calendar_date = '2021-10-28'
\echo ORDER BY lower(calendar_range);
SELECT *
FROM calendar
WHERE calendar_date = '2021-10-28'
ORDER BY lower(calendar_range);

\prompt 'Hit Enter to continue...' _

/** CHIPUG Virtual books a second event */
\echo
\prompt 'CHIPUG Virtual books a second event' _
\echo INSERT INTO unavailability (room_id, unavailable_date, unavailable_range)
\echo SELECT
\echo    room.id, '2021-10-28', tstzrange('2021-10-28 18:00', '2021-10-28 20:00')
\echo FROM room
\echo WHERE room.name = 'CHIPUG Virtual';
INSERT INTO unavailability (room_id, unavailable_date, unavailable_range)
SELECT
    room.id, '2021-10-28', tstzrange('2021-10-28 18:00', '2021-10-28 20:00')
FROM room
WHERE room.name = 'CHIPUG Virtual';

\echo
\echo SELECT *
\echo FROM calendar
\echo WHERE calendar_date = '2021-10-28'
\echo ORDER BY lower(calendar_range);
SELECT *
FROM calendar
WHERE calendar_date = '2021-10-28'
ORDER BY lower(calendar_range);

\prompt 'Hit Enter to continue...' _

/** The second event needs to start one hour earlier */
\echo
\prompt 'The second event needs to start one hour earlier' _
\echo UPDATE unavailability
\echo SET unavailable_range = tstzrange('2021-10-28 17:00', '2021-10-28 20:00')
\echo FROM room
\echo WHERE
\echo     room.name = 'CHIPUG Virtual' AND
\echo     unavailability.room_id = room.id AND
\echo     lower(unavailability.unavailable_range) = '2021-10-28 18:00';
UPDATE unavailability
SET unavailable_range = tstzrange('2021-10-28 17:00', '2021-10-28 20:00')
FROM room
WHERE
    room.name = 'CHIPUG Virtual' AND
    unavailability.room_id = room.id AND
    lower(unavailability.unavailable_range) = '2021-10-28 18:00';

\echo
\echo SELECT *
\echo FROM calendar
\echo WHERE calendar_date = '2021-10-28'
\echo ORDER BY lower(calendar_range);
SELECT *
FROM calendar
WHERE calendar_date = '2021-10-28'
ORDER BY lower(calendar_range);

\prompt 'Hit Enter to continue...' _

/** The first event cancels */
\echo
\prompt 'The first event cancels' _
\echo DELETE FROM unavailability
\echo USING room
\echo WHERE
\echo     room.name = 'CHIPUG Virtual' AND
\echo     unavailability.room_id = room.id AND
\echo     lower(unavailability.unavailable_range) = '2021-10-28 9:00';
DELETE FROM unavailability
USING room
WHERE
    room.name = 'CHIPUG Virtual' AND
    unavailability.room_id = room.id AND
    lower(unavailability.unavailable_range) = '2021-10-28 9:00';

\echo
\echo SELECT *
\echo FROM calendar
\echo WHERE calendar_date = '2021-10-28'
\echo ORDER BY lower(calendar_range);
SELECT *
FROM calendar
WHERE calendar_date = '2021-10-28'
ORDER BY lower(calendar_range);
