"""Top level account endpoints."""
from fastapi import APIRouter, HTTPException

from hive_gns.config import Config
from hive_gns.database.access import db
from hive_gns.engine.gns_sys import GnsStatus
from hive_gns.server.fields import Fields
from hive_gns.tools import is_valid_hive_account

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
        sql += f"LIMIT {limit}"
    res = db.select(sql, fields)
    return res

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

@router_core_accounts.get("/api/{account}/notifications", tags=['accounts'])
async def account_notifications(account:str, module:str=None, notif_code:str=None, limit:int=100, op_data:bool=False):
    if '@' not in account:
        raise HTTPException(status_code=400, detail="missing '@' in account")
    if not is_valid_hive_account(account.replace('@', '')):
        raise HTTPException(status_code=400, detail="invalid Hive account entered for")
    if module and module not in GnsStatus.get_module_list():
        raise HTTPException(status_code=400, detail="the module is not valid or is unavailable at the moment")
    if notif_code and len(notif_code) != 3:
        raise HTTPException(status_code=400, detail="invalid notif_code entered, must be a 3 char value")
    notifs = _get_all_notifs(account.replace('@', ''), limit, module, notif_code, op_data)
    return notifs or []

@router_core_accounts.get("/api/{account}/unread", tags=['accounts'])
async def account_unread_count(account:str):
    if '@' not in account:
        raise HTTPException(status_code=400, detail="missing '@' in account")
    if not is_valid_hive_account(account.replace('@', '')):
        raise HTTPException(status_code=400, detail="invalid Hive account entered for")
    count = _get_unread_count(account.replace('@', ''))
    return count