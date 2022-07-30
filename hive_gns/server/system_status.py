
from hive_gns.engine.gns_sys import GnsStatus

STATUS_MAPPING = (
    ('block_num', 'latest_block_num'),
    ('block_time', 'latest_block_time'),
    ('hive_rowid', 'latest_hive_rowid')
)

sync = {}
modules = {}

def is_init():
    return len(sync) > 0

def set_sync_status(status):
    global sync
    sync['status'] = status

def set_module_status(mod, status):
    global modules
    modules[mod] = status

def get_module_list():
    res = [k for (k,v) in modules]
    return res

def get_sys_status():
    global sync
    cur = GnsStatus.get_global_latest_state()
    for sync_key,map_key in STATUS_MAPPING:
        sync[sync_key] = cur[map_key]
    sync['modules'] = modules
    return sync

