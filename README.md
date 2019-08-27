# ness-monitor
Ness Alarm monitoring via IP232 for D8X/D16X

A very simple alarm notification that sends emails on alarm events.

ness-status.sh script connects to Ness IP232 and writes raw events to the local file ("events" file).
ness-monitor.path monitors the file "events" and on a file change, calls ness-monitor.service, which in turn executes ness-monitor.sh script.
ness-monitor.sh script sends alerts via email and writes events to the local sqlite database.

SOURCES
- events -> Contains raw alarm events written by ness-status.sh
- index -> A file to keep track of number of events + 
- ness-monitor -> A logrotate file
- ness-monitor.db -> A sqlite3 database to store alarm events
- ness-monitor.path -> A systemd service trigger on events file change
- ness-monitor.service -> A service that gets executed on the ness-monitor.path trigger and calls ness-monitor.sh
- ness-monitor.sh -> A script that processes events, sends an email alert and writes events into ness-monitor.db
- ness-status.service -> A service that calls ness-status.sh script
- ness-status.sh -> A script that connects to the Ness and write raw events to events file

SPECS
- ness-monitor.spec -> An rpm spec file

Installation:
- Update ness-monitor.sh to include sender email details and recepient email addresses where alerts will be sent
- Update ness-status.sh to include Ness IP address (IP232)
- Build an rpm and install
