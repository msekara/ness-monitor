%define _topdir %(pwd)

Name:           ness-monitor
Version:        0.1
Release:        11%{?dist}
Source0:        ness-monitor.service
Source1:        ness-monitor.path
Source2:        ness-status.service
Source3:	ness-monitor.sh
Source4:	ness-status.sh
Source5:	index
Source6:	events
Source7:	ness-monitor.db
Source8:	ness-monitor
Summary:        Ness Alarm Monitoring
License:        GPL
Requires:	wget, sendemail, sqlite, dos2unix

%description
systemd service to monitor the Ness alarm and send notifications

%prep
rm -rf %{buildroot}

%install
mkdir -p %{buildroot}/usr/local/bin/
mkdir -p %{buildroot}/var/local/lib/ness-monitor/
mkdir -p %{buildroot}/etc/systemd/system/
mkdir -p %{buildroot}/etc/logrotate.d/
cp %{SOURCE0} %{SOURCE1} %{SOURCE2} %{buildroot}/etc/systemd/system/
cp %{SOURCE3} %{SOURCE4} %{buildroot}/usr/local/bin/
cp %{SOURCE5} %{SOURCE6} %{SOURCE7} %{buildroot}/var/local/lib/ness-monitor/
cp %{SOURCE8} %{buildroot}/etc/logrotate.d/

%post
systemctl daemon-reload
systemctl start ness-status.service
systemctl enable ness-status.service
systemctl start ness-monitor.path
systemctl enable ness-monitor.path

%preun
if [ $1 = 0 ]
then
  systemctl stop ness-monitor.path
  systemctl stop ness-status.service
  systemctl disable ness-monitor.path
  systemctl disable ness-status.service
fi

%files
%doc
/var/local/lib/ness-monitor/
/var/local/lib/ness-monitor/events
/var/local/lib/ness-monitor/index
%config /var/local/lib/ness-monitor/ness-monitor.db
/usr/local/bin/ness-monitor.sh
/usr/local/bin/ness-status.sh
/etc/logrotate.d/ness-monitor
/etc/systemd/system/ness-monitor.path
/etc/systemd/system/ness-monitor.service
/etc/systemd/system/ness-status.service

%changelog
* Tue Aug 27 2019 Mladen Sekara <mladen.sekara@emefes.com> 0.1-11
- Changed the email notification to parent event only.
- Added raw event to sqlite db

* Thu Aug 22 2019 Mladen Sekara <mladen.sekara@emefes.com> 0.1-10
- Fixed the defect where email is not sent on alarm activation

* Thu Jul 25 2019 Mladen Sekara <mladen.sekara@emefes.com> 0.1-9
- Disabled email on exit delays.

* Tue Jun 18 2019 Mladen Sekara <mladen.sekara@emefes.com> 0.1-8
- Changed event log file to rotate via logrotate. Added dos2unix to fix DOS carriage returns in events file.

* Thu Jun 13 2019 Mladen Sekara <mladen.sekara@emefes.com> 0.1-7
- Added all Ness events to ness-monitor.sh

* Wed Jun 12 2019 Mladen Sekara <mladen.sekara@emefes.com> 0.1-6
- Included event datetime into the sqlite db and made db write optional.

* Tue Jun 11 2019 Mladen Sekara <mladen.sekara@emefes.com> 0.1-5
- Added sqlite db support.

* Thu Jun 06 2019 Mladen Sekara <mladen.sekara@emefes.com> 0.1-4
- Added a ness-status-restart service to restart ness-status daily.

* Wed Jun 05 2019 Mladen Sekara <mladen.sekara@emefes.com> 0.1-3
- Added daemon-preload

* Tue Jun 04 2019 Mladen Sekara <mladen.sekara@emefes.com> 0.1-2
- Changed the path for events

* Mon Jun 03 2019 Mladen Sekara <mladen.sekara@emefes.com> 0.1-1
- Added preun

* Sat Jun 01 2019 Mladen Sekara <mladen.sekara@emefes.com> 0.1-0
- Initial release.

