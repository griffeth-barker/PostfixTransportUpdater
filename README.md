# PostfixTransportUpdater
A simple script to update your Postfix transport file with the accepted domains from your Exchange Online environment.

## Use Case
If you use Microsoft Exchange Online for your email and have Postfix servers on-prem to handle SMTP relay, then you may want to ensure the Postfix transport file is kept up-to-date based on your accepted domains in Exchange Online. Some organizations may have this configured via another method while hosting their Exchange Server on-prem and find themselves in need of a new solution once migrating to Exchange Online.

## Prerequisites
You'll need the following for this to work:  
  - Network connectivity between the server where this script will run and the Postfix servers
  - Authentication between the account and server where this script will run and the Postfix servers (e.g. an account with some kind of askpass, or SSH pubkey authentication)
  - Access to the Entra ID admin portal and the ability to create an app registration, create a secret for the app registration, and assign API permissions to that app registration

## Instructions
### Set up app registration in Entra ID  
This won't be covered in depth here, but a high level overview is provided:
  1. Log into the Microsoft Entra ID portal and in the sidebar, expand Applications, then select App Registrations.  
  2. Create a new app registration. The name does not impact funtionality.
  3. Assign the Domains.Read.All API permission to the app registration.
  4. Create and securely document a secret for the app registration.

### Getting started with the script
Clone this repo onto the server where the script will run:  
```bash
git clone https://github.com/griffeth-barker/PostfixTransportUpdater.git
```

Once you've cloned the repo, update the `secret` file's contents to be the value of the secret for the app registration in Entra ID.
It is highly recommended that you restrict permissions to this file to only the owner.

**Just a reminder, the secret file in this repository is only a placeholder example with no secret in it; you should not ever commit secrets or credentials into repositories.**

You will also need to update the variables at the start of the script to reflect the app registration you created as well as next hops for your environment.

Finally, make the script executable:
```bash
chmod +x /path/to/PostfixTransportUpdater.sh
```

### Schedule the script
You can schedule this script to automatically run on a schedule by adding this line to crontab (be sure to update the file path to the real file path):
```
0 * * * * /path/to/PostfixTransportUpdater.sh
```

### Backups
The current transport file is backed up as "/etc/postfix/transport_DATE" prior to replacing it during each script run, so you can revert to it if needed.
You can optionally uncomment the cleanup at the end of the script, which will remove any backed up configurations older than 7 days to prevent /etc/postfix from becoming cluttered.
