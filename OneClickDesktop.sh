#!/bin/bash
###########################################################################################
#    One-click Desktop & Browser Access Setup Script v0.1.0                               #
#    Written by shc (https://qing.su)                                                     #
#    Github link: https://github.com/Har-Kuun/OneClickDesktop                             #
#    Contact me: https://t.me/hsun94   E-mail: hi@qing.su                                 #
#                                                                                         #
#    This script is distributed in the hope that it will be                               #
#    useful, but ABSOLUTELY WITHOUT ANY WARRANTY.                                         #
#                                                                                         #
#    The author thanks LinuxBabe for providing detailed                                   #
#    instructions on Guacamole setup.                                                     #
#    https://www.linuxbabe.com/debian/apache-guacamole-remote-desktop-debian-10-buster    #
#                                                                                         #
#    Thank you for using this script.                                                     #
###########################################################################################


#You can change the Guacamole source file download link here.
#Check https://guacamole.apache.org/releases/ for the latest stable version.

GUACAMOLE_DOWNLOAD_LINK="https://mirrors.ocf.berkeley.edu/apache/guacamole/1.2.0/source/guacamole-server-1.2.0.tar.gz"
GUACAMOLE_VERSION="1.2.0"

#By default, this script only works on Ubuntu 18/20 and Debian 10.
#You can disable the OS check switch below and tweak the code yourself to try to install it in other OS versions.
#Please do note that if you choose to use this script on OS other than Ubuntu 18/20 or Debian 10, you might mess up your OS.  Please keep a backup of your server before installation.

OS_CHECK_ENABLED=ON




#########################################################################
#    Functions start here.                                              #
#    Do not change anything below unless you know what you are doing.   #
#########################################################################

exec > >(tee -i OneClickDesktop.log)
exec 2>&1

function check_OS
{
	if [ -f /etc/lsb-release ]
	then
		cat /etc/lsb-release | grep "DISTRIB_RELEASE=18." >/dev/null
		if [ $? = 0 ]
		then
			OS=UBUNTU18
		else
			cat /etc/lsb-release | grep "DISTRIB_RELEASE=20." >/dev/null
			if [ $? = 0 ]
			then
				OS=UBUNTU20
			else
				say "Sorry, this script only supports Ubuntu 18, 20 and Debian 10." red
				echo 
				exit 1
			fi
		fi
	elif [ -f /etc/debian_version ] ; then
		cat /etc/debian_version | grep "^10." >/dev/null
		if [ $? = 0 ] ; then
			OS=DEBIAN10
		else
			say "Sorry, this script only supports Ubuntu 18, 20 and Debian 10." red
			echo 
			exit 1
		fi
	else
		say "Sorry, this script only supports Ubuntu 18, 20 and Debian 10." red
		echo 
		exit 1
	fi
}

function say
{
#This function is a colored version of the built-in "echo."
#https://github.com/Har-Kuun/useful-shell-functions/blob/master/colored-echo.sh
	echo_content=$1
	case $2 in
		black | k ) colorf=0 ;;
		red | r ) colorf=1 ;;
		green | g ) colorf=2 ;;
		yellow | y ) colorf=3 ;;
		blue | b ) colorf=4 ;;
		magenta | m ) colorf=5 ;;
		cyan | c ) colorf=6 ;;
		white | w ) colorf=7 ;;
		* ) colorf=N ;;
	esac
	case $3 in
		black | k ) colorb=0 ;;
		red | r ) colorb=1 ;;
		green | g ) colorb=2 ;;
		yellow | y ) colorb=3 ;;
		blue | b ) colorb=4 ;;
		magenta | m ) colorb=5 ;;
		cyan | c ) colorb=6 ;;
		white | w ) colorb=7 ;;
		* ) colorb=N ;;
	esac
	if [ "x${colorf}" != "xN" ] ; then
		tput setaf $colorf
	fi
	if [ "x${colorb}" != "xN" ] ; then
		tput setab $colorb
	fi
	printf "${echo_content}" | sed -e "s/@B/$(tput bold)/g"
	tput sgr 0
	printf "\n"
}

function determine_system_variables
{
	CurrentUser="$(id -u -n)"
	CurrentDir=$(pwd)
	HomeDir=$HOME
}

