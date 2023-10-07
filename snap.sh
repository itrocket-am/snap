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
NODE_PATH=/home/${PR_USER}/${PR_PATH}/
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

# configure app.toml
sed -i -e "s/^pruning *=.*/pruning = \"custom\"/" $NODE_PATH/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"100\"/" $NODE_PATH/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"10\"/" $NODE_PATH/config/app.toml
# sed -i -e "s/^snapshot-interval *=.*/snapshot-interval = 0/" $NODE_PATH/config/app.toml

# configure config.toml
sed -i -e "s/^seed_mode *=.*/seed_mode = \"true\"/" $NODE_PATH/config/config.toml
sed -i -e "s/^indexer *=.*/indexer = \"null\"/" $NODE_PATH/config/config.toml
sed -i -e "s/^filter_peers *=.*/filter_peers = \"true\"/" $NODE_PATH/config/config.toml
sed -i -e "s/^enable *=.*/enable = \"false\"/" $NODE_PATH/config/config.toml
sed -i -e "s/^rpc_servers *=.*/rpc_servers = \"\"/" $NODE_PATH/config/config.toml
sed -i -e "s/^trust_hash *=.*/trust_hash = \"\"/" $NODE_PATH/config/config.toml
sed -i -e "s/^trust_height *=.*/trust_height = 0/" $NODE_PATH/config/config.toml
sed -i -e "s/^persistent_peers *=.*/persistent_peers = \"\"/" $NODE_PATH/config/config.toml

echo '================================================='
echo -e "RPC: \e[1m\e[32m$RPC\e[0m"
echo -e "Service: \e[1m\e[32m${SERVICE}.service\e[0m"
echo -e "BIN: \e[1m\e[32m$BIN\e[0m"
echo -e "Node path folder: \e[1m\e[32m$NODE_PATH\e[0m"
echo -e "$PROJECT public folder: \e[1m\e[32m/var/www/$TYPE-files/$PROJECT\e[0m"
echo -e "Port: \e[1m\e[32m$PORT\e[0m"
echo -e "Snapshot MAX size: \e[1m\e[32m$snapMaxSize gb\e[0m"
echo -e "Sleep time: \e[1m\e[32m$SLEEP\e[0m"
echo -e "PEERS: \e[1m\e[32m$PEERS\e[0m"
echo -e "RESET: \e[1m\e[32m$PEERS\e[0m"
echo '================================================='
sleep 3

# check updates on git
sudo -u $PR_USER bash build.sh
systemctl restart ${PR_USER}-snap

# start script
for (( ;; )); do
# create addrbook cycles
cycles=3
 for i in $(eval echo {1..$cycles})
 do
echo -e "\033[0;34m"Starting the $i cycle"\033[0m"

# add check_localhost_connection function
check_localhost_connection() {
    if curl -s --head localhost:${PORT}657 | head -n 1 | grep "200 OK" > /dev/null; then
        return 0
    else
        return 1
    fi
}

# add check_rpc_connection function
check_rpc_connection() {
    if curl -s "$RPC" | grep -q "height" > /dev/null; then
        return 0
    else
        return 1
    fi
}

