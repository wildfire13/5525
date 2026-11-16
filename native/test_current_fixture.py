"""Current-format named actors for existing bridge regression scenarios."""
import json
from pathlib import Path
import subprocess


def current_campaign(bridge):
    raw = subprocess.check_output(
        ['node', '-e', "const C=require('./campaign.js');console.log(C.serialize(require('./test-current-fixture.cjs')()));"],
        cwd=Path(__file__).resolve().parent, text=True)
    reply = bridge.call(op='campaign_load', data=json.loads(raw))
    if not reply.get('ok'):
        raise AssertionError(reply.get('error', 'Current fixture rejected'))
    return reply
