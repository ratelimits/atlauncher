#!/usr/bin/env python3
"""Repair the developer installer's legacy role for ATLauncher's QML service.
Run as root on the TV. Keeps the installer manifest and existing permissions;
adds an app-id role matching the ApplicationClient used by WebOSServices.Service.
"""
import datetime
import json
import os
from pathlib import Path
import shutil
import subprocess

APP_ID = 'com.ratelimits.atlauncher'
BASE = Path('/var/luna-service2-dev')


def configuration(manifest, permissions, base=BASE):
    role_path = base / 'roles.d' / (APP_ID + '.app.json')
    name = APP_ID + '-*'
    role = {'appId': APP_ID, 'type': 'regular', 'allowedNames': [name],
            'permissions': [{'service': name, 'outbound': ['*']}]}
    updated = dict(manifest)
    updated['roleFiles'] = list(dict.fromkeys(manifest.get('roleFiles', []) + [str(role_path)]))
    clients = dict(permissions)
    # Public API access suffices for the normal app launch API. Do not elevate the app.
    clients[name] = list(dict.fromkeys(clients.get(name, []) + ['public']))
    return role, updated, clients


def bus(method, path):
    master, slave = os.openpty()
    try:
        result = subprocess.run(['luna-send', '-n', '1',
                                 'luna://com.webos.service.bus/' + method,
                                 json.dumps({'path': str(path), 'prefix': ''})],
                                stdin=slave, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                timeout=15, check=True, text=True)
        reply = json.loads(result.stdout)
        if not reply.get('returnValue'):
            raise RuntimeError(result.stdout)
        return reply
    finally:
        os.close(master)
        os.close(slave)


def main():
    manifest_path = BASE / 'manifests.d' / (APP_ID + '.json')
    client_path = BASE / 'client-permissions.d' / (APP_ID + '.app.json')
    role_path = BASE / 'roles.d' / (APP_ID + '.app.json')
    manifest = json.loads(manifest_path.read_text())
    permissions = json.loads(client_path.read_text())
    role, updated, clients = configuration(manifest, permissions)
    backup = Path('/var/lib/atlauncher/backups') / ('qml-permissions-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))
    backup.mkdir(parents=True)
    paths = [role_path, manifest_path, client_path]
    existed = {path: path.exists() for path in paths}
    for path in paths:
        if existed[path]:
            shutil.copy2(path, backup / (path.parent.name + "-" + path.name))
    # Unload before changing the files: the hub reads the old manifest to remove it.
    bus('removeOneManifest', manifest_path)
    try:
        for path, value in [(role_path, role), (client_path, clients), (manifest_path, updated)]:
            path.write_text(json.dumps(value, indent=2) + '\n')
        bus('addOneManifest', manifest_path)
    except Exception:
        for path in paths:
            if existed[path]:
                shutil.copy2(backup / (path.parent.name + "-" + path.name), path)
            elif path.exists():
                path.unlink()
        bus('addOneManifest', manifest_path)
        raise
    print('QML application role loaded. Backup: ' + str(backup))


if __name__ == '__main__':
    main()
