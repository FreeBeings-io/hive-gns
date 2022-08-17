
from hive_gns.engine.gns_sys import GnsStatus

STATUS_MAPPING = (
    ('block_num', 'latest_block_num'),
    ('block_time', 'latest_block_time'),
    ('last_updated', 'check_in'),
    ('sync_enabled', 'sync_enabled'),
    ('state_preloaded', 'state_preloaded')
)


def get_module_status():
    res = {}
    _modules = GnsStatus.get_module_list()
    for module in _modules:
        res[module] = GnsStatus.get_module_latest_state(module)
    return res

def get_sys_status():
    sync = {}
    cur = GnsStatus.get_global_latest_state()
    for sync_key,map_key in STATUS_MAPPING:
        sync[sync_key] = cur[map_key]
    sync['modules'] = get_module_status()
    return sync