function get_user_options
{
	echo 
	say @B"Please input your Guacamole username:" yellow
	read guacamole_username
	echo 
	say @B"Please input your Guacamole password:" yellow
	read guacamole_password_prehash
	read guacamole_password_md5 <<< $(echo -n $guacamole_password_prehash | md5sum | awk '{print $1}')
	echo 
	say @B"Would you like Guacamole to connect to the server desktop through RDP or VNC?" yellow
	say @B"Input 1 for RDP, or 2 for VNC.  If you have no idea what's this, please choose 1." yellow
	read choice_rdpvnc
	echo 
	if [ $choice_rdpvnc = 1 ] ; then
		say @B"Please choose a screen resolution." yellow
		echo "Choose 1 for 1280x800 (default), 2 to fit your local screen, or 3 to manually configure RDP screen resolution."
		read rdp_resolution_options
		if [ $rdp_resolution_options = 2 ] ; then
			set_rdp_resolution=0;
		else
			set_rdp_resolution=1;
			if [ $rdp_resolution_options = 3 ] ; then
				echo 
				echo "Please type in screen width (default is 1280):"
				read rdp_screen_width_input
				echo "Please type in screen height (default is 800):"
				read rdp_screen_height_input
				if [ $rdp_screen_width_input -gt 1 ] && [ $rdp_screen_height_input -gt 1 ] ; then
					rdp_screen_width=$rdp_screen_width_input
					rdp_screen_height=$rdp_screen_height_input
				else
					say "Invalid screen resolution input." red
					echo 
					exit 1
				fi
			else
				rdp_screen_width=1280
				rdp_screen_height=800
			fi
		fi
		say @B"Screen resolution successfully configured." green
	else
		echo 
		while [ ${#vnc_password} != 8 ] ; do
			say @B"Please input your 8-character VNC password:" yellow
		read vnc_password
		done
		say @B"VNC password successfully configured." green
		echo "Please note that VNC password is NOT needed for browser access."
		sleep 1
	fi
	echo 
	say @B"Would you like to set up Nginx Reverse Proxy?" yellow
	say @B"Please note that if you want to copy or paste text between the server and your computer, you MUST set up an Nginx Reverse Proxy AND an SSL certificate.  You can set it up later manually though." yellow
	echo "Please type [Y/n]:"
	read install_nginx
	if [ "x$install_nginx" = "xY" ] || [ "x$install_nginx" = "xy" ] ; then
		echo 
		say @B"Please tell me your domain name (e.g., desktop.qing.su):" yellow
		read guacamole_hostname
		echo 
		echo 
		echo "Would you like to install a free Let's Encrypt certificate for domain name ${guacamole_hostname}? [Y/N]"
		say @B"Please point your domain name to this server IP BEFORE continuing!" yellow
		echo "Type Y if you are sure that your domain is now pointing to this server IP."
		read confirm_letsencrypt
		echo 
		if [ "x$confirm_letsencrypt" = "xY" ] || [ "x$confirm_letsencrypt" = "xy" ] ; then
			echo "Please input an e-mail address:"
			read le_email
		fi
	else
		say @B"OK, Nginx will NOT be installed on this server." yellow
	fi
	echo 
	say @B"Desktop environment installation will start now.  Please wait." green
	sleep 3
}	

function install_guacamole
{
	echo 
	say @B"Setting up dependencies..." yellow
	echo 
	apt-get update && apt-get upgrade -y
	apt-get install wget curl sudo zip unzip tar perl expect build-essential libcairo2-dev libpng-dev libtool-bin libossp-uuid-dev libvncserver-dev freerdp2-dev libssh2-1-dev libtelnet-dev libwebsockets-dev libpulse-dev libvorbis-dev libwebp-dev libssl-dev libpango1.0-dev libswscale-dev libavcodec-dev libavutil-dev libavformat-dev tomcat9 tomcat9-admin tomcat9-common tomcat9-user japan* chinese* korean* fonts-arphic-ukai fonts-arphic-uming fonts-ipafont-mincho fonts-ipafont-gothic fonts-unfonts-core -y
	if [ "$OS" = "DEBIAN10" ] ; then
		apt-get install libjpeg62-turbo-dev -y
	else
		apt-get install libjpeg-turbo8-dev language-pack-ja language-pack-zh* language-pack-ko -y
	fi
	wget $GUACAMOLE_DOWNLOAD_LINK
	tar zxf guacamole-server-${GUACAMOLE_VERSION}.tar.gz
	rm -f guacamole-server-${GUACAMOLE_VERSION}.tar.gz
	cd $CurrentDir/guacamole-server-$GUACAMOLE_VERSION
	echo "Start building Guacamole Server from source..."
	./configure --with-init-dir=/etc/init.d
	if [ -f $CurrentDir/guacamole-server-$GUACAMOLE_VERSION/config.status ] ; then
		say @B"Dependencies met!" green
		say @B"Compiling now..." green
		echo
	else
		echo 
		say "Missing dependencies." red
		echo "Please check log, install required dependencies, and run this script again."
		echo "Please also consider to report your log here https://github.com/Har-Kuun/OneClickDesktop/issues so that I can fix this issue."
		echo "Thank you!"
		echo 
		exit 1
	fi
	sleep 2
	make
	make install
	ldconfig
	echo "Trying to start Guacamole Server for the first time..."
	echo "This can take a while..."
	echo 
	systemctl daemon-reload
	systemctl start guacd
	systemctl enable guacd
	ss -lnpt | grep guacd >/dev/null
	if [ $? = 0 ] ; then
		say @B"Guacamole Server successfully installed!" green
		echo 
	else 
		say "Guacamole Server installation failed." red
		say @B"Please check the above log for reasons." yellow
		echo "Please also consider to report your log here https://github.com/Har-Kuun/OneClickDesktop/issues so that I can fix this issue."
		echo "Thank you!"
		exit 1
	fi
}

function install_guacamole_web
{
	echo 
	echo "Start installaing Guacamole Web Application..."
	cd $CurrentDir
	wget https://downloads.apache.org/guacamole/$GUACAMOLE_VERSION/binary/guacamole-$GUACAMOLE_VERSION.war
	mv guacamole-$GUACAMOLE_VERSION.war /var/lib/tomcat9/webapps/guacamole.war
	systemctl restart tomcat9 guacd
	echo 
	say @B"Guacamole Web Application successfully installed!" green
	echo 
}

function configure_guacamole
{
	echo 
	mkdir /etc/guacamole/
	cat > /etc/guacamole/guacamole.properties <<END
guacd-hostname: localhost
guacd-port: 4822
auth-provider: net.sourceforge.guacamole.net.basic.BasicFileAuthenticationProvider
basic-user-mapping: /etc/guacamole/user-mapping.xml
END
	if [ $choice_rdpvnc = 1 ] ; then
		if [ $set_rdp_resolution = 0 ] ; then
			cat > /etc/guacamole/user-mapping.xml <<END
<user-mapping>
    <authorize
         username="$guacamole_username"
         password="$guacamole_password_md5"
         encoding="md5">      
       <connection name="default">
         <protocol>rdp</protocol>
         <param name="hostname">localhost</param>
         <param name="port">3389</param>
       </connection>
    </authorize>
</user-mapping>
END
		else
			cat > /etc/guacamole/user-mapping.xml <<END
<user-mapping>
    <authorize
         username="$guacamole_username"
         password="$guacamole_password_md5"
         encoding="md5">      
       <connection name="default">
         <protocol>rdp</protocol>
         <param name="hostname">localhost</param>
         <param name="port">3389</param>
		 <param name="width">$rdp_screen_width</param>
		 <param name="height">$rdp_screen_height</param>
       </connection>
    </authorize>
</user-mapping>
END
		fi
	else
		cat > /etc/guacamole/user-mapping.xml <<END
<user-mapping>
    <authorize
         username="$guacamole_username"
         password="$guacamole_password_md5"
         encoding="md5">      
       <connection name="default">
         <protocol>vnc</protocol>
         <param name="hostname">localhost</param>
         <param name="port">5901</param>
         <param name="password">$vnc_password</param>
       </connection>
    </authorize>
</user-mapping>
END
	fi
	systemctl restart tomcat9 guacd
	say @B"Guacamole successfully configured!" green
	echo 
}

function install_vnc
{
	echo 
	echo "Starting to install desktop, browser, and VNC server..."
	say @B"Please note that if you are asked to configure LightDM during this step, simply press Enter." yellow
	echo 
	echo "Press Enter to continue."
	read catch_all
	echo 
	if [ "$OS" = "DEBIAN10" ] ; then
		apt-get install xfce4 xfce4-goodies firefox-esr tigervnc-standalone-server tigervnc-common -y
	else 
		apt-get install xfce4 xfce4-goodies firefox tigervnc-standalone-server tigervnc-common -y
	fi
	say @B"Desktop, browser, and VNC server successfully installed." green
	echo "Starting to configure VNC server..."
	sleep 2
	echo 
	mkdir $HomeDir/.vnc
	cat > $HomeDir/.vnc/xstartup <<END
#!/bin/bash

xrdb $HomeDir/.Xresources
startxfce4 &
END
	cat > /etc/systemd/system/vncserver@.service <<END
[Unit]
Description=a wrapper to launch an X server for VNC
After=syslog.target network.target

[Service]
Type=forking
User=$CurrentUser
Group=$CurrentUser
WorkingDirectory=$HomeDir

ExecStartPre=-/usr/bin/vncserver -kill :%i > /dev/null 2>&1
ExecStart=/usr/bin/vncserver -depth 24 -geometry 1280x800 -localhost :%i
ExecStop=/usr/bin/vncserver -kill :%i

[Install]
WantedBy=multi-user.target
END
	vncpassbinpath=/usr/bin/vncpasswd
	/usr/bin/expect <<END
spawn "$vncpassbinpath"
expect "Password:"
send "$vnc_password\r"
expect "Verify:"
send "$vnc_password\r"
expect "Would you like to enter a view-only password (y/n)?"
send "n\r"
expect eof
exit
END
	vncserver
	sleep 2
	vncserver -kill :1
	systemctl start vncserver@1.service
	systemctl enable vncserver@1.service
	/usr/bin/vncconfig -display :1 &
	cat > $HomeDir/Desktop/EnableCopyPaste.sh <<END
#!/bin/bash
/usr/bin/vncconfig -display :1 &
END
	chmod +x $HomeDir/Desktop/EnableCopyPaste.sh
	echo 
	ss -lnpt | grep vnc > /dev/null
	if [ $? = 0 ] ; then
		say @B"VNC and desktop successfully configured!" green
		echo 
	else
		say "VNC installation failed!" red
		say @B"Please check the above log for reasons." yellow
		echo "Please also consider to report your log here https://github.com/Har-Kuun/OneClickDesktop/issues so that I can fix this issue."
		echo "Thank you!"
		exit 1
	fi
}

function install_rdp
{
	echo 
	echo "Starting to install desktop, browser, and XRDP server..."
	say @B"Please note that if you are asked to configure LightDM during this step, simply press Enter." yellow
	echo 
	echo "Press Enter to continue."
	read catch_all
	echo 
	if [ "$OS" = "DEBIAN10" ] ; then
		apt-get install xfce4 xfce4-goodies firefox-esr xrdp -y
	else 
		apt-get install xfce4 xfce4-goodies firefox xrdp -y
	fi
	say @B"Desktop, browser, and XRDP server successfully installed." green
	echo "Starting to configure XRDP server..."
	sleep 2
	echo 
	mv /etc/xrdp/startwm.sh /etc/xrdp/startwm.sh.backup
	cat > /etc/xrdp/startwm.sh <<END
#!/bin/sh
# xrdp X session start script (c) 2015, 2017 mirabilos
# published under The MirOS Licence

if test -r /etc/profile; then
        . /etc/profile
fi

if test -r /etc/default/locale; then
        . /etc/default/locale
        test -z "${LANG+x}" || export LANG
        test -z "${LANGUAGE+x}" || export LANGUAGE
        test -z "${LC_ADDRESS+x}" || export LC_ADDRESS
        test -z "${LC_ALL+x}" || export LC_ALL
        test -z "${LC_COLLATE+x}" || export LC_COLLATE
        test -z "${LC_CTYPE+x}" || export LC_CTYPE
        test -z "${LC_IDENTIFICATION+x}" || export LC_IDENTIFICATION
        test -z "${LC_MEASUREMENT+x}" || export LC_MEASUREMENT
        test -z "${LC_MESSAGES+x}" || export LC_MESSAGES
        test -z "${LC_MONETARY+x}" || export LC_MONETARY
        test -z "${LC_NAME+x}" || export LC_NAME
        test -z "${LC_NUMERIC+x}" || export LC_NUMERIC
        test -z "${LC_PAPER+x}" || export LC_PAPER
        test -z "${LC_TELEPHONE+x}" || export LC_TELEPHONE
        test -z "${LC_TIME+x}" || export LC_TIME
        test -z "${LOCPATH+x}" || export LOCPATH
fi

if test -r /etc/profile; then
        . /etc/profile
fi

 xfce4-session

test -x /etc/X11/Xsession && exec /etc/X11/Xsession
exec /bin/sh /etc/X11/Xsession

END
	chmod +x /etc/xrdp/startwm.sh
	systemctl enable xrdp
	systemctl restart xrdp
	sleep 5
	echo "Waiting to start XRDP server..."
	systemctl restart guacd
	cat > /etc/systemd/system/restartguacd.service <<END
[Unit]
Descript=Restart GUACD

[Service]
ExecStart=/etc/init.d/guacd start
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target

END
	systemctl daemon-reload
	systemctl enable restartguacd
	ss -lnpt | grep xrdp > /dev/null
	if [ $? = 0 ] ; then
		ss -lnpt | grep guacd > /dev/null
		if [ $? = 0 ] ; then
			say @B"XRDP and desktop successfully configured!" green
		else 
			say @B"XRDP and desktop successfully configured!" green
			sleep 3
			systemctl start guacd
		fi
		echo 
	else
		say "XRDP installation failed!" red
		say @B"Please check the above log for reasons." yellow
		echo "Please also consider to report your log here https://github.com/Har-Kuun/OneClickDesktop/issues so that I can fix this issue."
		echo "Thank you!"
		exit 1
	fi
}

function display_license
{
	echo 
	echo '*******************************************************************'
	echo '*       One-click Desktop & Browser Access Setup Script           *'
	echo '*       Version 0.0.2                                             *'
	echo '*       Author: shc (Har-Kuun) https://qing.su                    *'
	echo '*       https://github.com/Har-Kuun/OneClickDesktop               *'
	echo '*       Thank you for using this script.  E-mail: hi@qing.su      *'
	echo '*******************************************************************'
	echo 
}

function install_reverse_proxy
{
	echo 
	say @B"Setting up Nginx reverse proxy..." yellow
	sleep 2
	apt-get install nginx certbot python3-certbot-nginx -y
	say @B"Nginx successfully installed!" green
	cat > /etc/nginx/conf.d/guacamole.conf <<END
server {
        listen 80;
        listen [::]:80;
        server_name $guacamole_hostname;

        access_log  /var/log/nginx/guac_access.log;
        error_log  /var/log/nginx/guac_error.log;

        location / {
                    proxy_pass http://127.0.0.1:8080/guacamole/;
                    proxy_buffering off;
                    proxy_http_version 1.1;
                    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                    proxy_set_header Upgrade \$http_upgrade;
                    proxy_set_header Connection \$http_connection;
                    proxy_cookie_path /guacamole/ /;
        }

}
END
	systemctl reload nginx
	if [ "x$confirm_letsencrypt" = "xY" ] || [ "x$confirm_letsencrypt" = "xy" ] ; then
		certbot --nginx --agree-tos --redirect --hsts --staple-ocsp --email $le_email -d $guacamole_hostname
		echo 
		if [ -f /etc/letsencrypt/live/$guacamole_hostname/fullchain.pem ] ; then
			say @B"Congratulations! Let's Encrypt SSL certificate installed successfully!" green
			say @B"You can now access your desktop at https://${guacamole_hostname}!" green
		else
			say "Oops! Let's Encrypt SSL certificate installation failed." red
			say @B"Please manually try \"certbot --nginx --agree-tos --redirect --hsts --staple-ocsp --email $le_email -d $guacamole_hostname\"." yellow
			say @B"You can now access your desktop at http://${guacamole_hostname}!" green
		fi
	else
		say @B"Let's Encrypt certificate not installed! If you would like to install a Let's Encrypt certificate later, please manually run \"certbot --nginx --agree-tos --redirect --hsts --staple-ocsp -d $guacamole_hostname\"." yellow
		say @B"You can now access your desktop at http://${guacamole_hostname}!" green
	fi
	say @B"Your username is $guacamole_username and your password is $guacamole_password_prehash." green
}

function main
{
	display_license
	if [ "x$OS_CHECK_ENABLED" != "xOFF" ] ; then
		check_OS
	fi
	echo "This script is going to install a desktop environment with browser access."
	echo 
	say @B"This environment requires at least 1 GB of RAM." yellow
	echo 
	echo "Would you like to proceed? [Y/N]"
	read confirm_installation
	if [ "x$confirm_installation" = "xY" ] || [ "x$confirm_installation" = "xy" ] ; then
		determine_system_variables
		get_user_options
		install_guacamole
		install_guacamole_web
		configure_guacamole
		if [ $choice_rdpvnc = 1 ] ; then
			install_rdp
		else
			install_vnc
		fi
		if [ "x$install_nginx" = "xY" ] || [ "x$install_nginx" = "xy" ] ; then
			install_reverse_proxy
		else
			say @B"You can now access your desktop at http://$(curl -s icanhazip.com):8080/guacamole!" green
			say @B"Your Guacamole username is $guacamole_username and your password is $guacamole_password_prehash." green
		fi
		if [ $choice_rdpvnc = 1 ] ; then
			echo 
			say @B"Note that after entering Guacamole using the above Guacamole credentials, you will be asked to input your Linux server username and password in the XRDP login panel, which is NOT the guacamole username and password above." yellow
		fi
	fi
	echo 
	echo "Thank you for using this script written by https://qing.su!"
	echo "Have a nice day!"
}

###############################################################
#                                                             #
#               The main function starts here.                #
#                                                             #
###############################################################

main
exit 0
