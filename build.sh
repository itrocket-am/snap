#!/bin/bash
# Start command: /bin/bash snap.sh

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

# Выполнить git pull
  cd /home/${PR_USER}/snap
  sudo -u $PR_USER chown -R ${PR_USER}:${PR_USER} /home/${PR_USER}/snap
  sudo -u $PR_USER chmod -R 755 /home/${PR_USER}/snap
  echo Checking updates...
  git stash
  GIT_PULL_RESULT=$(git pull https://github.com/itrocket-am/snap.git main)
  echo -e "\033[0;32m"$GIT_PULL_RESULT"\033[0m"
  GIT_STATUS=$(echo ${GIT_PULL_RESULT} | awk '{print $1}')
  echo -e "\033[0;32m"$GIT_STATUS"\033[0m"
  PACKAGE_JSON_UPDATED=$(git diff HEAD@{1} HEAD --name-only | grep -c "package.json")

  if [ "$GIT_STATUS" != "Updating" ]; then
    echo "No have any updates yet"
  else
    if [ "$PACKAGE_JSON_UPDATED" -gt 0 ]; then
      echo "Dependencies changed, updating dependencies..."
    fi
    echo restarting and sending tg message...
    # systemctl restart ${PROJECT}-snap
    MESSAGE="$PR_USER snap.sh script updated"
  curl --header 'Content-Type: application/json' --request 'POST' --data '{"chat_id":"'"${CHAT_ID_ALARM}"'", "text":"'"$(echo -e "${MESSAGE}")"'", "parse_mode": "html"}' "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" /dev/null 2>&1
  fi
