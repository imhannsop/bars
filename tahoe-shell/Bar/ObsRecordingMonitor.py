import base64
import hashlib
import json
import math
import os
import secrets
import socket
import struct
import sys
import time
from pathlib import Path


def config_path():
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    return config_home / "obs-studio/plugin_config/obs-websocket/config.json"


def load_config():
    try:
        with config_path().open(encoding="utf-8") as config_file:
            return json.load(config_file)
    except (OSError, json.JSONDecodeError):
        return None


def receive_exact(connection, count):
    data = bytearray()
    while len(data) < count:
        part = connection.recv(count - len(data))
        if not part:
            raise ConnectionError("OBS WebSocket closed")
        data.extend(part)
    return bytes(data)


def send_frame(connection, opcode, payload):
    payload = payload.encode("utf-8") if isinstance(payload, str) else payload
    mask = secrets.token_bytes(4)
    length = len(payload)
    header = bytearray([0x80 | opcode])
    if length < 126:
        header.append(0x80 | length)
    elif length <= 0xFFFF:
        header.append(0x80 | 126)
        header.extend(struct.pack("!H", length))
    else:
        header.append(0x80 | 127)
        header.extend(struct.pack("!Q", length))
    header.extend(mask)
    masked_payload = bytes(value ^ mask[index % 4] for index, value in enumerate(payload))
    connection.sendall(header + masked_payload)


def receive_frame(connection):
    while True:
        first, second = receive_exact(connection, 2)
        opcode = first & 0x0F
        length = second & 0x7F
        if length == 126:
            length = struct.unpack("!H", receive_exact(connection, 2))[0]
        elif length == 127:
            length = struct.unpack("!Q", receive_exact(connection, 8))[0]
        if length > 16 * 1024 * 1024:
            raise ValueError("OBS WebSocket frame is too large")
        mask = receive_exact(connection, 4) if second & 0x80 else None
        payload = receive_exact(connection, length)
        if mask:
            payload = bytes(value ^ mask[index % 4] for index, value in enumerate(payload))
        if opcode == 0x9:
            send_frame(connection, 0xA, payload)
            continue
        if opcode == 0x8:
            raise ConnectionError("OBS WebSocket closed")
        if opcode == 0x1:
            return json.loads(payload.decode("utf-8"))


def emit(event, active, paused=False):
    print(json.dumps({"event": event, "active": active, "paused": paused}), flush=True)


def emit_audio(level):
    print(json.dumps({"event": "audio", "level": level}), flush=True)


def recording_audio_level(event_data):
    level = 0.0
    for source in event_data.get("inputs", []):
        for channel in source.get("inputLevelsMul", []):
            if len(channel) > 1:
                magnitude = channel[1]
                if isinstance(magnitude, (int, float)) and math.isfinite(magnitude):
                    level = max(level, min(1.0, max(0.0, magnitude)))
    return level


