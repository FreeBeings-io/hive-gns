import json
import os
import re
from threading import Thread
from hive_gns.config import Config
from hive_gns.database.modules import AvailableModules, Module

from hive_gns.tools import GLOBAL_START_BLOCK, INSTALL_DIR

START_DAYS_DISTANCE = 1
SOURCE_DIR = os.path.dirname(__file__) + "/sql"


config = Config.config


class Haf:

    module_list = []

    @classmethod
    def _get_haf_sync_head(cls, db):
        sql = """
            SELECT block_num, timestamp
            FROM hive.operations_view
            ORDER BY block_num DESC LIMIT 1;
        """
        res = db.do('select', sql)
        return res[0]
    
    @classmethod
    def _get_start_block(cls, db):
        sql = "SELECT gns.get_haf_head_block();"
        res = db.do('select', sql)
        head = res[0]
        return head[0] - (START_DAYS_DISTANCE * 24 * 60 * 20)

    @classmethod
    def _is_valid_module(cls, module):
        return bool(re.match(r'^[a-z]+[_]*$', module))
    
    @classmethod
    def _update_functions(cls, db, functions):
        db.do('execute', functions, None)
        db.do('commit')
    
    @classmethod
    def _check_context(cls, db, start_block=None):
        exists = db.do('select_one', f"SELECT hive.app_context_exists( '{config['schema']}' );")
        if exists is False:
            db.do('select', f"SELECT hive.app_create_context( '{config['schema']}' );")
            if start_block is not None:
                db.do('select', f"SELECT hive.app_context_detach( '{config['schema']}' );")
                db.do('select', f"SELECT hive.app_context_attach( '{config['schema']}', {(start_block-1)} );")
            db.do('commit')
            print(f"HAF SYNC:: created context: '{config['schema']}'")
    
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
        for _file in ['tables.sql', 'functions.sql', 'sync.sql', 'state_preload.sql', 'filters.sql']:
            _sql = (open(f'{SOURCE_DIR}/{_file}', 'r', encoding='UTF-8').read()
                .replace('gns.', f"{config['schema']}.")
                .replace('gns_operations_view', f"{config['schema']}_operations_view")
                .replace('gns_transactions_view', f"{config['schema']}_transactions_view")
            )
            db.do('execute', _sql)
        db.do('commit')
        has_globs = db.do('select', f"SELECT * FROM {config['schema']}.global_props;")
        if not has_globs:
            db.do('execute', f"INSERT INTO {config['schema']}.global_props (check_in) VALUES (NULL);")
            db.do('commit')
        cls._check_context(db, cls._get_start_block(db))
    
    @classmethod
    def _init_main_sync(cls, db):
        print("Starting main sync process...")
        db.do('execute', f"CALL {config['schema']}.sync_main();")
    
    @classmethod
    def _cleanup(cls, db):
        """Stops any running sync procedures from previous instances."""
        db.do('execute', f"SELECT {config['schema']}.terminate_main_sync();")
        working_dir = f'{INSTALL_DIR}/modules'
        cls.module_list = [f.name for f in os.scandir(working_dir) if cls._is_valid_module(f.name)]
        for module in cls.module_list:
            db.do('execute', f"SELECT {config['schema']}.module_terminate_sync('{module}');")
        print("Cleanup complete.")
        cmds = [
            f"DROP SCHEMA {config['schema']} CASCADE;",
            f"SELECT hive.app_remove_context('{config['schema']}');",
            f"CREATE SCHEMA IF NOT EXISTS {config['schema']};"
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
        print("Running state_preload script...")
        end_block = cls._get_haf_sync_head(db)[0] - 300
        db.do('execute', f"CALL {config['schema']}.load_state({GLOBAL_START_BLOCK}, {end_block});")
        Thread(target=AvailableModules.module_watch).start()
        Thread(target=cls._init_main_sync, args=(db,)).start()
