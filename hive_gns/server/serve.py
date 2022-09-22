import uvicorn

from datetime import datetime
from fastapi import FastAPI

from hive_gns.config import Config
from hive_gns.server import system_status
from hive_gns.server.api_metadata import TITLE, DESCRIPTION, VERSION, CONTACT, LICENSE, TAGS_METADATA
from hive_gns.server.core.transfers import router_core_transfers
from hive_gns.server.splinterlands.transfers import router_splinterlands_transfers
from hive_gns.server.core.accounts import router_core_accounts
from hive_gns.tools import normalize_types, UTC_TIMESTAMP_FORMAT
from hive_gns.engine.hive import make_request

config = Config.config

app = FastAPI(
    title=TITLE,
    description=DESCRIPTION,
    version=VERSION,
    contact=CONTACT,
    license_info=LICENSE,
    openapi_tags=TAGS_METADATA,
    openapi_url="/api/openapi.json"
)

app.include_router(router_core_transfers)
app.include_router(router_splinterlands_transfers)
app.include_router(router_core_accounts)

@app.get('/', tags=['system'])
async def root():
    """Reports the status of Hive Global Notification System."""
    try:
        report = {
            'name': 'Hive Global Notification System',
            'system': normalize_types(system_status.get_sys_status()),
            'timestamp': datetime.utcnow().strftime(UTC_TIMESTAMP_FORMAT)
        }
        head = make_request('condenser_api.get_dynamic_global_properties')['']
        sys_head = report['system']['block_num']

        diff = head - sys_head
        health = "GOOD"
        if diff > 30:
            health = "BAD"
        for mod in report['system']['modules']:
            if report['system']['modules'][mod]['latest_block_num'] < int(report['system']['block_num'] * 0.99):
                health = "BAD"
        report['health'] = health
    except Exception as err:
        print(err)
        report = "System not ready."
    return report

def run_server():
    """Run server."""
    uvicorn.run(
        "hive_gns.server.serve:app",
        host=config['server_host'],
        port=int(config['server_port']),
        log_level="info",
        reload=False,
        workers=1
    )
