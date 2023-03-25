import json
import os
import re
from threading import Thread
from hive_gns.config import Config
from hive_gns.database.core import DbSession
from hive_gns.database.modules import AvailableModules, Module

from hive_gns.tools import GLOBAL_START_BLOCK, INSTALL_DIR, schemafy

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
    def get_gns_start_block(cls, db):
        sql = schemafy("SELECT gns.get_start_block();")
        res = db.do('select', sql)
        return res[0][0]

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
        category = hooks['module_category']
        has_entry = db.do('select_exists', f"SELECT module FROM {config['schema']}.module_state WHERE module='{module}'")
        if has_entry is False:
            db.do('execute',
                f"""
                    INSERT INTO {config['schema']}.module_state (module, enabled, module_category)
                    VALUES ('{module}', '{enabled}', '{category}');
                """)
        else:
            db.do('execute',
                f"""
                    UPDATE {config['schema']}.module_state SET enabled = '{enabled}'
                    WHERE module = '{module}';
                """)
        del hooks['enabled']
        del hooks['module_category']
        # update module hooks table
        for notif_name in hooks:
            _notif_code = hooks[notif_name]['notif_code']
            _funct = hooks[notif_name]['function']
            _op_id = int(hooks[notif_name]['op_id'])
            _description = hooks[notif_name]['description']
            _filter = hooks[notif_name]['filter']
            _options = json.dumps(hooks[notif_name]['options'])
            has_hooks_entry = db.do('select_exists',
                f"""
                    SELECT module FROM {config['schema']}.module_hooks 
                    WHERE module='{module}' AND notif_name = '{notif_name}'
                """
            )
            if has_hooks_entry is False:
                db.do('execute',
                    f"""
                        INSERT INTO {config['schema']}.module_hooks (module, notif_name, notif_code, funct, op_id, notif_filter, description, options)
                        VALUES ('{module}', '{notif_name}', '{_notif_code}', '{_funct}', '{_op_id}', '{_filter}', '{_description}', '{_options}');
                    """
                )
            else:
                db.do('execute',
                    f"""
                        UPDATE {config['schema']}.module_hooks 
                        SET notif_code = '{_notif_code}',
                            funct = '{_funct}', op_id = {_op_id}, notif_filter= '{_filter}', description = '{_description}', options = '{_options}';
                    """
                )

    @classmethod
    def _init_modules(cls, db):
        working_dir = f'{INSTALL_DIR}/modules'
        cls.module_list = [f.name for f in os.scandir(working_dir) if cls._is_valid_module(f.name)]
        for module in cls.module_list:
            hooks = json.loads(open(f'{working_dir}/{module}/hooks.json', 'r', encoding='UTF-8').read().replace('gns.', f"{config['schema']}."))
            cls._check_hooks(db, module, hooks)
            # loop through all .sql files found in module, subfolder /notifs, then update functions on each
            for _file in os.listdir(f'{working_dir}/{module}/notifs'):
                if _file.endswith('.sql'):
                    _sql = open(f'{working_dir}/{module}/notifs/{_file}', 'r', encoding='UTF-8').read().replace('gns.', f"{config['schema']}.")
                    cls._update_functions(db, _sql)
            AvailableModules.add_module(module, Module(db, module, hooks))

    @classmethod
    def _init_gns(cls, db):
        print("Initializing GNS...")
        db.do('execute', f"CREATE SCHEMA IF NOT EXISTS {config['schema']};")
        for _file in ['tables.sql', 'functions.sql', 'sync.sql', 'state_preload.sql', 'filters.sql', 'validation.sql']:
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
    def _init_main_sync(cls, db, start_block):
        print("Starting main sync process...")
        db.do('execute', f"CALL {config['schema']}.sync_main({start_block});")
    
    @classmethod
    def _init_state_preload(cls, db, start_block):
        print("Running state preload process...")
        db.do('execute', f"CALL {config['schema']}.load_state({GLOBAL_START_BLOCK}, {start_block-1});")
    
    @classmethod
    def _cleanup(cls, db):
        """Stops any running sync procedures from previous instances."""
        print("Cleaning up...")
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
        start_block = cls.get_gns_start_block(db)
        Thread(target=cls._init_state_preload, args=(db,start_block)).start()
        db_main = DbSession('main')
        Thread(target=cls._init_main_sync, args=(db_main,start_block)).start()
