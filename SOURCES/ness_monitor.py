#!/usr/bin/env python3
"""
Ness D8x / D16x alarm monitor.

Holds one persistent TCP connection to the Ness IP232 serial-to-IP module,
decodes the ASCII protocol (Doc 338S27), logs every event to SQLite, and pushes
notifications (ntfy / Pushover / Telegram / email) for the events you care about.

Replaces the old ness-status.sh + ness-monitor.path + ness-monitor.service +
ness-monitor.sh + index/logrotate stack with a single always-on service.

Stdlib only - no pip install required. Python 3.6+.
"""

import configparser
import json
import logging
import os
import signal
import socket
import sqlite3
import sys
import threading
import time
import urllib.parse
import urllib.request
from datetime import datetime

# --------------------------------------------------------------------------- #
#  Protocol decoding
# --------------------------------------------------------------------------- #

# EVENT byte -> (human name, default priority)
#   priority: "high"  -> always push, marked urgent
#             "normal"-> push
#             "low"   -> log only, no push (unless you flip it in config)
EVENTS = {
    0x00: ("Unsealed",            "low"),
    0x01: ("Sealed",              "low"),
    0x02: ("ALARM",               "high"),
    0x03: ("Alarm Restore",       "normal"),
    0x04: ("Manual Exclude",      "low"),
    0x05: ("Manual Include",      "low"),
    0x06: ("Auto Exclude",        "low"),
    0x07: ("Auto Include",        "low"),
    0x08: ("TAMPER Unsealed",     "high"),
    0x09: ("Tamper Normal",       "normal"),
    0x10: ("Power Failure",       "high"),
    0x11: ("Power Normal",        "normal"),
    0x12: ("Battery Failure",     "high"),
    0x13: ("Battery Normal",      "normal"),
    0x14: ("Report Failure",      "high"),
    0x15: ("Report Normal",       "normal"),
    0x16: ("Supervision Failure", "high"),
    0x17: ("Supervision Normal",  "normal"),
    0x19: ("Real Time Clock",     "low"),
    0x20: ("Entry Delay Start",   "normal"),
    0x21: ("Entry Delay End",     "low"),
    0x22: ("Exit Delay Start",    "low"),
    0x23: ("Exit Delay End",      "low"),
    0x24: ("Armed Away",          "normal"),
    0x25: ("Armed Home",          "normal"),
    0x26: ("Armed Day",           "low"),
    0x27: ("Armed Night",         "low"),
    0x28: ("Armed Vacation",      "low"),
    0x2e: ("Armed Highest",       "low"),
    0x2f: ("Disarmed",            "normal"),
    0x30: ("Arming Delayed",      "normal"),
    0x31: ("Output On",           "low"),
    0x32: ("Output Off",          "low"),
}

# AREA byte -> label (when it isn't a plain area number)
AREA_LABELS = {
    0x00: None,          # no area
    0x01: "Area 1",
    0x02: "Area 2",
    0x03: "Monitor",
    0x04: "Day",
    0x80: "24hr",
    0x81: "Fire",
    0x82: "Panic",
    0x83: "Medical",
    0x84: "Duress",
    0x85: "Door",
    0x91: "Radio Detector",
    0x92: "Radio Pendant",
    0xa1: "Door 1", 0xa2: "Door 2", 0xa3: "Door 3",
}

# Output ID byte -> name (for Output On/Off events, 0x31/0x32)
OUTPUT_IDS = {
    0x90: "Siren", 0x91: "Soft Siren", 0x92: "Soft Monitor", 0x93: "Siren Fire",
    0x94: "Strobe", 0x95: "Reset", 0x96: "Sonalert", 0x97: "Keypad Display",
}

# Give your zones friendly names here (matches the DATA MSG table in your notes).
# Override / extend these in the [zones] section of the config file.
DEFAULT_ZONE_NAMES = {
    1: "Garage", 2: "Lounge", 3: "Dining", 4: "Family", 5: "Upstairs",
}


class Event:
    __slots__ = ("raw", "start", "address", "event", "id", "area",
                 "dt", "name", "priority", "description")

    def __init__(self, raw, start, address, event, id_, area, dt,
                 name, priority, description):
        self.raw = raw
        self.start = start
        self.address = address
        self.event = event
        self.id = id_
        self.area = area
        self.dt = dt
        self.name = name
        self.priority = priority
        self.description = description


def valid_frame(b: bytes) -> bool:
    """Checksum is valid when the sum of all bytes has an LSB of zero."""
    return len(b) >= 4 and (sum(b) & 0xFF) == 0


