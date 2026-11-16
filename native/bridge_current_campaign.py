"""Fresh current-roster setups for the five bridge protocol regression suites.

Only the town location is changed through a current save/load when testing shop
trials or purchases. Characters, equipment, enemies and battles come from the
campaign's public operations, never historical fixtures or reset scenarios.
"""

GUARD = 'character_mirei'
SCOUT = 'character_rio'
MAGE = 'character_merina'
HUMAN_MAGE = 'character_roze'
AMBUSH = 'character_shion'
PORTER = 'character_yuno'


def accepted(bridge, **request):
    data = bridge.call(**request)
    if not data.get('ok'):
        raise AssertionError((request, data.get('error')))
    return data


def campaign(bridge, action, *args, **options):
    return accepted(bridge, op='campaign', action=action, args=list(args), **options)


def fresh_campaign(bridge, selected=None, location=None):
    data = accepted(bridge, op='campaign_start')
    characters = data['campaign']['characters']
    assert len(characters) == 24 and all(uid.startswith('character_') for uid in characters)
    if selected is not None:
        data = campaign(bridge, 'select', selected)
    if location is not None:
        saved = accepted(bridge, op='campaign_save')['data']
        saved['state']['location'] = location
        data = accepted(bridge, op='campaign_load', data=saved)
    return data


def trial(bridge, uid, gear, location='east'):
    selected = [uid, GUARD, SCOUT] if uid not in (GUARD, SCOUT) else [uid, MAGE, PORTER]
    fresh_campaign(bridge, selected, location)
    data = campaign(bridge, 'trial', uid, gear)
    assert data['state']['actor'] == uid
    assert all(u['id'].startswith('character_') for u in data['state']['units'] if u['side'] == 'ally')
    return data


def journey(bridge, selected=None, deployments=(), stamp=False):
    fresh_campaign(bridge, selected, 'east' if stamp else None)
    if stamp:
        campaign(bridge, 'buyGear', MAGE, 'hammer-wood')
    campaign(bridge, 'depart', 'north', 'convoy')
    data = campaign(bridge, 'travel', 'short')
    for uid, pos in deployments:
        data = campaign(bridge, 'deploy', uid, pos)
    return data


def reach_actor(bridge, data, uid):
    for _ in range(80):
        if data['state']['actor'] == uid:
            return data
        assert data['state']['result'] is None, 'Battle ended before requested actor'
        data = accepted(bridge, op='act', kind='action_defend')
    raise AssertionError('Requested actor did not become active within 80 guards')


def guard_to_result(bridge, data):
    for _ in range(500):
        if data['state']['result']:
            return data
        data = accepted(bridge, op='act', kind='action_defend')
    raise AssertionError('Battle did not end within 500 guards')
