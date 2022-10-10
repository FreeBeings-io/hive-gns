
from hive_gns.engine.gns_sys import GnsStatus

STATUS_MAPPING = (
    ('block_num', 'latest_block_num'),
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

def get_app_data():
    data = {}
    data['categories'] = {
        "Currency": {
            "Hive/HBD transfers": "core:trn"
        },
        "Social": {
            "Votes": "core:vot"
        },
        "Splinterlands": {
            "DEC transfers": "splinterlands:trn"
        }
    }
    data['available_modules'] = _modules = GnsStatus.get_module_list()
    return data
