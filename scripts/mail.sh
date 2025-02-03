#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version       : 202111041659-git
# @Author        : Jason Hempstead
# @Contact       : jason@casjaysdev.pro
# @License       : WTFPL
# @ReadME        : mail.sh --help
# @Copyright     : Copyright: (c) 2021 Jason Hempstead, Casjays Developments
# @Created       : Thursday, Nov 04, 2021 16:59 EDT
# @File          : mail.sh
# @Description   : mail installer for Fedora
# @TODO          :
# @Other         :
# @Resource      :
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
APPNAME="$(basename "$0")"
VERSION="202111041659-git"
USER="${SUDO_USER:-${USER}}"
HOME="${USER_HOME:-${HOME}}"
SRC_DIR="${BASH_SOURCE%/*}"
SCRIPT_DESCRIBE="email server"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set bash options
if [[ "$1" == "--debug" ]]; then shift 1 && set -xo pipefail && export SCRIPT_OPTS="--debug" && export _DEBUG="on"; fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set functions
SCRIPTSFUNCTURL="${SCRIPTSFUNCTURL:-https://github.com/casjay-dotfiles/scripts/raw/main/functions}"
SCRIPTSFUNCTDIR="${SCRIPTSFUNCTDIR:-/usr/local/share/CasjaysDev/scripts}"
SCRIPTSFUNCTFILE="${SCRIPTSFUNCTFILE:-system-installer.bash}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ -f "../functions/$SCRIPTSFUNCTFILE" ]; then
  . "../functions/$SCRIPTSFUNCTFILE"
elif [ -f "$SCRIPTSFUNCTDIR/functions/$SCRIPTSFUNCTFILE" ]; then
  . "$SCRIPTSFUNCTDIR/functions/$SCRIPTSFUNCTFILE"
else
  curl -LSs "$SCRIPTSFUNCTURL/$SCRIPTSFUNCTFILE" -o "/tmp/$SCRIPTSFUNCTFILE" || exit 1
  . "/tmp/$SCRIPTSFUNCTFILE"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
