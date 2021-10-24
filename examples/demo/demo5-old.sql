/** SELECT * FROM pg_create_logical_replication_slot('schedule', 'wal2json'); */

/**
 * Schema
 */
CREATE TABLE room (
    id serial PRIMARY KEY,
    name text
);

CREATE TABLE availability_rule (
    id serial PRIMARY KEY,
    room_id int REFERENCES room (id) ON DELETE CASCADE,
    days_of_week int[],
    start_time time,
    end_time time,
    generate_weeks_into_future int DEFAULT 52
);

CREATE TABLE availability (
    id serial PRIMARY KEY,
    room_id int REFERENCES room (id) ON DELETE CASCADE,
    availability_rule_id int REFERENCES availability_rule (id) ON DELETE CASCADE,
    available_date date,
    available_range tstzrange
);
CREATE INDEX availability_available_range_gist_idx
    ON availability
    USING gist(available_range);

CREATE TABLE unavailability (
    id serial PRIMARY KEY,
    room_id int REFERENCES room (id) ON DELETE CASCADE,
    unavailable_date date,
    unavailable_range tstzrange
);
CREATE INDEX unavailability_unavailable_range_gist_idx
    ON unavailability
    USING gist(unavailable_range);

CREATE TABLE calendar (
    id serial PRIMARY KEY,
    room_id int REFERENCES room (id) ON DELETE CASCADE,
    status text,
    calendar_date date,
    calendar_range tstzrange
);
CREATE INDEX calendar_room_id_calendar_date_idx
    ON calendar (room_id, calendar_date);

/**
 * Helper functions and Triggers
 */

/**
 * AVAILABILITY RULE: Ensure that updates to general availability
 */

/** Helper: Bulk create availability rules; day_of_week ~ isodow (Mon: 1 - Sat: 7) */
CREATE OR REPLACE FUNCTION availability_rule_bulk_insert(availability_rule availability_rule, day_of_week int)
RETURNS void
AS $$
    INSERT INTO availability (
        room_id,
        availability_rule_id,
        available_date,
        available_range
    )
    SELECT
        $1.room_id,
        $1.id,
        available_date::date + $2 - 1,
        tstzrange(
            /** start of range */
            (available_date::date + $2 - 1) + $1.start_time,
            /** end of range */
            /** check if there is a time wraparound, if so, increment by a day */
            CASE $1.end_time <= $1.start_time
                WHEN TRUE THEN (available_date::date + $2) + $1.end_time
                ELSE (available_date::date + $2 - 1) + $1.end_time
            END
        )
    FROM
        generate_series(
            date_trunc('week', CURRENT_DATE),
            date_trunc('week', CURRENT_DATE) + ($1.generate_weeks_into_future::text || ' weeks')::interval,
            '1 week'::interval
        ) available_date;
$$ LANGUAGE SQL;

/**
 * availability_rule trigger function
 */


/** AVAILABILITY, UNAVAILABILITY, and CALENDAR */

