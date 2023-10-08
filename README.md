# Automatic snapshot creation, RPC scanner
### Manual installation

Clone repositories
```
cd $HOME
git clone https://github.com/itrocket-am/snap
cd snap
chmod +x snap.sh build.sh
```

Copy `$HOME/snap/.snap.conf_example` to `$HOME/snap/snap.conf` and configure
```
cp snap.conf_example snap.conf
```
Save variables
```
echo "export PROJECT="$USER"" >> $HOME/.bash_profile
echo "export SNAP_HOME="${HOME}/snap"" >> $HOME/.bash_profile
source $HOME/.bash_profile
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
ExecStartPre=/bin/chmod +x ${SNAP_HOME}/snap.sh
ExecStartPre=/bin/chmod +x ${SNAP_HOME}/build.sh
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

### Delete 
```
sudo systemctl stop ${PROJECT}-snap
sudo systemctl disable ${PROJECT}-snap
sudo rm -rf /etc/systemd/system/${PROJECT}-snap.service
```
