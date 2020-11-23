#!/bin/bash

set -eou pipefail

show_help() {
    echo "update-docker.sh [options]"
    echo " "
    echo "options:"
    echo "-h, --help                       show brief help"
    echo "    --tools-only                 update only database-tools images"
    echo "    --exporter-only              update only database-exporter images"
    echo "    --operator-only              update only operator image"
}

k8sVersions=(v1.14.10 v1.16.9 v1.18.8 v1.19.1)

elasticsearchVersions=(1.0.2-opendistro 1.1.0-opendistro 1.2.1-opendistro 1.3.0-opendistro 1.4.0-opendistro 1.6.0-opendistro 1.7.0-opendistro 1.8.0-opendistro 1.9.0-opendistro 6.8.1-searchguard 6.8.10-xpack 7.0.1-searchguard 7.0.1-xpack 7.1.1-searchguard 7.1.1-xpack 7.2.1-xpack 7.3.2-xpack 7.4.2-xpack 7.5.2-searchguard 7.5.2-xpack 7.6.2-xpack 7.7.1-xpack 7.8.0-xpack)
mariadbVersions=(10.5.8)
memcachedVersions=(1.5.22)
mongodbVersions=(4.2.3 4.1.13-v1 4.1.7-v3 4.1.4-v1 4.0.11-v1 4.0.5-v3 4.0.3-v1 3.6.13-v1 3.6.8-v1 3.4.22-v1 3.4.17-v1 4.2.7-percona 4.0.10-percona 3.6.18-percona)
mysqlVersions=(8.0.14 8.0.3 5.7.25)
perconaXtraDBVersions=(5.7 5.7-cluster)
pgbouncerVersions=(1.12.0)
postgresVersions=(11.2-v1 11.1-v3 10.6-v3 10.2-v5 9.6-v5 9.6.7-v5)
proxysqlVersions=(2.0.4)
redisVersions=(5.0.3-v1 4.0.11 4.0.6-v2)

declare -A CATALOG
CATALOG['elasticsearch']=$(echo ${elasticsearchVersions[@]})
CATALOG['mariadb']=$(echo ${mariadbVersions[@]})
CATALOG['memcached']=$(echo ${memcachedVersions[@]})
CATALOG['mongodb']=$(echo ${mongodbVersions[@]})
CATALOG['mysql']=$(echo ${mysqlVersions[@]})
CATALOG['percona-xtradb']=$(echo ${perconaXtraDBVersions[@]})
CATALOG['pgbouncer']=$(echo ${pgbouncerVersions[@]})
CATALOG['postgres']=$(echo ${postgresVersions[@]})
CATALOG['proxysql']=$(echo ${proxysqlVersions[@]})
CATALOG['redis']=$(echo ${redisVersions[@]})

IFS=' '
read -ra COMMENT <<<"$@"

declare -a k8s=()
ref='master'
db=${GITHUB_REPOSITORY#"${GITHUB_REPOSITORY_OWNER}/"}
if [ ${CATALOG[$db]+_} ]; then
    echo "Running test for $db";
else
    db=
fi

declare -a versions=()
profiles='all'
tls='false'

for ((i = 0; i < ${#COMMENT[@]}; i++)); do
    entry="${COMMENT[$i]}"

    echo "-------------- $entry"

    case "$entry" in
        '/ok-to-test') ;;

        ref*)
            ref=$(echo $entry | sed -e 's/^[^=]*=//g')
            ;;

        k8s*)
            v=$(echo $entry | sed -e 's/^[^=]*=//g')
            IFS=','
            read -ra k8s <<<"$v"
            ;;

        db*)
            db=$(echo $entry | sed -e 's/^[^=]*=//g')
            ;;

        versions*)
            v=$(echo $entry | sed -e 's/^[^=]*=//g')
            IFS=','
            read -ra versions <<<"$v"
            ;;

        profiles*)
            profiles=$(echo $entry | sed -e 's/^[^=]*=//g')
            ;;

        tls)
            tls='true'
            ;;

        *)
            show_help
            exit 1
            ;;
    esac
done

if [ ${#k8s[@]} -eq 0 ] || [ ${k8s[0]} == "*" ]; then
    k8s=("${k8sVersions[@]}")
    # echo ${k8s[@]}
    # echo ${#k8s[@]}
    # echo "~~~~~~~~~~~~~"
fi

# https://wiki.nix-pro.com/view/BASH_associative_arrays#Check_if_key_exists
if [ ${CATALOG[$db]+_} ]; then
    if [ ${#versions[@]} -eq 0 ] || [ ${versions[0]} == "*" ]; then
        IFS=' '
        read -ra versions <<<"${CATALOG[$db]}"
        # echo ${versions[@]}
        # echo ${#versions[@]}
        # echo "**************"
    fi
else
    echo "Unknonwn database: $s"
    exit 1
fi

echo "ref = $ref"
echo "k8s = ${k8s[@]}"
echo "db = $db"
echo "versions = ${versions[@]}"
echo "profiles = ${profiles}"
echo "tls=${tls}"

matrix=()
for k in ${k8s[@]}; do
    for v in ${versions[@]}; do
        echo "+++++++++++++++++>>> " $v
        matrix+=($(jq -n -c --arg k "$k" --arg d "$db" --arg v "$v" --arg p "$profiles" --arg t "$tls" '{"k8s":$k,"db":$d,"version":$v,"profiles":$p,"tls":$t}'))
    done
done

echo "_____________________________"
echo "_____________________________"
echo "_____________________________"

# https://stackoverflow.com/a/63046305/244009
function join { local IFS="$1"; shift; echo "$*"; }
matrix=$(echo '{"include":['$(join , ${matrix[@]})']}')
# echo $matrix
echo "::set-output name=matrix::$matrix"
echo "::set-output name=e2e_ref::$ref"