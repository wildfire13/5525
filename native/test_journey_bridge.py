"""Real-process journey adapter checks; no GUI, network, or state injection.

Enemy selection is reproducible through Node's supported --random-seed flag.
The separate reference process operates only on a JSON copy of the observed
battle state. Its selected actions are submitted through the production bridge;
every resulting battle state is compared against the unmodified battle module.
"""
import json
from pathlib import Path
import subprocess
import unittest

BASE = Path(__file__).resolve().parent


class Session:
    def __init__(self, seed=5525):
        self.process = subprocess.Popen(
            ['node', f'--random-seed={seed}', str(BASE / 'bridge.cjs')],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True, encoding="utf-8", cwd=BASE)

    def call(self, **request):
        self.process.stdin.write(json.dumps(request) + '\n')
        self.process.stdin.flush()
        line = self.process.stdout.readline()
        if not line:
            raise RuntimeError('Bridge exited: ' + self.process.stderr.read())
        return json.loads(line)

    def close(self):
        self.process.stdin.close()
        self.process.wait(timeout=5)
        self.process.stdout.close()
        self.process.stderr.close()


REFERENCE_POLICY = r"""
const B = require('./battle.js'), fs = require('node:fs');
const s = JSON.parse(fs.readFileSync(0, 'utf8')), steps = [];
for(let n=0;n<250&&!s.result;n++) {
  const a=s.units.find(u=>u.id===s.actor);
  const old=a.intent;
  B.plan(s,a);
  let {kind,target}=a.intent;
  if(old===undefined)delete a.intent;else a.intent=old;
  // The production AI is symmetric except that random enemies have no porter.
  // Keep the protected courier at its deployment position rather than walking
  // it into melee. All choices still use the original engine legality checks.
  if(a.job==='porter') {
    const hurt=s.units.filter(u=>u.hp>0&&u.side===a.side&&u.hp<30)
      .sort((l,r)=>l.hp-r.hp).find(u=>B.legal(s,'item',u.id));
    if(hurt){kind='item';target=hurt.id;}
    else {kind=B.legal(s,'skill',a.id)?'skill':'guard';target=kind==='skill'?a.id:null;}
  }
  if(!B.act(s,kind,target))throw Error('Illegal policy choice '+kind+' '+target);
  // Existing web cycle.js:117 relabels a successful journey terminal outcome.
  // This is the only frontend adaptation; all other state remains exact.
  if(s.result&&!s.failure&&s.units.some(u=>u.side==='ally'&&u.hp>0))
    s.result='勝利！ 荷物を守り切った。';
  steps.push({kind,target:target??null,state:JSON.parse(JSON.stringify(s))});
}
console.log(JSON.stringify({steps,result:s.result,actions:s.actions}));
"""


def resources(units):
    return [{k: u[k] for k in ('id', 'hp', 'mp', 'max', 'maxMp')}
            for u in units if u['side'] == 'ally']