# Check RPC and sync status
while true; do

    if [ "$rpcStatus" = "true" ]; then
        if check_localhost_connection && check_rpc_connection; then
            # RPC ready, checking synch status...
            echo -e "\033[0;32mCheck synch status...\033[0m"
            LATEST_CHAIN_BLOCK=$(curl -s $RPC/block | jq -r .result.block.header.height)
            NODE_HEIGHT=$(curl http://localhost:${PORT}657/block | jq .result.block.header.height | sed 's/\"//g')
            difference=$(($LATEST_CHAIN_BLOCK - $NODE_HEIGHT))
            echo ">>> Height $NODE_HEIGHT/$LATEST_CHAIN_BLOCK diff $difference"
            
            while [ $difference -gt 100 ]; do
                echo -e "\033[0;31mNode is not synced, restarting after $SLEEP sec...\033[0m"
                echo ">>> Height $NODE_HEIGHT/$LATEST_CHAIN_BLOCK"
                # sending message...
                MESSAGE="$PROJECT $TYPE SEED
                >>> ${NODE_HEIGHT}/${LATEST_CHAIN_BLOCK} diff $difference
                > but service has been restarted"
                curl --header 'Content-Type: application/json' --request 'POST' --data '{"chat_id":"'"${CHAT_ID_ALARM}"'", "text":"'"$(echo -e "${MESSAGE}")"'", "parse_mode": "html"}' "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" /dev/null 2>&1
                echo '---------------------------------------------------------'
                echo -e "\033[0;31m"$PROJECT is not synched ${NODE_HEIGHT}/${LATEST_CHAIN_BLOCK} but service has been restarted after $SLEEP sec"\033[0m"
                sleep $SLEEP
                systemctl restart $SERVICE
                sleep 180
                if check_localhost_connection && check_rpc_connection; then
                    # RPC ready, checking synch status...
                    echo -e "\033[0;32mCheck synch status...\033[0m"
                    sleep 60
                    LATEST_CHAIN_BLOCK=$(curl -s $RPC/block | jq -r .result.block.header.height)
                    NODE_HEIGHT=$(curl http://localhost:${PORT}657/block | jq .result.block.header.height | sed 's/\"//g')
                    difference=$(($LATEST_CHAIN_BLOCK - $NODE_HEIGHT))
                    echo ">>> Height $NODE_HEIGHT/$LATEST_CHAIN_BLOCK diff $difference"
                fi
            done
            break
        else
            echo -e "\033[0;31mRPC or localhost:${PORT}657 status - error, waiting 5 sec and retrying...\033[0m"
            sleep 5
        fi
    else
        echo check "rpcStatus=false"
        break  # Assuming you want to exit the loop when rpcStatus is false.
    fi
done
  echo "Copy and move addrbook to public folder..."
  cp -r $NODE_PATH/config/addrbook.json $PUBLIC_FOLDER
  echo '---------------------------------------------------------'
  echo -e "\033[0;93mAddrbook moved to $PUBLIC_FOLDER\033[0m" && sleep 2
FILE_1=$NODE_PATH/config/genesis.json
FILE_2=$PUBLIC_FOLDER/genesis.json
if [ -z "$(diff -q $FILE_1  $FILE_2)" ]; then
  echo "The public genesis file is correct"  && sleep 2
else
  cp -r $NODE_PATH/config/genesis.json $PUBLIC_FOLDER
  echo -e "\033[0;93mThe public genesis file updated\033[0m" && sleep 2
fi
  WASM_FOLDER=$NODE_PATH/wasm
if [ -d "$WASM_FOLDER" ]; then
    cd $NODE_PATH
    rm $NODE_PATH/wasm_$PROJECT.tar.lz4
    tar cvf - wasm | lz4 - $NODE_PATH/wasm_$PROJECT.tar.lz4 && cd $NODE_PATH
    mv wasm_$PROJECT.tar.lz4 "/var/www/$TYPE-files/$PROJECT"
    WASM_PATH=$(basename $(pwd))
    echo -e "\033[0;93mWasm folder located on $WASM_PATH moved to $PUBLIC_FOLDER\033[0m" && sleep 2
  else
  cd $NODE_PATH
  WASM_PATH=$(basename $(pwd))
  WASM_FOLDER=$NODE_PATH/data/wasm
if [ -d "$WASM_FOLDER" ]; then
    cd $NODE_PATH/data
    rm $NODE_PATH/data/wasm_$PROJECT.tar.lz4
    tar cvf - wasm | lz4 - $NODE_PATH/data/wasm_$PROJECT.tar.lz4
    mv wasm_$PROJECT.tar.lz4 "/var/www/$TYPE-files/$PROJECT"
    WASM_PATH_1=$(basename $(pwd))
    WASM_PATH=$WASM_PATH/$WASM_PATH_1
    echo -e "\033[0;93mWasm folder located on $WASM_PATH moved to $PUBLIC_FOLDER\033[0m"  && sleep 2
  else
    WASM_PATH=false
    echo "No have wasm on the $PROJECT"
fi
fi
  echo -e "\033[0;32mWaiting $SLEEP sec\033[0m"
  echo '================================================='
  sleep $SLEEP
done

# stop the node and create snapshot
while ! nc -z localhost ${PORT}657; do
  echo -e "\033[0;31m$PROJECT node localhost:${PORT}657 status failed, waiting 5 sec and retrying...\033[0m"
  sleep 5
done
SNAP_HEIGHT=$(curl -s localhost:${PORT}657/status | jq -r .result.sync_info.latest_block_height)
systemctl stop $SERVICE && cd $NODE_PATH
rm $NODE_PATH/snap_$PROJECT.tar.lz4
tar cvf - data wasm | lz4 - $NODE_PATH/snap_$PROJECT.tar.lz4 && cd $NODE_PATH
SNAP_SIZE=$(ls -lh $NODE_PATH/snap_$PROJECT.tar.lz4 | awk '{print $5}')
mv snap_$PROJECT.tar.lz4 "/var/www/$TYPE-files/$PROJECT"
# Create current snapshot state, current_state.json
SNAP_TIME=$(date '+%FT%T.%N%Z')
PRUNING_TYPE=$(grep "^pruning =" "$NODE_PATH/config/app.toml" | awk '{print $3}' | sed 's/\"//g')
PRUNING_KEEP_RECENT=$(grep "^pruning-keep-recent" "$NODE_PATH/config/app.toml"  | awk '{print $3}' | sed 's/\"//g')
PRUNING_INTERVAL=$(grep "^pruning-interval" "$NODE_PATH/config/app.toml" | awk '{print $3}' | sed 's/\"//g')
INDEXER=$(grep "^indexer =" "$NODE_PATH/config/config.toml" | awk '{print $3}' | sed 's/\"//g')
tee /var/www/$TYPE-files/$PROJECT/.current_state.json > /dev/null <<EOF
{
  "SnapshotHeight": "$SNAP_HEIGHT",
  "SnapshotSize": "$SNAP_SIZE",
  "SnapshotBlockTime": "$SNAP_TIME",
  "pruning": "$PRUNING_TYPE: $PRUNING_KEEP_RECENT/0/$PRUNING_INTERVAL",
  "indexer": "$INDEXER",
  "WasmPath": "$WASM_PATH"
}
EOF

echo '--------------------------------------------------'
echo -e "\033[0;93mSnapshot created and moved, starting node...\033[0m"
echo '--------------------------------------------------'
systemctl start $SERVICE
echo -e "\033[0;93msleep 1 min...\033[0m"
sleep 60

# check file size and start statesync if snap_size biggest
DATA_FOLDER=$NODE_PATH/data
DATA_FOLDER_SIZE=$(du -s $DATA_FOLDER | awk '{print $1}')
snapMaxSize_B=$(bc<<<"scale=3;$snapMaxSize*1024*1024")
echo $DATA_FOLDER_SIZE
echo $snapMaxSize_B && sleep 3
if [ $DATA_FOLDER_SIZE -gt $snapMaxSize_B ]; then
  while ! nc -z localhost ${PORT}657 && curl -s ${RPC} | grep -q "height"; do
  echo -e "\033[0;31mRPC or localhost:${PORT}657 status - error, waiting 5 sec and retrying...\033[0m"
  sleep 5
done
  LIVE_PEERS=$(curl -s "${RPC}/net_info" | jq -r '.result.peers[] | select(.is_outbound==true) | "\(.node_info.id)@\(.remote_ip):\(.node_info.listen_addr | split(":")[-1])"' | paste -sd, -)
#  PEERS="${PEERS},${LIVE_PEERS}"
  PEERS="${PEERS}"
  systemctl stop $SERVICE
  echo -e "\033[0;31m"Starting Statesync..."\033[0m"
  sleep 2
  sudo -u $PR_USER cp $NODE_PATH/data/priv_validator_state.json $NODE_PATH/priv_validator_state.json.backup
  sudo -u $PR_USER $BIN $RESET --home $NODE_PATH
  sudo -u $PR_USER sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $NODE_PATH/config/config.toml 
  while ! curl -s --head --fail $RPC; do
    echo "Waiting for RPC to be available..."
    sleep 5
done
  LATEST_HEIGHT=$(curl -s $RPC/block | jq -r .result.block.header.height);
  BLOCK_HEIGHT=$((LATEST_HEIGHT - 2000));
  TRUST_HASH=$(curl -s "$RPC/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash) 
  echo $LATEST_HEIGHT $BLOCK_HEIGHT $TRUST_HASH && sleep 2
  sudo -u $PR_USER sed -i.bak -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ;
  s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"$RPC,$RPC\"| ;
  s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1$BLOCK_HEIGHT| ;
  s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"$TRUST_HASH\"| ;
  s|^(seeds[[:space:]]+=[[:space:]]+).*$|\1\"\"|" $NODE_PATH/config/config.toml
  sudo -u $PR_USER mv $NODE_PATH/priv_validator_state.json.backup $NODE_PATH/data/priv_validator_state.json
  systemctl restart $SERVICE
echo -e "\033[0;31m"Snapshot size is $DATA_FOLDER_SIZE, StateSync started, waiting 20 min..."\033[0m"
sleep 1200

# checking sync status after statesync
while true; do
#  if curl -s --head localhost:${PORT}657 | head -n 1 | grep "200 OK" > /dev/null && curl -s ${RPC} | grep -q "height"; then
   if check_localhost_connection && check_rpc_connection; then
    echo checking sync status after statesync...
    LATEST_CHAIN_BLOCK=$(curl -s $RPC/block | jq -r .result.block.header.height)
    NODE_HEIGHT=$(curl http://localhost:${PORT}657/block | jq .result.block.header.height  | sed 's/\"//g')
    difference=$(($LATEST_CHAIN_BLOCK - $NODE_HEIGHT))
    echo ">>> Height $NODE_HEIGHT/$LATEST_CHAIN_BLOCK diff $difference"
    sleep 2
    break  # If everything is fine, then we break the loop
  else
    echo -e "\033[0;31mRPC or localhost:${PORT}657 status - error, waiting 5 sec and retrying...\033[0m"
    sleep 5 
  fi
done
if [ $difference -gt 100 ]
then
  echo '---------------------------------------------------------'
  echo -e "\033[0;31m"$PROJECT is not synched after StateSync ${NODE_HEIGHT}/${LATEST_CHAIN_BLOCK}, downloading snapshot..."\033[0m"
  sed -i -e "s/^enable *=.*/enable = \"false\"/" $NODE_PATH/config/config.toml
  systemctl stop $SERVICE
  sudo -u $PR_USER cp $NODE_PATH/data/priv_validator_state.json $NODE_PATH/priv_validator_state.json.backup
  rm -rf $NODE_PATH/data $NODE_PATH/wasm
  sudo -u $PR_USER curl https://${TYPE}-files.itrocket.net/${PROJECT}/snap_${PROJECT}.tar.lz4 | lz4 -dc - | tar -xf - -C $NODE_PATH
  sudo -u $PR_USER mv $NODE_PATH/priv_validator_state.json.backup $NODE_PATH/data/priv_validator_state.json
  systemctl restart $SERVICE
  echo -e "\033[0;31mSnapshot downloaded, waiting $SLEEP sec\033[0m"
fi
# set some params
  sed -i -e "s/^enable *=.*/enable = \"false\"/" $NODE_PATH/config/config.toml
  sed -i -e "s/^rpc_servers *=.*/rpc_servers = \"\"/" $NODE_PATH/config/config.toml
  sed -i -e "s/^trust_hash *=.*/trust_hash = \"\"/" $NODE_PATH/config/config.toml
  sed -i -e "s/^trust_height *=.*/trust_height = 0/" $NODE_PATH/config/config.toml
  sed -i -e "s/^persistent_peers *=.*/persistent_peers = \"\"/" $NODE_PATH/config/config.toml
else
  echo -e "\033[0;32m"Snapshot size less than $snapMaxSize gb, it is a great! Waiting $SLEEP sec..."\033[0m"
  sleep $SLEEP
fi

# собираем список доступных rpc
# Функция для получения данных
fetch_data() {
    local url=$1
    # Задаем таймаут в 2 секунды
    curl -s --max-time 2 "$url"
}

declare -A processed_rpc
declare -A rpc_list

process_data() {
    local data=$1
    local parent_rpc=$2  # Add this line to accept parent_rpc as an argument

    local peers=$(echo "$data" | jq -c '.result.peers[]')

    for peer in $peers; do
        rpc_address=$(echo "$peer" | jq -r '.node_info.other.rpc_address')

        if [[ $rpc_address == *"tcp://0.0.0.0:"* ]]; then
            ip=$(echo "$peer" | jq -r '.remote_ip // ""')
            port=${rpc_address##*:}

            rpc_combined="$ip:$port"
            
            temp_key="$rpc_combined"
            echo "Debug: rpc_combined = $rpc_combined, parent_rpc = $parent_rpc"  # Modified this line
            rpc_list["${temp_key}"]="{ \"rpc\": \"$rpc_combined\" }"

            # Если этот RPC еще не был обработан
            if [[ -z ${processed_rpc["$rpc_combined"]} ]]; then
                processed_rpc["$rpc_combined"]=1  # помечаем как обработанный
                echo "Processing new RPC: $rpc_combined (parent: $parent_rpc)"  # Modified this line
                new_data=$(fetch_data "http://$rpc_combined/net_info")
                process_data "$new_data" "$rpc_combined"  # Modified this line for recursive call
            fi
        fi
    done
}

# Функция для проверки доступности RPC на основе voting_power
check_rpc_accessibility() {
    local rpc=$1
    
    # Проверка протокола
    if [[ $rpc == http://* ]]; then
        protocol="http"
        rpc=${rpc#http://}
    elif [[ $rpc == https://* ]]; then
        protocol="https"
        rpc=${rpc#https://}
    else
        protocol="http"
    fi

    local status_data=$(fetch_data "$protocol://$rpc/status")

    # Если запрос не удался
    if [[ $? -ne 0 ]]; then
        return 1  # недоступен
    fi

    local voting_power=$(echo "$status_data" | jq '.result.validator_info.voting_power' 2>/dev/null)

    # Если поле voting_power существует
    if [[ -n "$voting_power" ]]; then
        return 0  # доступен
    else
        return 1  # недоступен
    fi
}

if check_localhost_connection; then
    local_data=$(fetch_data "localhost:${PORT}/net_info")
    process_data "$local_data" "None"  # "None" signifies no parent for the localhost

    if check_rpc_connection; then
        public_data=$(fetch_data "$RPC/net_info")
        process_data "$public_data" "$RPC"  # The parent here is whatever $RPC holds
    fi

    # Обработка доступных RPC
    for rpc in "${!rpc_list[@]}"; do
        # Если RPC доступен
        if check_rpc_accessibility "$rpc"; then
            # Если отсутствует в $PRE_FILE - добавляем
            if ! grep -q "$rpc" "$PRE_FILE"; then
                echo "$rpc" >> "$PRE_FILE"
            fi
        fi
    done

#    # Создание временного файла для хранения проверенных RPC
    TEMP_FILE=$(mktemp)

# Обработка RPC из $PRE_FILE
while IFS= read -r line; do
    # Если RPC начинается с "https://", сохраняем независимо от доступности
    if [[ "$line" == https://* ]]; then
        echo "$line" >> "$TEMP_FILE"
    # В противном случае проверяем доступность или наличие в rpc_list
    elif check_rpc_accessibility "$line" || [[ -n ${rpc_list["$line"]} ]]; then
        echo "$line" >> "$TEMP_FILE"
    fi
done < "$PRE_FILE"

    # Замена $PRE_FILE содержимым из TEMP_FILE
    mv "$TEMP_FILE" "$PRE_FILE"

    # Опционально: вывод содержимого $PRE_FILE
    cat "$PRE_FILE"
fi

# Создайте файл rpc_combined.json или очистите его, если он уже существует
FILE_PATH_JSON="/home/$PR_USER/snap/rpc_combined.json"
PUBLIC_FILE_JSON=/var/www/$TYPE-files/$PROJECT/.rpc_combined.json

# Если файл существует, очистите его. Если нет - создайте.
[[ -f $FILE_PATH_JSON ]] && > "$FILE_PATH_JSON" || touch "$FILE_PATH_JSON"

# Начинаем JSON с открытия объекта
echo "{" > $FILE_PATH_JSON

# Переменная для определения первой записи (чтобы избежать добавления запятой перед первым объектом)
first_entry=true

# Цикл для чтения каждой строки из файла $PRE_FILE
while IFS= read -r rpc; do
    # Проверка доступности RPC
    if check_rpc_accessibility "$rpc"; then
        # Извлечение данных с помощью функции fetch_data
        data=$(fetch_data "$rpc/status")
        
        # Извлекаем необходимые данные из ответа RPC
        network=$(echo "$data" | jq -r '.result.node_info.network')
        moniker=$(echo "$data" | jq -r '.result.node_info.moniker')
        tx_index=$(echo "$data" | jq -r '.result.node_info.other.tx_index')
        latest_block_height=$(echo "$data" | jq -r '.result.sync_info.latest_block_height')
        earliest_block_height=$(echo "$data" | jq -r '.result.sync_info.earliest_block_height')
        catching_up=$(echo "$data" | jq -r '.result.sync_info.catching_up')
        voting_power=$(echo "$data" | jq -r '.result.validator_info.voting_power')
        scan_time=$(date '+%FT%T.%N%Z')  # Текущая дата и время

        # Добавляем запятую перед следующим объектом, если это не первая запись
        if [ "$first_entry" = true ]; then
            first_entry=false
        else
            echo "," >> $FILE_PATH_JSON
        fi

       # Записываем извлеченные данные в файл
       echo -ne "  \"$rpc\": {\n    \"network\": \"$network\",\n    \"moniker\": \"$moniker\",\n    \"tx_index\": \"$tx_index\",\n    \"latest_block_height\": \"$latest_block_height\",\n    \"earliest_block_height\": \"$earliest_block_height\",\n    \"catching_up\": $catching_up,\n    \"voting_power\": \"$voting_power\",\n    \"scan_time\": \"$scan_time\"\n  }" >> $FILE_PATH_JSON
    fi
done < "$PRE_FILE"

# Закрываем объект в JSON
echo "}" >> $FILE_PATH_JSON

# Копируем JSON-файл в публичное место
sudo cp $FILE_PATH_JSON $PUBLIC_FILE_JSON

# Если хотите увидеть содержимое файла, раскомментируйте следующую строку
# cat $PUBLIC_FILE_JSON

# check updates on git
sudo -u $PR_USER bash build.sh 
done
