#!/usr/bin/env python3
"""Launch the FastAPI backend and Flutter frontend together."""

from __future__ import annotations

import argparse
import json
import os
import shlex
import signal
import subprocess
import sys
import threading
import time
from pathlib import Path
import shutil
from typing import Any

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_API_BASE = "http://127.0.0.1:8000/api"
DEFAULT_BACKEND_CMD = "python -m uvicorn app.main:app --reload"
DEFAULT_FRONTEND_CMD = "flutter run {device_flag} --dart-define API_BASE_URL={api_base_url}"
DEFAULT_DEVICE_TIMEOUT = 120
DEFAULT_DEVICE_POLL_INTERVAL = 3.0
DEVICE_WAIT_STATUS_INTERVAL = 15.0
EMULATOR_LAUNCH_GRACE_SECONDS = 30
EMULATOR_BINARY_NAMES = ("emulator.exe", "emulator")


def resolve_emulator_binary() -> Path | None:
    paths: list[Path] = []

    env_path = os.environ.get("ANDROID_EMULATOR_PATH")
    if env_path:
        paths.append(Path(env_path))

    which_path = shutil.which("emulator")
    if which_path:
        paths.append(Path(which_path))

    sdk_roots: list[Path] = []
    for var in ("ANDROID_SDK_ROOT", "ANDROID_HOME"):
        value = os.environ.get(var)
        if value:
            sdk_roots.append(Path(value))

    if os.name == "nt":
        local_app_data = os.environ.get("LOCALAPPDATA")
        if local_app_data:
            sdk_roots.append(Path(local_app_data) / "Android" / "Sdk")
        sdk_roots.append(Path.home() / "AppData" / "Local" / "Android" / "Sdk")
    else:
        sdk_roots.append(Path.home() / "Android" / "Sdk")
    sdk_roots.append(Path.home() / "Android" / "sdk")

    for root in sdk_roots:
        for name in EMULATOR_BINARY_NAMES:
            paths.append(root / "emulator" / name)

    for candidate in paths:
        if candidate.is_file():
            return candidate
    return None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Launch backend and frontend processes with coordinated shutdown.",
    )
    parser.add_argument(
        "--api-base-url",
        default=DEFAULT_API_BASE,
        help="API base URL injected into the frontend command (default: %(default)s).",
    )
    parser.add_argument(
        "--backend-cmd",
        default=DEFAULT_BACKEND_CMD,
        help="Command used to start the backend. Supports {api_base_url} placeholder.",
    )
    parser.add_argument(
        "--frontend-cmd",
        default=DEFAULT_FRONTEND_CMD,
        help="Command used to start the frontend. Supports {api_base_url}, {device_flag}, {device_id} placeholders.",
    )
    parser.add_argument(
        "--skip-backend",
        action="store_true",
        help="Skip launching the backend process.",
    )
    parser.add_argument(
        "--skip-frontend",
        action="store_true",
        help="Skip launching the frontend process.",
    )
    parser.add_argument(
        "--emulator-id",
        help="Launch the specified Flutter emulator before starting other processes.",
    )
    parser.add_argument(
        "--require-android-device",
        action="store_true",
        help="Wait for an Android device to appear before starting backend/frontend.",
    )
    parser.add_argument(
        "--device-timeout",
        type=int,
        default=DEFAULT_DEVICE_TIMEOUT,
        help="Seconds to wait for an Android device (default: %(default)s).",
    )
    parser.add_argument(
        "--device-poll-interval",
        type=float,
        default=DEFAULT_DEVICE_POLL_INTERVAL,
        help="Polling interval while waiting for an Android device (default: %(default)s).",
    )
    return parser.parse_args()


def split_command(command: str) -> list[str]:
    if not command.strip():
        raise ValueError("Command string cannot be empty.")
    return shlex.split(command, posix=os.name != "nt")


def stream_output(process: subprocess.Popen[str], name: str) -> None:
    assert process.stdout is not None
    for line in process.stdout:
        print(f"[{name}] {line}", end="")


