from datetime import datetime
import decimal
import os
import re

from hive_gns.config import Config

config = Config.config

GLOBAL_START_BLOCK = 73077699
INSTALL_DIR = os.path.dirname(__file__)
UTC_TIMESTAMP_FORMAT = "%Y-%m-%dT%H:%M:%S"
MAX_LIMIT = 50
HIVE_NODES = [
    "https://api.hive.blog",
    "https://api.openhive.network",
    "https://anyx.io",
    "https://rpc.ausbit.dev",
    "https://api.deathwing.me",
    "https://hive-api.arcange.eu"
]

NAI_MAP = {
    'HBD': '@@000000013',
    'HIVE': '@@000000021',
    'HP': '@@000000037'
}

def populate_by_schema(data, fields):
    result = {}
    for i in range(len(fields)):
        result[fields[i]] = data[i]
    return result

def _normalize(data):
    if isinstance(data, dict):
        for k in data:
            if isinstance(data[k], decimal.Decimal):
                data[k] = float(data[k])
            elif isinstance(data[k], datetime):
                data[k] = datetime.strftime(data[k], UTC_TIMESTAMP_FORMAT)
        return data

def normalize_types(data):
    if isinstance(data, list):
        res = []
        for l in data:
            res.append(_normalize(l))
        return res
    elif isinstance(data, dict):
        return _normalize(data)
    return data

def range_split(first, last, size):
    a = first
    b = first
    result = []
    while True:
        a += size
        if a >= last:
            result.append((b,last))
            return result
        elif a < last:
            result.append((b,a))
            b = a+1

def is_valid_hive_account(acc):
    return bool(re.match(r'^[a-z][a-z0-9-.]{3,16}$', acc))

def schemafy(data:str):
    _data = data.replace('gns.', f"{config['schema']}.")
    return _data