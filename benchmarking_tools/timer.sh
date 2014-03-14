#!/bin/bash

if [ $# -eq 0 ]; then
  echo "usage: timer.sh <socket_path> <file.sql>"
  echo "timer.sh needs to be run from MySQL directory under test."
  exit 1
fi


# get the current time
T="$(date +%s)"


bin/mysql -A -f -uroot -S$1 test < $2


# figure out how many seconds have elapsed
T="$(($(date +%s)-T))"

# print it out in hours, minutes, and seconds
printf "`date` | loader duration = %02d:%02d:%02d:%02d\n" "$((T/86400))" "$((T/3600%24))" "$((T/60%60))" "$((T%60))"

