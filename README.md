# Automatic snapshot creation, RPC scanner
### Manual installation

Clone repositories
```
cd $HOME
git clone https://github.com/itrocket-am/snap
cd snap
chmod +x snap.sh build.sh
```

Copy `.snap.conf_example` to `snap.conf` and configure
```
cp $HOME/snap/.snap.conf_example $HOME/snap/snap.conf
```

Create Service file
```
sudo tee /etc/systemd/system/${USER}-snap.service > /dev/null <<EOF
[Unit]
Description=$USER Snap script daemon
After=network.target

[Service]
User=root
WorkingDirectory=${HOME}/snap
ExecStartPre=/bin/chmod +x ${HOME}/snap/snap.sh
ExecStartPre=/bin/chmod +x ${HOME}/snap/build.sh
ExecStart=${HOME}/snap/snap.sh
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
```

Enable and start service
```
sudo systemctl daemon-reload
sudo systemctl enable ${USER}-snap.service
sudo systemctl restart ${USER}-snap.service && sudo journalctl -u ${USER}-snap.service -f
```

### Delete 
```
sudo systemctl stop ${USER}-snap
sudo systemctl disable ${USER}-snap
sudo rm -rf /etc/systemd/system/${USER}-snap.service
```
