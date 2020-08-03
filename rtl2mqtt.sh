#!/bin/sh

buttons='
1 0x2 4546e0 0
2 0x4 2546e0 0
3 0x8 1546e0 0
'

! [ -f mqtt.conf ] && echo "Fail to find mqtt.conf file" && exit 1
. ./mqtt.conf
mqtt="mosquitto_pub -h $host -p $port"
[ -n "$user$pass" ] && mqtt="$mqtt -u $user -P $pass"
[ -n "$topicpref" ] && mqtt="$mqtt -t $topicpref" || mqtt="$mqtt -t /rtl433"

cd `dirname "$0"`
! [ -f mqtt.conf ] && echo "Fail to find mqtt.conf file" && exit 1
. ./mqtt.conf

rtl_433 -F json -M utc |
    while IFS= read -r line; do
        code=`echo "$line" | sed '/"data"/!d;s/^.* "data" : "//;s/ .*$//'`
        if [ -n "$code" ]; then
            button=`echo "$buttons" | awk '$2~/'"$code"'/ {print $1}'`
            if [ -n "$button" ]; then
                buttons=`echo "$buttons" | awk '{ if ($1~/^'$button'$/) {print $1" "$2" "$3" "$4+1} else {print $0}}'`
            else
                echo "Found unknown code: $code"
            fi
        else
            code=`echo "$line" | sed 's/^.* "code" : "//;s/".*//'`
            if [ -n "$code" ]; then
                button=`echo "$buttons" | awk '$3~/'"$code"'/ {print $1}'`
                count=`echo "$buttons" | awk '$3~/'"$code"'/ {print $4}'`
                if [ -n "$button" ]; then
                    buttons=`echo "$buttons" | awk '{ if ($1~/^'$button'$/) {print $1" "$2" "$3" "0} else {print $0}}'`
                    if [ "$count" -lt 6 ]; then
                        l='short'
                    elif [ "$count" -lt 17 ]; then
                        l='middle'
                    else
                        l='long'
                    fi
                    echo "$(date '+%F %T') Button $button is up after $l press ($count)"
                    $mqtt/button_$button/$l -m '1'
                else
                    echo "Found unknown code: $code"
                fi
            fi
        fi
    done
