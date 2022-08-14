import sys
import time


from hive_gns.config import Config
from hive_gns.server.serve import run_server
from hive_gns.database.haf import Haf

config = Config.config

def run():
    try:
        """Runs main application processes and server."""
        print("---   Global Notification System (Hive Blockchain) started   ---")
        Haf.init()
        time.sleep(20)
        run_server()
    except KeyboardInterrupt:
        sys.exit()

if __name__ == "__main__":
    run()
