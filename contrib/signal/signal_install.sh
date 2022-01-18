#!/bin/bash
#$Id:$
SCRIPTVERSION="3.3"
# Author: Adimarantis
# License: GPL
#Install script for signal-cli 
SIGNALPATH=/opt
SIGNALUSER=signal-cli
LIBPATH=/usr/lib
SIGNALVERSION="0.9.2"
SIGNALVAR=/var/lib/$SIGNALUSER
DBSYSTEMD=/etc/dbus-1/system.d
DBSYSTEMS=/usr/share/dbus-1/system-services
SYSTEMD=/etc/systemd/system
LOG=/tmp/signal_install.log
TMPFILE=/tmp/signal$$.tmp
VIEWER=eog
DBVER=0.19
OPERATION=$1
JAVA_VERSION=11.0

if [ $OPERATION = "experimental" ]; then
  SIGNALVERSION="0.10.1"
  JAVA_VERSION=17.0
  OPERATION=
fi

#Make sure picture viewer exists
VIEWER=`which $VIEWER`

#Get OS data
if [ -e /etc/os-release ]; then
	source /etc/os-release
	cat /etc/os-release >$LOG
else
	echo "Could not find OS release data - are you on Linux?"
	exit
fi

if grep -q docker /proc/1/cgroup; then 
   echo "You seem to run in a docker environment."
   export LC_ALL=C
   export DEBIAN_FRONTEND=noninteractive
	USER=`id | grep root`
	if [ -z "$USER" ]; then
		echo "Docker Installation needs to run under root"
		exit
	fi
   DOCKER=yes
   if [ -n "$FHEMUSER" ]; then
		SIGNALUSER=$FHEMUSER
	fi
	#overide path so its in the "real" world
	SIGNALPATH=/opt/fhem
fi

#
install_and_check() {
#Check availability of tools and install via apt if missing
	TOOL=$1
	PACKAGE=$2
	echo -n "Checking for $TOOL..."
	WHICH=`which $TOOL`
	if [ -z "$WHICH" ]; then
		echo -n "installing ($PACKAGE)"
		apt-get -q -y install $PACKAGE >>$LOG
		WHICH=`which $TOOL`
		if [ -z "$TOOL" ]; then
			echo "Failed to install $TOOL"
			exit
		else
			echo "done"
		fi
	else
		echo "available"
	fi
}

install_by_file() {
#Check availability of tools and install via apt if missing
	FILE=$1
	PACKAGE=$2
	echo -n "Checking for $FILE..."
	if ! [ -e "$FILE" ]; then
		echo -n "installing ($PACKAGE)"
		apt-get -q -y install $PACKAGE >>$LOG
		if ! [ -e "$FILE" ]; then
			echo "Failed to install $FILE"
			exit
		else
			echo "done"
		fi
	else
		echo "available"
	fi
}


check_and_create_path() {
#Check if path is available and create of not
	CHECK=$1
	echo -n "Checking for $CHECK..."
	if ! [ -d $CHECK ]; then
		mkdir $1
		if ! [ -d $CHECK ]; then
			echo "Failed to create $CHECK - did you run on sudo?"
			exit
		else
			echo "created"
		fi
	else
		echo "found"
	fi
	if ! [ -w $CHECK ]; then
		echo "Cannot write to $CHECK - did you start this script with sudo?"
		exit
	fi
}

check_and_compare_file() {
#Check if a file exists and compare if its the same as our internal reference file
	CHECK=$1
	COMPARE=$2
	echo -n "Checking for $CHECK..."
	if [ -e $CHECK ]; then
		echo "found"
		diff $CHECK $COMPARE
		DIFF=`diff -q $CHECK $COMPARE`
		if ! [ -z "$DIFF" ]; then
			echo "$CHECK differs, update (Y/n)? "
			read REPLY
			if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
				cp $COMPARE $CHECK
				echo "$CHECK updated"
			else 
			echo "$CHECK left untouched"
			fi
		fi
	else
		cp $COMPARE $CHECK
		echo "$CHECK installed"
	fi
}

#Main part - do always, check basic system requirements like OS, packages etc - does not install any signal specific stuff

ARCH=`arch`
OSNAME=`uname`
APT=`which apt`
if [ $ARCH = "armv7l" ]; then 
	ARCH="armhf"
	ARCHJ="arm"
elif [ $ARCH = "x86_64" ]; then
	ARCH="amd64"
	ARCHJ="x64"
fi
GLIBC=`ldd --version |  grep -m1 -o '[0-9]\.[0-9][0-9]' | head -n 1`