/** We need some lengthy functions to help generate the calendar */
/** Helper function: generate the available chunks of time within a block of time for a day within a calendar */
CREATE OR REPLACE FUNCTION calendar_generate_available(room_id int, calendar_range tstzrange)
RETURNS TABLE(status text, calendar_range tstzrange)
AS $$
WITH RECURSIVE availables AS (
    SELECT
        'closed' AS left_status,
        CASE
            WHEN availability.id IS NULL THEN tstzrange(calendar_date, calendar_date + '1 day'::interval)
            ELSE
                tstzrange(
                    calendar_date,
                    lower(availability.available_range * tstzrange(calendar_date, calendar_date + '1 day'::interval))
                )
        END AS left_range,
        CASE isempty(availability.available_range * tstzrange(calendar_date, calendar_date + '1 day'::interval))
            WHEN TRUE THEN 'closed'
            ELSE 'available'
        END AS center_status,
        availability.available_range * tstzrange(calendar_date, calendar_date + '1 day'::interval) AS center_range,
        'closed' AS right_status,
        CASE
            WHEN availability.id IS NULL THEN tstzrange(calendar_date, calendar_date + '1 day'::interval)
            ELSE
                tstzrange(
                    upper(availability.available_range * tstzrange(calendar_date, calendar_date + '1 day'::interval)),
                    calendar_date + '1 day'::interval
                )
        END AS right_range
    FROM generate_series(lower($2), upper($2), '1 day'::interval) AS calendar_date
    LEFT OUTER JOIN availability ON
        availability.room_id = $1 AND
        availability.available_range && $2
    UNION ALL
    SELECT DISTINCT
        'closed' AS left_status,
        CASE
            WHEN availability.available_range && availables.left_range THEN
                tstzrange(
                    lower(availables.left_range),
                    lower(availables.left_range * availability.available_range)
                )
            ELSE
                tstzrange(
                    lower(availables.right_range),
                    lower(availables.right_range * availability.available_range)
                )
        END AS left_range,
        CASE
            WHEN
                availability.available_range && availables.left_range OR
                availability.available_range && availables.right_range
            THEN 'available'
            ELSE 'closed'
        END AS center_status,
        CASE
            WHEN availability.available_range && availables.left_range THEN
                availability.available_range * availables.left_range
            ELSE
                availability.available_range * availables.right_range
        END AS center_range,
        'closed' AS right_status,
        CASE
            WHEN availability.available_range && availables.left_range THEN
                tstzrange(
                    upper(availables.left_range * availability.available_range),
                    upper(availables.left_range)
                )
            ELSE
                tstzrange(
                    upper(availables.right_range * availability.available_range),
                    upper(availables.right_range)
                )
        END AS right_range
    FROM availables
    JOIN availability ON
        availability.room_id = $1 AND
        availability.available_range && $2 AND
        availability.available_range <> availables.center_range AND (
            availability.available_range && availables.left_range OR
            availability.available_range && availables.right_range
        )
)
SELECT *
FROM (
    SELECT
        x.left_status AS status,
        x.left_range AS calendar_range
    FROM availables x
    LEFT OUTER JOIN availables y ON
        x.left_range <> y.left_range AND
        x.left_range @> y.left_range
    GROUP BY 1, 2
    HAVING NOT bool_or(COALESCE(x.left_range @> y.left_range, FALSE))
    UNION
    SELECT DISTINCT
        x.center_status AS status,
        x.center_range AS calendar_range
    FROM availables x
    UNION
    SELECT
        x.right_status AS status,
        x.right_range AS calendar_range
    FROM availables x
    LEFT OUTER JOIN availables y ON
        x.right_range <> y.right_range AND
        x.right_range @> y.right_range
    GROUP BY 1, 2
    HAVING NOT bool_or(COALESCE(x.right_range @> y.right_range, FALSE))
) x
WHERE
    NOT isempty(x.calendar_range) AND
    NOT lower_inf(x.calendar_range) AND
    NOT upper_inf(x.calendar_range) AND
    x.calendar_range <@ $2
$$ LANGUAGE SQL STABLE;

/**
 * Helper function: combine the closed and available chunks of time with the unavailable chunks
 * of time to output the final calendar for the given `calendar_range`
 */
