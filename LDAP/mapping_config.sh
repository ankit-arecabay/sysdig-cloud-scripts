#!/usr/bin/env bash
set -uo pipefail

OPTS=`getopt -o s:frdh --long set:,forcesync,report,delete,help -n 'parse-options' -- "$@"`
if [ $? != 0 ] ; then
  echo "Failed parsing options." >&2
  exit 1
fi

ENV="./env.sh"

SET=false
SETTINGS_JSON=""
FORCESYNC=false
REPORT=false
DELETE=false
HELP=false

eval set -- "$OPTS"

function print_usage() {
  echo "Usage: ./mapping_config.sh [OPTION]"
  echo
  echo "Affect LDAP mapping settings for your Sysdig software platform installation"
  echo
  echo "If no OPTION is specified, the current mapping config settings are printed"
  echo
  echo "Options:"
  echo "  -s | --set  JSON_FILE   Set the current LDAP mapping config to the contents of JSON_FILE"
  echo "  -f | --forcesync        Force an immediate sync"
  echo "  -r | --report           Print the report of the most recent sync operation"
  echo "  -d | --delete           Delete the current LDAP mapping config"
  echo "  -h | --help             Print this Usage output"
  exit 1
}

while true; do
  case "$1" in
    -s | --set ) SET=true; SETTINGS_JSON="$2"; shift; shift ;;
    -f | --forcesync ) FORCESYNC=true; shift ;;
    -r | --report ) REPORT=true; shift ;;
    -d | --delete ) DELETE=true; shift ;;
    -h | --help ) HELP=true; shift ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

if [ $HELP = true ] ; then
  print_usage
fi

if [ $# -gt 0 ] ; then
  echo "Excess command-line arguments detected. Exiting."
  echo
  print_usage
fi

if [ -e "$ENV" ] ; then
  source "$ENV"
else
  echo "File not found: $ENV"
  echo "See the LDAP documentation for details on populating this file with your settings"
  exit 1
fi

function force_sync() {
  echo "Forcing sync"
  curl $CURL_OPTS \
    -H "Authorization: Bearer $API_TOKEN" \
    -X PUT \
    $URL/api/admin/ldap/syncLdap
  exit $?
}

if [ $SET = true ] ; then
  if [ $DELETE = true -o $REPORT = true ] ; then
    print_usage
  else
    if [ ! -e $SETTINGS_JSON ] ; then
      echo "Settings file \"$SETTINGS_JSON\" does not exist. No settings were changed."
      exit 1
    fi
    cat $SETTINGS_JSON | ${JSON_FILTER} > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      curl $CURL_OPTS \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $API_TOKEN" \
        -X POST \
        -d @$SETTINGS_JSON \
        $URL/api/admin/ldap/settings/sync
      if [ $? -eq 0 ] ; then
        if [ $FORCESYNC = true ] ; then
          force_sync
        else
          exit 0
        fi
      else
        exit $?
      fi
    else
      echo "\"$SETTINGS_JSON\" contains invalid JSON. No settings were changed."
      exit 1
    fi
  fi

elif [ $DELETE = true ] ; then
  if [ $SET = true -o $REPORT = true ] ; then
    print_usage
  else
    curl $CURL_OPTS \
      -H "Authorization: Bearer $API_TOKEN" \
      -X DELETE \
      $URL/api/admin/ldap/settings/sync
    if [ $? -eq 0 ] ; then
      if [ $FORCESYNC = true ] ; then
        force_sync
      else
        exit 0
      fi
    else
      exit $?
    fi
  fi

elif [ $REPORT = true ] ; then
  if [ $SET = true -o $DELETE = true -o $FORCESYNC = true ] ; then
    print_usage
  else
    curl $CURL_OPTS \
      -H "Authorization: Bearer $API_TOKEN" \
      -X GET \
      $URL/api/admin/ldap/syncReport | ${JSON_FILTER}
    exit $?
  fi

elif [ $FORCESYNC = true ] ; then
  if [ $SET = true -o $DELETE = true -o $REPORT = true ] ; then
    print_usage
  else
    force_sync
  fi

else
  curl $CURL_OPTS \
    -H "Authorization: Bearer $API_TOKEN" \
    -X GET \
    $URL/api/admin/ldap/settings/sync | ${JSON_FILTER}
  exit $?
fi