IDENTSTR=$ARCH-glibc$GLIBC-$SIGNALVERSION
KNOWN=("amd64-glibc2.27-0.9.0" "amd64-glibc2.28-0.9.0" "amd64-glibc2.31-0.9.0" "armhf-glibc2.28-0.9.0" "amd64-glibc2.27-0.9.2" "amd64-glibc2.28-0.9.2" "amd64-glibc2.31-0.9.2" "armhf-glibc2.28-0.9.2" "armhf-glibc2.31-0.9.2" "armhf-glibc2.31-0.10.1")

GETLIBS=1
if [[ ! " ${KNOWN[*]} " =~ " ${IDENTSTR} " ]]; then
    echo "$IDENTSTR is an unsupported combination - signal-cli binary libraries might not work"
	GETLIBS=0
fi

if [ $OSNAME != "Linux" ]; then
	echo "Only Linux systems are supported (you: $OSNAME), quitting"
	exit
fi
if [ -z "$APT" ]; then
	echo "Your system does not have apt installed, quitting"
	exit
fi

if [ -z "$OPERATION" ] || [ "$OPERATION" = "system" ] || [ "$OPERATION" = "install" ] || [ "$OPERATION" = "all" ]; then
echo "This script will help you to install signal-cli as system dbus service"
echo "and prepare the use of the FHEM Signalbot module"
echo
echo "Please verify that these settings are correct:"
echo "Signal-cli User:              $SIGNALUSER"
echo "Signal-cli Install directory: $SIGNALPATH"
echo "Signal config storage:        $SIGNALVAR"
echo "Signal version:               $SIGNALVERSION"
echo "System library path:          $LIBPATH"
echo "System architecture:          $ARCH"
echo "System GLIBC version:         $GLIBC"
fi

check_and_update() {

check_and_create_path $LIBPATH
check_and_create_path /etc/dbus-1
check_and_create_path $DBSYSTEMD
check_and_create_path /usr/share/dbus-1
check_and_create_path $DBSYSTEMS
check_and_create_path $SYSTEMD
check_and_create_path /run/dbus

if [ -n "$DOCKER" ]; then
	echo -n "Running in Docker, performing apt update/upgrade..."
	apt-get -q -y update
	apt-get -q -y upgrade
	echo "done"
fi

install_and_check apt-ftparchive apt-utils
install_and_check wget wget
install_and_check sudo sudo
install_and_check haveged haveged
install_and_check java default-jre
install_and_check diff diffutils
install_and_check dbus-send dbus
install_and_check cpan cpanminus
install_and_check zip zip
if [ -z "$BASH" ]; then
	echo "This script requires bash for some functions. Check if bash is installed."
	install_and_check bash bash
	echo "Please re-run using bash"
	exit
fi

#For DBus check a number of Perl modules on file level
install_by_file /usr/include/dbus-1.0/dbus/dbus.h libdbus-1-dev
install_by_file /usr/share/build-essential/essential-packages-list build-essential
install_by_file /usr/share/doc/libimage-librsvg-perl libimage-librsvg-perl
install_by_file /usr/share/perl5/URI.pm liburi-perl

cat >$TMPFILE <<EOF
#!/usr/bin/perl -w
use strict;
use warnings;

use Protocol::DBus;
print \$Protocol::DBus::VERSION."\n";
EOF

echo -n "Checking for Protocol::DBus..."
NETDBUS=`perl $TMPFILE`

if [ "$NETDBUS" = "$DBVER" ]; then
	echo "V$NETDBUS found"
else
	export PERL_MM_USE_DEFAULT=1
	echo -n "Installing latest Protocol::DBus..."
	cpan install Protocol::DBus >>$LOG 2>>$LOG
	echo "done"
fi

echo -n "Checking user $SIGNALUSER ..."
if id "$SIGNALUSER" &>/dev/null; then
    echo 'found'
else
	adduser --disabled-password --gecos none $SIGNALUSER
    echo 'created'
fi

echo -n "Checking system Java version ... "
JVER=`java --version | grep -m1 -o '[0-9][0-9]\.[0-9]'`
echo $JVER
if ! [ "$JAVA_VERSION" = "$JVER" ]; then
	if [ -e /opt/java ]; then
		echo -n "Checking for Java in /opt/java ... "
		JVER=`/opt/java/bin/java --version | grep -m1 -o '[0-9][0-9]\.[0-9]'`
		echo $JVER
	fi
	if ! [ "$JVER" = "$JAVA_VERSION" ]; then
		echo "Java version mismatch - version $JAVA_VERSION required"
		echo -n "Download from adoptium.net (this can take a while) ..."
		cd /tmp
		JAVA_ARC=OpenJDK17U-jdk_$ARCHJ\_linux_hotspot_17.0.1_12.tar.gz
		wget -qN https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.1%2B12/$JAVA_ARC
		if [ -z $JAVA_ARC ]; then
			echo "failed"
			exit
		fi
		echo "successful"
		cd /opt
		echo -n "Unpacking ..."
		tar zxf /tmp/$JAVA_ARC
		rm -rf /opt/java
		mv jdk* java
		rm /tmp/$JAVA_ARC
		echo "done"
	fi
	JAVA_HOME=/opt/java
fi
}

