#!/bin/sh
set -e

CB_HOST="couchbase-node1"
CB_USER="Administrator"
CB_PASS="password"
CB_BUCKET="demo"

wait_for_couchbase() {
  echo "Waiting for Couchbase on $CB_HOST..."
  until curl -sf "http://$CB_HOST:8091/ui/index.html" > /dev/null; do
    sleep 2
  done
  echo "Couchbase is up."
}

wait_for_couchbase

echo "Initializing cluster on node1..."
curl -sf -X POST "http://$CB_HOST:8091/clusterInit" \
  -d "hostname=couchbase-node1" \
  -d "username=$CB_USER" \
  -d "password=$CB_PASS" \
  -d "services=kv,n1ql,index" \
  -d "memoryQuota=512" \
  -d "indexMemoryQuota=256"

echo "Adding node2 to cluster..."
curl -sf -u "$CB_USER:$CB_PASS" \
  -X POST "http://$CB_HOST:8091/controller/addNode" \
  -d "hostname=couchbase-node2" \
  -d "user=$CB_USER" \
  -d "password=$CB_PASS" \
  -d "services=kv,n1ql,index"

echo "Adding node3 to cluster..."
curl -sf -u "$CB_USER:$CB_PASS" \
  -X POST "http://$CB_HOST:8091/controller/addNode" \
  -d "hostname=couchbase-node3" \
  -d "user=$CB_USER" \
  -d "password=$CB_PASS" \
  -d "services=kv,n1ql,index"

echo "Rebalancing cluster..."
curl -sf -u "$CB_USER:$CB_PASS" \
  -X POST "http://$CB_HOST:8091/controller/rebalance" \
  -d "knownNodes=ns_1@couchbase-node1,ns_1@couchbase-node2,ns_1@couchbase-node3"

sleep 5

echo "Creating bucket '$CB_BUCKET'..."
curl -sf -u "$CB_USER:$CB_PASS" \
  -X POST "http://$CB_HOST:8091/pools/default/buckets" \
  -d "name=$CB_BUCKET" \
  -d "bucketType=couchbase" \
  -d "ramQuota=256" \
  -d "replicaNumber=2"

sleep 3

echo "Creating primary index on '$CB_BUCKET'..."
curl -sf -u "$CB_USER:$CB_PASS" \
  -X POST "http://$CB_HOST:8093/query/service" \
  -d "statement=CREATE PRIMARY INDEX ON \`$CB_BUCKET\`"

echo "Couchbase cluster initialized successfully."
