#!/bin/bash

mongodbVersions=(4.2.3 4.1.13-v1 4.1.7-v3 4.1.4-v1 4.0.11-v1 4.0.5-v3 4.0.3-v1 3.6.13-v1 3.6.8-v1 3.4.22-v1 3.4.17-v1 4.2.7-percona 4.0.10-percona 3.6.18-percona)

declare -A CATALOG
CATALOG[mongodb]=$(echo ${mongodbVersions[@]})

x=v1.18.4

matrix=()
for db in ${!CATALOG[@]}; do
    for version in ${CATALOG[$db]}; do
        matrix+=($(jq -n -c --arg x "$x" --arg y "$db" --arg z "$version" '{"k8s":$x,"db":$y,"version":$z}'))
    done
done

# https://stackoverflow.com/a/63046305/244009
function join() {
    local IFS="$1"
    shift
    echo "$*"
}
matrix=$(echo "{"include":[$(join , ${matrix[@]})]}")
echo $matrix