def decode(hexline: str, zone_names: dict):
    """
    Decode one ASCII event frame (START 0x87/0x86/0x83 - the event-data frames).
    Returns an Event, or None if the line isn't a decodable/valid event frame.
    Status frames (START 0x82, command 0x60) are intentionally ignored.
    """
    hexline = hexline.strip().lower()
    if len(hexline) != 28:
        return None
    try:
        b = bytes.fromhex(hexline)
    except ValueError:
        return None
    if not valid_frame(b):
        return None

    start, address = b[0], b[1]
    command = b[3]
    if command != 0x61:          # only SYSTEM STATUS event frames
        return None

    event, id_, area = b[4], b[5], b[6]
    # The 6 timestamp bytes are transmitted as DECIMAL digit-pairs (per spec:
    # "these values are in decimal format"), so read them from the ASCII text
    # rather than from the hex-decoded bytes. e.g. day "27" means 27, not 0x27.
    try:
        yy = int(hexline[14:16]); mm = int(hexline[16:18]); dd = int(hexline[18:20])
        hh = int(hexline[20:22]); mi = int(hexline[22:24]); ss = int(hexline[24:26])
        dt = datetime(2000 + yy, mm, dd, hh, mi, ss)
    except ValueError:
        dt = datetime.now()

    name, priority = EVENTS.get(event, ("Event 0x%02x" % event, "low"))
    description = build_description(event, id_, area, name, zone_names)
    return Event(hexline, start, address, event, id_, area, dt,
                 name, priority, description)


def build_description(event, id_, area, name, zone_names):
    """Turn the raw event/id/area triplet into a readable sentence."""
    # Output on/off ------------------------------------------------------- #
    if event in (0x31, 0x32):
        out = OUTPUT_IDS.get(id_, "Output 0x%02x" % id_)
        return "%s: %s" % (name, out)

    # Motion / seal on a zone -------------------------------------------- #
    if event in (0x00, 0x01) and area == 0x00 and 1 <= id_ <= 16:
        zone = zone_names.get(id_, "Zone %d" % id_)
        verb = "Movement / unsealed" if event == 0x00 else "Sealed"
        return "%s - %s" % (verb, zone)

    # Alarm / tamper / restore on a zone --------------------------------- #
    if event in (0x02, 0x03, 0x08, 0x09) and 1 <= id_ <= 16 and area in (0x01, 0x02, 0x03, 0x04):
        zone = zone_names.get(id_, "Zone %d" % id_)
        area_lbl = AREA_LABELS.get(area, "Area %d" % area)
        return "%s - %s (%s)" % (name, zone, area_lbl)

    # Keypad-originated panic/fire/medical/duress ------------------------ #
    if id_ == 0xf0:
        return "%s - Keypad %s" % (name, AREA_LABELS.get(area, "0x%02x" % area))

    # Arm / disarm by a user --------------------------------------------- #
    if event in (0x24, 0x25, 0x2f) and 1 <= id_ <= 56:
        area_lbl = AREA_LABELS.get(area, "Area %d" % area)
        return "%s - User %d (%s)" % (name, id_, area_lbl)
    if event in (0x24, 0x25, 0x2f) and id_ == 57:
        return "%s - Keyswitch" % name
    if event in (0x24, 0x25, 0x2f) and id_ == 58:
        return "%s - Short Arm" % name

    # Fallback ------------------------------------------------------------ #
    bits = [name]
    if id_ not in (0x00, 0xf0):
        bits.append("ID %d" % id_)
    area_lbl = AREA_LABELS.get(area)
    if area_lbl:
        bits.append(area_lbl)
    return " - ".join(bits)


# --------------------------------------------------------------------------- #
#  Notifiers
# --------------------------------------------------------------------------- #

def _http_post(url, data=None, headers=None, timeout=10):
    req = urllib.request.Request(url, data=data, headers=headers or {}, method="POST")
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.status


class Notifier:
    """Base class - subclasses implement send()."""
    name = "base"

    def send(self, ev: "Event", urgent: bool):
        raise NotImplementedError


class NtfyNotifier(Notifier):
    name = "ntfy"

    def __init__(self, server, topic, token=None):
        self.url = "%s/%s" % (server.rstrip("/"), topic)
        self.token = token

    def send(self, ev, urgent):
        headers = {
            "Title": "Ness Alarm: %s" % ev.name,
            "Priority": "urgent" if urgent else "default",
            "Tags": "rotating_light" if urgent else "bell",
        }
        if self.token:
            headers["Authorization"] = "Bearer %s" % self.token
        body = "%s\n%s" % (ev.description, ev.dt.strftime("%d/%m/%Y %H:%M:%S"))
        _http_post(self.url, body.encode("utf-8"), headers)


