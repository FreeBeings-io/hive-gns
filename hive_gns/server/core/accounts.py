"""Top level account endpoints."""
import json
from fastapi import APIRouter, HTTPException

from hive_gns.config import Config
from hive_gns.database.access import db
from hive_gns.engine.gns_sys import GnsStatus
from hive_gns.server import system_status
from hive_gns.server.fields import Fields
from hive_gns.tools import MAX_LIMIT, is_valid_hive_account

config = Config.config
router_core_accounts = APIRouter()

def _get_all_notifs(acc, limit, module, notif_code, op_data=False):
    if op_data:
        fields = Fields.Global.get_all_notifs(['payload'])
    else:
        fields = Fields.Global.get_all_notifs()
    _fields = ", ".join(fields)
    sql = f"""
        SELECT {_fields}
        FROM gns.account_notifs
        WHERE account = '{acc}'
    """.replace("gns.", f"{config['schema']}.")
    if module:
        sql += f" AND module_name='{module}'"
    if notif_code:
        sql += f" AND notif_code='{notif_code}'"
    if limit:
        sql += f"ORDER BY id DESC LIMIT {limit}"
    res = db.select(sql, fields)
    return res

def _get_all_notifs_custom(acc, limit, pairings, op_data=False):
    if op_data:
        fields = Fields.Global.get_all_notifs(['payload'])
    else:
        fields = Fields.Global.get_all_notifs()
    _fields = ", ".join(fields)
    sql = f"""
        SELECT {_fields}
        FROM gns.account_notifs
        WHERE account = '{acc}' AND (
    """.replace("gns.", f"{config['schema']}.")
    _pairs_sql = []
    for pair in pairings:
        _pair = pair.split(':')
        _pairs_sql.append(f"(module_name='{_pair[0]}' AND notif_code='{_pair[1]}')")
    _tmp_sql = " OR ".join(_pairs_sql)
    sql += f"{_tmp_sql}) "
    if limit:
        sql += f"ORDER BY id DESC LIMIT {limit}"
    res = db.select(sql, fields)
    return res

def _valid_pairings(pairs):
    # TODO
    return True

def _get_unread_count(acc):
    sql = f"""
        SELECT COUNT(*)
        FROM gns.account_notifs
        WHERE account = '{acc}'
        AND created > (
            SELECT (last_reads->>'all')::timestamp
            FROM gns.accounts WHERE account = '{acc}'
        );
    """.replace("gns.", f"{config['schema']}.")
    res = db.select(sql, ['count'], True)
    return res['count']

def _get_preferences(account, module=None):
    fields = Fields.Core.get_preferences()
    _fields = ", ".join(fields)
    sql = f"""
        SELECT {_fields} FROM gns.accounts
        WHERE account = '{account}';
    """.replace("gns.", f"{config['schema']}.")
    res = db.select(sql, fields, True)
    if module and module in res['prefs']:
        return {
            'prefs': res['prefs'][module],
            'prefs_updated': res['prefs_updated']
        }
    return res

def _get_enabled_pairs(acc):
    """Get all enabled notif pairs for an account."""
    sql = f"""
        SELECT prefs->'enabled' AS enabled
        FROM gns.accounts
        WHERE account = '{acc}';
    """.replace("gns.", f"{config['schema']}.")
    res = db.select(sql, ['enabled'], True)
    enabled = res['enabled']
    pairs = []
    for module in enabled:
        for code in enabled[module]:
            pairs.append(f"{module}:{code}")
    return pairs

@router_core_accounts.get("/api/{account}/preferences", tags=['accounts'])
def account_preferences(account:str, module:str = None):
    if module and module not in GnsStatus.get_module_list():
        raise HTTPException(status_code=400, detail="the module is not valid or is unavailable at the moment")
    if '@' not in account:
        raise HTTPException(status_code=400, detail="missing '@' in account")
    if not is_valid_hive_account(account.replace('@', '')):
        raise HTTPException(status_code=400, detail="invalid Hive account entered for 'account'")
    prefs = _get_preferences(account.replace('@', ''), module)
    return prefs or {}

