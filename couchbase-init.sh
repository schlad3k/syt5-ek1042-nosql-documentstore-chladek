#!/bin/sh
set -e

CB_HOST="couchbase-node1"
CB_USER="Administrator"
CB_PASS="password"
CB_BUCKET="demo"

wait_for_node() {
  local host=$1
  local attempts=0
  echo "Waiting for Couchbase on $host..."
  until curl -sf "http://$host:8091/ui/index.html" > /dev/null; do
    attempts=$((attempts + 1))
    [ "$attempts" -ge 60 ] && echo "Timed out waiting for $host" && exit 1
    sleep 5
  done
  echo "$host is up."
}

wait_for_node "$CB_HOST"

echo "Initializing cluster on node1..."
cluster_init_status=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://$CB_HOST:8091/clusterInit" \
  -d "hostname=couchbase-node1" \
  -d "username=$CB_USER" \
  -d "password=$CB_PASS" \
  -d "services=kv,n1ql,index" \
  -d "memoryQuota=512" \
  -d "indexMemoryQuota=256" \
  -d "clusterName=demo-cluster")
[ "$cluster_init_status" = "200" ] || [ "$cluster_init_status" = "400" ] || { echo "clusterInit failed: $cluster_init_status"; exit 1; }

wait_for_node "couchbase-node2"

echo "Adding node2 to cluster..."
add_node2_status=$(curl -s -o /dev/null -w "%{http_code}" -u "$CB_USER:$CB_PASS" \
  -X POST "http://$CB_HOST:8091/controller/addNode" \
  -d "hostname=couchbase-node2" \
  -d "user=$CB_USER" \
  -d "password=$CB_PASS" \
  -d "services=kv,n1ql,index")
[ "$add_node2_status" = "200" ] || [ "$add_node2_status" = "400" ] || { echo "addNode node2 failed: $add_node2_status"; exit 1; }

wait_for_node "couchbase-node3"

echo "Adding node3 to cluster..."
add_node3_status=$(curl -s -o /dev/null -w "%{http_code}" -u "$CB_USER:$CB_PASS" \
  -X POST "http://$CB_HOST:8091/controller/addNode" \
  -d "hostname=couchbase-node3" \
  -d "user=$CB_USER" \
  -d "password=$CB_PASS" \
  -d "services=kv,n1ql,index")
[ "$add_node3_status" = "200" ] || [ "$add_node3_status" = "400" ] || { echo "addNode node3 failed: $add_node3_status"; exit 1; }

echo "Rebalancing cluster..."
curl -sf -u "$CB_USER:$CB_PASS" \
  -X POST "http://$CB_HOST:8091/controller/rebalance" \
  -d "knownNodes=ns_1@couchbase-node1,ns_1@couchbase-node2,ns_1@couchbase-node3"

echo "Waiting for rebalance to complete..."
until curl -sf -u "$CB_USER:$CB_PASS" \
    "http://$CB_HOST:8091/pools/default/rebalanceProgress" \
  | grep -q '"status":"none"'; do
  sleep 3
done

echo "Creating bucket '$CB_BUCKET'..."
bucket_status=$(curl -s -o /dev/null -w "%{http_code}" -u "$CB_USER:$CB_PASS" \
  -X POST "http://$CB_HOST:8091/pools/default/buckets" \
  -d "name=$CB_BUCKET" \
  -d "bucketType=couchbase" \
  -d "ramQuota=256" \
  -d "replicaNumber=2")
[ "$bucket_status" = "202" ] || [ "$bucket_status" = "400" ] || { echo "bucket creation failed: $bucket_status"; exit 1; }

sleep 3

echo "Creating primary index on '$CB_BUCKET'..."
index_status=$(curl -s -o /dev/null -w "%{http_code}" -u "$CB_USER:$CB_PASS" \
  -X POST "http://$CB_HOST:8093/query/service" \
  -d "statement=CREATE PRIMARY INDEX ON \`$CB_BUCKET\`")
[ "$index_status" = "200" ] || [ "$index_status" = "409" ] || { echo "index creation failed: $index_status"; exit 1; }

echo "Couchbase cluster initialized successfully."
