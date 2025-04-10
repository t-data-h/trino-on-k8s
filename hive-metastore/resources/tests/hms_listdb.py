import os
import sys
from hmsclient import hmsclient

hms = ""
ns   = os.getenv('HIVE_NAMESPACE')
port = os.getenv('HIVE_SERVICE_PORT') 

if ns is None:
    ns = "trino"
    
if port is None:
    port = 9083

if len(sys.argv) > 1:
    hms = sys.argv[1]
    if len(sys.argv) > 2:
        port = sys.argv[2]
else:
    hms = f"hive-metastore.{ns}.svc.cluster.local"

client = hmsclient.HMSClient(host=hms, port=port)

with client as c:
    dbs = c.get_all_databases()
    print(dbs)