class PushoverNotifier(Notifier):
    name = "pushover"

    def __init__(self, token, user):
        self.token, self.user = token, user

    def send(self, ev, urgent):
        data = urllib.parse.urlencode({
            "token": self.token,
            "user": self.user,
            "title": "Ness Alarm: %s" % ev.name,
            "message": "%s\n%s" % (ev.description, ev.dt.strftime("%d/%m/%Y %H:%M:%S")),
            "priority": "1" if urgent else "0",
        }).encode()
        _http_post("https://api.pushover.net/1/messages.json", data)


class TelegramNotifier(Notifier):
    name = "telegram"

    def __init__(self, bot_token, chat_id):
        self.url = "https://api.telegram.org/bot%s/sendMessage" % bot_token
        self.chat_id = chat_id

    def send(self, ev, urgent):
        prefix = "\U0001F6A8 " if urgent else "\U0001F514 "
        text = "%s*Ness Alarm: %s*\n%s\n%s" % (
            prefix, ev.name, ev.description, ev.dt.strftime("%d/%m/%Y %H:%M:%S"))
        data = urllib.parse.urlencode({
            "chat_id": self.chat_id, "text": text, "parse_mode": "Markdown",
        }).encode()
        _http_post(self.url, data)


class EmailNotifier(Notifier):
    name = "email"

    def __init__(self, host, port, user, pwd, sender, recipients, use_tls=True):
        self.host, self.port = host, int(port)
        self.user, self.pwd = user, pwd
        self.sender = sender
        self.recipients = [r.strip() for r in recipients.replace(";", ",").split(",") if r.strip()]
        self.use_tls = use_tls

    def send(self, ev, urgent):
        import smtplib
        from email.message import EmailMessage
        msg = EmailMessage()
        msg["Subject"] = "ALARM - %s" % ev.name
        msg["From"] = self.sender
        msg["To"] = ", ".join(self.recipients)
        msg.set_content("%s\n%s" % (ev.description, ev.dt.strftime("%d/%m/%Y %H:%M:%S")))
        with smtplib.SMTP(self.host, self.port, timeout=15) as s:
            if self.use_tls:
                s.starttls()
            if self.user:
                s.login(self.user, self.pwd)
            s.send_message(msg)


# --------------------------------------------------------------------------- #
#  Storage
# --------------------------------------------------------------------------- #

class Store:
    """SQLite logger. Keeps the original 6-column schema for drop-in compatibility."""

    def __init__(self, path):
        self.path = path
        self._lock = threading.Lock()
        con = sqlite3.connect(self.path)
        con.execute(
            "CREATE TABLE IF NOT EXISTS events "
            "(id INTEGER PRIMARY KEY, date TEXT, time TEXT, raw TEXT, "
            " event TEXT, description TEXT)"
        )
        con.commit()
        con.close()

    def save(self, ev: "Event"):
        with self._lock:
            con = sqlite3.connect(self.path)
            con.execute(
                "INSERT INTO events(date, time, raw, event, description) "
                "VALUES (?,?,?,?,?)",
                (ev.dt.strftime("%d.%m.%y"), ev.dt.strftime("%H:%M:%S"),
                 ev.raw, "%02x" % ev.event, ev.description),
            )
            con.commit()
            con.close()


# --------------------------------------------------------------------------- #
#  Monitor
# --------------------------------------------------------------------------- #

