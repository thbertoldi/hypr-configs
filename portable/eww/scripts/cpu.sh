#!/usr/bin/env bash
# Percent CPU used over a one-second sample, rounded to 0-100.
set -euo pipefail

read -r _ u1 n1 s1 i1 io1 _ < /proc/stat
sleep 1
read -r _ u2 n2 s2 i2 io2 _ < /proc/stat

used=$(( (u2+n2+s2) - (u1+n1+s1) ))
total=$(( used + (i2+io2) - (i1+io1) ))
[ "$total" -le 0 ] && total=1
echo $(( 100 * used / total ))
