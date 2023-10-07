# Automatic snapshot creation, RPC scanner
### Manual installation

Clone repositories
```
git clone git clone https://github.com/itrocket-am/snap
cd snap
```

Copy `snap.conf_example` to `snap.conf` and configure
```
cp snap.conf_example snap.conf
```
Save variables
```
PROJECT="$USER"
PATH="${HOME}/snap"
```

Create Service file
```
sudo tee /etc/systemd/system/${PROJECT}-snap.service > /dev/null <<EOF
[Unit]
Description=$PROJECT Snap script daemon
After=network.target

[Service]
User=root
Environment="USER=$PROJECT"
ExecStart=${PATH}/snap.sh
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```
