import uvicorn

from datetime import datetime
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

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

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
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
        head = make_request('condenser_api.get_dynamic_global_properties')['head_block_number']
        sys_head = report['system']['block_num'] or 0

        diff = head - sys_head
        health = "GOOD"
        if sys_head == 0:
            health = "BAD - System not ready"
        else:
            if diff > 30:
                health = f"BAD - {diff} blocks behind... "
            for mod in report['system']['modules']:
                mod_head = report['system']['modules'][mod]['latest_block_num'] or 0
                if mod_head < int(sys_head * 0.99):
                    diff_mod = mod_head - sys_head
                    health += f"BAD - module '{mod}' is {diff_mod} blocks behind... "
        report['health'] = health
        report['app_data'] = system_status.get_app_data()
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