@router_core_accounts.get("/api/{account}/enabled-notifs", tags=['accounts'])
def account_enabled_notifs(account:str):
    if '@' not in account:
        raise HTTPException(status_code=400, detail="missing '@' in account")
    if not is_valid_hive_account(account.replace('@', '')):
        raise HTTPException(status_code=400, detail="invalid Hive account entered for 'account'")
    pairs = _get_enabled_pairs(account.replace('@', ''))
    return pairs or []

@router_core_accounts.get("/api/{account}/notifications", tags=['accounts'])
async def account_notifications(account:str, module:str=None, notif_code:str=None, limit:int=MAX_LIMIT, op_data:bool=False):
    if '@' not in account:
        raise HTTPException(status_code=400, detail="missing '@' in account")
    if not is_valid_hive_account(account.replace('@', '')):
        raise HTTPException(status_code=400, detail="invalid Hive account entered for")
    if module and module not in GnsStatus.get_module_list():
        raise HTTPException(status_code=400, detail="the module is not valid or is unavailable at the moment")
    if notif_code and len(notif_code) != 3:
        raise HTTPException(status_code=400, detail="invalid notif_code entered, must be a 3 char value")

    if limit > MAX_LIMIT:
        limit = MAX_LIMIT
    notifs = _get_all_notifs(account.replace('@', ''), limit, module, notif_code, op_data)
    return notifs or []

@router_core_accounts.get("/api/{account}/notifications/category", tags=['accounts'])
async def account_notifications_category(account:str, category:str, limit:int=MAX_LIMIT, op_data:bool=False):
    if '@' not in account:
        raise HTTPException(status_code=400, detail="missing '@' in account")
    if not is_valid_hive_account(account.replace('@', '')):
        raise HTTPException(status_code=400, detail="invalid Hive account entered for")
    app_data = system_status.get_app_data()
    if category not in app_data:
        supported = app_data.keys()
        raise HTTPException(status_code=400, detail=f"the category entered is not valid. Supported: {supported}")
    _pairs = []
    for pair in app_data[category]:
        _pairs.append(app_data[category][pair])
    
    if limit > MAX_LIMIT:
        limit = MAX_LIMIT
    notifs = _get_all_notifs_custom(account.replace('@', ''), limit, _pairs, op_data)
    return notifs or []

@router_core_accounts.get("/api/{account}/notifications/custom", tags=['accounts'])
async def account_notifications_custom(account:str, pairings:str, limit:int=MAX_LIMIT, op_data:bool=False):
    if '@' not in account:
        raise HTTPException(status_code=400, detail="missing '@' in account")
    if not is_valid_hive_account(account.replace('@', '')):
        raise HTTPException(status_code=400, detail="invalid Hive account entered for")
    try:
        pairings = json.loads(pairings)
    except:
        raise HTTPException(status_code=400, detail="the `pairings` param must be an array of `module:notif_code` pairings.")
    if not isinstance(pairings, list):
        raise HTTPException(status_code=400, detail="the `pairings` param must be an array of `module:notif_code` pairings.")
    if not _valid_pairings(pairings):
        raise HTTPException(status_code=400, detail="invalid `pairings` entered. Please enter an array of `module:notif_code` pairings.")
    
    if limit > MAX_LIMIT:
        limit = MAX_LIMIT
    notifs = _get_all_notifs_custom(account.replace('@', ''), limit, pairings, op_data)
    return notifs or []

@router_core_accounts.get("/api/{account}/unread", tags=['accounts'])
async def account_unread_count(account:str):
    if '@' not in account:
        raise HTTPException(status_code=400, detail="missing '@' in account")
    if not is_valid_hive_account(account.replace('@', '')):
        raise HTTPException(status_code=400, detail="invalid Hive account entered for")
    count = _get_unread_count(account.replace('@', ''))
    return count