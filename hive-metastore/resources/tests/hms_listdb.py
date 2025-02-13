from hmsclient import hmsclient

ns  = os.getenv('HIVE_NAMESPACE')

if ns is None:
    ns = "trino"

hms = f"hive-metastore.{ns}.svc.cluster.local"

client = hmsclient.HMSClient(host=hms, port=9083)

with client as c:
    dbs = c.get_all_databases()
    print(dbs)
