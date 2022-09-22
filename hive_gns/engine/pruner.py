import time

from hive_gns.database.access import db

class Pruner:

    @classmethod
    def _delete_old_ops(cls):
        sql = """
            DELETE FROM gns.ops
            WHERE created <= NOW() - INTERVAL '30 DAYS';
        """
        return db.delete(sql)

    @classmethod
    def run_pruner(cls):
        while True:
            cls._delete_old_ops()
            time.sleep(300)
