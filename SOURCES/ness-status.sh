#!/bin/bash

ness_ip=<NESS_IP_ADDRESS>

while :
do
    wget -qO- $ness_ip:2401 | tee -a "/var/local/lib/ness-monitor/events" &> /dev/null
    sleep 75
done
