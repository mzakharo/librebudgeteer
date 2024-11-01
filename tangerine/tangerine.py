import pandas as pd
import os
import glob
import joblib
from notion_client import Client
from notion_client.helpers import is_full_page
import config
from influxdb_client import InfluxDBClient, Point, WritePrecision
from influxdb_client.client.write_api import SYNCHRONOUS, ASYNCHRONOUS
import argparse
import datetime
import sys


config_file = 'config.ini'

parser = argparse.ArgumentParser(description="Synchronize tangerine with InfluxDB database")
parser.add_argument("-v", "--verbose",    dest="verbose",        action='store_true',  help="If set, status messages will be output during sync process.")
parser.add_argument( "--dry",   dest="dry",       action='store_true',  help="If true, do not upload to influx")
parser.add_argument('path', help="path with Tangerine CSV files")
args = parser.parse_args()

cfg = config.Config(config_file)


all_files = glob.glob(os.path.join(args.path, "*.csv"))

df = pd.concat((pd.read_csv(f) for f in all_files), ignore_index=True)

df['Date'] = df['Transaction date'].combine_first(df['Date'])
df.pop('Transaction date')
df['Date'] = pd.to_datetime(df['Date'], format='%m/%d/%Y')
df.set_index('Date',  inplace=True)
df.sort_index(inplace=True)
df['hash'] = df.apply(joblib.hash, axis=1)

for _, dup in df[df.duplicated('hash', keep='first')].iterrows():
    l = []
    for (i, ( _, d))in enumerate(df.loc[df['hash'] == dup['hash']].iterrows()):
        l.append(d['hash'] + f'_{i}')
    df.loc[df['hash'] == dup['hash'], 'hash']= l

with pd.option_context('display.max_rows', None):  # more options can be specified also
    print(df)
#sys.exit(0)

notion_secret = cfg.config['TANGERINE']['notion_secret']
notion_database = cfg.config['TANGERINE']['notion_database']
notion = Client(auth=notion_secret)

full_or_partial_pages = notion.databases.query(database_id=notion_database)
rules = []
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
        if len(page['properties']['Rule']['title']) == 0:
            continue
        title = page['properties']['Rule']['title'][0]['text']['content']
        d = dict(replacement=replacement, title=title, method=method, key=key)
        rules.append(d)
    except Exception as e:
        raise
if args.verbose:
    print('notion rules', rules)
    
filter_rules = list(filter(lambda d: d['replacement'] is None, rules))
if args.verbose:
    print('filter rules', filter_rules)





class Transaction:
    def __init__(self, data, rules=[]):
        self.raw_data = data
        if not data['merchant_name']:
            data['merchant_name'] = data['name']
        old = data['category'][-1]
        for rule in rules:
            if rule['replacement'] is None:
                continue
            if rule['key'] in ['merchant_name', 'name']:
                if rule['method'] == 'exact' and data[rule['key']] == rule['title']:
                    data['category'][-1] = rule['replacement']
                elif rule['method'] == 'in' and rule['title'] in data[rule['key']]:
                    data['category'][-1] = rule['replacement']
            elif rule['key'] == 'category':
                if rule['method'] == 'exact' and data[rule['key']][-1] == rule['title']:
                    data['category'][-1] = rule['replacement']
                elif rule['method'] == 'in' and rule['title'] in data[rule['key']][-1]:
                    data['category'][-1] = rule['replacement']     
                    
        new = data['category'][-1]
        #if old != new:
        #    print(data['name'], old,  new)
        self.account_id     = data['account_id']
        self.date           = data['authorized_date'] if data['authorized_date'] is not None else data['date']
        self.name           = data['name']        
        #print(self.name, data['date'], data['amount'] , data['transaction_id'])
        self.transaction_id = data['transaction_id']
        self.pending        = data['pending']
        self.merchant_name  = data['merchant_name']
        self.amount         = data['amount']
        self.currency_code  = data['iso_currency_code']
        self.category       = data['category']

    def __str__(self):
        return "%s %s %s (%s) - %4.2f %s" % ( self.date, self.transaction_id, self.merchant_name, self.name, self.amount, self.category[-1])
    def __repr__(self):
        return self.__str__()