#Check, install the signal-cli package as system dbus
#After this, signal-cli should be running and ready to use over dbus
install_signal_cli() {

check_and_create_path $SIGNALPATH
check_and_create_path $SIGNALVAR

NEEDINSTALL=0
echo -n "Checking for existing signal-cli installation..."
if [ -x "$SIGNALPATH/signal/bin/signal-cli" ]; then
	echo "found"
	echo -n "Checking signal-cli version..."
	CHECKVER=`$SIGNALPATH/signal/bin/signal-cli -v`
	echo $CHECKVER
	if [ "$CHECKVER" = "signal-cli $SIGNALVERSION" ]; then
		echo "signal-cli matches target version...ok"
	else 
		echo -n "Update to current version (y/N)? "
		read REPLY
		if [ "$REPLY" = "y" ]; then
			NEEDINSTALL=1
		fi
	fi
else
	echo "not found"
	NEEDINSTALL=1
fi

if [ $NEEDINSTALL = 1 ]; then
	echo "Proceed with signal cli installation"
	stop_service
	cd /tmp
	echo -n "Downloading signal-cli $SIGNALVERSION..."
	wget -qN https://github.com/AsamK/signal-cli/releases/download/v$SIGNALVERSION/signal-cli-$SIGNALVERSION.tar.gz
	if ! [ -e signal-cli-$SIGNALVERSION.tar.gz ]; then
		echo "failed"
		exit
	else
		echo "done"
		echo "Unpacking ..."
		cd $SIGNALPATH
		tar zxf /tmp/signal-cli-$SIGNALVERSION.tar.gz
		rm -rf signal
		mv "signal-cli-$SIGNALVERSION" signal
		if [ "$GETLIBS" = 1 ]; then
			echo -n "Downloading native libraries..."
			cd /tmp
			rm -rf libsignal_jni.so libzkgroup.so
			if [ $JAVA_VERSION = "11.0" ]; then
				wget -qN https://github.com/bublath/FHEM-Signalbot/raw/main/$IDENTSTR/libzkgroup.so
			fi
			wget -qN https://github.com/bublath/FHEM-Signalbot/raw/main/$IDENTSTR/libsignal_jni.so
			echo "done"
			echo "Updating native libs for $IDENTSTR"
			if [ $JAVA_VERSION = "11.0" ]; then
				zip -u $SIGNALPATH/signal/lib/zkgroup-java-*.jar libzkgroup.so
			fi
			zip -u $SIGNALPATH/signal/lib/signal-client-java-*.jar libsignal_jni.so
			#Use updated libs in jar instead of /usr/lib
			#mv libsignal_jni.so libzkgroup.so $LIBPATH
			#rm -f $LIBDIR/libzkgroup.so $LIBDIR/libsignal_jni.so
		fi
		echo "done"
		rm -f /tmp/signal-cli-$SIGNALVERSION.tar.gz
		cd /opt/signal/bin
		mv signal-cli signal-cli.org
		echo "#!/bin/sh" >signal-cli
		echo "JAVA_HOME=$JAVA_HOME" >>signal-cli
		cat signal-cli.org >>signal-cli
		chmod a+x signal-cli
	fi
fi

#Updating ownership anyway - just if case
chown -R $SIGNALUSER: $SIGNALVAR
chown -R $SIGNALUSER: $SIGNALPATH/signal

if [ -z "$DOCKER" ]; then
	#Don't do this in Docker environment

cat >$TMPFILE <<EOF
<?xml version="1.0"?> <!--*-nxml-*-->
	<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
	  "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
	
	<busconfig>
	  <policy user="$SIGNALUSER">
	          <allow own="org.asamk.Signal"/>
	          <allow send_destination="org.asamk.Signal"/>
	          <allow receive_sender="org.asamk.Signal"/>
	  </policy>
	
	  <policy context="default">
	          <allow send_destination="org.asamk.Signal"/>
	          <allow receive_sender="org.asamk.Signal"/>
	  </policy>
	</busconfig>

EOF

check_and_compare_file $DBSYSTEMD/org.asamk.Signal.conf $TMPFILE

cat >$TMPFILE <<EOF
[D-BUS Service]
Name=org.asamk.Signal
Exec=/bin/false
User=$SIGNALUSER
SystemdService=dbus-org.asamk.Signal.service
EOF

check_and_compare_file  $DBSYSTEMS/org.asamk.Signal.service $TMPFILE

cat >$TMPFILE <<EOF
[Unit]
Description=Send secure messages to Signal clients
Requires=dbus.socket
After=dbus.socket
Wants=network-online.target
After=network-online.target
	
[Service]
Type=dbus
Environment="SIGNAL_CLI_OPTS=-Xms2m"
ExecStart=$SIGNALPATH/signal/bin/signal-cli --config $SIGNALVAR daemon --system
User=$SIGNALUSER
BusName=org.asamk.Signal
	
[Install]
WantedBy=multi-user.target
Alias=dbus-org.asamk.Signal.service
EOF

	check_and_compare_file  $SYSTEMD/signal.service $TMPFILE

	#Reload config after change
	systemctl daemon-reload
	systemctl enable signal.service
	systemctl reload dbus.service
fi
}

