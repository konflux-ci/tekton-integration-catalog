#!/usr/bin/env python3
"""Exercise the real inline selection task without provisioning cloud resources."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

import yaml

PIPELINE = Path(__file__).resolve().parents[1] / 'deploy-fbc-operator.yaml'


class ReleaseSelection(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pipeline = yaml.safe_load(PIPELINE.read_text())
        cls.task = next(t for t in cls.pipeline['spec']['tasks'] if t['name'] == 'select-cluster-release')
        cls.script = cls.task['taskSpec']['steps'][0]['script']

    def select(self, target='5.0', channel='stable', version=''):
        with tempfile.TemporaryDirectory() as tmp:
            result = Path(tmp) / 'release.json'
            env = dict(os.environ, TARGET_OCP_VERSION=target,
                       CLUSTER_RELEASE_CHANNEL=channel, CLUSTER_RELEASE_VERSION=version)
            run = subprocess.run(['bash', '-c', self.script.replace('$(results.releases.path)', str(result))],
                                 env=env, capture_output=True, text=True)
            return run, json.loads(result.read_text()) if result.exists() else None

    def test_unchanged_stable_default(self):
        run, data = self.select()
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertEqual(data, {'latest': {'release': {'channel': 'stable', 'version': '5.0', 'architecture': 'multi'}}})

    def test_exact_ga(self):
        run, data = self.select(channel='candidate', version='5.0.0')
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertEqual(data['latest']['release'], {'channel': 'candidate', 'version': '5.0.0', 'architecture': 'multi'})

    def test_existing_four_series(self):
        run, data = self.select(target='4.22', channel='fast', version='4.22.1')
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertEqual(data['latest']['release']['version'], '4.22.1')

    def test_explicit_prerelease(self):
        run, data = self.select(channel='candidate', version='5.0.0-rc.7')
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertEqual(data['latest']['release']['version'], '5.0.0-rc.7')

    def test_invalid_inputs_cannot_provision(self):
        cases = [
            {'channel': ''}, {'channel': 'candidate-5.0'}, {'channel': 'stable\"},\"injected\":true'},
            {'target': ''}, {'target': '5.0.0'},
            {'version': '4.22.1'}, {'version': '5.1.0'}, {'version': '5.0'},
            {'version': '5.0.0\"}'}, {'version': '5.0.0-rc..7'},
            {'version': '$(touch /tmp/ocp5-release-must-not-run)'},
        ]
        for args in cases:
            with self.subTest(args=args):
                run, data = self.select(**args)
                self.assertNotEqual(run.returncode, 0)
                self.assertIsNone(data)

    def test_provision_consumes_validated_json(self):
        provision = next(t for t in self.pipeline['spec']['tasks'] if t['name'] == 'provision-cluster')
        self.assertEqual(provision['runAfter'], ['select-cluster-release'])
        self.assertEqual(next(p['value'] for p in provision['params'] if p['name'] == 'releases'),
                         '$(tasks.select-cluster-release.results.releases)')
        self.assertTrue(any(w['input'] == '$(tasks.parse-metadata.results.test-event-type)' and
                            w['values'] == ['push', 'Push'] for w in self.task['when']))
        self.assertEqual(next(p['value'] for p in provision['taskRef']['params'] if p['name'] == 'revision'),
                         'ec115dd419bc7c675cb8d9d5b320df33c2c79274')


if __name__ == '__main__':
    unittest.main(verbosity=2)
