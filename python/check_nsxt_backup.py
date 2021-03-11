#!/usr/bin/env python
"""
Nagios check to monitor NSX-T backup status
Florian Grehl - www.virten.net

usage: check_nsxt_backup.py [-h] -n NSX_HOST [-t TCP_PORT] -u USER -p PASSWORD
                            [-i] [-a MAX_AGE]
"""

import requests
import urllib3
import argparse
import json
from datetime import datetime
from time import time 
import sys

def getargs():
    arg_parser = argparse.ArgumentParser()
    arg_parser.add_argument('-n', '--nsx_host', type=str, required=True, help='NSX-T Manager host')
    arg_parser.add_argument('-t', '--tcp_port', type=int, default=443, help='NSX-T Managet TCP port')
    arg_parser.add_argument('-u', '--user', type=str, required=True, help='NSX-T user')
    arg_parser.add_argument('-p', '--password', type=str, required=True, help='Password')
    arg_parser.add_argument('-i', '--insecure', default=False, action='store_true', help='Ignore SSL errors')
    arg_parser.add_argument('-a', '--max_age', type=int, default=1440, help='Backup maximum age (minutes)')
    parser = arg_parser
    args = parser.parse_args()
    return args

def main():
    args = getargs()
    session = requests.session()

    # Disable server certificate verification.
    if (args.insecure):
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
        session.verify = False

    session.auth = (args.user, args.password)
    response = session.get('https://' + args.nsx_host + '/api/v1/cluster/backups/history')
    if (response.status_code !=200):
        print ('Could not connect to NSX-T')
        sys.exit(2)

    data = response.json()
    now = int(time())
    error = False
    for key, value in data.items():
        age = int(now-(value[0]['end_time']/1000))/60
        if (age>args.max_age):
            print ('NSX-T ' + key.replace('_backup_statuses','') + ' backup is to old (' + str(age) + ' minutes)')
            error = True
        if (not value[0]['success']):
            print ('NSX-T ' + key.replace('_backup_statuses','') + ' backup failed')
            error = True
    
    if (error):
        sys.exit(2)
    else:
        print ('OK')

if __name__ == "__main__":
    main()
