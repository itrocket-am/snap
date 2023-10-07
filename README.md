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
SNAP_HOME="${HOME}/snap"
```

Create Service file
```
sudo tee /etc/systemd/system/${PROJECT}-snap.service > /dev/null <<EOF
[Unit]
Description=$PROJECT Snap script daemon
After=network.target

[Service]
User=root
WorkingDirectory=$SNAP_HOME
Environment="USER=$PROJECT"
ExecStart=${SNAP_HOME}/snap.sh
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
```

Enable and start service
```
sudo systemctl daemon-reload
sudo systemctl enable ${PROJECT}-snap.service
sudo systemctl restart ${PROJECT}-snap.service && sudo journalctl -u ${PROJECT}-snap.service -f
```