#stop service depending on Docker or not
stop_service() {
  if [ -z "$DOCKER" ]; then
	echo "Stopping signal-cli service"
	service signal stop
  else
	SIGSERVICE=`ps -eo pid,command | grep $SIGNALVAR | grep -v grep`
	if [ -n "$SIGSERVICE" ]; then
		echo "Stopping signal-cli daemon for Docker"
		ARRAY=($SIGSERVICE)
		PID=${ARRAY[0]}
		kill $PID
	fi
  fi
}

#start service depending on Docker or not
start_service() {
	if [ -z "$DOCKER" ]; then
		echo "Start signal-cli service"
		service signal start
	else
		DBDAEMON=`ps -eo command | grep dbus-daemon | grep -v grep`
		if [ -z "$DBDAEMON" ]; then
			rm /run/dbus/pid
			echo "Starting dbus daemon for Docker"
			dbus-daemon --system --address=unix:path=/run/dbus/system_bus_socket >/var/log/dbus.log 2>/var/log/dbus.err &
		fi
		echo -n "Waiting for dbus to become ready."
		WAIT=""
		while [ -z "$WAIT" ]
		do
			WAIT=`ps -eo pid,command | grep dbus-daemon | grep -v grep`
			echo -n "."
			sleep 1
		done
		echo "running"
		SIGSERVICE=`ps -eo pid,command | grep $SIGNALVAR | grep -v grep`
		WAITCHECK="ps -eo pid,command | grep $SIGNALVAR | grep java | grep -v grep"
		if [ -z "$SIGSERVICE" ]; then
			cd $SIGNALPATH/signal/bin
			echo "Starting signal-cli daemon for Docker"
			sudo -u $SIGNALUSER ./signal-cli --config $SIGNALVAR daemon --system >/var/log/signal.log 2>/var/log/signal.err &
			WAITCHECK="grep dbus /var/log/signal.err"
		fi
		echo -n "Waiting for signal-cli to become ready."
		WAIT=""
		while [ -z "$WAIT" ]
		do
			WAIT=`$WAITCHECK`
			echo -n "."
			sleep 1
		done
		echo "running"
	fi
}

test_device() {
start_service
echo -n "Checking installation via dbus-send command..."
REPLY=`dbus-send --system --type=method_call --print-reply --dest="org.asamk.Signal" /org/asamk/Signal org.asamk.Signal.version`
REP1=`echo $REPLY | grep $SIGNALVERSION`
#REP2=`echo $REPLY | grep "boolean true"`

if [ -n "$REP1" ]; then
   echo "success" # - "signal-cli running in standard registration mode"
else
   echo "unexpected reply"
   echo $REPLY
fi
#if [ -n "$REP2"  ]; then
#   echo "partial success - still running in -u mode - check $SYSTEMD/signal.service"
#fi

cat <<EOF >$TMPFILE
#!/usr/bin/perl -w
use strict;
use warnings;

use Protocol::DBus::Client;

my \$dbus = Protocol::DBus::Client::system();
\$dbus->initialize();
\$dbus->get_message();

my \$got_response;
my @recipients=('$RECIPIENT');
my @att=();
\$dbus->send_call(
	path => '/org/asamk/Signal',
	interface => 'org.asamk.Signal',
	signature => '',
	body => undef,
	destination => 'org.asamk.Signal',
	member => 'version',
)->then( sub {
	print "reply received\n";
} )->catch( sub {
	print "Error getting reply\n";
} )->finally( sub {
	\$got_response = 1;
} );

\$dbus->get_message() while !\$got_response;
EOF
echo -n "Sending a message via perl Protocol::DBus..."
perl $TMPFILE
}

