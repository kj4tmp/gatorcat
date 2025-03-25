import threading
import time
from typing import Any

import zenoh
import cbor2
from nicegui import Client, run, ui, app
import datetime

channels: dict[str, tuple[Any, Any]] = {}

def subscribe_in_background():
    config = zenoh.Config.from_file("zenoh_config.json5")
    print(config)
    zenoh.init_log_from_env_or("error")
    print("Opening session...")
    with zenoh.open(config) as session:
        def listener(sample: zenoh.Sample):
            # print(f"Got {str(sample.key_expr)}")
            if sample.kind == zenoh.SampleKind.DELETE:
                channels.pop(str(sample.key_expr), None)
            elif sample.kind == zenoh.SampleKind.PUT:
                channels[str(sample.key_expr)] = (cbor2.loads(sample.payload.to_bytes()), sample.timestamp.get_time() if sample.timestamp else datetime.datetime.now())

        session.declare_subscriber("**", listener)
        while True:
            time.sleep(1)

@ui.page("/")
async def main_page(client: Client):

    columns = [{"name": "channel", "label": "channel", "field": "channel", "align": "left"},
               {"name": "value", "label": "value", "field": "value", "align": "right"},
               {"name": "timestamp", "label": "timestamp", "field": "timestamp", "align": "right"},

               ]
    channels_table = ui.table(columns=columns, rows=[]).props("dense")
    async def update_table():
        channels_table.rows = [{"channel": channel, "value": value[0], "timestamp": value[1]} for channel,value in channels.items()]
    ui.timer(0.1, update_table)

async def on_start():
    subscribe_thread = threading.Thread(target=subscribe_in_background)
    subscribe_thread.start()

app.on_startup(on_start)
ui.run()
