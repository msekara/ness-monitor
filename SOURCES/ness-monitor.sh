#!/bin/bash

current_date=`date +"%Y-%m-%d"`
base_location="/var/local/lib/ness-monitor"
# Below db created with: sqlite3 ness-monitor.db  "create table events (id INTEGER PRIMARY KEY,date TEXT,time TEXT,raw TEXT,event TEXT, description TEXT);"
ness_db="$base_location/ness-monitor.db"
monfile="$base_location/events"
indexfile="$base_location/index"

# If set, store events to sqlite db
SQLITE_ON=true

# If set send an email notification
EMAIL_ON=true

# --- Gmail details ---
# A semicolumn separated list of receipient email addresses
GMAIL_RECV_ACC="<EMAIL1@GMAIL.COM;EMAIL2@GMAIL.COM"
# Gmail account to use to send emails
GMAIL_SEND_ACC="<FROMEMAIL@GMAIL.COM>"
GMAIL_SEND_PWD="<FROMEMAIL_PASSWORD"


send_email()
{
	sendemail -l /var/log/ness_email.log -f "alarm@gmail.com" -u "ALARM - Notification" -t "$GMAIL_RECV_ACC" -s "smtp.gmail.com:587" -o tls=yes -xu "$GMAIL_SEND_ACC" -xp "$GMAIL_SEND_PWD" -m "$1"	
#		-o message-file="/var/local/lib/emailbody.txt"
}

if [ -s "$indexfile" ]
then
        index=$(cat "$indexfile")
else
        index=1
fi