class NessMonitor:
    def __init__(self, cfg):
        self.host = cfg.get("ness", "host")
        self.port = cfg.getint("ness", "port", fallback=2401)
        self.reconnect_min = cfg.getint("ness", "reconnect_min_seconds", fallback=2)
        self.reconnect_max = cfg.getint("ness", "reconnect_max_seconds", fallback=60)
        self.dedup_seconds = cfg.getfloat("ness", "dedup_seconds", fallback=2.0)

        # which priority levels actually push
        push_levels = cfg.get("notify", "push_levels", fallback="high,normal")
        self.push_levels = {p.strip() for p in push_levels.split(",") if p.strip()}
        self.urgent_levels = {"high"}

        self.store = None
        if cfg.getboolean("storage", "enabled", fallback=True):
            self.store = Store(cfg.get("storage", "db_path"))

        self.zone_names = dict(DEFAULT_ZONE_NAMES)
        if cfg.has_section("zones"):
            for k, v in cfg.items("zones"):
                try:
                    self.zone_names[int(k)] = v
                except ValueError:
                    pass

        self.notifiers = self._build_notifiers(cfg)
        self._recent = {}          # raw -> last-seen monotonic time (dedup)
        self._stop = threading.Event()

    def _build_notifiers(self, cfg):
        notifiers = []
        if cfg.getboolean("ntfy", "enabled", fallback=False):
            notifiers.append(NtfyNotifier(
                cfg.get("ntfy", "server", fallback="https://ntfy.sh"),
                cfg.get("ntfy", "topic"),
                cfg.get("ntfy", "token", fallback=None) or None))
        if cfg.getboolean("pushover", "enabled", fallback=False):
            notifiers.append(PushoverNotifier(
                cfg.get("pushover", "token"), cfg.get("pushover", "user")))
        if cfg.getboolean("telegram", "enabled", fallback=False):
            notifiers.append(TelegramNotifier(
                cfg.get("telegram", "bot_token"), cfg.get("telegram", "chat_id")))
        if cfg.getboolean("email", "enabled", fallback=False):
            notifiers.append(EmailNotifier(
                cfg.get("email", "smtp_host"), cfg.get("email", "smtp_port", fallback="587"),
                cfg.get("email", "username", fallback=""), cfg.get("email", "password", fallback=""),
                cfg.get("email", "from"), cfg.get("email", "recipients"),
                cfg.getboolean("email", "use_tls", fallback=True)))
        logging.info("Notifiers enabled: %s",
                     ", ".join(n.name for n in notifiers) or "(none)")
        return notifiers

    # --- event handling --------------------------------------------------- #

    def handle(self, ev: "Event"):
        # dedup identical frames the panel repeats within a short window
        now = time.monotonic()
        last = self._recent.get(ev.raw)
        self._recent = {k: v for k, v in self._recent.items() if now - v < 30}
        if last is not None and now - last < self.dedup_seconds:
            return
        self._recent[ev.raw] = now

        logging.info("[%s] %s  (raw=%s)", ev.priority, ev.description, ev.raw)
        if self.store:
            try:
                self.store.save(ev)
            except Exception as e:
                logging.error("DB write failed: %s", e)

        if ev.priority in self.push_levels:
            urgent = ev.priority in self.urgent_levels
            for n in self.notifiers:
                try:
                    n.send(ev, urgent)
                except Exception as e:
                    logging.error("Notifier %s failed: %s", n.name, e)

    # --- connection loop -------------------------------------------------- #

    def run(self):
        backoff = self.reconnect_min
        while not self._stop.is_set():
            try:
                logging.info("Connecting to %s:%s ...", self.host, self.port)
                with socket.create_connection((self.host, self.port), timeout=15) as sock:
                    sock.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)
                    sock.settimeout(None)
                    logging.info("Connected.")
                    backoff = self.reconnect_min
                    self._read_stream(sock)
            except (socket.timeout, OSError) as e:
                if self._stop.is_set():
                    break
                logging.warning("Connection lost (%s). Reconnecting in %ss.", e, backoff)
                self._stop.wait(backoff)
                backoff = min(backoff * 2, self.reconnect_max)
        logging.info("Monitor stopped.")

    def _read_stream(self, sock):
        buf = b""
        while not self._stop.is_set():
            data = sock.recv(4096)
            if not data:
                raise OSError("peer closed connection")
            buf += data
            # frames terminate with CR/LF; also tolerate bare LF
            while True:
                idx = _find_line_end(buf)
                if idx < 0:
                    break
                line, buf = buf[:idx], buf[idx:].lstrip(b"\r\n")
                text = line.decode("ascii", "ignore").strip()
                if not text:
                    continue
                ev = decode(text, self.zone_names)
                if ev:
                    self.handle(ev)

    def stop(self, *_):
        self._stop.set()


def _find_line_end(buf: bytes) -> int:
    for i, c in enumerate(buf):
        if c in (0x0d, 0x0a):
            return i
    return -1


# --------------------------------------------------------------------------- #
#  Entry point
# --------------------------------------------------------------------------- #

def main():
    cfg_path = os.environ.get("NESS_CONFIG", "/etc/ness-monitor/ness-monitor.conf")
    if len(sys.argv) > 1:
        cfg_path = sys.argv[1]
    if not os.path.exists(cfg_path):
        sys.stderr.write("Config not found: %s\n" % cfg_path)
        sys.exit(1)

    cfg = configparser.ConfigParser()
    cfg.read(cfg_path)

    logging.basicConfig(
        level=getattr(logging, cfg.get("logging", "level", fallback="INFO").upper(), logging.INFO),
        format="%(asctime)s %(levelname)s %(message)s",
    )

    mon = NessMonitor(cfg)
    signal.signal(signal.SIGTERM, mon.stop)
    signal.signal(signal.SIGINT, mon.stop)
    mon.run()


if __name__ == "__main__":
    main()
