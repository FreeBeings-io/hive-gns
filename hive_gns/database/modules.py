import json
import time
from threading import Thread

from hive_gns.config import Config

config = Config.config


class Module:

    def __init__(self, db, name, hooks) -> None:
        self.db = db
        self.name = name
        self.hooks = hooks
        self.error = False

    def get_hooks(self):
        return self.hooks
    
    def disable(self):
        # TODO: rewrite
        self.hooks['enabled'] = False
        _defs = json.dumps(self.hooks)
        self.db.do(
            'execute',
            f"UPDATE {config['schema']}.module_state SET enabled = false WHERE module = '{self.name}';"
        )
        self.db.do('commit')
    
    def enable(self):
        self.db.do(
            'execute',
            f"UPDATE {config['schema']}.module_state SET enabled = false WHERE module = '{self.name}';"
        )
        self.db.do('commit')
    
    def is_enabled(self):
        enabled = bool(
            self.db.do(
                'select_one',
                f"SELECT enabled FROM {config['schema']}.module_state WHERE module ='{self.name}';"
            )
        )
        return enabled

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