def start_process(name: str, command: list[str], cwd: Path, env: dict[str, str]) -> subprocess.Popen[str]:
    resolved = shutil.which(command[0])
    if resolved is None:
        raise RuntimeError(f"Required executable '{command[0]}' not found in PATH for {name}.")

    use_shell = False
    popen_args: object = command
    if os.name == "nt" and os.path.splitext(resolved)[1].lower() in {".bat", ".cmd"}:
        use_shell = True
        popen_args = subprocess.list2cmdline(command)

    printable_cmd = popen_args if isinstance(popen_args, str) else ' '.join(command)
    print(f"Starting {name}: {printable_cmd} (cwd={cwd})")
    creationflags = getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0)
    process = subprocess.Popen(
        popen_args,
        cwd=str(cwd),
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        stdin=None,
        text=True,
        bufsize=1,
        creationflags=creationflags,
        shell=use_shell,
        encoding="utf-8",
        errors="replace",
    )
    threading.Thread(target=stream_output, args=(process, name), daemon=True).start()
    return process


def run_command_with_shell(command: list[str], cwd: Path, *, capture_output: bool = False) -> subprocess.CompletedProcess[str]:
    resolved = shutil.which(command[0])
    if resolved is None:
        raise RuntimeError(f"Required executable '{command[0]}' not found in PATH.")

    use_shell = False
    popen_args: object = command
    if os.name == "nt" and os.path.splitext(resolved)[1].lower() in {".bat", ".cmd"}:
        use_shell = True
        popen_args = subprocess.list2cmdline(command)

    return subprocess.run(
        popen_args,
        cwd=str(cwd),
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=capture_output,
        shell=use_shell,
        check=False,
    )


def terminate_process(name: str, process: subprocess.Popen[str]) -> None:
    if process.poll() is not None:
        return

    print(f"Stopping {name}...")
    try:
        if os.name == "nt":
            process.send_signal(signal.CTRL_BREAK_EVENT)
        else:
            process.terminate()
        process.wait(timeout=10)
    except (ProcessLookupError, PermissionError):
        return
    except subprocess.TimeoutExpired:
        print(f"{name} did not stop in time; killing.")
        process.kill()


def launch_emulator(emulator_id: str, frontend_dir: Path) -> None:
    flutter_launch_error: str | None = None
    if shutil.which("flutter") is not None:
        cmd = ["flutter", "emulators", "--launch", emulator_id]
        print(f"Launching emulator '{emulator_id}' with Flutter...")
        env = os.environ.copy()
        process = start_process("flutter-emulator", cmd, frontend_dir, env)
        try:
            exit_code = process.wait(timeout=EMULATOR_LAUNCH_GRACE_SECONDS)
        except subprocess.TimeoutExpired:
            print(
                "Flutter launch command is still running; continuing while waiting for the device to appear."
            )
            return
        if exit_code == 0:
            print("Flutter launch command completed; emulator may continue booting in the background.")
            return
        flutter_launch_error = f"flutter emulators exited with code {exit_code}"
        print(f"Flutter launch failed: {flutter_launch_error}")

    emulator_binary = resolve_emulator_binary()
    if emulator_binary is None:
        if flutter_launch_error:
            raise RuntimeError(
                "Failed to launch emulator via Flutter and unable to locate the Android emulator executable.\n"
                f"Flutter error: {flutter_launch_error}"
            )
        raise RuntimeError(
            "Unable to locate the Android emulator executable. Ensure ANDROID_SDK_ROOT or ANDROID_HOME is set."
        )

    print(f"Launching emulator '{emulator_id}' using {emulator_binary}...")
    env = os.environ.copy()
    process = start_process(
        "emulator",
        [str(emulator_binary), "-avd", emulator_id],
        emulator_binary.parent,
        env,
    )
    time.sleep(min(EMULATOR_LAUNCH_GRACE_SECONDS, 5))
    exit_code = process.poll()
    if exit_code is not None and exit_code != 0:
        raise RuntimeError(f"Android emulator process exited early with code {exit_code}.")
    print("Android emulator process is running; continuing while waiting for the device to appear.")


def list_android_devices(frontend_dir: Path) -> list[dict[str, Any]]:
    cmd = ["flutter", "devices", "--machine"]
    result = run_command_with_shell(cmd, frontend_dir, capture_output=True)
    if result.returncode != 0:
        raise RuntimeError(
            "'flutter devices' failed with code "
            f"{result.returncode}: {result.stderr.strip()}"
        )
    try:
        devices = json.loads(result.stdout or "[]")
    except json.JSONDecodeError as exc:
        raise RuntimeError(
            "Unable to parse output from 'flutter devices --machine'."
        ) from exc
    return devices if isinstance(devices, list) else []


