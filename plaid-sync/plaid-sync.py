#!.env/bin/python

import argparse
import datetime
from datetime import tzinfo
import sys
from collections import namedtuple

import config
import plaidapi
from plaidapi import PlaidAccountUpdateNeeded, PlaidError
import pandas as pd
from influxdb_client import InfluxDBClient, Point, WritePrecision
from influxdb_client.client.write_api import SYNCHRONOUS, ASYNCHRONOUS
import os
from notion_client import Client
from notion_client.helpers import is_full_page
try:
    from rich import print
except ImportError:
    pass


def parse_options():
    parser = argparse.ArgumentParser(description="Synchronize Plaid transactions and balances to local SQLite3 database")

    def valid_date(value):
        try:
            return datetime.datetime.strptime(value, '%Y-%m-%d').date()
        except:
            parser.error("Cannot parse [%s] as valid YYYY-MM-DD date" % value)

    parser.add_argument("-v", "--verbose",    dest="verbose",        action='store_true',  help="If set, status messages will be output during sync process.")
    parser.add_argument("-c", "--config",     dest="config_file",    required=True,        help="[REQUIRED] Configuration filename", metavar="CONFIG_FILE")
    parser.add_argument("-b", "--balances",   dest="balances",       action='store_true',  help="If true, updated balance information (slow) is loaded. Defaults to false.")
    parser.add_argument("-d", "--dump",   dest="dump",       action='store_true',  help="If true, dump csv")
    parser.add_argument( "--dry",   dest="dry",       action='store_true',  help="If true, do not upload to influx")
    parser.add_argument("-s", "--start_date", dest="start_date",     type=valid_date,      help="[YYYY-MM-DD] Start date for querying transactions. If ommitted, 30 days ago is used.")
    parser.add_argument("-e", "--end_date",   dest="end_date",       type=valid_date,      help="[YYYY-MM-DD] End date for querying transactions. If ommitted, tomorrow is used.")
    parser.add_argument("--update-account",   dest="update_account",                       help="Specify the name of the account to run the update process for."
                                                                                                "To be used when Plaid returns an error that credetials are out of date for an account.")
    parser.add_argument("--link-account",     dest="link_account",                         help="Run with this option to set up an entirely new account through Plaid.")
    args = parser.parse_args()

    if not args.start_date:
        args.start_date = (datetime.datetime.now() - datetime.timedelta(days=14)).date()

    if not args.end_date:
        args.end_date = (datetime.datetime.now() + datetime.timedelta(days=1)).date()

    if args.end_date < args.start_date:
        parser.error("End date [%s] cannot be before start date [%s]" % ( args.end_date, args.start_date ) )
        sys.exit(1)

    return args


class SyncCounts(
        namedtuple("SyncCounts", [
            "new",
            "new_pending",
            "archived",
            "archived_pending",
            "total_fetched",
            "accounts",
        ])):
    pass


class PlaidSynchronizer:
    def __init__(self, db,
                 plaid: plaidapi.PlaidAPI, account_name: str,
                 access_token: str):
        self.transactions = {}
        self.balances = []
        self.db           = db
        self.plaid        = plaid
        self.account_name = account_name
        self.access_token = access_token
        self.plaid_error  = None
        self.item_info    = None
        self.counts       = SyncCounts(0,0,0,0,0,0)

    def add_transactions(self, transactions):
        self.transactions.update(
            dict(map(lambda t: (t.transaction_id, t), transactions)
        )
        )

    def count_pending(self, tids):
        return len([tid for tid in tids if self.transactions.get(tid) and self.transactions[tid].pending])

    def sync(self, cfg, start_date, end_date, fetch_balances=True, verbose=False):       
        try:       
            if verbose:
                print("Account: %s" % self.account_name)
                #print("    Fetching item (bank login) info")
            #self.item_info = self.plaid.get_item_info(self.access_token)
            if verbose:
                print('item info', self.item_info)
            if fetch_balances:
                if verbose:
                    print("     Fetching current balances")
                self.balances += self.plaid.get_account_balance(self.access_token)
            if verbose:
                print("    Fetching transactions from %s to %s" % (start_date, end_date))

            self.add_transactions(self.plaid.get_transactions(
                access_token    = self.access_token,
                start_date      = start_date,
                end_date        = end_date,
                status_callback = (lambda c,t: print("        %d/%d fetched" % ( c, t ) )) if verbose else None
            ) )
     
        except plaidapi.PlaidError as ex:
            self.plaid_error = ex
            raise
            
