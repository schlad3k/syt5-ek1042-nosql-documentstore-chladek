#!/bin/sh
set -e

CB_HOST="${CB_NODE1_IP:-172.28.0.2}"
CB_NODE1="${CB_NODE1_IP:-172.28.0.2}"
CB_NODE2="${CB_NODE2_IP:-172.28.0.3}"
CB_NODE3="${CB_NODE3_IP:-172.28.0.4}"
CB_USER="${CB_USER:-Administrator}"
CB_PASS="${CB_PASS:-password}"
CB_BUCKET="${CB_BUCKET:-demo}"
CB_MEMORY_QUOTA="${CB_MEMORY_QUOTA:-512}"
CB_INDEX_MEMORY_QUOTA="${CB_INDEX_MEMORY_QUOTA:-256}"
CB_REPLICA_COUNT="${CB_REPLICA_COUNT:-2}"

wait_for_pools() {
  local host=$1
  local attempts=0
  echo "Waiting for Couchbase on $host..."
  until curl -sf "http://$host:8091/pools" > /dev/null 2>&1; do
    attempts=$((attempts + 1))
    [ "$attempts" -ge 60 ] && echo "Timed out waiting for $host" && exit 1
    sleep 5
  done
  echo "$host is ready."
}

wait_for_pools_auth() {
  local host=$1
  local attempts=0
  echo "Waiting for Couchbase (with auth) on $host..."
  until curl -sf -u "$CB_USER:$CB_PASS" "http://$host:8091/pools/default" > /dev/null 2>&1; do
    attempts=$((attempts + 1))
    [ "$attempts" -ge 60 ] && echo "Timed out waiting for $host" && exit 1
    sleep 5
  done
  echo "$host is ready (authenticated)."
}

# --- Init Node1 ---
wait_for_pools "$CB_HOST"
sleep 5

echo "Setting up services on node1..."
curl -sf -X POST "http://$CB_HOST:8091/node/controller/setupServices" \
  -d "services=kv%2Cn1ql%2Cindex"

echo "Setting memory quotas..."
curl -sf -X POST "http://$CB_HOST:8091/pools/default" \
  -d "memoryQuota=$CB_MEMORY_QUOTA" \
  -d "indexMemoryQuota=$CB_INDEX_MEMORY_QUOTA"

echo "Setting admin credentials..."
curl -sf -X POST "http://$CB_HOST:8091/settings/web" \
  -d "username=$CB_USER" \
  -d "password=$CB_PASS" \
  -d "port=8091"

echo "Waiting for node1 to restart after credential setup..."
sleep 10
wait_for_pools_auth "$CB_HOST"
sleep 5

# --- Add Node2 ---
wait_for_pools "$CB_NODE2"
sleep 5

echo "Adding node2 to cluster..."
add2_body=$(curl -s -u "$CB_USER:$CB_PASS" \
  -X POST "http://$CB_HOST:8091/controller/addNode" \
  -d "hostname=$CB_NODE2" \
  -d "user=$CB_USER" \
  -d "password=$CB_PASS" \
  -d "services=kv%2Cn1ql%2Cindex")
echo "addNode node2 response: $add2_body"

# --- Add Node3 ---
wait_for_pools "$CB_NODE3"
sleep 5

echo "Adding node3 to cluster..."
add3_body=$(curl -s -u "$CB_USER:$CB_PASS" \
  -X POST "http://$CB_HOST:8091/controller/addNode" \
  -d "hostname=$CB_NODE3" \
  -d "user=$CB_USER" \
  -d "password=$CB_PASS" \
  -d "services=kv%2Cn1ql%2Cindex")
echo "addNode node3 response: $add3_body"

sleep 5

# --- Rebalance ---
echo "Rebalancing cluster..."
reb=$(curl -s -o /dev/null -w "%{http_code}" -u "$CB_USER:$CB_PASS" \
  -X POST "http://$CB_HOST:8091/controller/rebalance" \
  -d "knownNodes=ns_1%40$CB_NODE1%2Cns_1%40$CB_NODE2%2Cns_1%40$CB_NODE3")
echo "rebalance: $reb"
[ "$reb" = "200" ] || { echo "rebalance failed: $reb"; exit 1; }

echo "Waiting 30s for rebalance..."
sleep 30

# --- Bucket ---
echo "Creating bucket '$CB_BUCKET'..."
bkt=$(curl -s -o /dev/null -w "%{http_code}" -u "$CB_USER:$CB_PASS" \
  -X POST "http://$CB_HOST:8091/pools/default/buckets" \
  -d "name=$CB_BUCKET" \
  -d "bucketType=couchbase" \
  -d "ramQuota=256" \
  -d "replicaNumber=$CB_REPLICA_COUNT")
echo "bucket: $bkt"
[ "$bkt" = "202" ] || [ "$bkt" = "400" ] || { echo "bucket creation failed: $bkt"; exit 1; }

sleep 10

# --- Index Storage Mode ---
echo "Setting index storage mode..."
curl -s -u "$CB_USER:$CB_PASS" \
  -X POST "http://$CB_HOST:8091/settings/indexes" \
  -d "storageMode=forestdb"

sleep 5

# --- Primary Index ---
echo "Creating primary index..."
idx=$(curl -s -o /dev/null -w "%{http_code}" -u "$CB_USER:$CB_PASS" \
  -X POST "http://$CB_HOST:8093/query/service" \
  -d "statement=CREATE%20PRIMARY%20INDEX%20ON%20%60$CB_BUCKET%60")
echo "index: $idx"
[ "$idx" = "200" ] || [ "$idx" = "409" ] || { echo "index creation failed: $idx"; exit 1; }

echo "Couchbase cluster initialized successfully."
