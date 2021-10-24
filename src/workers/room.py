from base import Worker

class RoomWorker(Worker):
    OPERATIONS = set(['insert'])

    def insert(self, cursor, params):
        """Insert closed dates for a year"""
        cursor.execute("""
            INSERT INTO calendar (
                room_id,
                status,
                calendar_date,
                calendar_range
            )
            SELECT
                %(id)s, 'closed', calendar_date, tstzrange(calendar_date, calendar_date + '1 day'::interval)
            FROM generate_series(
                date_trunc('week', CURRENT_DATE),
                date_trunc('week', CURRENT_DATE + '52 weeks'::interval),
                '1 day'::interval
            ) calendar_date""",
            params
        )

if __name__ == "__main__":
    worker = RoomWorker('room')
    worker.run()