def upload(transactions, balances, cfg, start_date, end_date, verbose=False, dump=False, dry=False):
    old = {}
    client = InfluxDBClient(url=cfg.config['PLAID']['influx_url'], token=cfg.config['PLAID']['influx_token'],  org=cfg.config['PLAID']['influx_org'], timeout=200000)
    try:
        query_api = client.query_api()
        tables = query_api.query('''
        from(bucket: "%s")
          |> range(start: %s, stop: %s)
          |> filter(fn: (r) => r["_measurement"] == "transactions")
          |> group()
          |> sort(columns: ["_time"], desc: false)
        ''' %(cfg.config['PLAID']['influx_bucket'], start_date, end_date))
        for table in tables:
            for row in table.records:
                if row['id'] not in old:                    
                    old[row['id']] = row  #could be deleted transaction, track it here
                elif row['_value'] != 0:
                    old[row['id']] = row  # we should only have one transaction with non-zero value
    finally:
        client.close()
    
    lst = []
    for row in old.values():
        if row['_value'] != 0: # only track non-deleted transactions
            lst.append((row['_time'], row['payee'],row['memo'], row['_value'], row['category'], row['id'], row['account']))
    df = pd.DataFrame(lst, columns = ['Date', 'Description', 'Memo', 'Amount', 'Category', 'Check#', 'Account'])
    if verbose:
        print(df)
    if dump:
        df.to_csv('transactions.csv', index=False)
        return
    
    
    adict = {}
    for balance in balances:
        adict[balance.account_id] = balance.account_type
              
    client = InfluxDBClient(url=cfg.config['PLAID']['influx_url'], token=cfg.config['PLAID']['influx_token'], timeout=20000)            
    write_api = client.write_api(write_options=ASYNCHRONOUS)

    tt = list(transactions.values())
    tt.sort(key=lambda x : x.date)
    for t in tt:
        date = datetime.datetime.strptime(t.date, '%Y-%m-%d')                
        if (date.date() < start_date or date.date() > end_date):
            if verbose:
                print('skipping (out of range)', t)
            continue
        
        skip = True if t.transaction_id in old else False  
        if verbose:
            print('skip', skip, t)

        point = Point("transactions")\
        .tag("payee", t.merchant_name) \
        .tag("memo", t.name) \
        .tag('account', adict.get(t.account_id, None)) \
        .tag('category', t.category[-1]) \
        .tag('id', t.transaction_id) \
        .field('amount', -1.0 * t.amount)  \
        .time(int(date.timestamp() * 10**9), WritePrecision.NS)
        if balances and not skip:
            if verbose:
                print(point.to_line_protocol(), end='\n~~~~~~~~~~~~~~~~~~~~~~\n')
            if not dry:
                write_api.write(cfg.config['PLAID']['influx_bucket'], cfg.config['PLAID']['influx_org'], point)
    client.close()

    if balances:
        net = 0    
        types = {}
        for balance in balances:
            mult = -1.0 if balance.account_type == 'credit' else 1.0
            amnt = mult * balance.balance_current
            net += amnt
            if balance.account_type not in types:
                types[balance.account_type] = 0.0
            types[balance.account_type] += amnt
            if verbose:
                print('balance', balance.account_type, balance.balance_current, balance.balance_available, balance.balance_limit, balance.currency_code)
        
        ts = datetime.datetime.now().timestamp()          
        points = []
        for typ, v in types.items():
            if v == 0.0:
                continue
            point = Point("balances")\
            .tag('account',typ) \
            .field('amount', v)  \
            .time(int(ts * 10**9), WritePrecision.NS)
            if verbose:
                print(point.to_line_protocol(), end='\n~~~~~~~~~~~~~~~~~~~~~~\n')
            points.append(point)
        point = Point("balances")\
            .tag('account','net') \
            .field('amount', net)  \
            .time(int(ts * 10**9), WritePrecision.NS)
        if verbose:
            print(point.to_line_protocol(), end='\n~~~~~~~~~~~~~~~~~~~~~~\n')
        points.append(point)
        if points:
            client = InfluxDBClient(url=cfg.config['PLAID']['influx_url'], token=cfg.config['PLAID']['influx_token'], timeout=20000)
            try:
                write_api = client.write_api(write_options=ASYNCHRONOUS)
                if not dry:
                    write_api.write(cfg.config['PLAID']['influx_bucket'], cfg.config['PLAID']['influx_org'], points)
            finally:
                client.close()
        if verbose:
            print('balance Net = ', net)



def try_get_tqdm():
    try:
        import tqdm
        return tqdm.tqdm
    except: # NOQA E722
        return None


def update_account(cfg: config.Config, plaid: plaidapi.PlaidAPI, account_name: str):
    try:
        print("Starting account update process for [%s]" % account_name)

        if account_name not in cfg.get_enabled_accounts():
            print("Unknown account name [%s]." % account_name, file=sys.stderr)
            print("Configured accounts: ", file=sys.stderr)
            for account in cfg.get_enabled_accounts():
                print("    %s" % account, file=sys.stderr)
            sys.exit(1)

        if cfg.environment == "sandbox":
            print("\nSandbox mode. Resetting credentials prior to update.\n")
            try:
                plaid.sandbox_reset_login(cfg.get_account_access_token(account_name))
            except PlaidAccountUpdateNeeded:
                # the point is to get it into this state
                # so just ignore and proceed
                pass

        link_token = plaid.get_link_token(
            access_token=cfg.get_account_access_token(account_name)
        )

        import webserver
        plaid_response = webserver.serve(
            env=cfg.environment,
            clientName="plaid-sync",
            pageTitle="Update Account Credentials",
            type="update",
            accountName=account_name,
            token=link_token,
        )

        if 'public_token' not in plaid_response:
            print("No public token returned in the response.")
            print("The update process may not have been successful.")
            print("")
            print("This is OK. You can try syncing to confirm, or")
            print("retry the update process. The account data/link")
            print("is not lost.")
            sys.exit(1)

        public_token = plaid_response['public_token']
        print("")
        print(f"Public token obtained [{public_token}].")
        print("")
        print("There is nothing else to do, the account should sync "
              "properly now with the existing credentials.")

        sys.exit(0)
    except PlaidError as ex:
        print("")
        print("Unhandled exception during account update process.")
        print(ex)


