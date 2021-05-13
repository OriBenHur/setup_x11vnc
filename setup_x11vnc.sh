#!/usr/bin/env bash
set -euo pipefail
set -x

function install_vnc() {
	sudo apt update || true
	sudo apt install x11vnc -y
}

function create_password_file() {
	sudo x11vnc -storepasswd /etc/x11vnc.pass
	sudo chmod 644 /etc/x11vnc.pass
}

function create_vnc_files() {
	source /etc/os-release
	if dpkg --compare-versions "${VERSION_ID}" "lt" "18.04"; then
		sudo tee /etc/systemd/system/x11vnc.service > /dev/null <<- EOM
		## Description: Custom Service Unit file
		## File: /etc/systemd/system/x11vnc.service
		[Unit]
		Description=Start x11vnc at startup.
		After=multi-user.target

		[Service]
		Type=simple
		ExecStart=/usr/bin/x11vnc -loop -forever -bg -rfbport 5900 -xkb -noxrecord -noxfixes -noxdamage -shared -norc -auth guess -rfbauth /etc/x11vnc.pass
		ExecStop=/bin/bash -c 'killall -9 x11vnc'
		[Install]
		WantedBy=multi-user.target
	EOM
	systemctl enable x11vnc
	else
		local GDM_ID
		GDM_ID="$(id -u gdm)"
		local GUID
		GUID="$(id -u "$(logname)")"


		sudo tee /etc/systemd/system/x11vnc.service > /dev/null <<- EOM
			## Description: Custom Service Unit file
			## File: /etc/systemd/system/x11vnc.service
			[Unit]
			Description=Start x11vnc at startup.
			After=multi-user.target

			[Service]
			Type=simple
			ExecStart=/usr/bin/x11vnc -loop -forever -bg -rfbport 5900 -xkb -noxrecord -noxfixes -noxdamage -shared -norc -auth /run/user/${GDM_ID}/gdm/Xauthority -rfbauth /etc/x11vnc.pass
			ExecStop=/bin/bash -c 'killall -9 x11vnc'
			[Install]
			WantedBy=multi-user.target
		EOM

		sudo tee /etc/systemd/system/x11vnc-desktop.service > /dev/null <<- EOM
			# Description: Custom Service Unit file
			# File: /etc/systemd/system/x11vnc-desktop.service
			[Unit]
			Description=Start x11vnc at startup.
			After=multi-user.target

			[Service]
			Type=simple
			User=${GUID}
      ExecStart=/usr/bin/x11vnc -display "${DISPLAY}" -loop -forever -bg -rfbport 5900 -xkb -noxrecord -noxfixes -noxdamage -shared -norc -auth /run/user/${GUID}/gdm/Xauthority -rfbauth /etc/x11vnc.pass
			ExecStop=/bin/bash -c 'killall -9 x11vnc'


			[Install]
			WantedBy=multi-user.target
		EOM

		sudo tee /etc/systemd/system/stop_x11vnc.service > /dev/null <<- EOM
			## Description: Custom Service Unit file
			## File: /etc/systemd/system/stop_x11vnc.service
			[Unit]
			Description=Stop x11vnc on logon
			After=multi-user.target

			[Service]
			Type=simple
			ExecStart=/bin/bash /etc/replace_x11vnc_service.sh

			[Install]
			WantedBy=multi-user.target
		EOM


		sudo tee /etc/replace_x11vnc_service.sh > /dev/null << EOM
#!/usr/bin/env bash

while [[ ! -f '/tmp/x11vnc.lock' ]]; do
	sleep 1
done
killall -9 x11vnc
systemctl stop x11vnc
systemctl start x11vnc-desktop.service
rm /tmp/x11vnc.lock -rf
EOM


		sudo tee /etc/profile.d/stop_x11vnc.sh > /dev/null <<- 'EOM'
		#!/usr/bin/env bash
		[[ -z $SSH_CONNECTION ]] && touch /tmp/x11vnc.lock
		EOM
	fi
}

function setup() {
	source /etc/os-release
	if dpkg --compare-versions "${VERSION_ID}" "lt" "18.04"; then
		sudo systemctl enable x11vnc
		sudo systemctl start x11vnc
	else
		sudo systemctl daemon-reload
		sudo systemctl enable x11vnc
		sudo systemctl stop x11vnc
		sudo systemctl enable stop_x11vnc
		sudo systemctl stop stop_x11vnc
		sudo systemctl start x11vnc-desktop
		sudo rm /tmp/x11vnc.lock -rf
	fi
}

install_vnc
create_password_file
create_vnc_files
setup