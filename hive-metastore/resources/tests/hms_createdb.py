import os
import sys
from hmsclient import hmsclient

if len(sys.argv) < 2:
    print("Usage: hms_createdb.py <dbname>")
    sys.exit(1)

dbn  = sys.argv[1]
port = 9083
if len(sys.argv) > 2:
    port = sys.argv[2]

ns   = os.getenv('HIVE_NAMESPACE')
hms  = os.getenv('HIVE_DOMAINNAME')

if ns is None:
    ns = "trino"
    
if hms is None: 
    hms = f"hive-metastore.{ns}.svc.cluster.local"

client = hmsclient.HMSClient(host=hms, port=port)

with client as c:
    newdb = hmsclient.Database(
        name=dbn
    )
    try:
        c.create_database(newdb)
    except Exception as e:
        print("Error creating database: ", e)