CREATE OR REPLACE FUNCTION calendar_generate_calendar(room_id int, calendar_range tstzrange)
RETURNS TABLE (status text, calendar_range tstzrange)
AS $$
    WITH RECURSIVE calendars AS (
        SELECT
            calendar.status AS left_status,
            tstzrange(
                lower(calendar.calendar_range),
                lower(unavailability.unavailable_range * calendar.calendar_range)
            ) AS left_range,
            CASE
                unavailability.unavailable_range IS NULL OR
                isempty(calendar.calendar_range * unavailability.unavailable_range)
            WHEN TRUE THEN calendar.status
            ELSE 'unavailable'
            END AS center_status,
            CASE
                unavailability.unavailable_range IS NULL OR
                isempty(calendar.calendar_range * unavailability.unavailable_range)
                WHEN TRUE THEN calendar.calendar_range
                ELSE unavailability.unavailable_range * calendar.calendar_range
            END AS center_range,
            calendar.status AS right_status,
            tstzrange(
                upper(unavailability.unavailable_range * calendar.calendar_range),
                upper(calendar.calendar_range)
            ) AS right_range
        FROM calendar_generate_available($1, $2) calendar
        LEFT OUTER JOIN unavailability ON
            unavailability.room_id = $1 AND
            unavailability.unavailable_range && $2
        UNION ALL
        SELECT DISTINCT
            calendars.left_status,
            CASE
                WHEN unavailability.unavailable_range && calendars.left_range THEN
                    tstzrange(
                        lower(calendars.left_range),
                        lower(calendars.left_range * unavailability.unavailable_range)
                    )
                ELSE
                    tstzrange(
                        lower(calendars.right_range),
                        lower(calendars.right_range * unavailability.unavailable_range)
                    )
            END AS left_range,
            CASE
                WHEN
                    unavailability.unavailable_range && calendars.left_range OR
                    unavailability.unavailable_range && calendars.right_range
                THEN 'unavailable'
                ELSE calendars.center_status
            END AS center_status,
            CASE
                WHEN unavailability.unavailable_range && calendars.left_range THEN
                    unavailability.unavailable_range * calendars.left_range
                ELSE
                    unavailability.unavailable_range * calendars.right_range
            END AS center_range,
            calendars.right_status,
            CASE
                WHEN unavailability.unavailable_range && calendars.left_range THEN
                    tstzrange(
                        upper(calendars.left_range * unavailability.unavailable_range),
                        upper(calendars.left_range)
                    )
                ELSE
                    tstzrange(
                        upper(calendars.right_range * unavailability.unavailable_range),
                        upper(calendars.right_range)
                    )
            END AS right_range
        FROM calendars
        JOIN unavailability ON
            unavailability.room_id = $1 AND
            unavailability.unavailable_range && $2 AND
            unavailability.unavailable_range <> calendars.center_range AND (
                unavailability.unavailable_range && calendars.left_range OR
                unavailability.unavailable_range && calendars.right_range
            )
    )
    SELECT *
    FROM (
        SELECT
            x.left_status AS status,
            x.left_range AS calendar_range
        FROM calendars x
        LEFT OUTER JOIN calendars y ON
            x.left_range <> y.left_range AND
            x.left_range @> y.left_range AND
            y.left_status <> 'unavailable'
        GROUP BY 1, 2
        HAVING NOT bool_or(COALESCE(x.left_range @> y.left_range, FALSE))
        UNION
        SELECT
            x.center_status AS status,
            x.center_range AS calendar_range
        FROM calendars x
        LEFT OUTER JOIN calendars y ON
            x.center_range <> y.center_range AND
            x.center_range @> y.center_range
        GROUP BY 1, 2
        HAVING NOT bool_or(COALESCE(x.center_range @> y.center_range, FALSE))
        UNION
        SELECT
            x.right_status AS status,
            x.right_range AS calendar_range
        FROM calendars x
        LEFT OUTER JOIN calendars y ON
            x.right_range <> y.right_range AND
            x.right_range @> y.right_range AND
            y.right_status <> 'unavailable'
        GROUP BY 1, 2
        HAVING NOT bool_or(COALESCE(x.right_range @> y.right_range, FALSE))
    ) x
    WHERE
        NOT isempty(x.calendar_range) AND
        NOT lower_inf(x.calendar_range) AND
        NOT upper_inf(x.calendar_range)
$$ LANGUAGE SQL STABLE;

/**
 * Helper function: substitute the data within the `calendar`; this can be used
 *  for all updates that occur on `availability` and `unavailability`
 */
CREATE OR REPLACE FUNCTION calendar_manage(room_id int, calendar_date date)
RETURNS void
AS $$
    WITH delete_calendar AS (
        DELETE FROM calendar
        WHERE
            room_id = $1 AND
            calendar_date = $2
    )
    INSERT INTO calendar (room_id, status, calendar_date, calendar_range)
    SELECT $1, c.status, $2, c.calendar_range
    FROM calendar_generate_calendar($1, tstzrange($2, $2 + 1)) c
$$ LANGUAGE SQL;

/** Now, the trigger functions for availability and unavailability; needs this for DELETE  */
CREATE OR REPLACE FUNCTION availability_manage()
RETURNS trigger
AS $trigger$
    BEGIN
        IF TG_OP = 'DELETE' THEN
            PERFORM calendar_manage(OLD.room_id, OLD.available_date);
            RETURN OLD;
        END IF;
    END;
$trigger$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION unavailability_manage()
RETURNS trigger
AS $trigger$
    BEGIN
        IF TG_OP = 'DELETE' THEN
            PERFORM calendar_manage(OLD.room_id, OLD.unavailable_date);
            RETURN OLD;
        END IF;
    END;
$trigger$
LANGUAGE plpgsql;

/** And the triggers, applied to everything */
CREATE TRIGGER availability_manage
AFTER DELETE ON availability
FOR EACH ROW
EXECUTE PROCEDURE availability_manage();

CREATE TRIGGER unavailability_manage
AFTER DELETE ON unavailability
FOR EACH ROW
EXECUTE PROCEDURE unavailability_manage();
