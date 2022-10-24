from fastapi import APIRouter, HTTPException

from hive_gns.config import Config
from hive_gns.database.access import db
from hive_gns.server.fields import Fields
from hive_gns.tools import MAX_LIMIT, NAI_MAP, is_valid_hive_account

MODULE_NAME = 'core'
NOTIF_CODE = 'vot'

config = Config.config
router_core_votes = APIRouter()

def _get_votes(acc, limit, min_date=None, max_date=None, op_data=False):
    if op_data:
        fields = Fields.Core.get_votes(['payload'])
    else:
        fields = Fields.Core.get_votes()
    _fields = ", ".join(fields)
    sql = f"""
        SELECT {_fields}
        FROM gns.account_notifs
        WHERE account = '{acc}'
        AND module_name = '{MODULE_NAME}'
        AND notif_code = '{NOTIF_CODE}'
        AND created > (
            SELECT COALESCE(
                (last_reads->'{MODULE_NAME}'->>'{NOTIF_CODE}')::timestamp,
                (NOW() - INTERVAL '30 DAYS')
            )
            FROM gns.accounts WHERE account = '{acc}'
        )
    """.replace("gns.", f"{config['schema']}.")
    if min_date:
        sql += f"AND created >= '{min_date}'"
    if max_date:
        sql += f"AND created <= '{max_date}'"
    sql += f"ORDER BY created DESC LIMIT {limit}"
    res = db.select(sql, fields)
    return res

@router_core_votes.get("/api/{account}/core/votes", tags=['core'])
async def core_votes(account:str, limit:int=100, min_date:str=None, max_date:str=None, op_data:bool=False):
    if limit and not isinstance(limit, int):
        raise HTTPException(status_code=400, detail="limit param must be an integer")
    if '@' not in account:
        raise HTTPException(status_code=400, detail="missing '@' in account")
    if not is_valid_hive_account(account.replace('@', '')):
        raise HTTPException(status_code=400, detail="invalid Hive account entered")
    if min_date:
        min_date = min_date.replace('T', ' ')
    if max_date:
        max_date = max_date.replace('T', ' ')

    if limit > MAX_LIMIT:
        limit = MAX_LIMIT
    notifs = _get_votes(account.replace('@', ''), limit, min_date, max_date, op_data)
    return notifs or []
