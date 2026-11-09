import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('repair', Path(__file__).resolve().parents[1] / 'scripts/setup-qml-permissions.py')
repair = importlib.util.module_from_spec(spec)
spec.loader.exec_module(repair)


class PermissionsTest(unittest.TestCase):
    def test_add_qml_role_preserving_installer_configuration(self):
        manifest = {'id': repair.APP_ID, 'version': '1.0.1',
                    'roleFilesPrv': ['legacy-private'], 'roleFilesPub': ['legacy-public'],
                    'clientPermissionFiles': ['existing-clients']}
        permissions = {repair.APP_ID: ['public']}
        role, updated, clients = repair.configuration(manifest, permissions)
        self.assertEqual(role['appId'], repair.APP_ID)
        self.assertEqual(role['type'], 'regular')
        self.assertEqual(role['allowedNames'], [repair.APP_ID + '-*'])
        self.assertEqual(clients[repair.APP_ID + '-*'], ['public'])
        for key, value in manifest.items():
            self.assertEqual(updated[key], value)
        self.assertEqual(permissions, {repair.APP_ID: ['public']})
        self.assertEqual(repair.configuration(updated, clients), (role, updated, clients))


if __name__ == '__main__':
    unittest.main()