[[ "$1" == "--help" ]] && printf_exit "${GREEN}apache installer for Fedora"
cat /etc/*-release | grep 'ID_LIKE=' | grep -E 'rhel|centos' &>/dev/null && true || printf_exit "This installer is meant to be run on a CentOS based system"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
system_service_exists() { systemctl status "$1" 2>&1 | grep -iq "$1" && return 0 || return 1; }
system_service_enable() { systemctl status "$1" 2>&1 | grep -iq 'inactive' && execute "systemctl enable $1" "Enabling service: $1" || return 1; }
system_service_disable() { systemctl status "$1" 2>&1 | grep -iq 'active' && execute "systemctl disable --now $1" "Disabling service: $1" || return 1; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
test_pkg() {
  for pkg in "$@"; do
    if rpm -q "$pkg" &>/dev/null; then
      printf_blue "[ ✔ ] $pkg is already installed"
      return 1
    else
      return 0
    fi
  done
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
remove_pkg() {
  test_pkg "$*" &>/dev/null || execute "yum remove -q -y $*" "Removing: $*"
  test_pkg "$*" &>/dev/null || return 0
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
install_pkg() {
  test_pkg "$*" && if execute "yum install -q -y --skip-broken $*" "Installing: $*"; then
    return 0
    elserun_post() {
      local e="$1"
      local m="${1//devnull /}"
      execute "$e" "executing: $m"
      setexitstatus
      set --
    }

    return 1
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
detect_selinux() {
  selinuxenabled
  if [ $? -ne 0 ]; then return 0; else return 1; fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
disable_selinux() {
  if selinuxenabled; then
    printf_blue "Disabling selinux"
    devnull setenforce 0
  else
    printf_green "selinux is already disabled"
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
rm_repo_files() { printf_green "Removing files from /etc/yum.repos.d" && rm -Rf /etc/yum.repos.d/*; }
run_external() { printf_green "Executing $*" && eval "$*" >/dev/null 2>&1 || return 1; }
grab_remote_file() { urlverify "$1" && curl -q -SLs "$1" || exit 1; }
save_remote_file() { urlverify "$1" && curl -q -SLs "$1" | tee "$2" &>/dev/null || exit 1; }
retrieve_version_file() { grab_remote_file "https://github.com/casjay-base/fedora/raw/main/version.txt" | head -n1 || echo "Unknown version"; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
retrieve_repo_file() {
  local RELEASE_VER RELEASE_FILE IFS
  RELEASE_FILE="https://github.com/rpm-devel/casjay-release/raw/main/casjay.fc.repo"
  RELEASE_VER="$(cat /etc/*-release | grep 'VERSION_ID=' | awk -F '=' '{print $2}' | sed 's#"##g' | awk -F '.' '{print $1}')"
  save_remote_file "$RELEASE_FILE" "/etc/yum.repos.d/casjay.repo"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
run_grub() {
  printf_green "Setting up grub"
  rm -Rf /boot/*rescue*
  devnull grub2-mkconfig -o /boot/grub2/grub.cfg
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
run_post() {
  local e="$*"
  local m="${e//devnull /}"
  execute "$e" "executing: $m"
  setexitstatus
  set --
}
##################################################################################################################
clear
ARGS="$*" && shift $#
##################################################################################################################
printf_head "Initializing the installer"
##################################################################################################################
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ -f /etc/casjaysdev/updates/versions/default.txt ]; then
  printf_red "This has already been installed"
  printf_red "To reinstall please remove the version file in"
  printf_exit "/etc/casjaysdev/updates/versions/default.txt"
fi
if ! builtin type -P systemmgr &>/dev/null; then
  if [[ -d "/usr/local/share/CasjaysDev/scripts" ]]; then
    run_external "git -C https://github.com/casjay-dotfiles/scripts pull"
  else
    run_external "git clone https://github.com/casjay-dotfiles/scripts /usr/local/share/CasjaysDev/scripts"
  fi
  run_external /usr/local/share/CasjaysDev/scripts/install.sh
  run_external systemmgr --config &>/dev/null
  run_external systemmgr install scripts
  run_external "yum clean all"
fi
if [ "$(hostname -s)" != "pbx" ]; then
  rm_repo_files
  retrieve_repo_file
fi

##################################################################################################################
printf_head "Disabling selinux"
##################################################################################################################
disable_selinux

##################################################################################################################
printf_head "Configuring cores for compiling"
##################################################################################################################
numberofcores=$(grep -c ^processor /proc/cpuinfo)
printf_yellow "Total cores avaliable: $numberofcores"
if [ -f /etc/makepkg.conf ]; then
  if [ $numberofcores -gt 1 ]; then
    sed -i 's/#MAKEFLAGS="-j2"/MAKEFLAGS="-j'$(($numberofcores + 1))'"/g' /etc/makepkg.conf
    sed -i 's/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T '"$numberofcores"' -z -)/g' /etc/makepkg.conf
  fi
fi

##################################################################################################################
printf_head "Configuring the system"
##################################################################################################################
run_external yum clean all
run_external yum update -q -y --skip-broken
install_pkg vnstat
system_service_enable vnstat
install_pkg net-tools
install_pkg wget
install_pkg curl
install_pkg git
install_pkg nail
install_pkg e2fsprogs
install_pkg redhat-lsb
install_pkg neovim
install_pkg unzip
run_external rm -Rf /tmp/dotfiles
run_external timedatectl set-timezone America/New_York
install_pkg cronie-noanacron
for rpms in $(echo cronie-anacron sendmail sendmail-cf); do
  rpm -ev --nodeps $rpms &>/dev/null
done
run_external rm -Rf /root/anaconda-ks.cfg /var/log/anaconda
if [ "$(hostname -s)" != "pbx" ]; then
  rm_repo_files
  retrieve_repo_file
fi
run_external yum clean all
run_external yum update -q -y --skip-broken
run_grub

##################################################################################################################
printf_head "Installing the packages for $SCRIPT_DESCRIBE"
##################################################################################################################
install_pkg acl
install_pkg aic94xx-firmware
install_pkg alsa-firmware
install_pkg alsa-lib
install_pkg alsa-tools-firmware
install_pkg altermime
install_pkg amavisd-new
install_pkg apr
install_pkg apr-devel
install_pkg apr-util
install_pkg apr-util-devel
install_pkg arj
install_pkg audit
install_pkg audit-libs
install_pkg audit-libs-python
install_pkg augeas-libs
install_pkg authconfig
install_pkg autoconf
install_pkg autogen-libopts
install_pkg automake
install_pkg avahi-autoipd
install_pkg avahi-libs
install_pkg awffull
install_pkg awstats
install_pkg basesystem
install_pkg bash
install_pkg bash-completion
install_pkg bc
install_pkg bind
install_pkg bind-libs
install_pkg bind-libs-lite
install_pkg bind-license
install_pkg binutils
install_pkg biosdevname
install_pkg btrfs-progs
install_pkg bzip2
install_pkg bzip2-libs
install_pkg cabextract
install_pkg ca-certificates
install_pkg cairo
install_pkg casjay-release
install_pkg centos-indexhtml
install_pkg centos-logos
install_pkg centos-release
install_pkg certbot
install_pkg checkpolicy
install_pkg chkconfig
install_pkg clamav
install_pkg clamav-data
install_pkg clamav-devel
install_pkg clamav-filesystem
install_pkg clamav-lib
install_pkg clamav-scanner-systemd
install_pkg clamav-server
install_pkg clamav-server-systemd
install_pkg clamav-update
install_pkg clucene-core
install_pkg coreutils
install_pkg cowsay
install_pkg cpio
install_pkg cracklib
install_pkg cracklib-dicts
install_pkg createrepo
install_pkg cronie
install_pkg cronie-noanacron
install_pkg crontabs
install_pkg cryptsetup-libs
install_pkg cups-libs
install_pkg curl
install_pkg cyrus-sasl
install_pkg cyrus-sasl-devel
install_pkg cyrus-sasl-lib
install_pkg dbus
install_pkg dbus-glib
install_pkg dbus-libs
install_pkg dbus-python
install_pkg dejavu-fonts-common
install_pkg dejavu-sans-mono-fonts
install_pkg deltarpm
install_pkg device-mapper
install_pkg device-mapper-libs
install_pkg dhclient
install_pkg dhcp-common
install_pkg dhcp-libs
install_pkg dialog
install_pkg diffutils
install_pkg dmidecode
install_pkg dnsmasq
install_pkg dovecot
install_pkg downtimed
install_pkg dracut
install_pkg dracut-config-rescue
install_pkg dracut-network
install_pkg e2fsprogs
install_pkg e2fsprogs-libs
install_pkg ebtables
install_pkg elfutils-default-yama-scope
install_pkg elfutils-libelf
install_pkg elfutils-libs
install_pkg ethtool
install_pkg expat
install_pkg expat-devel
install_pkg fail2ban
install_pkg fail2ban-firewalld
install_pkg fail2ban-sendmail
install_pkg fail2ban-server
install_pkg file
install_pkg file-libs
install_pkg filesystem
install_pkg findutils
install_pkg fipscheck
install_pkg fipscheck-lib
install_pkg firewalld
install_pkg firewalld-filesystem
install_pkg fontconfig
install_pkg fontpackages-filesystem
install_pkg fortune-mod
install_pkg fping
install_pkg freetype
install_pkg freeze
install_pkg fxload
install_pkg gawk
install_pkg gd
install_pkg gdbm
install_pkg gdbm-devel
install_pkg gdk-pixbuf2
install_pkg gd-last
install_pkg GeoIP
install_pkg GeoIP-data
install_pkg GeoIP-update
install_pkg gettext
install_pkg gettext-libs
install_pkg ghostscript
install_pkg ghostscript-fonts
install_pkg git
install_pkg glib2
install_pkg glibc
install_pkg glibc-common
install_pkg glibc-devel
install_pkg glibc-headers
install_pkg glib-networking
install_pkg gmp
install_pkg gnupg2
install_pkg gnutls
install_pkg gobject-introspection
install_pkg gpgme
install_pkg gpm-libs
install_pkg graphite2
install_pkg grep
install_pkg groff-base
install_pkg grub2
install_pkg grub2-common
install_pkg grub2-pc
install_pkg grub2-pc-modules
install_pkg grub2-tools
install_pkg grub2-tools-extra
install_pkg grub2-tools-minimal
install_pkg grubby
install_pkg gsettings-desktop-schemas
install_pkg gzip
install_pkg hardlink
install_pkg harfbuzz
install_pkg hdparm
install_pkg hostname
install_pkg httpd
install_pkg httpd-devel
install_pkg httpd-filesystem
install_pkg httpd-tools
install_pkg hwdata
install_pkg ilmbase
install_pkg ImageMagick
install_pkg inews
install_pkg info
install_pkg initscripts
install_pkg inn
install_pkg inn-libs
install_pkg iproute
install_pkg iprutils
install_pkg ipset
install_pkg ipset-libs
install_pkg iptables
install_pkg iputils
install_pkg irqbalance
install_pkg kbd
install_pkg kbd-legacy
install_pkg kbd-misc
install_pkg kexec-tools
install_pkg keyutils-libs
install_pkg keyutils-libs-devel
install_pkg kmod
install_pkg kmod-libs
install_pkg kpartx
install_pkg krb5-devel
install_pkg krb5-libs
install_pkg lcms2
install_pkg less
install_pkg linux-firmware
install_pkg lm_sensors-libs
install_pkg logrotate
install_pkg lsof
install_pkg lsscsi
install_pkg lua
install_pkg lynx
install_pkg lzo
install_pkg lzop
install_pkg m4
install_pkg mailcap
install_pkg mailman
install_pkg mailx
install_pkg make
install_pkg man-db
install_pkg mesa-libEGL
install_pkg mesa-libgbm
install_pkg mesa-libGL
install_pkg mesa-libglapi
install_pkg microcode_ctl
install_pkg mlocate
install_pkg mod_fcgid
install_pkg mod_geoip
install_pkg mod_http2
install_pkg mod_perl
install_pkg mod_ssl
install_pkg mozjs17
install_pkg mrtg
install_pkg munin
install_pkg munin-common
install_pkg munin-node
install_pkg nano
install_pkg ncurses
install_pkg ncurses-base
install_pkg ncurses-libs
install_pkg net-snmp
install_pkg net-snmp-agent-libs
install_pkg net-snmp-libs
install_pkg net-snmp-utils
install_pkg nettle
install_pkg net-tools
install_pkg NetworkManager
install_pkg NetworkManager-libnm
install_pkg NetworkManager-ppp
install_pkg NetworkManager-team
install_pkg NetworkManager-tui
install_pkg NetworkManager-wifi
install_pkg newt
install_pkg newt-python
install_pkg nomarch
install_pkg nspr
install_pkg nss
install_pkg nss-pem
install_pkg nss-softokn
install_pkg nss-softokn-freebl
install_pkg nss-sysinit
install_pkg nss-tools
install_pkg nss-util
install_pkg ntp
install_pkg ntpdate
install_pkg numactl-libs
install_pkg opendbx
install_pkg opendkim
install_pkg opendmarc
install_pkg openssh
install_pkg openssh-clients
install_pkg openssh-server
install_pkg openssl
install_pkg openssl-devel
install_pkg openssl-libs
install_pkg os-prober
install_pkg p11-kit
install_pkg p11-kit-trust
install_pkg p7zip
install_pkg p7zip-plugins
install_pkg pam
install_pkg pango
install_pkg parted
install_pkg passwd
install_pkg pax
install_pkg pcre
install_pkg pcre-devel
install_pkg perl
install_pkg perl-Archive-Tar
install_pkg perl-Archive-Zip
install_pkg perl-Authen-SASL
install_pkg perl-BerkeleyDB
install_pkg perl-BSD-Resource
install_pkg perl-Business-ISBN
install_pkg perl-Business-ISBN-Data
install_pkg perl-Cache-Cache
install_pkg perl-Carp
install_pkg perl-CGI
install_pkg perl-Class-Load
install_pkg perl-Class-Singleton
install_pkg perl-Compress-Raw-Bzip2
install_pkg perl-Compress-Raw-Zlib
install_pkg perl-constant
install_pkg perl-Convert-ASN1
install_pkg perl-Convert-BinHex
install_pkg perl-Convert-TNEF
install_pkg perl-Convert-UUlib
install_pkg perl-Crypt-DES
install_pkg perl-Crypt-OpenSSL-Bignum
install_pkg perl-Crypt-OpenSSL-Random
install_pkg perl-Crypt-OpenSSL-RSA
install_pkg perl-Data-Dumper
install_pkg perl-Data-OptList
install_pkg perl-Date-Manip
install_pkg perl-DateTime
install_pkg perl-DateTime-Locale
install_pkg perl-DateTime-TimeZone
install_pkg perl-DBD-MySQL
install_pkg perl-DBD-Pg
install_pkg perl-DBD-SQLite
install_pkg perl-DB_File
install_pkg perl-DBI
install_pkg perl-devel
install_pkg perl-Digest
install_pkg perl-Digest-HMAC
install_pkg perl-Digest-MD5
install_pkg perl-Digest-SHA
install_pkg perl-Digest-SHA1
install_pkg perl-Email-Date-Format
install_pkg perl-Encode
install_pkg perl-Encode-Detect
install_pkg perl-Encode-Locale
install_pkg perl-Error
install_pkg perl-Exporter
install_pkg perl-ExtUtils-Install
install_pkg perl-ExtUtils-MakeMaker
install_pkg perl-ExtUtils-Manifest
install_pkg perl-ExtUtils-ParseXS
install_pkg perl-FCGI
install_pkg perl-File-Copy-Recursive
install_pkg perl-File-Listing
install_pkg perl-File-Path
install_pkg perl-File-Temp
install_pkg perl-Filter
install_pkg perl-Geo-IP
install_pkg perl-Getopt-Long
install_pkg perl-Git
install_pkg perl-GSSAPI
install_pkg perl-HTML-Parser
install_pkg perl-HTML-Tagset
install_pkg perl-HTML-Template
install_pkg perl-HTTP-Cookies
install_pkg perl-HTTP-Daemon
install_pkg perl-HTTP-Date
install_pkg perl-HTTP-Message
install_pkg perl-HTTP-Negotiate
install_pkg perl-HTTP-Tiny
install_pkg perl-interpreter
install_pkg perl-IO-Compress
install_pkg perl-IO-HTML
install_pkg perl-IO-Multiplex
install_pkg perl-IO-Socket-INET6
install_pkg perl-IO-Socket-IP
install_pkg perl-IO-Socket-SSL
install_pkg perl-IO-stringy
install_pkg perl-IO-Zlib
install_pkg perl-IPC-ShareLite
install_pkg perl-JSON
install_pkg perl-LDAP
install_pkg perl-libs
install_pkg perl-libwww-perl
install_pkg perl-Linux-Pid
install_pkg perl-List-MoreUtils
install_pkg perl-Log-Dispatch
install_pkg perl-Log-Dispatch-FileRotate
install_pkg perl-Log-Log4perl
install_pkg perl-LWP-MediaTypes
install_pkg perl-macros
install_pkg perl-Mail-DKIM
install_pkg perl-Mail-Sender
install_pkg perl-Mail-Sendmail
install_pkg perl-Mail-SPF
install_pkg perl-MailTools
install_pkg perl-MIME-Lite
install_pkg perl-MIME-tools
install_pkg perl-MIME-Types
install_pkg perl-Module-Implementation
install_pkg perl-Module-Runtime
install_pkg perl-NetAddr-IP
install_pkg perl-Net-CIDR
install_pkg perl-Net-Daemon
install_pkg perl-Net-DNS
install_pkg perl-Net-HTTP
install_pkg perl-Net-IP
install_pkg perl-Net-LibIDN
install_pkg perl-Net-Server
install_pkg perl-Net-SMTP-SSL
install_pkg perl-Net-SNMP
install_pkg perl-Net-SSLeay
install_pkg perl-Package-Constants
install_pkg perl-Package-DeprecationManager
install_pkg perl-Package-Stash
install_pkg perl-Package-Stash-XS
install_pkg perl-Params-Util
install_pkg perl-Params-Validate
install_pkg perl-parent
install_pkg perl-PathTools
install_pkg perl-PlRPC
install_pkg perl-Pod-Escapes
install_pkg perl-podlators
install_pkg perl-Pod-Perldoc
install_pkg perl-Pod-Simple
install_pkg perl-Pod-Usage
install_pkg perl-Razor-Agent
install_pkg perl-Scalar-List-Utils
install_pkg perl-SNMP_Session
install_pkg perl-Socket
install_pkg perl-Socket6
install_pkg perl-Storable
install_pkg perl-Sub-Install
install_pkg perl-Switch
install_pkg perl-Sys-Syslog
install_pkg perl-Taint-Runtime
install_pkg perl-TermReadKey
install_pkg perl-Test-Harness
install_pkg perl-Text-ParseWords
install_pkg perl-Text-Soundex
install_pkg perl-Text-Unidecode
install_pkg perl-Thread-Queue
install_pkg perl-threads
install_pkg perl-threads-shared
install_pkg perl-TimeDate
install_pkg perl-Time-HiRes
install_pkg perl-Time-Local
install_pkg perl-Try-Tiny
install_pkg perl-Unix-Syslog
install_pkg perl-URI
install_pkg perl-version
install_pkg perl-WWW-RobotRules
install_pkg perl-XML-DOM
install_pkg perl-XML-Filter-BufferText
install_pkg perl-XML-LibXML
install_pkg perl-XML-NamespaceSupport
install_pkg perl-XML-Parser
install_pkg perl-XML-RegExp
install_pkg perl-XML-SAX
install_pkg perl-XML-SAX-Base
install_pkg perl-XML-SAX-Writer
install_pkg perl-ZMQ-Constants
install_pkg perl-ZMQ-LibZMQ3
install_pkg php
install_pkg php-cli
install_pkg php-common
install_pkg php-devel
install_pkg php-fedora-autoloader
install_pkg php-fpm
install_pkg php-gd
install_pkg php-imap
install_pkg php-ldap
install_pkg php-mbstring
install_pkg php-mcrypt
install_pkg php-mysqlnd
install_pkg php-odbc
install_pkg php-opcache
install_pkg php-pdo
install_pkg php-pear
install_pkg php-pecl-apcu
install_pkg php-pecl-geoip
install_pkg php-pecl-jsonc
install_pkg php-pecl-jsonc-devel
install_pkg php-pecl-zip
install_pkg php-pgsql
install_pkg php-process
install_pkg php-snmp
install_pkg php-soap
install_pkg php-tidy
install_pkg php-xml
install_pkg php-xmlrpc
install_pkg pinentry
install_pkg pixman
install_pkg pkgconfig
install_pkg plymouth
install_pkg plymouth-core-libs
install_pkg plymouth-scripts
install_pkg policycoreutils
install_pkg policycoreutils-python
install_pkg polkit
install_pkg polkit-pkla-compat
install_pkg poppler-data
install_pkg popt
install_pkg postfix
install_pkg procmail
install_pkg procps-ng
install_pkg proftpd
install_pkg pygpgme
install_pkg pyliblzma
install_pkg pyOpenSSL
install_pkg pyparsing
install_pkg python
install_pkg python2-acme
install_pkg python2-certbot
install_pkg python2-certbot-apache
install_pkg python2-configargparse
install_pkg python2-cryptography
install_pkg python2-dialog
install_pkg python2-future
install_pkg python2-josepy
install_pkg python2-mock
install_pkg python2-psutil
install_pkg python2-pyasn1
install_pkg python2-pyrfc3339
install_pkg python-augeas
install_pkg python-backports
install_pkg python-backports-ssl_match_hostname
install_pkg python-cffi
install_pkg python-chardet
install_pkg python-configobj
install_pkg python-decorator
install_pkg python-deltarpm
install_pkg python-dns
install_pkg python-enum34
install_pkg python-firewall
install_pkg python-gobject-base
install_pkg python-idna
install_pkg python-iniparse
install_pkg python-ipaddress
install_pkg python-IPy
install_pkg python-kitchen
install_pkg python-libs
install_pkg python-linux-procfs
install_pkg python-ndg_httpsclient
install_pkg python-parsedatetime
install_pkg python-perf
install_pkg python-ply
install_pkg python-pycparser
install_pkg python-pycurl
install_pkg python-pyudev
install_pkg python-requests
install_pkg python-schedutils
install_pkg python-setuptools
install_pkg python-six
install_pkg python-slip
install_pkg python-slip-dbus
install_pkg python-urlgrabber
install_pkg python-urllib3
install_pkg python-zope-component
install_pkg python-zope-event
install_pkg python-zope-interface
install_pkg pytz
install_pkg pyxattr
install_pkg pyzor
install_pkg qrencode-libs
install_pkg rdma-core
install_pkg readline
install_pkg recode
install_pkg rkhunter
install_pkg rootfiles
install_pkg rpm
install_pkg rpm-build-libs
install_pkg rpm-libs
install_pkg rpm-python
install_pkg rrdtool
install_pkg rrdtool-perl
install_pkg rsync
install_pkg rsync-daemon
install_pkg rsyslog
install_pkg screen
install_pkg sed
install_pkg selinux-policy
install_pkg selinux-policy-targeted
install_pkg sendmail-milter
install_pkg setools-libs
install_pkg setup
install_pkg shadow-utils
install_pkg shared-mime-info
install_pkg shorewall
install_pkg shorewall6
install_pkg shorewall-core
install_pkg slang
install_pkg snappy
install_pkg spamassassin
install_pkg speedtest-cli
install_pkg sqlite
install_pkg stix-fonts
install_pkg sudo
install_pkg sysstat
install_pkg systemd
install_pkg systemd-libs
install_pkg systemd-python
install_pkg systemd-sysv
install_pkg systemtap-sdt-devel
install_pkg sysvinit-tools
install_pkg t1lib
install_pkg tar
install_pkg tcp_wrappers-libs
install_pkg telnet
install_pkg tmpwatch
install_pkg trousers
install_pkg tzdata
install_pkg unixODBC
install_pkg unzoo
install_pkg uptimed
install_pkg urw-fonts
install_pkg ustr
install_pkg util-linux
install_pkg vim-common
install_pkg vim-enhanced
install_pkg vim-filesystem
install_pkg vim-minimal
install_pkg vnstat
install_pkg webalizer
install_pkg wget
install_pkg which
install_pkg wpa_supplicant
install_pkg xfsprogs
install_pkg xorg-x11-font-utils
install_pkg xorg-x11-xauth
install_pkg xz
install_pkg xz-devel
install_pkg xz-libs
install_pkg yum
install_pkg yum-metadata-parser
install_pkg yum-plugin-fastestmirror
install_pkg yum-utils
install_pkg zeromq3
install_pkg zlib
install_pkg zlib-devel

##################################################################################################################
printf_head "Fixing packages"
##################################################################################################################
run_grub
rm -Rf /etc/named* /var/named/* /etc/ntp* /etc/cron*/0* /etc/cron*/dailyjobs /var/ftp/uploads /etc/httpd/conf.d/ssl.conf /tmp/configs

