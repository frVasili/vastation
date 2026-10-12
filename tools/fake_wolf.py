#!/usr/bin/env python3
"""Threaded stdlib fake; --record writes JSONL requests. /control is test-only."""
import argparse
import json
import os
import socketserver
import threading
import time


class State:
    def __init__(self, record):
        self.record = record
        self.lock = threading.RLock()
        self.lobbies = {}
        self.images = set()
        self.listeners = []
        self.counter = 0

    def event(self, kind, data):
        packet = ('event: wolf::core::events::' + kind + '\ndata: ' + json.dumps(data) + '\n\n').encode()
        for listener in self.listeners[:]:
            try:
                listener.sendall(packet)
            except OSError:
                self.listeners.remove(listener)


class Handler(socketserver.StreamRequestHandler):
    def handle(self):
        try:
            self.handle_request()
        except (BrokenPipeError, ConnectionResetError):
            pass

    def handle_request(self):
        from urllib.parse import urlsplit, parse_qs
        first = self.rfile.readline().decode().split()
        if len(first) != 3:
            return
        method, target, version = first
        headers = {}
        while True:
            line = self.rfile.readline().decode().strip()
            if not line:
                break
            key, value = line.split(':', 1)
            headers[key.lower()] = value.strip()
        body = json.loads(self.rfile.read(int(headers['content-length']))) if int(headers.get('content-length', 0)) else {}
        path = urlsplit(target).path.removeprefix('/api/v1')
        state = self.server.state
        with state.lock:
            if state.record:
                with open(state.record, 'a') as output:
                    output.write(json.dumps({'method': method, 'path': path, 'body': body}) + '\n')
        if path == '/events':
            self.connection.sendall(b'HTTP/1.0 200 OK\r\nContent-Type: text/event-stream\r\n\r\n')
            state.listeners.append(self.connection)
            try:
                while True:
                    self.connection.sendall(b':keepalive\n\n')
                    time.sleep(1)
            except OSError:
                if self.connection in state.listeners:
                    state.listeners.remove(self.connection)
            return
        if path == '/docker/images/pull':
            self.connection.sendall(b'HTTP/1.0 200 OK\r\n\r\n')
            for progress in ['Pulling layers', 'Downloading', 'Extracting']:
                self.connection.sendall((json.dumps({'status': progress, 'progress': '50%'}) + '\r\n').encode())
                time.sleep(.1)
            state.images.add(body['image_name'])
            self.connection.sendall(b'{"success":true}\r\n')
            return
        result, status = {'success': True}, 200
        with state.lock:
            if path == '/sessions':
                result['sessions'] = [{'client_id': '42', 'client_ip': '100.64.0.2', 'aes_key': 'NEVER_LOG_THIS', 'aes_iv': 'NEVER_LOG_THIS', 'video_width': 1280, 'video_height': 720, 'video_refresh_rate': 60, 'audio_channel_count': 2, 'client_settings': {'run_uid': 1000, 'run_gid': 1000, 'controllers_override': [], 'mouse_acceleration': 1.0, 'v_scroll_acceleration': 1.0, 'h_scroll_acceleration': 1.0, 'motion_controller_override': 'AUTO'}}]
            elif path == '/profiles':
                result['profiles'] = [{'id': 'user', 'name': 'User', 'icon_png_path': '', 'apps': [{'title': 'Steam', 'id': '1', 'render_node': '/dev/dri/renderD128', 'runner': {'type': 'docker', 'name': 'WolfSteam', 'image': 'fake/steam:edge', 'env': ['OLD=1'], 'mounts': [], 'ports': [], 'devices': [], 'base_create_json': '{}'}}]}]
            elif path == '/lobbies':
                result['lobbies'] = list(state.lobbies.values())
            elif path == '/docker/images/inspect':
                image = parse_qs(urlsplit(target).query)['image_name'][0]
                if image not in state.images:
                    status, result = 404, {'success': False, 'error': 'Image not found'}
                else:
                    result = {'Id': 'sha256:fake'}  # Real inspect returns raw Docker JSON.
            elif path == '/lobbies/create':
                # Wolf (reflect-cpp) rejects 60.0 for an int field; be as strict as the real thing.
                for group, keys in (('video_settings', ('width', 'height', 'refresh_rate')), ('audio_settings', ('channel_count',)), ('client_settings', ('run_uid', 'run_gid'))):
                    for key in keys:
                        assert type(body[group][key]) is int, (group, key, body[group][key])
                assert body['video_settings']['refresh_rate'] == 60
                assert body['runner_state_folder'] == 'profile-data/user/WolfSteam'
                assert body['multi_user'] is False and body['stop_when_everyone_leaves'] is False
                state.counter += 1
                lobby_id = str(state.counter)
                state.lobbies[lobby_id] = {'id': lobby_id, 'name': body['name'], 'runner': body['runner'], 'connected_sessions': [], 'started_by_profile_id': body['profile_id'], 'multi_user': False, 'pin_required': False, 'stop_when_everyone_leaves': False}
                result['lobby_id'] = lobby_id
            elif path == '/lobbies/join':
                if body['lobby_id'] not in state.lobbies:
                    status, result = 400, {'success': False, 'error': 'Lobby not found'}
                else:
                    state.lobbies[body['lobby_id']]['connected_sessions'] = [body['moonlight_session_id']]
                    state.event('JoinLobbyEvent', body)
            elif path in ['/lobbies/leave', '/lobbies/stop', '/control']:
                lobby_id = body.get('lobby_id', next(iter(state.lobbies), ''))
                if path == '/lobbies/stop' or body.get('action') == 'exit':
                    state.lobbies.pop(lobby_id, None)
                    state.event('StopLobbyEvent', {'lobby_id': lobby_id})
                elif lobby_id in state.lobbies:
                    state.lobbies[lobby_id]['connected_sessions'] = []
                    state.event('LeaveLobbyEvent', {'lobby_id': lobby_id, 'moonlight_session_id': '42'})
            elif path != '/sessions/stop':
                status, result = 404, {'success': False, 'error': 'Unknown endpoint'}
        payload = json.dumps(result).encode()
        self.connection.sendall(('HTTP/1.0 %d OK\r\nContent-Length: %d\r\n\r\n' % (status, len(payload))).encode() + payload)


class Server(socketserver.ThreadingUnixStreamServer):
    daemon_threads = True


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--socket', required=True)
    parser.add_argument('--record')
    args = parser.parse_args()
    with Server(args.socket, Handler) as server:
        os.chmod(args.socket, 0o777)
        server.state = State(args.record)
        print('fake Wolf ready', flush=True)
        server.serve_forever()