remove_all() {
#just in case paths are wrong to not accidentially remove wrong things
 cd /tmp
echo "Warning. This will remove signal-cli and all related configurations from your system"
echo "Your configuration will be archived to $HOME/signalconf.tar.gz"
echo -n "Continue (y/N)? "
read REPLY
if ! [ "$REPLY" = "y" ]; then
	echo "Abort"
	exit
fi

stop_service

echo "Archiving config"
tar czf ~/signalconf.tar.gz $SIGNALVAR
echo "Removing files"
rm -rf $SIGNALVAR
rm -rf $SIGNALPATH/signal
rm -f $LIBPATH/libsignal_jni.so 
rm -f $LIBPATH/libzkgroup.so 
rm -f $DBSYSTEMD/org.asamk.Signal.conf
rm -f $DBSYSTEMS/org.asamk.Signal.service
rm -f $SYSTEMD/signal.service
echo "Disabling services"
if [ -z "$DOCKER" ]; then
	systemctl daemon-reload
	systemctl disable signal.service
	systemctl reload dbus.service
else
	DBDAEMON=`ps -eo pid,command | grep dbus-daemon | grep -v grep`
	if [ -n "$DBDAEMON" ]; then
		echo "Stopping dbus daemon for Docker"
		ARRAY=($DBDAEMON)
		PID=${ARRAY[0]}
		kill $PID
	fi
fi
}

if [ -z "$OPERATION" ] ; then
	echo "This will update system packages, install or uninstall signal-cli"
	echo
	echo "system   : prepare required system package (except signal-cli)"
	echo "install  : install signal-cli and setup as dbus system service"
	echo "test     : run a basic test if everything is installed and registered correctly"
	echo "remove   : Remove signal-cli and all configurations (will be archived)"
	echo "start    : Start the signal-cli service (or respective docker processes)"
	echo "all      : Run system, install, start and test (default)"
	echo
	echo "!!! Everything needs to run with sudo/root !!!"
	OPERATION=all
else
	echo "You chose the following option: $OPERATION"
fi
echo
if [ -z "$OPERATION" ] || [ "$OPERATION" = "system" ] || [ "$OPERATION" = "install" ] || [ "$OPERATION" = "all" ]; then
  echo -n "Proceed (Y/n)? "
  read REPLY
  if [ "$REPLY" = "n" ]; then
	echo "Aborting..."
	exit
  fi
fi

if [ $OPERATION = "docker" ]; then
	OPERATION=""
fi

# Main flow without option: intall, register
if [ -z "$OPERATION" ] || [ $OPERATION = "all" ] || [ $OPERATION = "system" ]; then
	check_and_update
fi

if [ -z "$OPERATION" ] || [ $OPERATION = "all" ] || [ $OPERATION = "install" ]; then
	install_signal_cli
fi

if [ -z "$OPERATION" ] || [ $OPERATION = "all" ] || [ $OPERATION = "test" ]; then
	test_device
	exit
fi

# Other options
if [ $OPERATION = "remove" ]; then 
	remove_all
fi

if [ $OPERATION = "start" ]; then
	start_service
fi

if [ $OPERATION = "backup" ]; then
	echo "Creating backup of all configuration files"
	stop_service
	rm signal-backup.tar.gz
	tar czPf signal-backup.tar.gz $SIGNALVAR $DBSYSTEMD/org.asamk.Signal.conf  $DBSYSTEMS/org.asamk.Signal.service $SYSTEMD/signal.service
	start_service
	ls -l signal-backup.tar.gz
fi

if [ $OPERATION = "restore" ]; then
	if ! [ -e signal-backup.tar.gz ]; then
		echo "Make sure signal-backup.tar.gz is in current directory"
		exit
	fi
	echo "Are you sure you want to restore all signal-cli configuration files?"
	echo -n "Any existing configuration will be lost (y/N)? "
	read REPLY
	if ! [ "$REPLY" = "y" ]; then
		echo "Aborting..."
		exit
	fi
	stop_service
	echo -n "Restoring backup..."
	tar xPf signal-backup.tar.gz
	chown -R $SIGNALUSER: $SIGNALVAR
	echo "done"
	start_service
fi

rm -f $TMPFILE

exit
