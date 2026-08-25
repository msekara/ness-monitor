# Ness D8x / D16x alarm monitor

Persistent-connection monitor for the Ness D8x/D16x IP232 serial interface.
Decodes the ASCII protocol, logs every event to SQLite, and sends push
notifications (ntfy / Pushover / Telegram / email) for the events you care
about — with mobile push or just email.

It keeps **one connection open continuously**, auto-reconnects with
backoff if the link drops, uses TCP keepalive to detect dead links, and
verifies each frame's checksum so garbage on the wire is discarded rather
than logged.

It's plain Python 3 (standard library only — no `pip install`), tested end to
end against the captured event data, including a full alarm sequence
(motion → entry delay → alarm → outputs → restore → disarm) and all three
real alarm activations in the capture logs.

## Push notifications

Default is **ntfy** — free, open source, one HTTP call, iOS + Android apps,
and self-hostable (worth considering if you'd rather not route alarm events
through a third party). Pushover, Telegram, and native SMTP email are all
built in and switchable in the config; you can enable more than one at once.

Priority routing keeps push meaningful:

| Level  | Examples                                             | Default |
|--------|------------------------------------------------------|---------|
| high   | alarm, tamper, power/battery/report/supervision fail | push (urgent) |
| normal | arm/disarm, alarm restore, entry-delay start         | push |
| low    | motion, seal/unseal, outputs, exit delay             | log only |

Everything is always written to SQLite regardless of level. Change what pushes
via `push_levels` in the config.

## Install

```bash
sudo ./install.sh
sudoedit /etc/ness-monitor/ness-monitor.conf   # set ness.host + ntfy.topic
sudo systemctl enable --now ness-monitor.service
journalctl -u ness-monitor -f                  # watch live events
```

### ntfy setup (2 minutes)
1. Install the **ntfy** app (App Store / Play Store) or open https://ntfy.sh.
2. Subscribe to a random, hard-to-guess topic, e.g. `ness-alarm-8fk3d9q2`.
   (Anyone who knows a public ntfy topic can read it, so keep it random — or
   self-host ntfy and set a `token`.)
3. Put that same topic in the `[ntfy]` section of the config.

Test it any time without the panel:
```bash
curl -H "Title: Test" -H "Priority: urgent" -d "hello from ness" ntfy.sh/YOUR-TOPIC
```

## Files

| File                   | Purpose                                            |
|------------------------|----------------------------------------------------|
| `ness_monitor.py`      | The daemon: connect, decode, log, notify           |
| `ness-monitor.conf`    | All settings (connection, notifiers, zone names)   |
| `ness-monitor.service` | systemd unit (Type=simple, Restart=always)         |
| `install.sh`           | Installs files, creates `ness` user + data dir     |

## Notes / things you may want to tweak

- **Zone names** live in the `[zones]` section — e.g.
  Garage/Lounge/Dining/Family/Upstairs. Add
  the rest of your zones there and they'll appear in every notification.
- **Database schema** is unchanged from the original
  (`date, time, raw, event, description`), so your existing `ness-monitor.db`
  and any queries against it keep working. The daemon just writes richer
  `description` text.
- The daemon only reads from the panel — it never sends arm/disarm commands.
  The protocol supports input commands (keypad strings, status requests).
