
Original sources taken from https://github.com/mbafford/plaid-sync

# Overview

`plaid-sync` is a Python based command-line interface to the [Plaid API](https://plaid.com/docs/api/) that synchronizes your bank/credit card transactions to InfluxDB Database

# Usage

## Installation

python[3] -m pip install -r requirements.txt

## Configuration

Establish a configuration file with your Plaid credentials. This is in standard INI format. There is an example file `config/sandbox.example`. Copy this file to sandbox.example in the root directory.

Once you've set up the basic credentials, run through linking a new account:

```$ python[3] plaid-sync.py -c sandbox.example --link 'Test Chase'

Open the following page in your browser to continue:
    http://127.0.0.1:4583/link.html
```

Open the above link, follow the instructions (click the button, find your bank, enter credentials).

The console will then update with confirmation:

```Public token obtained [public-sandbox-XXXX]. Exchanging for access token.
Access token received: access-sandbox-XXXX

Saving new link to configuration file
Backing up existing configuration to: config/sandbox.1605537592.bkp
Overwriting existing config file: config/sandbox

Test Chase is linked and is ready to sync.
```

Your config file will have updated to have a line for this new account:

```
[Test Chase]
access_token = access-sandbox-XXXX
```

And you can now run the sync process:

```
$ ./plaid-sync.py -c sandbox.example -v -b
                                                                                       
```

## Updating an Expired Account

Occasionally you'll get an error like this while syncing:

```./plaid-sync.py -c sandbox.example                    

Finished syncing 2 Plaid accounts

Test Chase :  0 new transactions (0 pending),  0 archived transactions over 0 accounts
           : *** Plaid Error ***
           : ITEM_LOGIN_REQUIRED: the login details
           : of this item have changed (credentials,
           : MFA, or required user action) and a user
           : login is required to update this
           : information. use Link's update mode to
           : restore the item to a good state
           : *** re-run with: ***
           : --update 'Test Chase'
           : to fix
```

This just means your bank either isn't accepting the old credentials, or has a setup/arrangement where the login needs to be refreshed periodically. 

This process requires the Plaid Link (web browser) process again, but it's fairly painless. 

Just run the update process:

```
$ ./plaid-sync.py -c sandbox.example --update 'Test Chase'
Starting account update process for [Test Chase]

Open the following page in your browser to continue:
    http://127.0.0.1:4583/link.html
```

Open the page in your browser, click the button, enter new credentials, return to the console, confirm the process completed:

```
Public token obtained [public-sandbox-be30eb9a-8bcb-4dd0-9cf5-048ca7dfa5a3].

There is nothing else to do, the account should sync properly now with the existing credentials.
```

The sync process should run normally again.

# WARNINGS

When linking/setting up a new account, your public token (temporary) and access token (permanent) cannot be recovered if lost. I've taken care to show them to you during this process in both the browser and the command line so you can recover the flow if 
something goes wrong. Once you've saved the access token, you don't need the public token anymore.

This is important for accounts in the "test" level, as there is a 100 lifetime account limit.

