from hmsclient import hmsclient

if len(argv) < 2:
    print("Usage: hms_createdb.py <dbname>")
    sys.exit(1)

dbn = argv[1]
ns  = os.getenv('HIVE_NAMESPACE')

if ns is None:
    ns = "trino"

hms    = f"hive-metastore.{ns}.svc.cluster.local"
client = hmsclient.HMSClient(host=hms, port=9083)

with client as c:
    newdb = hmsclient.Database(
        name=dbname
    )

    try:
        c.create_database(newdb)
    except Exception as e:
        print("Error creating database: ", e)
