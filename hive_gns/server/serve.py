import logging
import uvicorn

from datetime import datetime
from fastapi import FastAPI, Response
from fastapi.middleware.cors import CORSMiddleware

from hive_gns.config import Config
from hive_gns.engine.gns_sys import GnsStatus
from hive_gns.server import system_status
from hive_gns.server.api_metadata import TITLE, DESCRIPTION, VERSION, CONTACT, LICENSE, TAGS_METADATA
from hive_gns.server.core.transfers import router_core_transfers
from hive_gns.server.core.votes import router_core_votes
from hive_gns.server.splinterlands.transfers import router_splinterlands_transfers
from hive_gns.server.core.accounts import router_core_accounts
from hive_gns.tools import normalize_types, UTC_TIMESTAMP_FORMAT

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
app.include_router(router_core_votes)
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
        if report['system']['state_preloaded'] is True:
            del report['system']['state_preload_progress']
        head = GnsStatus.get_haf_head()
        sys_head = report['system']['block_num'] or 0
        report['app_data'] = system_status.get_app_data()
        # check health
        if report['system']['state_preloaded'] is False:
            report['health'] = "BAD - State not preloaded."
            return report
        if sys_head == 0:
            report['health'] = "BAD - System not ready."
            return report
        block_time = report['system']['block_time']
        now = datetime.utcnow()
        diff = now - block_time
        if diff.total_seconds() < 60:
            report['health'] = f"BAD - {diff.total_seconds()} seconds behind... {head-sys_head} blocks behind"
            return report
        else:
            diff = head - sys_head
            if diff > 30:
                report['health'] = f"BAD - {diff} blocks behind... "
                return report
        report['health'] = "GOOD"
        return report
    except Exception as err:
        logging.error(err)
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
        workers=int(config['server_workers'])
    )
