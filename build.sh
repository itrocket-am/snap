#!/bin/bash

# read '${PROJECT}.json'
PR_USER=$(sed -n "/prHome:/s/.*'\([^']*\)'.*/\1/p" /home/${PR_USER}/snap/snap.conf | awk -F/ '{print $NF}')

# Выполнить git pull
  cd /home/${PR_USER}/snap
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
    chmod +x /home/${PR_USER}/snap/snap.sh /home/${PR_USER}/snap/build.sh
    ls -l /home/${PR_USER}/snap/snap.sh /home/${PR_USER}/snap/build.sh
    MESSAGE="$PR_USER snap.sh script updated"
  curl --header 'Content-Type: application/json' --request 'POST' --data '{"chat_id":"'"${CHAT_ID_ALARM}"'", "text":"'"$(echo -e "${MESSAGE}")"'", "parse_mode": "html"}' "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" /dev/null 2>&1
  fi
exit
