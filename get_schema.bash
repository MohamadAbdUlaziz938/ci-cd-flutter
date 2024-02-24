#!/bin/bash

while getopts "u:k:" opt; do
  case $opt in
    u) ENDPOINT_URL=$OPTARG ;;
    k) SECRET_KEY=$OPTARG ;;
    \?) echo "Invalid option: -$OPTARG" >&2
        exit 1 ;;
  esac
done
OUTPUT_FILE="schema.graphql"
# Check if the endpoint URL and secret key are provided
if [ -z "$ENDPOINT_URL" ] || [ -z "$SECRET_KEY" ]; then
    echo "Usage: ./get_schema.sh <ENDPOINT_URL> <SECRET_KEY>"
    exit 1
fi
if ! command -v jq &> /dev/null; then
    echo "jq is not installed. Installing..."

    # Install jq using package manager
    if [[ "$(uname)" == "Darwin" ]]; then
        brew install jq
    elif [[ "$(uname)" == "Linux" ]]; then
        if [[ -f /etc/os-release ]]; then
            source /etc/os-release
            if [[ $ID == "ubuntu" || $ID_LIKE == "debian" ]]; then
                sudo apt-get update
                sudo apt-get install -y jq
            elif [[ $ID == "centos" || $ID_LIKE == "rhel fedora" ]]; then
                sudo yum install -y epel-release
                sudo yum install -y jq
            fi
        fi
    fi
fi

# Fetch the schema using curl
RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "x-hasura-admin-secret:$SECRET_KEY" \
  -d '{"query":"{ __schema { types { name kind } } }"}' \
  "$ENDPOINT_URL")

# Check if the request was successful
STATUS=$(echo "$RESPONSE" | jq -r '.data | if has("__schema") then "success" else "error" end')

if [ "$STATUS" = "success" ]; then
  # Extract the schema from the response
  SCHEMA=$(echo "$RESPONSE" | jq -r '.data | .__schema')

  # Save the schema to the output file
  echo "$SCHEMA" > "$OUTPUT_FILE"

  echo "Schema saved to $OUTPUT_FILE"
else
  # Display the error message
  ERROR=$(echo "$RESPONSE" | jq -r '.errors[0].message')
  echo "Failed to fetch schema: $ERROR"
fi