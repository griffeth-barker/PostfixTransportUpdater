# SYNOPSIS
#  This script automatically updates the Postfix transport file.
# DESCRIPTION
#  This script automatically updates the Postfix transport file based on accepted domains in Exchange Online,
#  obtained using the Microsoft Graph API. Specified domains are mapped to Exchange Online, while the wildcard
#  entry is mapped to your preferred smarthost.
# NOTES
#  Author         : Griff Barker (github@griff.systems)
#  Creation Date  : 2025-02-26
#  Purpose/Change : Initial script development
#
#  This script requires an App Registration created in Microsoft Entra ID, along with a secret for that app
#  registration, whose value is contained in a file called "secret" in the same directory as this script.
#  
#  This script will run on one server, get the accepted domains using the Graph API, then connect to each 
#  Postfix server to update their transport configurations, so network access and a method of authentication 
#  between them such as an SSH key will be required.

#!/bin/bash

# Declare constant variables
# Populate this list with your Postfix servers
SERVER_LIST=("192.168.254.163" "192.168.254.166") 
NEW_TRANSPORT_NAME="postfix_transport_${uuidgen}"
# Tenant ID as displayed on the overview page for your app registration in Entra ID
TENANT_ID="5769b52a-7b03-4c0d-8f28-8b086606617a"
# Application ID as displayed on the overview page for your app registration in Entra ID
CLIENT_ID="540a2c66-1932-4a64-bc6f-31767c46be71"
# Secret for the app registration in Entra ID.
# This file's permissions should be tightened to at least mode 700. 
# You could directly specify the secret value here, but that is not recommended. 
# It could also be replaced with code accessomg a key vault or similar.
CLIENT_SECRET=$(cat ./secret) 
SCOPE="https://graph.microsoft.com/.default"
GRANT_TYPE="client_credentials"
# Next hop for Exchange Online
# Update this with your tenant's name
ROUTE_EXCHANGEONLINE="[yourTenantName-com.mail.protection.outlook.com]"
# Next hop for all other mail
# Update this with the FQDN of your smarthost (Mimecast, SendGrid, etc.)
ROUTE_OTHER="[yourSmartHost.domain.tld]"

# Dependency handling
# This uses yum be default, but you should swap out for whatever package manager
# you're using on the server where this script will run.
if ! command -v jq &> /dev/null; then
    sudo yum install -y jq
fi
if ! command -v curl &> /dev/null; then
    sudo yum install -y curl
fi

ACCESS_TOKEN=$(curl -s -X POST -d "client_id=$CLIENT_ID&scope=$SCOPE&client_secret=$CLIENT_SECRET&grant_type=$GRANT_TYPE" https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token | jq -r '.access_token')
ACCEPTED_DOMAINS=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" "https://graph.microsoft.com/v1.0/domains" | jq -r '.value[].id')

for DOMAIN in $ACCEPTED_DOMAINS; do
  echo "${DOMAIN} smtp:${ROUTE_EXCHANGEONLINE}" >> /tmp/$NEW_TRANSPORT_NAME
done
echo "* $ROUTE_OTHER" >> /tmp/$NEW_TRANSPORT_NAME

for SERVER in "${SERVER_LIST[@]}"; do
  echo "Updating /etc/postfix/transport and reloading Postfixon $SERVER..."
  scp "/tmp/$NEW_TRANSPORT_NAME" "$SERVER:/tmp/$NEW_TRANSPORT_NAME"
  ssh "$SERVER" "mv /etc/postfix/transport /etc/postfix/transport_$(date +"%Y%m%d") && mv /tmp/$NEW_TRANSPORT_NAME /etc/postfix/transport && postfix reload"
done

rm /tmp/$NEW_TRANSPORT_NAME
# Optionally, you can uncomment the below line to clean up the /etc/postfix directory during each script run by removing backed up transport files older than 7 days.
# find /etc/postfix -name "transport_*" -type f -mtime +7 -exec rm -f {} \;
