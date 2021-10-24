from base import Worker

class AvailabilityWorker(Worker):
    OPERATIONS = set(['delete', 'insert', 'update'])

    def delete(self, cursor, params):
        """Update the calendar"""
        self._query(cursor, params)

    def insert(self, cursor, params):
        """Update the calendar"""
        self._query(cursor, params)

    def update(self, cursor, params):
        """Update the calendar"""
        self._query(cursor, params)

    def _query(self, cursor, params):
        cursor.execute("""SELECT calendar_manage(%(room_id)s, %(available_date)s)""", params)

if __name__ == "__main__":
    worker = AvailabilityWorker('availability')
    worker.run()