tail -n +$index $monfile | dos2unix | while read -r line
do
	((index++))
	if [ "${#line}" -eq 28 ]
	then
		event="${line:8:2}"
		id="${line:10:2}"
		area="${line:12:2}"
		date_time="${line:14:12}"
		day="${line:14:2}"
                month="${line:16:2}"
                year="${line:18:2}"
                hour="${line:20:2}"
                min="${line:22:2}"
                sec="${line:24:2}"
		
		############################################################################
                # ZONE OR USER EVENTS                                                      #
                ############################################################################
		# ===== UNSEALED =====
		if [ ${event} == 00 ]
		then
			# --- Zone ---
			if [ ${id} -ge 1 -a ${id} -le 16 ] && [ ${area} == 00 ]
			then
				[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Unsealed - Movement Detection in Zone ${id}');"
			# --- Door ---
			else
				[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Unsealed - Door Access Detection, User ${area}');"
			fi
		fi
		# ===== SEALED =====
		if [ ${event} == 01 ]
		then
			# --- Zone ---
                        if [ ${id} -ge 1 -a ${id} -le 16 ] && [ ${area} == 00 ]
                        then
				[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Sealed - Movement Detection in Zone ${id}');"
                        # --- Door ---
                        else
				[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Sealed - Door Access Detection, User ${area}');"
                        fi
		fi
		# ===== ALARM =====
		if [ ${event} == 02 ]
		then
			[ ${EMAIL_ON} ] && send_email "Alarm Activated"
                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Alarm Activated');"
			# --- Keypad ---
			if [ ${id} == f0 ]
			then
				if [ ${area} == 81 ]
				then
					#[ ${EMAIL_ON} ] && send_email "Alarm Activated - Keypad Fire"
					[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Alarm Activated - Keypad Fire');"
				elif [ ${area} == 82 ]
                                then
                                        #[ ${EMAIL_ON} ] && send_email "Alarm Activated - Keypad Panic"
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Alarm Activated - Keypad Panic');"
				elif [ ${area} == 83 ]
                                then
                                        #[ ${EMAIL_ON} ] && send_email "Alarm Activated - Keypad Medical"
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Alarm Activated - Keypad Medical');"
				elif [ ${area} == 84 ]
                                then
                                        #[ ${EMAIL_ON} ] && send_email "Alarm Activated - Keypad Duress"
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Alarm Activated - Keypad Duress');"
				fi
			# --- Main Unit ---	
			elif [ ${id} == 00 ]
			then
				if [ ${area} == 82 ]
                                then
					#[ ${EMAIL_ON} ] && send_email "Alarm Activated - Keyswitch Panic"
					[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Alarm Activated - Keyswitch Panic');"
				fi
			# --- User 1-56 ---
			elif [ ${id} -ge 1 -a ${id} -le 56 ]
			then
				if [ ${area} == 82 ]
				then
					#[ ${EMAIL_ON} ] && send_email "Alarm Activated - Radio Panic, User ${id}"
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Alarm Activated - Radio Panic, User ${id}');"
				fi
			# --- Zone 1-16 ---
			# The below is commented out since the above is check is matched first and this never gets executed
			#elif [ ${id} -ge 1 -a ${id} -le 16 ]
                        #then
                                if [ ${area} == 01 ] || [ ${area} == 02 ]
                                then
                                        #[ ${EMAIL_ON} ] && send_email "Alarm Activated - Area ${area}, Zone ${id}"
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Alarm Activated - Area ${area}, Zone ${id}');"
				elif [ ${area} == 03 ]
                                then
                                        #[ ${EMAIL_ON} ] && send_email "Alarm Activated - Monitor, Zone ${id}"
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Alarm Activated - Monitor, Zone ${id}');"
				elif [ ${area} == 04 ]
                                then
                                        #[ ${EMAIL_ON} ] && send_email "Alarm Activated - Day, Zone ${id}"
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Alarm Activated - Day, Zone ${id}');"
                                elif [ ${area} == 80 ]
                                then
                                        #[ ${EMAIL_ON} ] && send_email "Alarm Activated - 24 hr, Zone ${id}"
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Alarm Activated - 24 hr, Zone ${id}');"
				elif [ ${area} == 81 ]
                                then
                                        #[ ${EMAIL_ON} ] && send_email "Alarm Activated - 24 hr converted to Fire, Zone ${id}"
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Alarm Activated - 24 hr converted to Fire, Zone ${id}');"
				elif [ ${area} == 85 ]
                                then
                                        #[ ${EMAIL_ON} ] && send_email "Alarm Activated - Door Open too Long, Zone ${id}"
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Alarm Activated - Door Open too Long, Zone ${id}');"
                                fi
			fi
		fi
		# ===== ALARM RESTORE =====
		if [ ${event} == 03 ]
		then
			[ ${EMAIL_ON} ] && send_email "Alarm Restored"
                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Alarm Restored');"
                        # --- Keypad ---
                        if [ ${id} == f0 ]
                        then
                                if [ ${area} == 81 ]
                                then
                                        #[ ${EMAIL_ON} ] && send_email "Alarm Restored - Keypad Fire"
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Alarm Restored - Keypad Fire');"
                                elif [ ${area} == 82 ]
                                then
                                        #[ ${EMAIL_ON} ] && send_email "Alarm Restored - Keypad Panic"
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Alarm Restored - Keypad Panic');"
                                elif [ ${area} == 83 ]
                                then
                                        #[ ${EMAIL_ON} ] && send_email "Alarm Restored - Keypad Medical"
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Alarm Restored - Keypad Medical');"
                                elif [ ${area} == 84 ]
                                then
                                        #[ ${EMAIL_ON} ] && send_email "Alarm Restored - Keypad Duress"
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Alarm Restored - Keypad Duress');"
                                fi
                        # --- Main Unit ---
                        elif [ ${id} == 00 ]
                        then
                                if [ ${area} == 82 ]
                                then
                                        #[ ${EMAIL_ON} ] && send_email "Alarm Restored - Keyswitch Panic"
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Alarm Restored - Keyswitch Panic');"
                                fi
                        # --- User 1-56 ---
                        elif [ ${id} -ge 1 -a ${id} -le 56 ]
                        then
                                if [ ${area} == 82 ]
                                then
                                        #[ ${EMAIL_ON} ] && send_email "Alarm Restored - Radio Panic, User ${id}"
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Alarm Restored - Radio Panic, User ${id}');"
                                fi
                        # --- Zone 1-16 ---
                        # The below is commented out since the above check is matched first and this never gets executed
			#elif [ ${id} -ge 1 -a ${id} -le 16 ]
                        #then
                                if [ ${area} == 01 ] || [ ${area} == 02 ]
                                then
                                        #[ ${EMAIL_ON} ] && send_email "Alarm Restored - Area ${area}, Zone ${id}"
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Alarm Restored - Area ${area}, Zone ${id}');"
                                elif [ ${area} == 03 ]
                                then
                                        #[ ${EMAIL_ON} ] && send_email "Alarm Restored - Monitor, Zone ${id}"
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Alarm Restored - Monitor, Zone ${id}');"
                                elif [ ${area} == 04 ]
                                then
                                        #[ ${EMAIL_ON} ] && send_email "Alarm Restored - Day, Zone ${id}"
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Alarm Restored - Day, Zone ${id}');"
                                elif [ ${area} == 80 ]
                                then
                                        #[ ${EMAIL_ON} ] && send_email "Alarm Restored - 24 hr, Zone ${id}"
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Alarm Restored - 24 hr, Zone ${id}');"
                                elif [ ${area} == 81 ]
                                then
                                        #[ ${EMAIL_ON} ] && send_email "Alarm Restored - 24 hr converted to Fire, Zone ${id}"
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Alarm Restored - 24 hr converted to Fire, Zone ${id}');"
                                elif [ ${area} == 85 ]
                                then
                                        #[ ${EMAIL_ON} ] && send_email "Alarm Restored - Door Open too Long, Zone ${id}"
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Alarm Restored - Door Open too Long, Zone ${id}');"
                                fi
                        fi
		fi
		# ===== MANUAL EXCLUDE =====
		if [ ${event} == 04 ]
		then
			[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Manual Exclude of Zone ${id}');"
		fi
		# ===== MANUAL INCLUDE =====
		if [ ${event} == 05 ]
		then
			[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Manual Include of Zone ${id}');"
		fi
		# ===== AUTO EXCLUDE =====
		if [ ${event} == 06 ]
		then
			[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Auto Exclude Zone ${id}');"
		fi
		# ===== AUTO INCLUDE =====
		if [ ${event} == 07 ]
		then
			[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Auto Include Zone ${id}');"
		fi
		# ===== TAMPER UNSEALED =====
		if [ ${event} == 08 ]
		then
			if [ ${id} == 00 ]
                        then
				if [ ${area} == 00 ]
				then
					[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Tamper Unsealed - Internal');"
				elif [ ${area} == 01 ]
                                then
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Tamper Unsealed - External');"
				fi
			elif [ ${id} == f0 ]
			then
				if [ ${area} == 00 ]
				then
					[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Tamper Unsealed - Keypad');"
				fi
			elif [ ${id} -ge 1 -a ${id} -le 16 ]
			then
				if [ ${area} == 91 ]
				then
					[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Tamper Unsealed - Radio Detector');"
				fi
			fi
		fi
		# ===== TAMPER NORMAL =====
		if [ ${event} == 09 ]
		then
		       if [ ${id} == 00 ]
                        then
                                if [ ${area} == 00 ]
                                then
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Tamper Normal - Internal');"
                                elif [ ${area} == 01 ]
                                then
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Tamper Normal - External');"
                                fi
                        elif [ ${id} == f0 ]
                        then
                                if [ ${area} == 00 ]
                                then
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Tamper Normal - Keypad');"
                                fi
                        elif [ ${id} -ge 1 -a ${id} -le 16 ]
                        then
                                if [ ${area} == 91 ]
                                then
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Tamper Normal - Radio Detector');"
                                fi
                        fi
		fi

		############################################################################
		# SYSTEM EVENTS                                                            #
		############################################################################
		# ===== POWER FAILURE =====
		if [ ${event} == 10 ]
		then
			[ ${EMAIL_ON} ] && send_email "AC Mains Failure"
			[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','AC Mains Failure');"
		fi
		# ===== POWER NORMAL =====
		if [ ${event} == 11 ]
		then
			[ ${EMAIL_ON} ] && send_email "AC Mains Restored"
			[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','AC Mains Restored');"
		fi
		# ===== BATTERY FAILURE =====
		if [ ${event} == 12 ]
		then
			if [ ${id} == 00 ] && [ ${area} == 00 ]
			then
				[ ${EMAIL_ON} ] && send_email "Main Battery Failure"
				[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Main Battery Failure');"
			elif [ ${id} -ge 1 -a ${id} -le 56 ] && [ ${area} == 92 ]
			then
				[ ${EMAIL_ON} ] && send_email "Radio Key Battery Failure"
                                [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Radio Key Battery Failure');"
			elif [ ${id} -ge 1 -a ${id} -le 16 ] && [ ${area} == 91 ]
                        then
                                [ ${EMAIL_ON} ] && send_email "Radio Detector Battery Failure"
                                [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Radio Detector Battery Failure');"
			fi
		fi
		# ===== BATTERY NORMAL =====
		if [ ${event} == 13 ]
		then
			if [ ${id} == 00 ] && [ ${area} == 00 ]
                        then
                                [ ${EMAIL_ON} ] && send_email "Main Battery Normal"
                                [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Main Battery Normal');"
                        elif [ ${id} -ge 1 -a ${id} -le 56 ] && [ ${area} == 92 ]
                        then
                                [ ${EMAIL_ON} ] && send_email "Radio Key Battery Normal"
                                [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Radio Key Battery Normal');"
                        elif [ ${id} -ge 1 -a ${id} -le 16 ] && [ ${area} == 91 ]
                        then
                                [ ${EMAIL_ON} ] && send_email "Radio Detector Battery Normal"
                                [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Radio Detector Battery Normal');"
                        fi
		fi
		# ===== REPORT FAILURE =====
		if [ ${event} == 14 ]
		then
			[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Dialer Failed to Report');"
		fi
		# ===== REPORT NORMAL =====
		if [ ${event} == 15 ]
		then
			[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Dealer Report Restored');"
		fi
		# ===== SUPERVISION FAILURE =====
		if [ ${event} == 16 ] && [ ${id} -ge 1 -a ${id} -le 16 ]
		then
			[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Supervised Zone Failure, Zone ${id}');"
		fi
		# ===== SUPERVISION NORMAL =====
		if [ ${event} == 17 ] && [ ${id} -ge 1 -a ${id} -le 16 ]
		then
			[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Supervised Zone Zone Normal, Zone ${id}');"
		fi
		# ===== REAL TIME CLOCK =====	
		if [ ${event} == 19 ] && [ ${id} == 00 ]
		then
			[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Real Time Clock Time or Date Changed');"
		fi

		############################################################################
                # AREA EVENTS                                                              #
                ############################################################################
		# ===== Entry Delay Start =====
		if [ ${event} == 20 ]
		then
			[ ${EMAIL_ON} ] && send_email "Entry Delay Start"
                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Entry Delay Start');"
			if [ ${area} == 01 ] || [ ${area} == 02 ]
			then
				[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Entry Delay Start - Zone ${id}, Area ${area}');"
                        elif [ ${area} == 03 ]
                        then
                                [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Entry Delay Start - Zone ${zone}, Monitor');"
                        fi
		fi
		# ===== Entry Delay End =====
		if [ ${event} == 21 ]
		then
			[ ${EMAIL_ON} ] && send_email "Entry Delay End"
                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Entry Delay End');"
		        if [ ${area} == 01 ] || [ ${area} == 02 ]
                        then
                                [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Entry Delay End - Zone ${zone}, Area ${area}');"
                        elif [ ${area} == 03 ]
                        then
                                [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Entry Delay End - Zone ${zone}, Monitor');"
                        fi
		fi
		# ===== Exit Delay Start =====
		if [ ${event} == 22 ]
                then
                        if [ ${area} == 01 ] || [ ${area} == 02 ]
                        then
                                #[ ${EMAIL_ON} ] && send_email "Exit Delay Start - Area ${area}"
                                [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Exit Delay Start - Zone ${id}, Area ${area}');"
                        elif [ ${area} == 03 ]
                        then
                                #[ ${EMAIL_ON} ] && send_email "Exit Delay Start - Monitor"
                                [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Exit Delay Start - Zone ${zone}, Monitor');"
                        fi
                fi
		# ===== Exit Delay End =====
                if [ ${event} == 23 ]
                then
                        if [ ${area} == 01 ] || [ ${area} == 02 ]
                        then
                                #[ ${EMAIL_ON} ] && send_email "Exit Delay End - Area ${area}"
                                [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Exit Delay End - Zone, ${zone}, Area ${area}');"
                        elif [ ${area} == 03 ]
                        then
                                #[ ${EMAIL_ON} ] && send_email "Exit Delay End - Monitor"
                                [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Exit Delay End - Zone ${zone}, Monitor');"
                        fi
                fi
		# ===== Armed Away =====
		if [ ${event} == 24 ]
		then
			[ ${EMAIL_ON} ] && send_email "Armed Away"
                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Armed Away');"
			if [ ${id} -ge 1 -a ${id} -le 56 ]
			then
				# If we get here it can be either Area1 or Area2
				[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Armed Away - User ${id}, Area ${area}');"
			elif [ ${id} == 57 ]
			then
                                [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Armed Away - Keyswitch, Area ${area}');"
			elif [ ${id} == 58 ]
			then
                                [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Armed Away - Short Arm, Area ${area}');"
			fi
		fi
		# ===== Armed Home =====
		if [ ${event} == 25 ]
		then
			[ ${EMAIL_ON} ] && send_email "Armed Home"
                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Armed Home');"
			if [ ${id} -ge 1 -a ${id} -le 56 ]
                        then
                                [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Armed Home - User ${id}, Monitor');"
                        elif [ ${id} == 57 ]
                        then
                                [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Armed Home - Keyswitch, Monitor');"
                        elif [ ${id} == 58 ]
                        then
                                [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Armed Home - Short Arm, Monitor');"
                        fi
		fi
		# ===== Armed Day =====
		if [ ${event} == 26 ] && [ ${area} == 04 ]
		then
			[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Armed Day');"
		fi
		# ===== Armed Night =====
		if [ ${event} == 27 ]
		then
			[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Armed Night');"
		fi
		# ===== Armed Vacation =====
		if [ ${event} == 28 ]
		then
			[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Armed Vacation');"
		fi
		# ===== Armed Highest =====
		if [ ${event} == 2e ]
		then
			[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Armed Highest');"
		fi
		# ===== Disarmed =====
		if [ ${event} == 2f ]
		then
			[ ${EMAIL_ON} ] && send_email "Disarmed"
                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Disarmed');"
			if [ ${id} -ge 1 -a ${id} -le 56 ]
			then
				if [ ${area} == 01 ] || [ ${area} == 02 ]
				then
					#[ ${EMAIL_ON} ] && send_email "Disarmed - User ${id}, Area ${area}"
					[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Disarmed - User ${id}, Area ${area}');"
				elif [ ${area} == 03 ]
				then
					#[ ${EMAIL_ON} ] && send_email "Disarmed Home - User ${id}, Monitor"
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Disarmed - User ${id}, Monitor');"
				elif [ ${area} == 04 ]
                                then
                                        #[ ${EMAIL_ON} ] && send_email "Disarmed - User ${id}, Day"
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Disarmed - User ${id}, Day');"
				fi
			elif [ ${id} == 57 ]
			then
				if [ ${area} == 01 ] || [ ${area} == 02 ]
                                then
                                        #[ ${EMAIL_ON} ] && send_email "Disarmed - Keyswitch, Area ${area}"
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Disarmed - Keyswitch, Area ${area}');"
                                elif [ ${area} == 03 ]
                                then
                                        #[ ${EMAIL_ON} ] && send_email "Disarmed Home - Keyswitch, Monitor"
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Disarmed - Keyswitch, Monitor');"
                                elif [ ${area} == 04 ]
                                then
                                        #[ ${EMAIL_ON} ] && send_email "Disarmed - Keyswitch, Day"
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Disarmed - Keyswitch, Day');"
                                fi
			elif [ ${id} == 58 ]
                        then
                                if [ ${area} == 01 ] || [ ${area} == 02 ]
                                then
                                        #[ ${EMAIL_ON} ] && send_email "Disarmed - Short Arm, Area ${area}"
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Disarmed - Short Arm, Area ${area}');"
                                elif [ ${area} == 03 ]
                                then
                                        #[ ${EMAIL_ON} ] && send_email "Disarmed Home - Short Arm, Monitor"
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Disarmed - Short Arm, Monitor');"
                                elif [ ${area} == 04 ]
                                then
                                        #[ ${EMAIL_ON} ] && send_email "Disarmed - Short Arm, Day"
                                        [ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Disarmed - Short Arm, Day');"
                                fi
                        fi
		fi
		# ===== Arming Delayed =====
		if [ ${event} == 30 ]
		then
			if [ ${area} == 01 ] || [ ${area} == 02 ]
                        then
                        	[ ${EMAIL_ON} ] && send_email "Auto Arming Delayed - User ${id}, Area ${area}"
                       		[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Auto Arming Delayed - User ${id}, Area ${area}');"
                	elif [ ${area} == 03 ]
                	then
				[ ${EMAIL_ON} ] && send_email "Auto Arming Delayed - User ${id}, Monitor"
				[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Auto Arming Delayed - User ${id}, Monitor');"
			fi
		fi

		############################################################################
                # RESULT EVENTS                                                            #
                ############################################################################
		if [ ${event} == 31 ]
		then
			if [ ${id} == 90 ]
			then
				[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Siren ON');"
			fi
			if [ ${id} == 91 ]
			then
				[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Soft Siren ON');"
			fi
			if [ ${id} == 92 ]
			then
				[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Soft Monitor ON');"
			fi
			if [ ${id} == 93 ]
			then
				[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Siren Fire ON');"
			fi
			if [ ${id} == 94 ]
			then
				[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Strobe ON');"
			fi
			if [ ${id} == 95 ]
			then
				[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Reset ON');"
			fi
			if [ ${id} == 96 ]
			then
				[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Sonalert ON');"	
			fi
		fi
		if [ ${event} == 32 ]
		then
			if [ ${id} == 90 ]
			then
				[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Siren OFF');"
			fi
			if [ ${id} == 91 ]
			then
				[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Soft Siren OFF');"
			fi
			if [ ${id} == 92 ]
			then
				[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Soft Monitor OFF');"
			fi
			if [ ${id} == 93 ]
			then
				[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Siren Fire OFF');"
			fi
			if [ ${id} == 94 ]
			then
				[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Strobe OFF');"
			fi
			if [ ${id} == 95 ]
			then
				[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Reset OFF');"
			fi
			if [ ${id} == 96 ]
			then
				[ ${SQLITE_ON} ] && sqlite3 "$ness_db" "insert into events(date,time,raw,event,description) values ('$day.$month.$year.','$hour:$min:$sec','$line','$event','Sonalert OFF');"
			fi
		fi
	fi
echo $index > "$indexfile"
done
