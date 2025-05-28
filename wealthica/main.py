import gspread
import pandas as pd


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

parser = argparse.ArgumentParser(description="Synchronize with InfluxDB database")
parser.add_argument("-v", "--verbose",    dest="verbose",        action='store_true',  help="If set, status messages will be output during sync process.")
parser.add_argument( "--dry",   dest="dry",       action='store_true',  help="If true, do not upload to influx")
args = parser.parse_args()

cfg = config.Config(config_file)

gc = gspread.api_key(cfg.config['WEALTHICA']['gspread_api_key'])
sh = gc.open_by_key(cfg.config['WEALTHICA']['gspread_sheet_key'])
worksheet = sh.sheet1
data = worksheet.get(cfg.config['WEALTHICA']['gspread_range'])
df = pd.DataFrame(data[1:], columns=data[0])

df['Trade Date'] = pd.to_datetime(df['Trade Date'], format='%Y-%m-%d')
df.set_index('Trade Date',  inplace=True)
df.sort_index(inplace=True)
df['Currency Amount'] = df['Currency Amount'].astype(float)

#with pd.option_context('display.max_rows', None):  # more options can be specified also
print(df)

sh = gc.open_by_key(cfg.config['WEALTHICA']['gspread_sheet_balances_key'])
worksheet = sh.sheet1
data = worksheet.get(cfg.config['WEALTHICA']['gspread_balances_range'])
dfb = pd.DataFrame(data[1:], columns=data[0])
print(dfb)

notion_secret = cfg.config['WEALTHICA']['notion_secret']
notion_database = cfg.config['WEALTHICA']['notion_database']
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
                    
        self.account_id     = data['account_id']
        self.date           = data['date']
        self.name           = data['name']        
        self.transaction_id = data['transaction_id']
        self.merchant_name  = data['merchant_name']
        self.amount         = data['amount']
        self.currency_code  = data['iso_currency_code']
        self.category       = data['category']

    def __str__(self):
        return "%s %s %s (%s) - %4.2f %s" % ( self.date, self.transaction_id, self.account_id, self.name, self.amount, self.category[-1])
    def __repr__(self):
        return self.__str__()


transactions = []
for date, row in df.iterrows():
    category = 'Other Expense' if row['Currency Amount'] < 0 else 'Other Income'
    t = dict(name=row['Description'], category=[category], date=date, account_id=str(row['Account Number']), transaction_id=row['ID'], iso_currency_code=row['Account Currency'], amount=row['Currency Amount'], merchant_name=None)
    skip = False
    for rule in filter_rules:
        if rule['method'] == 'exact' and rule['title'] == t[rule['key']]:
            skip = True
            break
        elif rule['method'] == 'in' and rule['title'] in t[rule['key']]:
            skip = True
            break
    if skip:
        print('filter', t)
        continue
    tt = Transaction(t, rules)
    transactions.append(tt)
    #print(tt)


def upload(transactions, cfg, start_date, end_date, verbose=False, dump=False, dry=False):
    old = {}
    client = InfluxDBClient(url=cfg.config['WEALTHICA']['influx_url'], token=cfg.config['WEALTHICA']['influx_token'],  org=cfg.config['WEALTHICA']['influx_org'], timeout=200000)
    try:
        query_api = client.query_api()
        tables = query_api.query('''
        from(bucket: "%s")
          |> range(start: %s, stop: %s)
          |> filter(fn: (r) => r["_measurement"] == "transactions")
          |> group()
          |> sort(columns: ["_time"], desc: false)
        ''' %(cfg.config['WEALTHICA']['influx_bucket'], start_date, end_date))
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
                  
    client = InfluxDBClient(url=cfg.config['WEALTHICA']['influx_url'], token=cfg.config['WEALTHICA']['influx_token'], timeout=20000)            
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
                write_api.write(cfg.config['WEALTHICA']['influx_bucket'], cfg.config['WEALTHICA']['influx_org'], point)
        if verbose:
            print('skip', skip, t)

        point = Point("transactions")\
        .tag("payee", t.merchant_name) \
        .tag("memo", t.name) \
        .tag('account', 'NA') \
        .tag('category', t.category[-1]) \
        .tag('id', t.transaction_id) \
        .field('amount', t.amount)  \
        .time(int(date.timestamp() * 10**9), WritePrecision.NS)
        if not skip:
            #if verbose:
            #    print(point.to_line_protocol(), end='\n~~~~~~~~~~~~~~~~~~~~~~\n')
            if not dry:
                write_api.write(cfg.config['WEALTHICA']['influx_bucket'], cfg.config['WEALTHICA']['influx_org'], point)

    client.close()

    net = 0    
    types = {}
    for _, row in dfb.iterrows():
        amnt = float(row['Balance'])
        net += amnt
        atype = row['Account Type']
        if atype not in types:
            types[atype] = 0.0
        types[atype]  += amnt
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
        client = InfluxDBClient(url=cfg.config['WEALTHICA']['influx_url'], token=cfg.config['WEALTHICA']['influx_token'], timeout=20000)
        try:
            write_api = client.write_api(write_options=ASYNCHRONOUS)
            if not dry:
                write_api.write(cfg.config['WEALTHICA']['influx_bucket'], cfg.config['WEALTHICA']['influx_org'], points)
        finally:
            client.close()
    if verbose:
        print('balance Net = ', net)





start_date = df.index.min().date()
end_date = (df.index.max() + datetime.timedelta(days=1)).date()
upload(transactions,cfg, start_date, end_date, verbose=args.verbose, dump=False, dry=args.dry)

