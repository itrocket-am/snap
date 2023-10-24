#!/bin/bash
# Start command: sudo /bin/bash snap.sh

# read '${PROJECT}.json'
PROJECT=$(awk -F/ '/link:/ {print $4}' snap.conf)
TYPE=$(sed -n "/link:/s/.*https:\/\/\([^\.]*\)\..*/\1/p" snap.conf)
PR_USER=$(sed -n "/prHome:/s/.*'\([^']*\)'.*/\1/p" snap.conf | awk -F/ '{print $NF}')
SERVICE=$(sed -n "/bin:/s/.*'\([^']*\)'.*/\1/p" snap.conf)
BIN=$(sed -n "/binHome:/s/.*'\([^']*\)'.*/\1/p" snap.conf)
PORT=$(sed -n "/port:/s/.*'\([^']*\)'.*/\1/p" snap.conf)
RPC="https://${PROJECT}-${TYPE}-rpc.itrocket.net:443"
PEERID=$(sed -n "/peerID:/s/.*'\([^']*\)'.*/\1/p" snap.conf)
PEERPORT=$(sed -n "/peerPort:/s/.*'\([^']*\)'.*/\1/p" snap.conf)
PEERS=${PEERID}@${PROJECT}-${TYPE}-peer.itrocket.net:${PEERPORT}
snapMaxSize=$(sed -n "/snapMaxSize:/s/.*'\([^']*\)'.*/\1/p" snap.conf)
PR_PATH=$(sed -n "/path:/s/.*'\([^']*\)'.*/\1/p" snap.conf)
NODE_PATH=/home/${PR_USER}/${PR_PATH}
RESET=$(sed -n "/reset:/s/.*'\([^']*\)'.*/\1/p" snap.conf)
rpcStatus=$(sed -n "/rpcStatus:/s/.*'\([^']*\)'.*/\1/p" snap.conf)
CHAT_ID_ALARM=$(sed -n "/chat_id_alarm:/s/.*'\([^']*\)'.*/\1/p" snap.conf)
BOT_TOKEN=$(sed -n "/bot_token:/s/.*'\([^']*\)'.*/\1/p" snap.conf)
SLEEP=$(sed -n "/sleep:/s/.*'\([^']*\)'.*/\1/p" snap.conf)

# Check folder on the file server
PUBLIC_FOLDER=/var/www/$TYPE-files/$PROJECT
if [ -d "$PUBLIC_FOLDER" ]; then
    echo "$PUBLIC_FOLDER folder exists."
    else
    mkdir /var/www/$TYPE-files/$PROJECT
    echo "$PUBLIC_FOLDER folder created."
fi
# Check pre_rpc file on the file server
PRE_FILE=/home/$PR_USER/snap/rpc_combined.txt

if [ -f "$PRE_FILE" ]; then
    echo "$PRE_FILE file exists."
else
    touch "$PRE_FILE"
    echo "$PRE_FILE file created."
fi

#Check: is there a genesis file on the file server folder
FILE=/var/www/$TYPE-files/$PROJECT/genesis.json
if test -f "$FILE"; then
    echo "$FILE file exists." && sleep 1
    else
    cp -r $NODE_PATH/config/genesis.json $PUBLIC_FOLDER
    echo "genesys file moved" && sleep 1
fi

while ! nc -z localhost ${PORT}657; do
  echo -e "\033[0;31m$PROJECT node localhost:${PORT}657 status failed, waiting 5 sec and retrying...\033[0m"
  sleep 5
done
SNAP_HEIGHT=$(curl -s localhost:${PORT}657/status | jq -r .result.sync_info.latest_block_height)
systemctl stop $SERVICE && cd $NODE_PATH
rm $NODE_PATH/snap_$PROJECT.tar.lz4
tar cvf - data wasm | lz4 - $NODE_PATH/snap_$PROJECT.tar.lz4 && cd $NODE_PATH
SNAP_SIZE=$(ls -lh $NODE_PATH/snap_$PROJECT.tar.lz4 | awk '{print $5}')
mv $NODE_PATH/snap_$PROJECT.tar.lz4 "/var/www/$TYPE-files/$PROJECT"
# Create current snapshot state, current_state.json
SNAP_TIME=$(date '+%FT%T.%N%Z')
PRUNING_TYPE=$(grep "^pruning =" "$NODE_PATH/config/app.toml" | awk '{print $3}' | sed 's/\"//g')
PRUNING_KEEP_RECENT=$(grep "^pruning-keep-recent" "$NODE_PATH/config/app.toml"  | awk '{print $3}' | sed 's/\"//g')
PRUNING_INTERVAL=$(grep "^pruning-interval" "$NODE_PATH/config/app.toml" | awk '{print $3}' | sed 's/\"//g')
INDEXER=$(grep "^indexer =" "$NODE_PATH/config/config.toml" | awk '{print $3}' | sed 's/\"//g')
tee /var/www/$TYPE-files/$PROJECT/.snap__state.json > /dev/null <<EOF
{
  "SnapshotHeight": "$SNAP_HEIGHT",
  "SnapshotSize": "$SNAP_SIZE",
  "SnapshotBlockTime": "$SNAP_TIME",
  "pruning": "$PRUNING_TYPE: $PRUNING_KEEP_RECENT/0/$PRUNING_INTERVAL",
  "indexer": "$INDEXER",
  "WasmPath": "$WASM_PATH"
}
EOF
systemctl start $SERVICE
echo '--------------------------------------------------'
echo -e "\033[0;93mSnapshot created and moved, starting node...\033[0m"
echo '--------------------------------------------------'
