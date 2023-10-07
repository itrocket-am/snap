#!/bin/bash

# Проверяем, передан ли аргумент для PR_USER
if [ -z "$1" ]; then
    echo "Usage: $0 <username>"
    exit 1
fi

PR_USER=$1

# Переходим в директорию и проверяем, успешно ли это произошло
cd "/home/${PR_USER}/snap" || { echo "Cannot change directory to /home/${PR_USER}/snap"; exit 1; }

# Проверка обновлений
echo "Checking updates..."

git stash

# Храним результат git pull в переменной
GIT_PULL_RESULT=$(git pull https://github.com/itrocket-am/snap.git main)
echo -e "\033[0;32m$GIT_PULL_RESULT\033[0m"

# Получаем первое слово результата для проверки статуса
GIT_STATUS=$(echo "$GIT_PULL_RESULT" | awk '{print $1}')
echo -e "\033[0;32m$GIT_STATUS\033[0m"

# Проверяем, был ли обновлен package.json
PACKAGE_JSON_UPDATED=$(git diff HEAD@{1} HEAD --name-only | grep -c "package.json")

if [ "$GIT_STATUS" != "Updating" ]; then
    echo "No updates found"
else
    if [ "$PACKAGE_JSON_UPDATED" -gt 0 ]; then
        echo "Dependencies changed, updating dependencies..."
    fi
    echo "Restarting and sending Telegram message..."
    # Здесь можно добавить команды для отправки сообщений в Telegram и перезапуска службы
fi