def connect(config, action=None):
    port = int(config.get("server_port", 4455))
    with socket.create_connection(("127.0.0.1", port), timeout=3) as connection:
        connection.settimeout(None)
        key = base64.b64encode(secrets.token_bytes(16)).decode("ascii")
        request = (
            "GET / HTTP/1.1\r\n"
            f"Host: 127.0.0.1:{port}\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            "Sec-WebSocket-Version: 13\r\n\r\n"
        )
        connection.sendall(request.encode("ascii"))
        response = bytearray()
        while not response.endswith(b"\r\n\r\n"):
            response.extend(receive_exact(connection, 1))
            if len(response) > 16384:
                raise ConnectionError("Invalid OBS WebSocket handshake")
        headers = response.decode("latin-1").split("\r\n")
        expected_accept = base64.b64encode(
            hashlib.sha1((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode("ascii")).digest()
        ).decode("ascii")
        if "101" not in headers[0] or not any(
            line.lower() == f"sec-websocket-accept: {expected_accept}".lower()
            for line in headers[1:]
        ):
            raise ConnectionError("OBS WebSocket handshake was rejected")

        hello = receive_frame(connection)
        if hello.get("op") != 0:
            raise ConnectionError("OBS WebSocket did not send a Hello message")

        hello_data = hello.get("d", {})
        auth = None
        auth_data = hello_data.get("authentication")
        if auth_data:
            password = str(config.get("server_password", ""))
            if not password:
                raise ConnectionError("OBS WebSocket authentication needs a password in OBS settings")
            secret = base64.b64encode(
                hashlib.sha256((password + auth_data["salt"]).encode("utf-8")).digest()
            ).decode("ascii")
            auth = base64.b64encode(
                hashlib.sha256((secret + auth_data["challenge"]).encode("utf-8")).digest()
            ).decode("ascii")

        subscriptions = 64 if action else 64 | 65536
        identify = {"rpcVersion": 1, "eventSubscriptions": subscriptions}
        if auth:
            identify["authentication"] = auth
        send_frame(connection, 0x1, json.dumps({"op": 1, "d": identify}))

        initialized = False
        requested = False
        last_active = None
        last_paused = None
        last_audio_emit = 0.0
        while True:
            message = receive_frame(connection)
            opcode = message.get("op")
            data = message.get("d", {})
            if opcode == 2 and not requested:
                request_type = action or "GetRecordStatus"
                request_id = f"quickshell-obs-{request_type.lower()}"
                send_frame(
                    connection,
                    0x1,
                    json.dumps({
                        "op": 6,
                        "d": {
                            "requestType": request_type,
                            "requestId": request_id,
                        },
                    }),
                )
                requested = True
            elif opcode == 5 and data.get("eventType") == "RecordStateChanged":
                event_data = data.get("eventData", {})
                active = bool(event_data.get("outputActive"))
                paused = bool(event_data.get("outputPaused"))
                if initialized and (active != last_active or paused != last_paused):
                    emit("recording", active, paused)
                last_active = active
                last_paused = paused
            elif opcode == 5 and data.get("eventType") == "InputVolumeMeters":
                if initialized and last_active and not last_paused:
                    now = time.monotonic()
                    if now - last_audio_emit >= 1 / 30:
                        emit_audio(recording_audio_level(data.get("eventData", {})))
                        last_audio_emit = now
            elif (
                opcode == 7
                and data.get("requestId") == (
                    f"quickshell-obs-{(action or 'GetRecordStatus').lower()}"
                )
            ):
                if action:
                    if not data.get("requestStatus", {}).get("result"):
                        comment = data.get("requestStatus", {}).get("comment", f"OBS rejected {action}")
                        raise ConnectionError(str(comment))
                    return
                if not data.get("requestStatus", {}).get("result"):
                    raise ConnectionError(data.get("requestStatus", {}).get("comment", "OBS rejected GetRecordStatus"))
                active = bool(data.get("responseData", {}).get("outputActive"))
                paused = bool(data.get("responseData", {}).get("outputPaused"))
                if not initialized:
                    emit("state", active, paused)
                    initialized = True
                elif active != last_active or paused != last_paused:
                    emit("recording", active, paused)
                last_active = active
                last_paused = paused


def main():
    action_types = {
        "--stop": "StopRecord",
        "--pause": "PauseRecord",
        "--resume": "ResumeRecord",
    }
    action = action_types.get(sys.argv[1]) if len(sys.argv) > 1 else None
    if action:
        config = load_config()
        if not config or not config.get("server_enabled", False):
            print("OBS WebSocket server is not enabled", file=sys.stderr, flush=True)
            return 1
        try:
            connect(config, action=action)
            return 0
        except (ConnectionError, OSError, ValueError, KeyError, json.JSONDecodeError) as error:
            print(f"Unable to {action.lower()} on OBS: {error}", file=sys.stderr, flush=True)
            return 1

    last_error = None
    while True:
        config = load_config()
        if not config or not config.get("server_enabled", False):
            time.sleep(3)
            continue
        try:
            connect(config)
            last_error = None
        except (ConnectionError, OSError, ValueError, KeyError, json.JSONDecodeError) as error:
            message = str(error)
            if message != last_error:
                print(f"OBS recording monitor: {message}", file=sys.stderr, flush=True)
                last_error = message
            time.sleep(3)
    return 0


if __name__ == "__main__":
    sys.exit(main())