def link_account(cfg: config.Config, plaid: plaidapi.PlaidAPI, account_name: str):
    if account_name in cfg.get_all_config_sections():
        print("Cannot link new account - the account name you selected")
        print("is already defined in your local configuration. Re-run with")
        print("a different name.")
        sys.exit(1)

    # need the special token to initiate a link attempt
    link_token = plaid.get_link_token()

    import webserver
    plaid_response = webserver.serve(
        env=cfg.environment,
        clientName="plaid-sync",
        pageTitle="Link New Account",
        type="link",
        accountName=account_name,
        token=link_token,
    )

    if 'public_token' not in plaid_response:
        print("**** WARNING ****")
        print("Plaid Link process did not return a public token to exchange for a permanent token.")
        print("If the process did complete, you may be able to recover the public token from the browser.")
        print("Check the webpage for the public token, and if you see it in the JSON response, re-run this")
        print("command with:")
        print("--link-account '%s' --link-account-token '<TOKEN>" % account_name)
        sys.exit(1)

    public_token = plaid_response['public_token']
    print("")
    print(f"Public token obtained [{public_token}]. "
          "Exchanging for access token.")

    try:
        exchange_response = plaid.exchange_public_token(public_token)
    except PlaidError as ex:
        print("**** WARNING ****")
        print("Error exchanging Plaid public token for access token.")
        print("")
        print(ex)
        print("")
        print("You can attempt the exchange again by re-runnning this command with:")
        print("--link-account '%s' --link-account-token '<TOKEN>" % account_name)
        sys.exit(1)

    access_token = exchange_response['access_token']

    print("Access token received: %s" % access_token)
    print("")

    print("Saving new link to configuration file")
    cfg.add_account(account_name, access_token)

    print("")
    print(f"{account_name} is linked and is ready to sync.")

    sys.exit(0)


def main():
    args = parse_options()
    cfg = config.Config(args.config_file)
    db = None 
      
    if args.dump:
        plaid = None
    else:
        notion = Client(auth=cfg.config['PLAID']['notion_secret'])
        full_or_partial_pages = notion.databases.query(database_id=cfg.config['PLAID']['notion_database'])
        plaid_rules = []
        for page in full_or_partial_pages["results"]:
            if not is_full_page(page):
                continue
            try:
                #print(page)
                #print(f"Created at: {page['created_time']}")
                if len(page['properties']['Replacement']['multi_select']):
                    replacement = page['properties']['Replacement']['multi_select'][0]['name']
                else:
                    replacement = None
                method = 'exact'
                key = None
                for t in page['properties']['Type']['multi_select']:
                    if t['name'] == 'in':
                        method = 'in'
                    else:
                        key = t['name']
                title = page['properties']['Rule']['title'][0]['text']['content']
                d = dict(replacement=replacement, title=title, method=method, key=key)
                plaid_rules.append(d)
            except Exception as e:
                print(e)
                continue
        if args.verbose:
            print('notion rules', plaid_rules)
        plaid = plaidapi.PlaidAPI(**cfg.get_plaid_client_config(), rules=plaid_rules)

    if args.update_account:
        update_account(cfg, plaid, args.update_account)
        return

    if args.link_account:
        link_account(cfg, plaid, args.link_account)
        return

    if not cfg.get_enabled_accounts():
        print("There are no configured Plaid accounts in the specified "
              "configuration file.")
        print("")
        print("Re-run with --link-account to add one.")
        sys.exit(1)

    results = {}
    def process_account(account_name):
        if args.dump:
            return
        sync = PlaidSynchronizer(db, plaid, account_name, cfg.get_account_access_token(account_name))
        sync.sync(cfg, args.start_date, args.end_date, fetch_balances=args.balances, verbose=args.verbose)
        results[account_name] = sync

    tqdm = try_get_tqdm() if not args.verbose else None
    if tqdm:
        for account_name in tqdm(cfg.get_enabled_accounts(), desc="Synchronizing Plaid accounts", leave=False):
            process_account(account_name)
    else:
        for account_name in cfg.get_enabled_accounts():
            process_account(account_name)

    print("")
    transactions = {}
    balances = []
    for res in results.values():
        transactions.update(res.transactions)
        balances += res.balances
    upload(transactions, balances, cfg, args.start_date, args.end_date, verbose=args.verbose, dump=args.dump, dry=args.dry)
    print("Finished syncing %d Plaid accounts" % (len(results)))

if __name__ == '__main__':
    main()
