import json
import os
import re
from threading import Thread
from hive_gns.config import Config
from hive_gns.database.core import DbSession
from hive_gns.database.modules import AvailableModules, Module

from hive_gns.tools import GLOBAL_START_BLOCK, INSTALL_DIR

START_DAYS_DISTANCE = 1
SOURCE_DIR = os.path.dirname(__file__) + "/sql"


config = Config.config


class Haf:

    module_list = []

    @classmethod
    def _get_haf_sync_head(cls, db):
        sql = "SELECT hive.app_get_irreversible_block();"
        res = db.do('select', sql)
        return res[0]

    @classmethod
    def _is_valid_module(cls, module):
        return bool(re.match(r'^[a-z]+[_]*$', module))
    
    @classmethod
    def _update_functions(cls, db, functions):
        db.do('execute', functions, None)
        db.do('commit')
    
    @classmethod
    def _check_hooks(cls, db, module, hooks):
        enabled = hooks['enabled']
        has_entry = db.do('select_exists', f"SELECT module FROM {config['schema']}.module_state WHERE module='{module}'")
        if has_entry is False:
            db.do('execute',
                f"""
                    INSERT INTO {config['schema']}.module_state (module, enabled)
                    VALUES ('{module}', '{enabled}');
                """)
        else:
            db.do('execute',
                f"""
                    UPDATE {config['schema']}.module_state SET enabled = '{enabled}'
                    WHERE module = '{module}';
                """)
        del hooks['enabled']
        # update module hooks table
        for notif_name in hooks:
            _notif_code = hooks[notif_name]['notif_code']
            _funct = hooks[notif_name]['function']
            _op_id = int(hooks[notif_name]['op_id'])
            _filter = json.dumps(hooks[notif_name]['filter'])
            has_hooks_entry = db.do('select_exists',
                f"""
                    SELECT module FROM {config['schema']}.module_hooks 
                    WHERE module='{module}' AND notif_name = '{notif_name}'
                """
            )
            if has_hooks_entry is False:
                db.do('execute',
                    f"""
                        INSERT INTO {config['schema']}.module_hooks (module, notif_name, notif_code, funct, op_id, notif_filter)
                        VALUES ('{module}', '{notif_name}', '{_notif_code}', '{_funct}', '{_op_id}', '{_filter}');
                    """
                )
            else:
                db.do('execute',
                    f"""
                        UPDATE {config['schema']}.module_hooks 
                        SET notif_code = '{_notif_code}',
                            funct = '{_funct}', op_id = {_op_id}, notif_filter= '{_filter}';
                    """
                )

    @classmethod
    def _init_modules(cls, db):
        working_dir = f'{INSTALL_DIR}/modules'
        cls.module_list = [f.name for f in os.scandir(working_dir) if cls._is_valid_module(f.name)]
        for module in cls.module_list:
            hooks = json.loads(open(f'{working_dir}/{module}/hooks.json', 'r', encoding='UTF-8').read().replace('gns.', f"{config['schema']}."))
            functions = open(f'{working_dir}/{module}/functions.sql', 'r', encoding='UTF-8').read().replace('gns.', f"{config['schema']}.")
            cls._check_hooks(db, module, hooks)
            cls._update_functions(db, functions)
            AvailableModules.add_module(module, Module(db, module, hooks))

    @classmethod
    def _init_gns(cls, db):
        db.do('execute', f"CREATE SCHEMA IF NOT EXISTS {config['schema']};")
        for _file in ['tables.sql', 'functions.sql', 'sync.sql', 'state_preload.sql', 'filters.sql']:
            _sql = (open(f'{SOURCE_DIR}/{_file}', 'r', encoding='UTF-8').read()
                .replace('gns.', f"{config['schema']}.")
            )
            db.do('execute', _sql)
        db.do('commit')
        has_globs = db.do('select', f"SELECT * FROM {config['schema']}.global_props;")
        if not has_globs:
            db.do('execute', f"INSERT INTO {config['schema']}.global_props (check_in) VALUES (NULL);")
            db.do('commit')
    
    @classmethod
    def _init_main_sync(cls, db):
        print("Starting main sync process...")
        db.do('execute', f"CALL {config['schema']}.sync_main();")
    
    @classmethod
    def _cleanup(cls, db):
        """Stops any running sync procedures from previous instances."""
        running = db.do('select_one', f"SELECT {config['schema']}.is_sync_running('{config['schema']}-main');")
        if running is True:
            db.do('execute', f"SELECT {config['schema']}.terminate_main_sync('{config['schema']}-main');")
        cmds = [
            f"DROP SCHEMA {config['schema']} CASCADE;",
        ]
        if config['reset'] == 'true':
            for cmd in cmds:
                try:
                    db.do('execute', cmd)
                except Exception as err:
                    print(f"Reset encountered error: {err}")
            cls._init_gns(db)

    @classmethod
    def init(cls, db):
        """Initializes the HAF sync process."""
        cls._init_gns(db)
        cls._cleanup(db)
        cls._init_modules(db)
        start = db.do('select', f"SELECT {config['schema']}.global_sync_enabled()")[0][0]
        if start is True:
            print("Running state_preload script...")
            end_block = cls._get_haf_sync_head(db)[0] - 300
            db.do('execute', f"CALL {config['schema']}.load_state({GLOBAL_START_BLOCK}, {end_block});")
            db_main = DbSession('main')
            Thread(target=cls._init_main_sync, args=(db_main,)).start()
        else:
            print("Global sync is disabled. Shutting down")
            os._exit(0)
