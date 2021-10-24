\timing

/** Create the room */
INSERT INTO room (name) VALUES ('CHIPUG Virtual');

/** Look at initial calendar on May 30, 2018 */
SELECT *
FROM calendar
WHERE calendar_date = '2021-10-28'
ORDER BY lower(calendar_range);

/** Liberty only allows bookings from 8am - 1pm, and 4pm to 10pm on Mon - Fri */
INSERT INTO availability_rule
    (room_id, days_of_week, start_time, end_time, generate_weeks_into_future)
SELECT
    room.id, ARRAY[1,2,3,4,5]::int[], times.start_time::time, times.end_time::time, 52
FROM room,
    LATERAL (
        VALUES ('8:00', '13:00'), ('16:00', '22:00')
    ) times(start_time, end_time)
WHERE room.name = 'CHIPUG Virtual';

INSERT INTO unavailability (room_id, unavailable_date, unavailable_range)
SELECT
    room.id, '2021-10-28', tstzrange('2021-10-28 9:00', '2021-10-28 11:00')
FROM room
WHERE room.name = 'CHIPUG Virtual';

DROP TABLE IF EXISTS room CASCADE;
DROP TABLE IF EXISTS availability CASCADE;
DROP TABLE IF EXISTS availability_rule CASCADE;
DROP TABLE IF EXISTS unavailability CASCADE;
DROP TABLE IF EXISTS calendar CASCADE;
DROP FUNCTION IF EXISTS calendar_manage CASCADE;
DROP FUNCTION IF EXISTS calendar_generate_calendar CASCADE;
DROP FUNCTION IF EXISTS calendar_generate_available CASCADE;
