from base import Worker

class AvailabilityRuleWorker(Worker):
    OPERATIONS = set(['insert', 'update'])

    def insert(self, cursor, params):
        """Insert availability rules into all of the calendar entries"""
        self._insert_availability(cursor, params)

    def update(self, cursor, params):
        """Update availability rules in calendar"""
        cursor.execute("""DELETE FROM availability WHERE availability_rule_id = %(id)s""", params)
        self._insert_availability(cursor, params)

    def _insert_availability(self, cursor, params):
        """common functionality shared between insert/update with all rules"""
        days_of_week = params['days_of_week'].replace('{', '').replace('}', '').split(',')
        for day_of_week in days_of_week:
            params['day_of_week'] = day_of_week
            cursor.execute(
                """
                SELECT availability_rule_bulk_insert(ar, %(day_of_week)s)
                FROM availability_rule ar
                WHERE ar.id = %(id)s
                """, params)

if __name__ == "__main__":
    worker = AvailabilityRuleWorker('availability_rule')
    worker.run()
