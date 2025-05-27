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

parser = argparse.ArgumentParser(description="Synchronize tangerine with InfluxDB database")
parser.add_argument("-v", "--verbose",    dest="verbose",        action='store_true',  help="If set, status messages will be output during sync process.")
parser.add_argument( "--dry",   dest="dry",       action='store_true',  help="If true, do not upload to influx")
args = parser.parse_args()

cfg = config.Config(config_file)

gc = gspread.api_key(cfg.config['WEALTHICA']['gspread_api_key'])
sh = gc.open_by_key(cfg.config['WEALTHICA']['gspread_sheet_key'])
worksheet = sh.sheet1
data = worksheet.get(cfg.config['WEALTHICA']['gspread_range'])
df = pd.DataFrame(data[1:], columns=data[0])
print(df)


with pd.option_context('display.max_rows', None):  # more options can be specified also
    print(df)

