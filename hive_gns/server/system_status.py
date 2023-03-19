
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
    """Populate categories with all available module:notif_code pairings."""
    _data = GnsStatus.get_all_modules_data()
    data = {}
    for module in _data:
        entries = _data[module]
        for notif in entries:
            category = notif[0]
            notif_desc = notif[1]
            module = notif[2]
            notif_code = notif[3]
            if category not in data:
                data[category] = {}
            data[category] |= {notif_desc: f"{module}:{notif_code}"}
    return data
