#!/bin/bash

#
# FusionAuth External Authentication for Apache HTTP Server
#

error() {
  echo "$@" 1>&2
}

# Default configuration file
CONFIG=/usr/local/fusionauth/config/fusionauth_mod.properties

if [ ! -f "$CONFIG" ]; then
  error "Unable to find the configuration file [${CONFIG}]"
  exit 1
fi

value=$(cat ${CONFIG} | grep "^fusionauth.url" | awk -F'=' '{print $2}')
if [ -n "$value" ]; then
  URL="$value"
else
  error "Unable to find the configuration for [fusionauth.url]"
  exit 1
fi

value=$(cat ${CONFIG} | grep "^fusionauth.network_interface" | awk -F'=' '{print $2}')
if [ -n "$value" ]; then
  INTERFACE="$value"
else
  INTERFACE="eth0"
fi

# The application Id is required as the first parameter
if [[ $# -lt 1 ]]; then
  echo "The Application Id is required as the first parameter."
  exit 1
fi

APPLICATION_ID=$1
shift
# Take the remaining arguments as the role, it may contain a space.
ROLE="$@"

read -n1024 USER
read -n1024 PASSWORD

IP_ADDR=`ifconfig ${INTERFACE} | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'`

# Authenticate and verify role
if [ -n "$ROLE" ]; then

  RESULT=$(/usr/bin/curl -s -X POST -H 'Accept: application/json' -H 'Content-Type: application/json' -d \
         "{\"applicationId\": \"$APPLICATION_ID\", \"loginId\": \"$USER\", \"password\": \"$PASSWORD\", \"ipAddress\": \"$IP_ADDR\"}" ${URL}/api/login | jq \
         "contains({user: {registrations: [{applicationId: \"${APPLICATION_ID}\", roles:[\"${ROLE}\"] }] } })")

  STATUS=`echo $?`
  if [ ${STATUS} -eq 0 ]; then
    if [ "${RESULT}" == "true" ]; then
        exit 0
    fi
  fi

  exit 1

else

  # Authenticate and only verify registration
  STATUS=$(/usr/bin/curl -sw '%{http_code}' -X POST -H 'Accept: application/json' -H 'Content-Type: application/json' -d "{\"applicationId\": \"$APPLICATION_ID\", \"loginId\": \"$USER\", \"password\": \"$PASSWORD\", \"ipAddress\": \"$IP_ADDR\"}" -o /dev/null ${URL}/api/login)
  if [ "$STATUS" -ne 200 ]; then
      exit ${STATUS}
  fi

  exit 0

fi