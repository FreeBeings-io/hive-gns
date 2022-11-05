import time
from threading import Thread

from hive_gns.config import Config
from hive_gns.database.access import db

config = Config.config

class Pruner:

    @classmethod
    def _run(cls):
        while True:
            sql_gns = "SELECT gns.prune_gns();".replace("gns.", f"{config['schema']}.")
            db.execute(sql_gns)
            #sql_haf = "SELECT gns.prune_haf();".replace("gns.", f"{config['schema']}.")
            #db.execute(sql_haf)
            time.sleep(300)

    @classmethod
    def run_pruner(cls):
        Thread(target=cls._run).start()