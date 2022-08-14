from hive_gns.external.splinterlands import Splinterlands
from hive_gns.database.access import db

class ExternalVerifications:

    @classmethod
    def splinterlands(cls):
        sql_notifs = """
            SELECT id, trx_id FROM gns.account_notifs
            WHERE verified IS NULL;
        """
        notifications = db.select(sql_notifs, ['id', 'trx_id']) or []
        sql = ""
        for notif in notifications:
            trx_id = notif['trx_id']
            _id = notif['id']
            valid = Splinterlands.verify_transaction(trx_id)
            if valid is True or valid is False:
                sql += f"""
                    UPDATE gns.account_notifs SET verified = '{str(valid).lower()}'
                    WHERE id = '{_id}';
                """
        if sql != "":
            db.write(sql)