##################################################################################################################
printf_head "setting up config files"
##################################################################################################################
devnull git clone -q https://github.com/phpsysinfo/phpsysinfo /var/www/html/sysinfo
devnull git clone -q https://github.com/casjay-base/centos /tmp/configs
devnull find /tmp/configs -type f -iname "*.sh" -exec chmod 755 {} \;
devnull find /tmp/configs -type f -iname "*.pl" -exec chmod 755 {} \;
devnull find /tmp/configs -type f -iname "*.cgi" -exec chmod 755 {} \;
devnull find /tmp/configs -type f -exec sed -i "s#myserverdomainname#$(hostname -f)#g" {} \;
devnull find /tmp/configs -type f -exec sed -i "s#myhostnameshort#$(hostname -s)#g" {} \;
devnull find /tmp/configs -type f -exec sed -i "s#mydomainname#$(hostname -f | awk -F. '{$1="";OFS="." ; print $0}' | sed 's/^.//')#g" {} \;
devnull #rm -Rf /tmp/configs/etc/{fail2ban,shorewall,shorewall6}
devnull cp -Rf /tmp/configs/{etc,root,usr,var}* /
devnull mkdir -p /etc/rsync.d /var/log/named &&
  devnull chown -Rf named:named /etc/named* /var/named /var/log/named
