#!/bin/bash
set -e

# EXAMPLES
#
# * Requesting a token
#
#   keystone.get_token
#
# * Getting the image properties
#
#   # Image JSON
#   # {
#   #   "size": 5242880000,
#   #   "id": "b4efbc2a-6130-4f2e-b436-55a618c4de20",
#   #   "checksum": "750a56555d4ec7303f5dc33b007ff632",
#   #   "disk_format": "raw",
#   #   "container_format": "bare",
#   #   "name": "Debian-7.0-Wheezy"
#   # }
#
#   for image in $(nova.image_list); do
#     echo $image | jq -r '.id'
#     echo $image | jq -r '.name'
#     echo $image | jq -r '.size'
#     echo $image | jq -r '.container_format'
#     echo $image | jq -r '.checksum'
#   done
#
# * Listing instances
#
#   for server in $(nova.list); do
#     echo $server | jq -r '.id'
#     echo $server | jq -r '.name'
#     echo $server | jq -r '.flavor'
#   done
#


OS_COMPUTE_URL="https://compute.dream.io:8774"
OS_GLANCE_URL="https://image.dream.io:9292"
OS_KEYSTONE_URL="https://keystone.dream.io"

nova.get_request() {
  keystone.get_token

  local url="$1"

  curl -s -X GET \
       --retry 3 \
       -H "X-Auth-Token: $OS_TOKEN" \
       -H "Content-Type: application/json" \
       -H "Accept: application/json" \
       $url
}

# Get a scoped token from keystone, required to authenticate further requests
keystone.get_token() {
  [ -n "$OS_TOKEN" ] && return

  local json='
  {
    "auth":
    {
      "tenantName": "'"$OS_TENANT_NAME"'",
      "passwordCredentials": {
        "username": "'"$OS_USERNAME"'", "password": "'"$OS_PASSWORD"'"
      }
    }
  }
  '

  local token=$(curl --retry 2 -s \
    -H "Content-type: application/json" \
    -H "Accept: application/json" \
    -d "$json" \
    $OS_KEYSTONE_URL/v2.0/tokens | jq -r '.access.token.id')
  export OS_TOKEN=$token
}

nova.image_delete() {
  id="$1"

  keystone.get_token

  if ! curl -s "$OS_COMPUTE_URL/v2/$OS_TENANT_ID/images/$id" \
             --retry 3 \
             -X DELETE \                                                                         -H "X-Auth-Project-Id: $OS_TENANT_NAME" \
             -H "Accept: application/json" \
             -H "X-Auth-Token: $OS_TOKEN"; then
    return 1
  fi
}

# List Glance images, one image per line, CSV format
nova.image_list() {
  nova.get_request "$OS_GLANCE_URL/v1/images" | jq -c '.images[]' | sed 's/^\[\]$//'
}

nova.list() {
  nova.get_request "$OS_COMPUTE_URL/v2/$OS_TENANT_ID/servers" \
    | jq -c '.servers[]' | sed 's/^\[\]$//'
}
