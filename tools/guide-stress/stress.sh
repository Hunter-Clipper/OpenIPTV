#!/bin/bash
A=${ADB:-adb}; TV=${ADB_SERIAL:?set ADB_SERIAL to the device serial}
$A -s $TV logcat -c
$A -s $TV shell "RANDOM=$1; for i in \$(seq 1 $2); do r=\$((RANDOM%10)); if [ \$r -lt 4 ]; then k=22; elif [ \$r -lt 6 ]; then k=21; elif [ \$r -lt 8 ]; then k=20; else k=19; fi; input keyevent \$k; sleep $3; done; sleep 2"
$A -s $TV logcat -d -s flutter | grep OTV-perf | cut -d: -f4-
