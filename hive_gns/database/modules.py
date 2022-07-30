import json
from threading import Thread
import time

from hive_gns.database.core import DbSession


class Module:

    def __init__(self, name, hooks) -> None:
        self.name = name
        self.hooks = hooks
        self.db_conn = DbSession()
        self.error = False
    
    def create_new_connection(self):
        if self.error == False:
            del self.db_conn
            self.db_conn = DbSession()

    def get_hooks(self):
        return self.hooks
    
    def disable(self):
        # TODO: rewrite
        self.hooks['enabled'] = False
        _defs = json.dumps(self.hooks)
        self.db_conn.execute(
            f"UPDATE gns.module_state SET enabled = false WHERE module = '{self.name}';"
        )
        self.db_conn.commit()
    
    def enable(self):
        self.db_conn.execute(
            f"UPDATE gns.module_state SET enabled = false WHERE module = '{self.name}';"
        )
        self.db_conn.commit()
    
    def terminate_sync(self):
        self.db_conn.execute(
            f"SELECT gns.terminate_sync({self.name});"
        )
    
    def is_enabled(self):
        enabled = bool(
            self.db_conn.select_one(
                f"SELECT enabled FROM gns.module_state WHERE module ='{self.name}';"
            )
        )
        return enabled

    def is_connection_open(self):
        return self.db_conn.is_open()
    
    def running(self):
        running = self.db_conn.select_one(
            f"SELECT gns.module_running('{self.name}');")
        return running
    
    def is_long_running(self):
        long_running = self.db_conn.select_one(
            f"SELECT gns.module_long_running('{self.name}');")
        return long_running
    
    def start(self):
        try:
            if self.is_enabled():
                print(f"{self.name}:: starting")
                self.db_conn.execute(f"CALL gns.sync_module( '{self.name}' );")
        except Exception as err:
            print(f"Module error: '{self.name}'")
            print(err)
            self.error = True
            self.disable()
            self.db_conn.conn.close()

class AvailableModules:

    modules = dict[str, Module]()

    @classmethod
    def add_module(cls, module_name, module:Module):
        cls.modules[module_name] = module

    @classmethod
    def module_watch(cls):
        while True:
            for _module in cls.modules.items():
                module = cls.modules[_module[0]]
                if not module.error:
                    good = module.is_connection_open()
                    if good is False:
                        print(f"{_module[0]}:: creating new DB connection.")
                        module.create_new_connection()
                    if module.running() is False:
                        Thread(target=module.start).start()
                    elif module.is_long_running():
                        module.terminate_sync()
            time.sleep(60)
