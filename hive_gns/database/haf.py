from faulthandler import is_enabled
import json
import os
import re
from threading import Thread
import time
from hive_gns.config import Config
from hive_gns.database.core import DbSession
from hive_gns.database.modules import AvailableModules, Module

from hive_gns.tools import GLOBAL_START_BLOCK, INSTALL_DIR

SOURCE_DIR = os.path.dirname(__file__) + "/sql"

MAIN_CONTEXT = "gns"

config = Config.config


class Haf:

    module_list = []

    @classmethod
    def _get_haf_sync_head(cls, db):
        sql = f"""
            SELECT block_num, timestamp FROM hive.operations_view ORDER BY block_num DESC LIMIT 1;
        """
        res = db.select(sql)
        return res[0]

    @classmethod
    def _is_valid_module(cls, module):
        return bool(re.match(r'^[a-z]+[_]*$', module))

    @classmethod
    def _check_context(cls, db, name, start_block=None):
        exists = db.select_one(
            f"SELECT hive.app_context_exists( '{name}' );"
        )
        if exists is False:
            db.select(f"SELECT hive.app_create_context( '{name}' );")
            if start_block is not None:
                db.select(f"SELECT hive.app_context_detach( '{name}' );")
                db.select(f"SELECT hive.app_context_attach( '{name}', {(start_block-1)} );")
            db.commit()
            print(f"HAF SYNC:: created context: '{name}'")
    
    @classmethod
    def _update_functions(cls, db, functions):
        db.execute(functions, None)
        db.commit()
    
    @classmethod
    def _check_hooks(cls, db, module, hooks):
        enabled = hooks['enabled']
        has_entry = db.select_exists(f"SELECT module FROM {config['main_schema']}.module_state WHERE module='{module}'")
        if has_entry is False:
            db.execute(
                f"""
                    INSERT INTO {config['main_schema']}.module_state (module, enabled)
                    VALUES ('{module}', '{enabled}');
                """)
        else:
            db.execute(
                f"""
                    UPDATE {config['main_schema']}.module_state SET enabled = '{enabled}'
                    WHERE module = '{module}';
                """)
        del hooks['enabled']
        # update module hooks table
        for notif_name in hooks:
            _notif_code = hooks[notif_name]['notif_code']
            _funct = hooks[notif_name]['function']
            _op_id = int(hooks[notif_name]['op_id'])
            _filter = json.dumps(hooks[notif_name]['filter'])
            has_hooks_entry = db.select_exists(
                f"""
                    SELECT module FROM {config['main_schema']}.module_hooks 
                    WHERE module='{module}' AND notif_name = '{notif_name}'
                """
            )
            if has_hooks_entry is False:
                db.execute(
                    f"""
                        INSERT INTO {config['main_schema']}.module_hooks (module, notif_name, notif_code, funct, op_id, notif_filter)
                        VALUES ('{module}', '{notif_name}', '{_notif_code}', '{_funct}', '{_op_id}', '{_filter}');
                    """
                )
            else:
                db.execute(
                    f"""
                        UPDATE {config['main_schema']}.module_hooks 
                        SET notif_code = '{_notif_code}',
                            funct = '{_funct}', op_id = {_op_id}, notif_filter= '{_filter}';
                    """
                )

    @classmethod
    def _init_modules(cls, db):
        working_dir = f'{INSTALL_DIR}/modules'
        cls.module_list = [f.name for f in os.scandir(working_dir) if cls._is_valid_module(f.name)]
        for module in cls.module_list:
            hooks = json.loads(open(f'{working_dir}/{module}/hooks.json', 'r', encoding='UTF-8').read().replace("gns.", f"{config['main_schema']}."))
            functions = open(f'{working_dir}/{module}/functions.sql', 'r', encoding='UTF-8').read().replace("gns.", f"{config['main_schema']}.")
            cls._check_hooks(db, module, hooks)
            cls._update_functions(db, functions)
            AvailableModules.add_module(module, Module(db, module, hooks))

    @classmethod
    def _init_gns(cls, db):
        if config['reset'] == 'true':
            resets = []
            resets.append(f"SELECT hive.app_remove_context('{config['main_schema']}');")
            resets.append(f"DROP SCHEMA {config['main_schema']} CASCADE;")
            for sql in resets:
                try:
                    db.execute(sql)
                except Exception as e:
                    print(f"Reset encountered error: {e}")
        db.execute(f"CREATE SCHEMA IF NOT EXISTS {config['main_schema']};")
        cls._check_context(db, config['main_schema'])
        for _file in ['tables.sql', 'functions.sql', 'sync.sql', 'state_preload.sql', 'filters.sql']:
            _sql = open(f'{SOURCE_DIR}/{_file}', 'r', encoding='UTF-8').read().replace("gns.", f"{config['main_schema']}.")
            db.execute(_sql.replace("INHERITS( hive.gns )", f"INHERITS( hive.{config['main_schema']} )"))
        db.commit()
        has_globs = db.select(f"SELECT * FROM {config['main_schema']}.global_props;")
        if not has_globs:
            db.execute(f"INSERT INTO {config['main_schema']}.global_props (check_in) VALUES (NULL);")
            db.commit()
    
    @classmethod
    def _init_main_sync(cls, db):
        print("Starting main sync process...")
        sql = f"""
            CALL {config['main_schema']}.sync_main( '{config['main_schema']}' );
        """
        db.execute(sql)
        print("Main sync started successfully.")

    @classmethod
    def init(cls, db):
        cls._init_gns(db)
        cls._init_modules(db)
        print("Running state_preload script...")
        end_block = cls._get_haf_sync_head(db)[0]
        db.execute(f"CALL {config['main_schema']}.load_state({GLOBAL_START_BLOCK}, {end_block});")
        Thread(target=AvailableModules.module_watch).start()
        Thread(target=cls._init_main_sync, args=(db,)).start()
        #Thread(target=cls._init_pruner).start()
