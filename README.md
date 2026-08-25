# Ness D8x / D16x alarm monitor

Persistent-connection monitor for the Ness D8x/D16x IP232 serial interface.
Decodes the ASCII protocol, logs every event to SQLite, and sends push
notifications (ntfy / Pushover / Telegram / email) for the events you care
about — with mobile push, not just email.

This replaces the older five-script setup (`ness-status.sh`,
`ness-monitor.path`, `ness-monitor.service`, `ness-monitor.sh`, plus the
`index`/logrotate bookkeeping) with a single always-on service.

## Why the rewrite (the important bit)

The old `ness-status.sh` connected, grabbed whatever was waiting, then
`sleep 75` — so the TCP link to the panel was **closed for 75 seconds at a
time**. The Ness IP232 streams events over a persistent connection, so any
alarm, arm/disarm, or sensor trip that happened inside those 75-second gaps
was silently lost. For an alarm notifier that's a real hole.

This version keeps **one connection open continuously**, auto-reconnects with
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

- **Zone names** live in the `[zones]` section — the defaults match the
  Garage/Lounge/Dining/Family/Upstairs mapping from your capture notes. Add
  the rest of your zones there and they'll appear in every notification.
- **Database schema** is unchanged from the original
  (`date, time, raw, event, description`), so your existing `ness-monitor.db`
  and any queries against it keep working. The daemon just writes richer
  `description` text.
- **Migration**: once this service is running, disable the old ones:
  `sudo systemctl disable --now ness-status.service ness-monitor.path`.
  You no longer need the `events` file, the `index` file, or the logrotate
  rule — event history lives in SQLite.
- **RPM**: if you still want to package this, the same `.spec` approach works;
  the payload is just `ness_monitor.py`, the `.conf`, and the `.service`. Happy
  to write the spec if you want it.
- The daemon only reads from the panel — it never sends arm/disarm commands.
  The protocol supports input commands (keypad strings, status requests) if
  you ever want two-way control; that's a deliberate next step, not included
  here.