class JourneyBridgeTests(unittest.TestCase):
    def setUp(self):
        self.bridge = Session()
        self.data = self.bridge.call(op='journey_start')

    def tearDown(self):
        self.bridge.close()

    def action(self, action, *args, ok=True):
        self.data = self.bridge.call(op='journey', action=action, args=list(args))
        self.assertEqual(self.data['ok'], ok, (action, self.data.get('error')))
        return self.data

    def snapshot(self):
        return {'journey': self.data['journey'], 'state': self.data['state']}

    def reject_unchanged(self, action, *args):
        before = self.snapshot()
        self.action(action, *args, ok=False)
        self.assertEqual(self.snapshot(), before, action)

    def prepare(self, job='parts', kit='medicine', formation='convoy', party=None):
        self.action('accept', job)
        if party is not None:
            self.action('select', party)
        self.action('depart', kit, formation)

    def play_battle(self):
        before = self.data['state']
        result = subprocess.run(['node', '-e', REFERENCE_POLICY], cwd=BASE,
                                input=json.dumps(before), capture_output=True,
                                text=True, encoding="utf-8", timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        expected = json.loads(result.stdout)
        self.assertTrue(expected['result'], 'Reference reached 250-action limit')
        for index, step in enumerate(expected['steps']):
            self.data = self.bridge.call(op='act', kind=step['kind'], target=step['target'])
            self.assertTrue(self.data['ok'], (index, step['kind'], self.data.get('error')))
            self.assertEqual(self.data['state'], step['state'], f'Adapter parity at action {index + 1}')
        return expected

    def test_start_selection_and_phase_gates(self):
        self.assertEqual(self.data['journey']['phase'], 'jobs')
        self.assertIsNone(self.data['state'])
        self.assertEqual(len(self.data['roster']), 11)
        self.assertEqual(len(self.data['jobs']), 2)
        self.reject_unchanged('travel', 'short')
        self.reject_unchanged('select', ['porter'])
        self.reject_unchanged('accept', 'unknown')
        self.action('accept', 'medicine')
        self.reject_unchanged('accept', 'parts')
        self.reject_unchanged('select', ['porter', 'guard', 'archer', 'mage', 'scout', 'warrior'])
        self.reject_unchanged('select', ['porter', 'porter'])
        self.reject_unchanged('select', ['porter', 'unknown'])
        self.action('select', ['guard', 'warrior'])
        self.reject_unchanged('depart', 'medicine', 'convoy')
        self.action('select', ['porter', 'porter-2', 'warrior', 'archer', 'mage'])
        self.reject_unchanged('depart', 'unknown', 'convoy')
        self.reject_unchanged('depart', 'medicine', 'unknown')
        self.action('depart', 'medicine', 'convoy')
        self.reject_unchanged('select', ['porter'])

    def test_initial_run_one_and_repeated_start_increments(self):
        first = self.bridge.call(op='export')['data']
        self.assertEqual(first['mode'], 'journey')
        self.assertEqual(first['run'], 1)
        self.assertEqual(first['events'][0]['type'], 'run.started')
        self.assertEqual(first['events'][0]['run'], 1)
        self.data = self.bridge.call(op='journey_start')
        second = self.bridge.call(op='export')['data']
        self.assertEqual(second['run'], 2)
        self.assertEqual([e['run'] for e in second['events'] if e['type'] == 'run.started'], [1, 2])
        self.assertEqual(second['current']['journey']['phase'], 'jobs')
        self.assertIsNone(second['current']['battle'])

    def test_forecast_is_read_only_and_strictly_late(self):
        self.prepare('medicine')
        before = self.snapshot()
        self.action('forecast', 'short')
        self.assertEqual(self.data['forecast'], {'hours': 6, 'late': False, 'over': 0})
        self.assertEqual(self.snapshot(), before)
        self.action('forecast', 'safe')
        self.assertEqual(self.data['forecast'], {'hours': 8, 'late': True, 'over': 1})
        self.assertEqual(self.snapshot(), before)

    def test_kits_and_deployment_move_swap_reset_begin(self):
        for kit, potions, bonus in [('medicine', 3, 0), ('ether', 1, 2)]:
            with self.subTest(kit=kit):
                self.data = self.bridge.call(op='journey_start')
                self.prepare(kit=kit, formation='flank')
                self.action('travel', 'safe')
                state = self.data['state']
                self.assertEqual(self.data['journey']['phase'], 'deployment')
                self.assertEqual(self.data['journey']['hours'], 4)
                self.assertIsNone(state['actor'])
                self.assertTrue(state['deploying'])
                self.assertEqual(state['actions'], 0)
                self.assertEqual(state['potions'], {'ally': potions, 'enemy': 0})
                enemies = [u for u in state['units'] if u['side'] == 'enemy']
                self.assertEqual(len(enemies), 2)
                self.assertTrue(all('intent' not in u for u in enemies))
                self.assertTrue(all(u['job'] not in ('porter', 'warrior') for u in enemies))
                templates = {u['id']: u for u in self.data['roster']}
                for u in state['units']:
                    if u['side'] == 'ally':
                        self.assertEqual(u['mp'], templates[u['id']]['mp'] + bonus)
                        self.assertEqual(u['maxMp'], u['mp'])
                self.assertEqual(next(u['pos'] for u in state['units'] if u['id'] == 'scout'), 14)
                initial = self.snapshot()
                self.action('deploy', 'scout', 0)
                self.action('deploy', 'scout', 22)
                positions = {u['id']: u['pos'] for u in self.data['state']['units']}
                self.assertEqual((positions['scout'], positions['porter']), (22, 0))
                self.assertEqual(resources(self.data['state']['units']), resources(state['units']))
                self.assertEqual(self.data['journey']['hours'], 4)
                for uid, pos in [('scout', 25), ('scout', -1), ('scout', 2.5), (enemies[0]['id'], 1)]:
                    self.reject_unchanged('deploy', uid, pos)
                self.action('deployment_reset')
                self.assertEqual(self.snapshot(), initial)
                rejected = self.bridge.call(op='act', kind='guard')
                self.assertFalse(rejected['ok'])
                self.assertEqual(rejected['state'], initial['state'])
                self.action('begin')
                self.assertEqual(self.data['journey']['phase'], 'battle')
                self.assertFalse(self.data['state']['deploying'])
                self.assertIsNotNone(self.data['state']['actor'])
                self.assertTrue(all('intent' in u for u in self.data['state']['units'] if u['side'] == 'enemy'))
                self.reject_unchanged('begin')
                self.reject_unchanged('deployment_reset')
                self.reject_unchanged('deploy', 'scout', 0)

    def run_delivery(self, job, rest, kit='medicine', route='short'):
        self.prepare(job, kit=kit)
        counts = []
        for leg in range(2):
            prior_party = self.data['journey']['party']
            prior_potions = self.data['journey']['potions']
            self.action('forecast', route)
            self.action('travel', route)
            self.assertEqual(len([u for u in self.data['state']['units'] if u['side'] == 'enemy']), leg + (3 if route == 'short' else 2))
            self.assertEqual(self.data['state']['potions'], {'ally': prior_potions, 'enemy': leg})
            if prior_party is not None:
                self.assertEqual(resources(self.data['state']['units']), resources(prior_party))
            self.action('begin')
            result = self.play_battle()
            counts.append(result['actions'])
            self.assertTrue(all(u['hp'] <= 0 for u in self.data['state']['units'] if u['side'] == 'enemy'), result['result'])
            self.assertNotIn('failure', self.data['state'])
            terminal = self.data['state']
            before_hours = self.data['journey']['hours']
            self.action('finish')
            self.assertEqual(self.data['journey']['hours'], before_hours + 1)
            self.assertEqual(self.data['journey']['stage'], leg + 1)
            self.assertEqual(resources(self.data['journey']['party']), resources(terminal['units']))
            self.assertEqual(self.data['journey']['potions'], terminal['potions']['ally'])
            self.reject_unchanged('finish')
            if leg == 0:
                self.assertEqual(self.data['journey']['phase'], 'camp')
                if rest:
                    before = resources(self.data['journey']['party'])
                    self.action('rest')
                    for previous, after in zip(before, resources(self.data['journey']['party'])):
                        self.assertEqual(after['hp'], min(previous['max'], previous['hp'] + 60))
                        self.assertEqual(after['mp'], min(previous['maxMp'], previous['mp'] + 2))
                    self.reject_unchanged('rest')
                self.action('onward')
        self.assertEqual(self.data['journey']['phase'], 'delivery')
        self.action('deliver')
        j = self.data['journey']
        expected_hours = (6 if route == 'short' else 10) + (2 if rest else 0)
        late = expected_hours > j['job']['deadline']
        self.assertEqual(j['hours'], expected_hours)
        self.assertEqual(j['outcome'], 'late' if late else 'success')
        self.assertEqual(j['gold'], int(j['job']['reward'] * (.65 if late else 1)))
        self.assertEqual(j['xp'], 60 if late else 100)
        self.assertEqual(j['level'], 1 if late else 2)
        self.assertFalse(j.get('completionSeen', False))
        self.reject_unchanged('deliver')
        self.action('rewards')
        self.assertTrue(self.data['journey']['completionSeen'])
        print(f'Journey adapter: {job}, rest={rest}, kit={kit}, route={route}, actions={counts}, outcome={j["outcome"]}')

    def test_safe_routes_ether_carryover_and_exact_deadline(self):
        self.run_delivery('parts', False, kit='ether', route='safe')
        self.assertEqual(self.data['journey']['hours'], self.data['journey']['job']['deadline'])
        self.assertEqual(self.data['journey']['outcome'], 'success')
        self.assertTrue(all(u['maxMp'] == next(t['mp'] for t in self.data['roster'] if t['id'] == u['id']) + 2
                            for u in self.data['journey']['party']))

    def test_complete_deliveries_resources_rewards_and_retry(self):
        for job in ('parts', 'medicine'):
            for rest in (False, True):
                with self.subTest(job=job, rest=rest):
                    # A fresh seeded real bridge makes each case reproducible.
                    self.bridge.close()
                    self.bridge = Session()
                    self.data = self.bridge.call(op='journey_start')
                    self.run_delivery(job, rest)
                    exported = self.bridge.call(op='export')['data']
                    self.assertEqual(exported['mode'], 'journey')
                    self.assertEqual(exported['schemaVersion'], 1)
                    self.assertEqual(exported['current']['journey']['outcome'], self.data['journey']['outcome'])
                    self.assertTrue(any(e['type'] == 'journey.deliver' for e in exported['events']))
                    self.assertEqual(exported['events'][-1]['type'], 'log.export.requested')
                    old_run = exported['run']
                    self.data = self.bridge.call(op='journey_start')
                    self.assertEqual(self.data['journey']['phase'], 'jobs')
                    self.assertEqual(self.data['journey']['gold'], 0)
                    self.assertIsNone(self.data['state'])
                    restarted = self.bridge.call(op='export')['data']
                    self.assertEqual(restarted['run'], old_run + 1)
                    self.assertTrue(any(e['run'] == old_run for e in restarted['events']))
                    self.assertIsNone(restarted['current']['battle'])

    def test_export_retains_snapshots_and_rejected_actions(self):
        self.prepare()
        self.action('travel', 'short')
        before = self.bridge.call(op='export')['data']
        original_positions = {u['id']: u['pos'] for u in before['current']['battle']['units']}
        self.action('deploy', 'scout', 0)
        self.reject_unchanged('deploy', 'scout', 25)
        exported = self.bridge.call(op='export')['data']
        self.assertEqual(exported['mode'], 'journey')
        self.assertEqual(exported['schemaVersion'], 1)
        self.assertEqual(original_positions['scout'], 4)
        self.assertEqual(next(u['pos'] for u in exported['current']['battle']['units'] if u['id'] == 'scout'), 0)
        self.assertTrue(any(e['type'] == 'journey.deploy' and not e['details']['accepted'] for e in exported['events']))
        self.assertEqual([e['sequence'] for e in exported['events']], list(range(1, exported['retention']['lastSequence'] + 1)))

    def test_standalone_reset_changes_export_mode(self):
        self.prepare()
        self.bridge.call(op='reset')
        exported = self.bridge.call(op='export')['data']
        self.assertEqual(exported['mode'], 'battle')
        self.assertIsNone(exported['current']['journey'])
        self.assertEqual(exported['current']['battle']['actions'], 0)


if __name__ == '__main__':
    unittest.main(verbosity=2)
