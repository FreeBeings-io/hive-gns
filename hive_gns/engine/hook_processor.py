import json
import time
from threading import Thread

from hive_gns.database.access import alter_schema, perform, select, write
from hive_gns.engine.gns_sys import GnsOps, GnsStatus
from hive_gns.database.haf_sync import HafSync
from hive_gns.engine.verifications import ExternalVerifications
from hive_gns.server import system_status
from hive_gns.tools import INSTALL_DIR

REQ_VERIFY = {
    'splinterlands': ExternalVerifications.splinterlands
}


class HookProcessor:

    def __init__(self, module) -> None:
        self.module = module
        self.good = False
        try:
            self.wd = f'{INSTALL_DIR}/modules/{self.module}'
            self.functions = open(f'{self.wd}/functions.sql', 'r').read()
            self.hooks = json.loads(open(f'{self.wd}/hooks.json', 'r').read())
            self._get_notif_details()
            alter_schema(self.functions)
            self.good = True
        except Exception as e:
            print(e)
            print(f"ERROR: ignoring incorrectly configured module: '{self.module}'")
            # TODO: log error
            pass

    def _get_notif_details(self):
        """
            Loads the notification hook into memory and saves to DB.
            ```
                notif_code -> op_type_id / func / filter
            ```
        """
        notifs = {}
        for hook_name in self.hooks:
            data = self.hooks[hook_name]
            op_type_id = data[0]
            func = data[1]
            notif_code = data[2]
            h_filter = data[3].split('=') if op_type_id == 18 else None
            if notif_code not in notifs:
                notifs[notif_code] = {
                    'op_type_id': op_type_id,
                    'func': func,
                    'filter': h_filter
                }
        self.notifs = notifs
        # update DB entry
        has = select(f"SELECT module FROM gns.module_state WHERE module='{self.module}'", ['module'], True)
        hooks = json.dumps(self.notifs)
        if has is not None:
            # update
            sql = f"""
                UPDATE gns.module_state SET hooks='{hooks}' WHERE module='{self.module}';
            """
        else:
            # insert
            sql = f"""
                    INSERT INTO gns.module_state (module, hooks)
                    VALUES ('{self.module}', '{hooks}');
                """
        done = write(sql)
        if done is not True:
            raise Exception(f"Failed to save hooks to DB for module: '{self.module}")

    def _main_loop(self):
        while True:
            head_gns_op_id = GnsStatus.get_global_latest_gns_op_id()
            cur_gns_op_id = GnsStatus.get_module_latest_gns_op_id(self.module)
            if head_gns_op_id - cur_gns_op_id > 0:
                system_status.set_module_status(self.module, 'synchronizing...')
                try:
                    done = perform('gns.update_module', [self.module, cur_gns_op_id+1, head_gns_op_id])
                    if not done:
                        # TODO: log
                        pass
                except Exception as err:
                    # TODO: log
                    print(err)
                    return
                if self.module in REQ_VERIFY:
                    REQ_VERIFY[self.module]()
            system_status.set_module_status(self.module, 'synchronized')
            time.sleep(1)

    def start(self):
        if self.good:
            Thread(target=self._main_loop).start()
            system_status.set_module_status(self.module, 'started')
            print(f"'{self.module}' module started.")