def upload(transactions, cfg, start_date, end_date, verbose=False, dump=False, dry=False):
    old = {}
    client = InfluxDBClient(url=cfg.config['TANGERINE']['influx_url'], token=cfg.config['TANGERINE']['influx_token'],  org=cfg.config['TANGERINE']['influx_org'], timeout=200000)
    try:
        query_api = client.query_api()
        tables = query_api.query('''
        from(bucket: "%s")
          |> range(start: %s, stop: %s)
          |> filter(fn: (r) => r["_measurement"] == "transactions")
          |> group()
          |> sort(columns: ["_time"], desc: false)
        ''' %(cfg.config['TANGERINE']['influx_bucket'], start_date, end_date))
        for table in tables:
            for row in table.records:
                row['old'] = True if row['_value'] == 0 else False
                if row['id'] not in old:                    
                    old[row['id']] = row  #could be deleted transaction, track it here
                elif row['_value'] != 0:
                    if old[row['id']]['old']:
                        row['old'] = True
                    old[row['id']] = row  # we should only have one transaction with non-zero value
                elif row['_value'] == 0:
                    old[row['id']]['old'] = True
                
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
                  
    client = InfluxDBClient(url=cfg.config['TANGERINE']['influx_url'], token=cfg.config['TANGERINE']['influx_token'], timeout=20000)            
    write_api = client.write_api(write_options=ASYNCHRONOUS)

    tt = transactions
    tt.sort(key=lambda x : x.date)
    for t in tt:
        date = t.date               
        if (date.date() < start_date or date.date() > end_date):
            if verbose:
                print('skipping (out of range)', t)
            continue
        
        skip = True if t.transaction_id in old else False

        if skip and t.category[-1] != old[t.transaction_id]['category'] and not old[t.transaction_id]['old']:
            skip = False
            tt = old[t.transaction_id]
            print(tt)
            point = Point("transactions")\
            .tag("payee", tt['payee']) \
            .tag("memo", tt['memo']) \
            .tag('account', tt['account']) \
            .tag('category', tt['category']) \
            .tag('id', tt['id']) \
            .field('amount', 0.0)  \
            .time(int(date.timestamp() * 10**9), WritePrecision.NS)
            if verbose:
                print(point.to_line_protocol(), end='\n~~~~~~~~~~~~~~~~~~~~~~\n')
            if not dry:
                write_api.write(cfg.config['TANGERINE']['influx_bucket'], cfg.config['TANGERINE']['influx_org'], point)
        if verbose:
            print('skip', skip, t)

        point = Point("transactions")\
        .tag("payee", t.merchant_name) \
        .tag("memo", t.name) \
        .tag('account', t.account_id) \
        .tag('category', t.category[-1]) \
        .tag('id', t.transaction_id) \
        .field('amount', t.amount)  \
        .time(int(date.timestamp() * 10**9), WritePrecision.NS)
        if not skip:
            #if verbose:
            #    print(point.to_line_protocol(), end='\n~~~~~~~~~~~~~~~~~~~~~~\n')
            if not dry:
                write_api.write(cfg.config['TANGERINE']['influx_bucket'], cfg.config['TANGERINE']['influx_org'], point)
    client.close()

transactions = []
for date, row in df.iterrows():
    try:
        category = row['Memo'].split('Category:')
    except AttributeError:
        category = []
    if len(category) == 2:
        category = category[-1].strip()
        if category == 'Other':
            category = 'Other Expense' if row['Amount'] < 0 else 'Other Income'
        #print(f'category = "{category}"')
    else:
        category = 'Other Expense' if row['Amount'] < 0 else 'Other Income'
    t = dict(name=row['Name'], category=[category], date=date, account_id='NA', transaction_id=row['hash'], pending=False, iso_currency_code='CA', amount=row['Amount'], merchant_name=None, authorized_date=None)
    
    skip = False
    for rule in filter_rules:
        if rule['method'] == 'exact' and rule['title'] == t[rule['key']]:
            skip = True
            break
        elif rule['method'] == 'in' and rule['title'] in t[rule['key']]:
            skip = True
            break
    if t['pending']:
        skip = True
    if skip:
        print('filter', t)
        continue
    transactions.append(Transaction(t, rules))



start_date = df.index.min().date()
end_date = (df.index.max() + datetime.timedelta(days=1)).date()







upload(transactions,cfg, start_date, end_date, verbose=args.verbose, dump=False, dry=args.dry)