def wait_for_android_device(frontend_dir: Path, timeout: int, poll_interval: float) -> dict[str, Any]:
    deadline = time.time() + timeout
    attempts = 0
    last_log = 0.0
    while True:
        attempts += 1
        devices = list_android_devices(frontend_dir)
        for device in devices:
            platform = device.get("platformType") or device.get("targetPlatform")
            if platform and "android" in platform.lower() and device.get("isSupported", True):
                return device
        now = time.time()
        remaining = max(0, int(deadline - now))
        if attempts == 1 or now - last_log >= DEVICE_WAIT_STATUS_INTERVAL:
            last_log = now
            detected = ", ".join(
                f"{dev.get('name', 'unknown')} ({dev.get('id') or dev.get('deviceId') or dev.get('identifier') or '?'})"
                for dev in devices
            ) or "none detected"
            print(
                "Waiting for Android device... "
                f"attempt {attempts}, {remaining}s remaining. Detected: {detected}"
            )
        if now >= deadline:
            raise TimeoutError("Timed out waiting for an Android device to become available.")
        time.sleep(poll_interval)


def main() -> int:
    args = parse_args()

    backend_dir = PROJECT_ROOT / "backend"
    frontend_dir = PROJECT_ROOT / "frontend"

    device_id: str | None = None

    if not backend_dir.exists() and not args.skip_backend:
        print(f"Backend directory not found: {backend_dir}", file=sys.stderr)
        return 1
    if not frontend_dir.exists() and not args.skip_frontend:
        print(f"Frontend directory not found: {frontend_dir}", file=sys.stderr)
        return 1

    need_device = (not args.skip_frontend) and (args.require_android_device or bool(args.emulator_id))
    if need_device and shutil.which("flutter") is None:
        print("flutter command not found in PATH. Install Flutter SDK or adjust PATH before continuing.", file=sys.stderr)
        return 1

    if need_device:
        try:
            if args.emulator_id:
                launch_emulator(args.emulator_id, frontend_dir)
            device = wait_for_android_device(frontend_dir, args.device_timeout, args.device_poll_interval)
        except TimeoutError as exc:
            print(str(exc), file=sys.stderr)
            return 1
        except RuntimeError as exc:
            print(str(exc), file=sys.stderr)
            return 1
        else:
            raw_device_id = device.get("id") or device.get("deviceId") or device.get("identifier")
            device_id = str(raw_device_id) if raw_device_id else None
            device_name = device.get("name", "unknown")
            device_label = device_id or "unknown"
            print(f"Android device ready: {device_name} ({device_label})")

    processes: list[tuple[str, subprocess.Popen[str]]] = []

    try:
        if not args.skip_backend:
            backend_cmd = split_command(args.backend_cmd.format(api_base_url=args.api_base_url))
            backend_env = os.environ.copy()
            backend_process = start_process("backend", backend_cmd, backend_dir, backend_env)
            processes.append(("backend", backend_process))

        if not args.skip_frontend:
            placeholders = {"api_base_url": args.api_base_url, "device_id": device_id or "", "device_flag": f"-d {device_id}" if device_id else ""}
            try:
                frontend_cmd_str = args.frontend_cmd.format(**placeholders)
            except KeyError as exc:
                print(f"Unknown placeholder {{{exc.args[0]}}} in --frontend-cmd.", file=sys.stderr)
                return 1
            frontend_cmd = split_command(frontend_cmd_str)
            frontend_env = os.environ.copy()
            frontend_env.setdefault("API_BASE_URL", args.api_base_url)
            if device_id:
                frontend_env.setdefault("FLUTTER_DEVICE_ID", device_id)
            frontend_process = start_process("frontend", frontend_cmd, frontend_dir, frontend_env)
            processes.append(("frontend", frontend_process))

        exit_code = 0
        while processes:
            for index in range(len(processes) - 1, -1, -1):
                name, process = processes[index]
                return_code = process.poll()
                if return_code is not None:
                    print(f"{name} exited with code {return_code}.")
                    processes.pop(index)
                    if exit_code == 0:
                        exit_code = return_code
            time.sleep(0.5)
        return exit_code
    except KeyboardInterrupt:
        print("\nInterrupted by user. Shutting down...")
        return 0
    finally:
        for name, process in processes:
            terminate_process(name, process)


if __name__ == "__main__":
    sys.exit(main())

