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

    db = DbSession()
    module_list = []

    @classmethod
    def _get_haf_sync_head(cls):
        sql = f"""
            SELECT block_num, timestamp FROM hive.operations_view ORDER BY block_num DESC LIMIT 1;
        """
        res = cls.db.select(sql)
        return res[0]

    @classmethod
    def _is_valid_module(cls, module):
        return bool(re.match(r'^[a-z]+[_]*$', module))

    @classmethod
    def _check_context(cls, name, start_block=None):
        exists = cls.db.select_one(
            f"SELECT hive.app_context_exists( '{name}' );"
        )
        if exists is False:
            cls.db.select(f"SELECT hive.app_create_context( '{name}' );")
            if start_block is not None:
                cls.db.select(f"SELECT hive.app_context_detach( '{name}' );")
                cls.db.select(f"SELECT hive.app_context_attach( '{name}', {(start_block-1)} );")
            cls.db.commit()
            print(f"HAF SYNC:: created context: '{name}'")
    
    @classmethod
    def _update_functions(cls, functions):
        cls.db.execute(functions, None)
        cls.db.commit()
    
    @classmethod
    def _check_hooks(cls, module, hooks):
        enabled = hooks['enabled']
        has_entry = cls.db.select_exists(f"SELECT module FROM gns.module_state WHERE module='{module}'")
        if has_entry is False:
            cls.db.execute(
                f"""
                    INSERT INTO gns.module_state (module, enabled)
                    VALUES ('{module}', '{enabled}');
                """)
        else:
            cls.db.execute(
                f"""
                    UPDATE gns.module_state SET enabled = '{enabled}'
                    WHERE module = '{module}';
                """)
        del hooks['enabled']
        # update module hooks table
        for notif_name in hooks:
            _notif_code = hooks[notif_name]['notif_code']
            _funct = hooks[notif_name]['function']
            _op_id = int(hooks[notif_name]['op_id'])
            _filter = json.dumps(hooks[notif_name]['filter'])
            has_hooks_entry = cls.db.select_exists(
                f"""
                    SELECT module FROM gns.module_hooks 
                    WHERE module='{module}' AND notif_name = '{notif_name}'
                """
            )
            if has_hooks_entry is False:
                cls.db.execute(
                    f"""
                        INSERT INTO gns.module_hooks (module, notif_name, notif_code, funct, op_id, notif_filter)
                        VALUES ('{module}', '{notif_name}', '{_notif_code}', '{_funct}', '{_op_id}', '{_filter}');
                    """
                )
            else:
                cls.db.execute(
                    f"""
                        UPDATE gns.module_hooks 
                        SET notif_code = '{_notif_code}',
                            funct = '{_funct}', op_id = {_op_id}, notif_filter= '{_filter}';
                    """
                )

    @classmethod
    def _init_modules(cls):
        working_dir = f'{INSTALL_DIR}/modules'
        cls.module_list = [f.name for f in os.scandir(working_dir) if cls._is_valid_module(f.name)]
        for module in cls.module_list:
            hooks = json.loads(open(f'{working_dir}/{module}/hooks.json', 'r', encoding='UTF-8').read())
            functions = open(f'{working_dir}/{module}/functions.sql', 'r', encoding='UTF-8').read()
            cls._check_context(module)
            cls._check_hooks(module, hooks)
            cls._update_functions(functions)
            AvailableModules.add_module(module, Module(module, hooks))

    @classmethod
    def _init_gns(cls):
        if config['reset'] == 'true':
            cls.db.execute(f"SELECT hive.app_remove_context('{MAIN_CONTEXT}');")
            cls.db.execute(f"DROP SCHEMA {MAIN_CONTEXT} CASCADE;")
        cls._check_context(MAIN_CONTEXT)
        for _file in ['tables.sql', 'functions.sql', 'sync.sql', 'state_preload.sql', 'filters.sql']:
            _sql = open(f'{SOURCE_DIR}/{_file}', 'r', encoding='UTF-8').read()
            cls.db.execute(_sql)
        cls.db.commit()
        has_globs = cls.db.select("SELECT * FROM gns.global_props;")
        if not has_globs:
            cls.db.execute("INSERT INTO gns.global_props (check_in) VALUES (NULL);")
            cls.db.commit()
    
    @classmethod
    def _init_pruner(cls):
        while True:
            ready = cls.db.select_one("SELECT state_preloaded FROM gns.global_props;")
            if ready is True:
                break
            time.sleep(60)
        while True:
            cls.db.execute("CALL gns.run_pruner();")
            time.sleep(30)

    @classmethod
    def init(cls):
        cls._init_gns()
        cls._init_modules()
        print("Running state_preload script...")
        end_block = cls._get_haf_sync_head()[0]
        cls.db.execute(f"CALL gns.load_state({GLOBAL_START_BLOCK}, {end_block});")
        Thread(target=AvailableModules.module_watch).start()
        Thread(target=cls._init_pruner).start()
