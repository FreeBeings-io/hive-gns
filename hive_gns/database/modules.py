import json
import time
from threading import Thread

from hive_gns.config import Config
from hive_gns.database.core import DbSession

config = Config.config


class Module:

    def __init__(self, db, name, hooks) -> None:
        self.name = name
        self.hooks = hooks
        self.db_conn = DbSession(name)
        self.error = False

    def get_hooks(self):
        return self.hooks
    
    def disable(self):
        # TODO: rewrite
        self.hooks['enabled'] = False
        _defs = json.dumps(self.hooks)
        self.db_conn.execute(
            f"UPDATE {config['main_schema']}.module_state SET enabled = false WHERE module = '{self.name}';"
        )
        self.db_conn.commit()
    
    def enable(self):
        self.db_conn.execute(
            f"UPDATE {config['main_schema']}.module_state SET enabled = false WHERE module = '{self.name}';"
        )
        self.db_conn.commit()
    
    def terminate_sync(self):
        self.db_conn.execute(
            f"SELECT {config['main_schema']}.module_terminate_sync({self.name});"
        )
    
    def is_enabled(self):
        enabled = bool(
            self.db_conn.select_one(
                f"SELECT enabled FROM {config['main_schema']}.module_state WHERE module ='{self.name}';"
            )
        )
        return enabled
    
    def running(self):
        running = self.db_conn.select_one(
            f"SELECT {config['main_schema']}.module_running('{self.name}');")
        return running
    
    def is_long_running(self):
        long_running = self.db_conn.select_one(
            f"SELECT {config['main_schema']}.module_long_running('{self.name}');")
        return long_running
    
    def start(self):
        try:
            if self.is_enabled():
                print(f"{self.name}:: starting")
                self.db_conn.execute(f"CALL {config['main_schema']}.sync_module( '{self.name}' );")
        except Exception as err:
            print(f"Module error: '{self.name}'")
            print(err)
            self.error = True
            self.disable()

class AvailableModules:

    modules = dict[str, Module]()

    @classmethod
    def add_module(cls, module_name, module:Module):
        cls.modules[module_name] = module

    @classmethod
    def module_watch(cls):
        print("Starting module watch...")
        while True:
            for _module in cls.modules.items():
                module = cls.modules[_module[0]]
                if not module.error:
                    if module.running() is False:
                        Thread(target=module.start).start()
                    elif module.is_long_running():
                        module.terminate_sync()
            time.sleep(60)
