#!/bin/bash

set -o errexit -o pipefail

[ $# -lt 2 ] && {
    echo "ERROR: specify two manifest files to merge"
    exit
}

m1=$1
m2=$2
shift 2

[ $# -gt 0 ] && {
    echo "ERROR: don't know what to do with $@"
    exit
}

remove_default() {
    local val name=$1 xml=$(cat)

    val=$(echo "$xml" | xmlstarlet sel -t -v "/manifest/default/@$name")
    if [ -n "$val" ]; then
        echo "$xml" | xmlstarlet ed -i "/manifest/*[not(self::remote|@$name)]" -t attr -n "$name" -v "$val"
    fi
}

remove_defaults() {
    local xml=$(cat)

    xml=$(echo "$xml" | remove_default "remote")
    xml=$(echo "$xml" | remove_default "revision")

    echo "$xml" | xmlstarlet ed -d "/manifest/default"
}

update_remote() {
    local orig new

    orig=$1
    new=$2
    xmlstarlet ed -u "/manifest/remote[@name='$orig']/@name" -v "$new" -u "/manifest/*[@remote='$orig']/@remote" -v "$new"
}

xml1=$(cat "$m1" | remove_defaults)
xml2=$(cat "$m2" | remove_defaults)

m1remotes=($(cat "$m1" | xmlstarlet sel -t -m '/manifest/remote' -v '@name' -o ' '))
m2remotes=($(cat "$m2" | xmlstarlet sel -t -m '/manifest/remote' -v '@name' -o ' '))
for m1remote in "${m1remotes[@]}"; do
    for m2remote in "${m2remotes[@]}"; do
        if [ "$m1remote" = "$m2remote" ]; then
            xml1=$(echo "$xml1" | update_remote "$m1remote" "${m1remote}1")
            xml2=$(echo "$xml2" | update_remote "$m2remote" "${m2remote}2")
        fi
    done
done

{
    echo '<?xml version="1.0" encoding="UTF-8"?>
        <manifest>'

    echo "$xml1" | xmlstarlet sel -t -c '/manifest/*[not(self::project)]'
    echo "$xml2" | xmlstarlet sel -t -c '/manifest/*[not(self::project)]'

    echo "$xml1" | xmlstarlet sel -t -c "/manifest/project"
    echo "$xml2" | xmlstarlet sel -t -c "/manifest/project"

    echo '</manifest>'
} | xmlstarlet fo