devnull chown -Rf apache:apache /var/www /usr/local/share/httpd
devnull sed -i "s#myserverdomainname#$(echo $HOSTNAME)#g" /etc/sysconfig/network
devnull sed -i "s#mydomain#$(echo $HOSTNAME | awk -F. '{$1="";OFS="." ; print $0}' | sed 's/^.//')#g" /etc/sysconfig/network
devnull domainname $(hostname -f | awk -F. '{$1="";OFS="." ; print $0}' | sed 's/^.//') &&
  echo "kernel.domainname=$(domainname)" >>/etc/sysctl.conf
devnull chmod 644 -Rf /etc/cron.d/* /etc/logrotate.d/*
devnull touch /etc/postfix/mydomains.pcre
devnull chattr +i /etc/resolv.conf
if devnull postmap /etc/postfix/transport /etc/postfix/canonical /etc/postfix/virtual /etc/postfix/mydomains; then
  newaliases &>/dev/null || newaliases.postfix -I &>/dev/null
fi

##################################################################################################################
printf_head "Disabling services"
##################################################################################################################
system_service_disable firewalld
system_service_disable chrony
system_service_disable kdump
system_service_disable iscsid.socket
system_service_disable iscsi
system_service_disable iscsiuio.socket
system_service_disable lvm2-lvmetad.socket
system_service_disable lvm2-lvmpolld.socket
system_service_disable lvm2-monitor
system_service_disable mdmonitor
system_service_disable fail2ban
system_service_disable shorewall
system_service_disable shorewall6
system_service_disable dhcpd
system_service_disable dhcpd6
system_service_disable radvd

##################################################################################################################
printf_head "Enabling services"
##################################################################################################################
system_service_enable sshd
system_service_enable tor
system_service_enable munin-node
system_service_enable cockpit
system_service_enable postfix
system_service_enable uptimed
system_service_enable php-fpm
system_service_enable proftpd
system_service_enable rsyslog
system_service_enable ntpd
system_service_enable snmpd
system_service_enable cockpit.socket
system_service_enable named
system_service_enable httpd
system_service_enable nginx

##################################################################################################################
printf_head "Cleaning up"
##################################################################################################################
echo "" >/etc/yum/pluginconf.d/subscription-manager.conf
rm -Rf /tmp/*.tar /tmp/dotfiles /tmp/configs
/root/bin/changeip.sh >/dev/null 2>&1
mkdir -p /mnt/backups /var/www/html/.well-known /etc/letsencrypt/live
echo "" >>/etc/fstab
#echo "10.0.254.1:/mnt/Volume_1/backups         /mnt/backups                 nfs defaults,rw 0 0" >> /etc/fstab
#echo "10.0.254.1:/var/www/html/.well-known     /var/www/html/.well-known    nfs defaults,rw 0 0" >> /etc/fstab
#echo "10.0.254.1:/etc/letsencrypt              /etc/letsencrypt             nfs defaults,rw 0 0" >> /etc/fstab
#mount -a
update-ca-trust && update-ca-trust extract
#if using letsencrypt certificates
chmod 600 /etc/named/certbot-update.conf
if [[ -d /etc/letsencrypt/live/$(domainname) ]] || [[ -d /etc/letsencrypt/live/domain ]]; then
  ln -s /etc/letsencrypt/live/$(domainname) /etc/letsencrypt/live/domain
  find /etc/postfix /etc/httpd /etc/nginx -type f -exec sed -i 's#/etc/ssl/CA/CasjaysDev/certs/localhost.crt#/etc/letsencrypt/live/domain/fullchain.pem#g' {} \;
  find /etc/postfix /etc/httpd /etc/nginx -type f -exec sed -i 's#/etc/ssl/CA/CasjaysDev/private/localhost.key#/etc/letsencrypt/live/domain/privkey.pem#g' {} \;
  cat /etc/letsencrypt/live/domain/fullchain.pem >/etc/cockpit/ws-certs.d/1-my-cert.cert
  cat /etc/letsencrypt/live/domain/privkey.pem >>/etc/cockpit/ws-certs.d/1-my-cert.cert
else
  #If using self-signed certificates
  find /etc/postfix /etc/httpd /etc/cockpit/ws-certs.d -type f -exec sed -i 's#/etc/letsencrypt/live/domain/fullchain.pem#/etc/ssl/CA/CasjaysDev/certs/localhost.crt#g' {} \;
  find /etc/postfix /etc/httpd /etc/cockpit/ws-certs.d -type f -exec sed -i 's#/etc/letsencrypt/live/domain/privkey.pem#/etc/ssl/CA/CasjaysDev/private/localhost.key#g' {} \;
fi
bash -c "$(munin-node-configure --remove-also --shell >/dev/null 2>&1)"
if [ -f /var/lib/tor/hidden_service/hostname ]; then
  cp -Rf /var/lib/tor/hidden_service/hostname /var/www/html/tor_hostname
fi
if [ "$(hostname -s)" != "pbx" ]; then
  rm_repo_files
  retrieve_repo_file
fi
chown -Rf apache:apache /var/www
history -c && history -w

##################################################################################################################
printf_info "Installer version: $(retrieve_version_file)"
##################################################################################################################
mkdir -p /etc/casjaysdev/updates/versions
echo "$VERSION" >/etc/casjaysdev/updates/versions/configs.txt
chmod -Rf 664 /etc/casjaysdev/updates/versions/configs.txt

##################################################################################################################
printf_head "Finished "
echo ""
##################################################################################################################
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
set --
exit
# end
