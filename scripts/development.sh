#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version       : 202111041659-git
# @Author        : Jason Hempstead
# @Contact       : jason@casjaysdev.pro
# @License       : WTFPL
# @ReadME        : development.sh --help
# @Copyright     : Copyright: (c) 2021 Jason Hempstead, Casjays Developments
# @Created       : Thursday, Nov 04, 2021 16:59 EDT
# @File          : development.sh
# @Description   : development installer for Fedora
# @TODO          :
# @Other         :
# @Resource      :
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
APPNAME="$(basename "$0")"
VERSION="202111041659-git"
USER="${SUDO_USER:-${USER}}"
HOME="${USER_HOME:-${HOME}}"
SRC_DIR="${BASH_SOURCE%/*}"
SCRIPT_DESCRIBE="development system"
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
  else
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
for rpms in echo cronie-anacron sendmail sendmail-cf; do
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
install_pkg adwaita-cursor-theme
install_pkg adwaita-icon-theme
install_pkg aether-api
install_pkg aether-connector-wagon
install_pkg aether-impl
install_pkg aether-spi
install_pkg aether-util
install_pkg aic94xx-firmware
install_pkg alsa-firmware
install_pkg alsa-lib
install_pkg alsa-lib-devel
install_pkg alsa-tools-firmware
install_pkg ant
install_pkg antlr-tool
install_pkg aopalliance
install_pkg apache-commons-beanutils
install_pkg apache-commons-cli
install_pkg apache-commons-codec
install_pkg apache-commons-collections
install_pkg apache-commons-compress
install_pkg apache-commons-configuration
install_pkg apache-commons-daemon
install_pkg apache-commons-dbcp
install_pkg apache-commons-digester
install_pkg apache-commons-io
install_pkg apache-commons-jexl
install_pkg apache-commons-jxpath
install_pkg apache-commons-lang
install_pkg apache-commons-lang3
install_pkg apache-commons-logging
install_pkg apache-commons-net
install_pkg apache-commons-parent
install_pkg apache-commons-pool
install_pkg apache-commons-validator
install_pkg apache-commons-vfs
install_pkg apache-parent
install_pkg apache-rat
install_pkg apache-rat-core
install_pkg apache-rat-plugin
install_pkg apache-rat-tasks
install_pkg apache-resource-bundles
install_pkg apr
install_pkg apr-devel
install_pkg apr-util
install_pkg apr-util-bdb
install_pkg apr-util-devel
install_pkg apr-util-ldap
install_pkg apr-util-mysql
install_pkg apr-util-nss
install_pkg apr-util-odbc
install_pkg apr-util-openssl
install_pkg apr-util-pgsql
install_pkg apr-util-sqlite
install_pkg aqute-bnd
install_pkg aqute-bndlib
install_pkg asciidoc
install_pkg at
install_pkg atinject
install_pkg atk
install_pkg atk-devel
install_pkg at-spi2-atk
install_pkg at-spi2-atk-devel
install_pkg at-spi2-core
install_pkg at-spi2-core-devel
install_pkg attr
install_pkg audit
install_pkg audit-libs
install_pkg audit-libs-python
install_pkg augeas-libs
install_pkg authconfig
install_pkg autoconf
install_pkg autogen-libopts
install_pkg automake
install_pkg avahi-autoipd
install_pkg avahi-glib
install_pkg avahi-libs
install_pkg avalon-framework
install_pkg avalon-logkit
install_pkg awffull
install_pkg awstats
install_pkg base64coder
install_pkg basesystem
install_pkg bash
install_pkg bash-completion
install_pkg batik
install_pkg bc
install_pkg bcel
install_pkg bea-stax
install_pkg bea-stax-api
install_pkg beust-jcommander
install_pkg bind
install_pkg bind-libs
install_pkg bind-libs-lite
install_pkg bind-license
install_pkg bind-utils
install_pkg binutils
install_pkg biosdevname
install_pkg bison
install_pkg boost-date-time
install_pkg boost-program-options
install_pkg boost-regex
install_pkg boost-system
install_pkg boost-thread
install_pkg bridge-utils
install_pkg brotli
install_pkg brotli-devel
install_pkg bsf
install_pkg bsh
install_pkg btrfs-progs
install_pkg buildnumber-maven-plugin
install_pkg byacc
install_pkg bzip2
install_pkg bzip2-devel
install_pkg bzip2-libs
install_pkg ca-certificates
install_pkg cairo
install_pkg cairo-devel
install_pkg cairo-gobject
install_pkg cairo-gobject-devel
install_pkg cal10n
install_pkg c-ares
install_pkg c-ares-devel
install_pkg cdi-api
install_pkg cdparanoia-libs
install_pkg centos-indexhtml
install_pkg centos-logos
install_pkg centos-release
install_pkg certbot
install_pkg cglib
install_pkg checkpolicy
install_pkg chkconfig
install_pkg chrony
install_pkg c-icap
install_pkg c-icap-devel
install_pkg c-icap-libs
install_pkg cifs-utils
install_pkg cmake
install_pkg cockpit
install_pkg cockpit-bridge
install_pkg cockpit-dashboard
install_pkg cockpit-packagekit
install_pkg cockpit-pcp
install_pkg cockpit-system
install_pkg cockpit-ws
install_pkg codehaus-parent
install_pkg colord-libs
install_pkg color-filesystem
install_pkg composer
install_pkg comps-extras
install_pkg conntrack-tools
install_pkg coolkey
install_pkg copy-jdk-configs
install_pkg coreutils
install_pkg cowsay
install_pkg cpio
install_pkg cpp
install_pkg cppunit
install_pkg cppunit-devel
install_pkg cracklib
install_pkg cracklib-dicts
install_pkg crda
install_pkg createrepo
install_pkg cronie
install_pkg cronie-noanacron
install_pkg crontabs
install_pkg cryptsetup
install_pkg cryptsetup-libs
install_pkg cscope
install_pkg ctags
install_pkg CUnit
install_pkg CUnit-devel
install_pkg cups-client
install_pkg cups-libs
install_pkg curl
install_pkg cvs
install_pkg cvsps
install_pkg cyrus-sasl
install_pkg cyrus-sasl-devel
install_pkg cyrus-sasl-gssapi
install_pkg cyrus-sasl-lib
install_pkg cyrus-sasl-plain
install_pkg dbus
install_pkg dbus-devel
install_pkg dbus-glib
install_pkg dbus-libs
install_pkg dbus-python
install_pkg dconf
install_pkg dejavu-fonts-common
install_pkg dejavu-sans-mono-fonts
install_pkg deltarpm
install_pkg desktop-file-utils
install_pkg device-mapper
install_pkg device-mapper-event
install_pkg device-mapper-event-libs
install_pkg device-mapper-libs
install_pkg device-mapper-multipath
install_pkg device-mapper-multipath-libs
install_pkg device-mapper-persistent-data
install_pkg dhclient
install_pkg dhcp-common
install_pkg dhcp-libs
install_pkg dialog
install_pkg diffstat
install_pkg diffutils
install_pkg dmidecode
install_pkg dnsmasq
install_pkg docbook-dtds
install_pkg docbook-style-dsssl
install_pkg docbook-style-xsl
install_pkg docbook-utils
install_pkg dom4j
install_pkg dos2unix
install_pkg dosfstools
install_pkg downtimed
install_pkg doxygen
install_pkg dracut
install_pkg dracut-config-rescue
install_pkg dracut-network
install_pkg dwz
install_pkg dyninst
install_pkg e2fsprogs
install_pkg e2fsprogs-libs
install_pkg easymock
install_pkg easymock2
install_pkg easymock3
install_pkg ebtables
install_pkg ecj
install_pkg ed
install_pkg efivar-libs
install_pkg elfutils
install_pkg elfutils-default-yama-scope
install_pkg elfutils-libelf
install_pkg elfutils-libs
install_pkg emacs
install_pkg emacs-common
install_pkg emacs-filesystem
install_pkg enchant
install_pkg ethtool
install_pkg expat
install_pkg expat-devel
install_pkg fail2ban
install_pkg fail2ban-firewalld
install_pkg fail2ban-mail
install_pkg fail2ban-sendmail
install_pkg fail2ban-server
install_pkg fdupes
install_pkg felix-bundlerepository
install_pkg felix-framework
install_pkg felix-osgi-compendium
install_pkg felix-osgi-core
install_pkg felix-osgi-foundation
install_pkg felix-osgi-obr
install_pkg felix-shell
install_pkg felix-utils
install_pkg ffmpeg-devel
install_pkg ffmpeg-libs
install_pkg file
install_pkg file-libs
install_pkg filesystem
install_pkg findutils
install_pkg fipscheck
install_pkg fipscheck-lib
install_pkg firewalld
install_pkg firewalld-filesystem
install_pkg flac-libs
install_pkg flex
install_pkg fontconfig
install_pkg fontconfig-devel
install_pkg fontpackages-filesystem
install_pkg foomatic-filters
install_pkg fop
install_pkg forge-parent
install_pkg fortune-mod
install_pkg fpaste
install_pkg fping
install_pkg freerdp-devel
install_pkg freerdp-libs
install_pkg freetype
install_pkg freetype-devel
install_pkg fribidi
install_pkg fuse
install_pkg fuse-libs
install_pkg fuse-sshfs
install_pkg fxload
install_pkg galera
install_pkg gamin
install_pkg gamin-devel
install_pkg gawk
install_pkg gc
install_pkg gcc
install_pkg gcc-c++
install_pkg gcc-gfortran
install_pkg GConf2
install_pkg GConf2-devel
install_pkg gcr
install_pkg gd
install_pkg gdb
install_pkg gdbm
install_pkg gdbm-devel
install_pkg gdisk
install_pkg gdk-pixbuf2
install_pkg gdk-pixbuf2-devel
install_pkg gd-last
install_pkg gd-last-devel
install_pkg geoclue2
install_pkg GeoIP
install_pkg GeoIP-data
install_pkg GeoIP-devel
install_pkg GeoIP-update
install_pkg geronimo-annotation
install_pkg geronimo-jaxrpc
install_pkg geronimo-jms
install_pkg geronimo-jta
install_pkg geronimo-osgi-support
install_pkg geronimo-parent-poms
install_pkg geronimo-saaj
install_pkg gettext
install_pkg gettext-common-devel
install_pkg gettext-devel
install_pkg gettext-libs
install_pkg ghostscript
install_pkg ghostscript-fonts
install_pkg giflib
install_pkg git
install_pkg git-core
install_pkg git-core-doc
install_pkg git-perl-Git
install_pkg glib2
install_pkg glib2-devel
install_pkg glibc
install_pkg glibc-common
install_pkg glibc-devel
install_pkg glibc-headers
install_pkg glibc-static
install_pkg glibc-utils
install_pkg glib-networking
install_pkg gl-manpages
install_pkg gmp
install_pkg gmp-devel
install_pkg gnome-doc-utils
install_pkg gnome-doc-utils-stylesheets
install_pkg gnome-vfs2
install_pkg gnome-vfs2-devel
install_pkg gnupg2
install_pkg gnupg2-smime
install_pkg gnutls
install_pkg gnutls-c++
install_pkg gnutls-dane
install_pkg gnutls-devel
install_pkg go-bindata
install_pkg gobject-introspection
install_pkg golang
install_pkg golang-bin
install_pkg golang-github-golang-sys-devel
install_pkg golang-github-oschwald-maxminddb-golang-devel
install_pkg golang-src
install_pkg google-guice
install_pkg gpgme
install_pkg gpg-pubkey
install_pkg gpg-pubkey
install_pkg gpg-pubkey
install_pkg gpm-libs
install_pkg graphite2
install_pkg graphite2-devel
install_pkg graphviz
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
install_pkg gsm
install_pkg gssproxy
install_pkg gstreamer1
install_pkg gstreamer1-plugins-base
install_pkg gtk2
install_pkg gtk2-devel
install_pkg gtk3
install_pkg gtk3-devel
install_pkg gtk-doc
install_pkg gtk-update-icon-cache
install_pkg guava
install_pkg guile
install_pkg gvfs
install_pkg gvfs-client
install_pkg gzip
install_pkg hamcrest
install_pkg hardlink
install_pkg harfbuzz
install_pkg harfbuzz-devel
install_pkg harfbuzz-icu
install_pkg hdparm
install_pkg hicolor-icon-theme
install_pkg highlight
install_pkg hiredis
install_pkg hiredis-devel
install_pkg hostname
install_pkg hsqldb
install_pkg htop
install_pkg httpcomponents-client
install_pkg httpcomponents-core
install_pkg httpcomponents-project
install_pkg httpd
install_pkg httpd-devel
install_pkg httpd-filesystem
install_pkg httpd-manual
install_pkg httpd-tools
install_pkg http-parser
install_pkg hunspell
install_pkg hunspell-en-US
install_pkg hwdata
install_pkg hyphen
install_pkg icc-profiles-openicc
install_pkg iftop
install_pkg ilmbase
install_pkg ImageMagick
install_pkg indent
install_pkg info
install_pkg initscripts
install_pkg intltool
install_pkg iproute
install_pkg iprutils
install_pkg ipset
install_pkg ipset-libs
install_pkg iptables
install_pkg iptstate
install_pkg iputils
install_pkg irqbalance
install_pkg iscsi-initiator-utils
install_pkg iscsi-initiator-utils-iscsiuio
install_pkg iso-codes
install_pkg isorelax
install_pkg ivtv-firmware
install_pkg iw
install_pkg iwl1000-firmware
install_pkg iwl100-firmware
install_pkg iwl105-firmware
install_pkg iwl135-firmware
install_pkg iwl2000-firmware
install_pkg iwl2030-firmware
install_pkg iwl3160-firmware
install_pkg iwl3945-firmware
install_pkg iwl4965-firmware
install_pkg iwl5000-firmware
install_pkg iwl5150-firmware
install_pkg iwl6000-firmware
install_pkg iwl6000g2a-firmware
install_pkg iwl6000g2b-firmware
install_pkg iwl6050-firmware
install_pkg iwl7260-firmware
install_pkg iwl7265-firmware
install_pkg jai-imageio-core
install_pkg jakarta-commons-httpclient
install_pkg jakarta-oro
install_pkg jakarta-taglibs-standard
install_pkg jansson
install_pkg jasper-libs
install_pkg java-1.8.0-openjdk
install_pkg java-1.8.0-openjdk-devel
install_pkg java-1.8.0-openjdk-headless
install_pkg javamail
install_pkg javapackages-tools
install_pkg javassist
install_pkg jaxen
install_pkg jbigkit-libs
install_pkg jboss-ejb-3.1-api
install_pkg jboss-el-2.2-api
install_pkg jboss-interceptors-1.1-api
install_pkg jboss-jaxrpc-1.1-api
install_pkg jboss-jsp-2.2-api
install_pkg jboss-parent
install_pkg jboss-servlet-3.0-api
install_pkg jboss-transaction-1.1-api
install_pkg jdom
install_pkg jemalloc
install_pkg jline
install_pkg jna
install_pkg jsch
install_pkg js-jquery
install_pkg json-c
install_pkg json-glib
install_pkg jsoup
install_pkg jsr-305
install_pkg jss
install_pkg jtidy
install_pkg junit
install_pkg jvnet-parent
install_pkg jwhois
install_pkg jzlib
install_pkg kbd
install_pkg kbd-legacy
install_pkg kbd-misc
install_pkg kernel
install_pkg kernel
install_pkg kernel-devel
install_pkg kernel-headers
install_pkg kernel-tools
install_pkg kernel-tools-libs
install_pkg kexec-tools
install_pkg keyutils
install_pkg keyutils-libs
install_pkg keyutils-libs-devel
install_pkg kmod
install_pkg kmod-libs
install_pkg kpartx
install_pkg krb5-devel
install_pkg krb5-libs
install_pkg kxml
install_pkg lame-devel
install_pkg lame-libs
install_pkg lcms2
install_pkg less
install_pkg libacl
install_pkg libacl-devel
install_pkg libaio
install_pkg libapreq2
install_pkg libapreq2-devel
install_pkg libarchive
install_pkg libargon2
install_pkg libart_lgpl
install_pkg libart_lgpl-devel
install_pkg libass
install_pkg libassuan
install_pkg libasyncns
install_pkg libatasmart
install_pkg libattr
install_pkg libattr-devel
install_pkg libavdevice
install_pkg libbasicobjects
install_pkg libblkid
install_pkg libblockdev
install_pkg libblockdev-crypto
install_pkg libblockdev-fs
install_pkg libblockdev-loop
install_pkg libblockdev-lvm
install_pkg libblockdev-mdraid
install_pkg libblockdev-part
install_pkg libblockdev-swap
install_pkg libblockdev-utils
install_pkg libbluray
install_pkg libbonobo
install_pkg libbonobo-devel
install_pkg libbonoboui
install_pkg libbonoboui-devel
install_pkg libbytesize
install_pkg libcanberra
install_pkg libcanberra-devel
install_pkg libcanberra-gtk2
install_pkg libcanberra-gtk3
install_pkg libcap
install_pkg libcap-devel
install_pkg libcap-ng
install_pkg libcdio
install_pkg libcdio-paranoia
install_pkg libcgroup
install_pkg libcollection
install_pkg libcom_err
install_pkg libcom_err-devel
install_pkg libcroco
install_pkg libcurl
install_pkg libcurl-devel
install_pkg libdaemon
install_pkg libdb
install_pkg libdb4
install_pkg libdb4-devel
install_pkg libdb-devel
install_pkg libdb-utils
install_pkg libdc1394
install_pkg libdnet
install_pkg libdrm
install_pkg libdrm-devel
install_pkg libdwarf
install_pkg libecap
install_pkg libecap-devel
install_pkg libedit
install_pkg libedit-devel
install_pkg libepoxy
install_pkg libepoxy-devel
install_pkg libestr
install_pkg libev
install_pkg libev-devel
install_pkg libevent
install_pkg libfastjson
install_pkg libffi
install_pkg libfontenc
install_pkg libgcc
install_pkg libgcrypt
install_pkg libgcrypt-devel
install_pkg libgfortran
install_pkg libglade2
install_pkg libglade2-devel
install_pkg libgnome
install_pkg libgnomecanvas
install_pkg libgnomecanvas-devel
install_pkg libgnome-devel
install_pkg libgnome-keyring
install_pkg libgnome-keyring-devel
install_pkg libgnomeui
install_pkg libgnomeui-devel
install_pkg libgomp
install_pkg libgpg-error
install_pkg libgpg-error-devel
install_pkg libguac
install_pkg libguac-client-rdp
install_pkg libguac-client-ssh
install_pkg libguac-client-vnc
install_pkg libgudev1
install_pkg libgusb
install_pkg libICE
install_pkg libICE-devel
install_pkg libicu
install_pkg libicu-devel
install_pkg libIDL
install_pkg libIDL-devel
install_pkg libidn
install_pkg libidn2
install_pkg libini_config
install_pkg libjpeg-turbo
install_pkg libjpeg-turbo-devel
install_pkg libkadm5
install_pkg libksba
install_pkg libldb
install_pkg libldb-devel
install_pkg liblockfile
install_pkg libmemcached
install_pkg libmng
install_pkg libmnl
install_pkg libmodman
install_pkg libmount
install_pkg libmpc
install_pkg libmspack
install_pkg libndp
install_pkg libnetfilter_conntrack
install_pkg libnetfilter_cthelper
install_pkg libnetfilter_cttimeout
install_pkg libnetfilter_queue
install_pkg libnfnetlink
install_pkg libnfsidmap
install_pkg libnghttp2
install_pkg libnghttp2-devel
install_pkg libnl
install_pkg libnl3
install_pkg libnl3-cli
install_pkg libnotify
install_pkg libogg
install_pkg libogg-devel
install_pkg libotf
install_pkg libpath_utils
install_pkg libpcap
install_pkg libpcap-devel
install_pkg libpciaccess
install_pkg libpipeline
install_pkg libpng
install_pkg libpng12
install_pkg libpng-devel
install_pkg libproxy
install_pkg libpwquality
install_pkg libquadmath
install_pkg libquadmath-devel
install_pkg librados2
install_pkg libraw1394
install_pkg libref_array
install_pkg libreport-filesystem
install_pkg librsvg2
install_pkg libseccomp
install_pkg libsecret
install_pkg libsecret-devel
install_pkg libselinux
install_pkg libselinux-devel
install_pkg libselinux-python
install_pkg libselinux-utils
install_pkg libsemanage
install_pkg libsemanage-python
install_pkg libsepol
install_pkg libsepol-devel
install_pkg libshout
install_pkg libshout-devel
install_pkg libSM
install_pkg libsmbclient
install_pkg libSM-devel
install_pkg libsndfile
install_pkg libsoup
install_pkg libss
install_pkg libssh
install_pkg libssh2
install_pkg libssh2-devel
install_pkg libstdc++
install_pkg libstdc++-devel
install_pkg libsysfs
install_pkg libtalloc
install_pkg libtalloc-devel
install_pkg libtasn1
install_pkg libtasn1-devel
install_pkg libtdb
install_pkg libtdb-devel
install_pkg libteam
install_pkg libtelnet
install_pkg libtelnet-devel
install_pkg libtermkey
install_pkg libtevent
install_pkg libtevent-devel
install_pkg libthai
install_pkg libtheora
install_pkg libtheora-devel
install_pkg libtiff
install_pkg libtiff-devel
install_pkg libtirpc
install_pkg libtool
install_pkg libtool-ltdl
install_pkg libtool-ltdl-devel
install_pkg libudisks2
install_pkg libunistring
install_pkg libupnp
install_pkg libupnp-devel
install_pkg libusb
install_pkg libusbx
install_pkg libuser
install_pkg libuser-python
install_pkg libutempter
install_pkg libuuid
install_pkg libuuid-devel
install_pkg libuv
install_pkg libv4l
install_pkg libva
install_pkg libverto
install_pkg libverto-devel
install_pkg libverto-libevent
install_pkg libvisual
install_pkg libvncserver
install_pkg libvncserver-devel
install_pkg libvorbis
install_pkg libvorbis-devel
install_pkg libvterm
install_pkg libwayland-client
install_pkg libwayland-cursor
install_pkg libwayland-server
install_pkg libwbclient
install_pkg libwebp
install_pkg libwebp-devel
install_pkg libwmf-lite
install_pkg libX11
install_pkg libX11-common
install_pkg libX11-devel
install_pkg libXau
install_pkg libXau-devel
install_pkg libXaw
install_pkg libxcb
install_pkg libxcb-devel
install_pkg libXcomposite
install_pkg libXcomposite-devel
install_pkg libXcursor
install_pkg libXcursor-devel
install_pkg libXdamage
install_pkg libXdamage-devel
install_pkg libXext
install_pkg libXext-devel
install_pkg libXfixes
install_pkg libXfixes-devel
install_pkg libXfont
install_pkg libXft
install_pkg libXft-devel
install_pkg libXi
install_pkg libXi-devel
install_pkg libXinerama
install_pkg libXinerama-devel
install_pkg libxkbcommon
install_pkg libxkbcommon-devel
install_pkg libxkbfile
install_pkg libxml2
install_pkg libxml2-devel
install_pkg libxml2-python
install_pkg libXmu
install_pkg libXpm
install_pkg libXpm-devel
install_pkg libXrandr
install_pkg libXrandr-devel
install_pkg libXrender
install_pkg libXrender-devel
install_pkg libxshmfence
install_pkg libxslt
install_pkg libxslt-devel
install_pkg libXt
install_pkg libXtst
install_pkg libXv
install_pkg libXxf86vm
install_pkg libXxf86vm-devel
install_pkg libyaml
install_pkg libzip
install_pkg libzip5
install_pkg linux-firmware
install_pkg lksctp-tools
install_pkg lksctp-tools-devel
install_pkg lm_sensors-libs
install_pkg log4j
install_pkg logrotate
install_pkg lshw
install_pkg lsof
install_pkg lsscsi
install_pkg lua
install_pkg lua-bit32
install_pkg lua-devel
install_pkg luajit
install_pkg luajit-devel
install_pkg lvm2
install_pkg lvm2-libs
install_pkg lynx
install_pkg lyx-fonts
install_pkg lz4
install_pkg lzo
install_pkg lzo-minilzo
install_pkg m17n-db
install_pkg m17n-lib
install_pkg m4
install_pkg mailcap
install_pkg mailx
install_pkg make
install_pkg man-db
install_pkg man-pages
install_pkg mariadb
install_pkg mariadb-devel
install_pkg mariadb-libs
install_pkg mariadb-server
install_pkg maven
install_pkg maven-antrun-plugin
install_pkg maven-archiver
install_pkg maven-artifact
install_pkg maven-artifact-manager
install_pkg maven-artifact-resolver
install_pkg maven-assembly-plugin
install_pkg maven-common-artifact-filters
install_pkg maven-compiler-plugin
install_pkg maven-dependency-tree
install_pkg maven-doxia-core
install_pkg maven-doxia-logging-api
install_pkg maven-doxia-module-apt
install_pkg maven-doxia-module-fml
install_pkg maven-doxia-module-fo
install_pkg maven-doxia-module-xdoc
install_pkg maven-doxia-module-xhtml
install_pkg maven-doxia-sink-api
install_pkg maven-doxia-sitetools
install_pkg maven-doxia-tools
install_pkg maven-enforcer-api
install_pkg maven-enforcer-plugin
install_pkg maven-enforcer-rules
install_pkg maven-file-management
install_pkg maven-filtering
install_pkg maven-invoker
install_pkg maven-jar-plugin
install_pkg maven-javadoc-plugin
install_pkg maven-local
install_pkg maven-model
install_pkg maven-monitor
install_pkg maven-parent
install_pkg maven-plugin-annotations
install_pkg maven-plugin-bundle
install_pkg maven-plugin-descriptor
install_pkg maven-plugin-plugin
install_pkg maven-plugin-registry
install_pkg maven-plugins-pom
install_pkg maven-plugin-testing-harness
install_pkg maven-plugin-tools
install_pkg maven-plugin-tools-annotations
install_pkg maven-plugin-tools-api
install_pkg maven-plugin-tools-beanshell
install_pkg maven-plugin-tools-generators
install_pkg maven-plugin-tools-java
install_pkg maven-plugin-tools-model
install_pkg maven-profile
install_pkg maven-project
install_pkg maven-release
install_pkg maven-release-manager
install_pkg maven-release-plugin
install_pkg maven-remote-resources-plugin
install_pkg maven-reporting-api
install_pkg maven-reporting-exec
install_pkg maven-reporting-impl
install_pkg maven-repository-builder
install_pkg maven-resources-plugin
install_pkg maven-scm
install_pkg maven-settings
install_pkg maven-shared-incremental
install_pkg maven-shared-io
install_pkg maven-shared-utils
install_pkg maven-site-plugin
install_pkg maven-source-plugin
install_pkg maven-surefire
install_pkg maven-surefire-plugin
install_pkg maven-surefire-provider-junit
install_pkg maven-surefire-provider-testng
install_pkg maven-toolchain
install_pkg maven-wagon
install_pkg mdadm
install_pkg mesa-libEGL
install_pkg mesa-libEGL-devel
install_pkg mesa-libgbm
install_pkg mesa-libGL
install_pkg mesa-libglapi
install_pkg mesa-libGL-devel
install_pkg mesa-libGLU
install_pkg mesa-libwayland-egl
install_pkg mesa-libwayland-egl-devel
install_pkg mhash
install_pkg mhash-devel
install_pkg microcode_ctl
install_pkg mlocate
install_pkg modello
install_pkg ModemManager-glib
install_pkg mod_fcgid
install_pkg mod_geoip
install_pkg mod_http2
install_pkg mod_ldap
install_pkg mod_perl
install_pkg mod_proxy_html
install_pkg mod_proxy_uwsgi
install_pkg mod_session
install_pkg mod_ssl
install_pkg mod_wsgi
install_pkg mojo-parent
install_pkg mokutil
install_pkg mozjs17
install_pkg mpfr
install_pkg mrtg
install_pkg msgpack
install_pkg msv-msv
install_pkg msv-xsdlib
install_pkg mtr
install_pkg munin
install_pkg munin-apache
install_pkg munin-common
install_pkg munin-node
install_pkg nano
install_pkg ncurses
install_pkg ncurses-base
install_pkg ncurses-devel
install_pkg ncurses-libs
install_pkg nekohtml
install_pkg neon
install_pkg neovim
install_pkg net-snmp
install_pkg net-snmp-agent-libs
install_pkg net-snmp-libs
install_pkg net-snmp-utils
install_pkg nettle
install_pkg nettle-devel
install_pkg net-tools
install_pkg NetworkManager
install_pkg NetworkManager-libnm
install_pkg NetworkManager-team
install_pkg NetworkManager-tui
install_pkg newt
install_pkg newt-python
install_pkg nfs-utils
install_pkg nghttp2
install_pkg nginx
install_pkg nmap-ncat
install_pkg nodejs
install_pkg nodesource-release
install_pkg nspr
install_pkg nspr-devel
install_pkg nss
install_pkg nss-devel
install_pkg nss-pem
install_pkg nss-softokn
install_pkg nss-softokn-devel
install_pkg nss-softokn-freebl
install_pkg nss-softokn-freebl-devel
install_pkg nss-sysinit
install_pkg nss-tools
install_pkg nss-util
install_pkg nss-util-devel
install_pkg ntp
install_pkg ntpdate
install_pkg numactl-libs
install_pkg objectweb-asm
install_pkg objenesis
install_pkg oddjob
install_pkg oddjob-mkhomedir
install_pkg openal-soft
install_pkg opencore-amr
install_pkg OpenEXR-libs
install_pkg openjade
install_pkg openjpeg-libs
install_pkg openldap
install_pkg openldap-devel
install_pkg opensp
install_pkg openssh
install_pkg openssh-clients
install_pkg openssh-server
install_pkg openssl
install_pkg openssl-devel
install_pkg openssl-libs
install_pkg open-vm-tools
install_pkg opus
install_pkg ORBit2
install_pkg ORBit2-devel
install_pkg orc
install_pkg os-prober
install_pkg ostree
install_pkg p11-kit
install_pkg p11-kit-devel
install_pkg p11-kit-trust
install_pkg PackageKit
install_pkg PackageKit-glib
install_pkg PackageKit-yum
install_pkg pakchois
install_pkg pam
install_pkg pam-devel
install_pkg pango
install_pkg pango-devel
install_pkg parted
install_pkg passwd
install_pkg patch
install_pkg patchutils
install_pkg pciutils
install_pkg pciutils-libs
install_pkg pcp
install_pkg pcp-conf
install_pkg pcp-libs
install_pkg pcp-selinux
install_pkg pcre
install_pkg pcre2
install_pkg pcre-devel
install_pkg pcsc-lite
install_pkg pcsc-lite-ccid
install_pkg pcsc-lite-libs
install_pkg perl
install_pkg perl-Algorithm-Diff
install_pkg perl-Archive-Tar
install_pkg perl-Archive-Zip
install_pkg perl-Authen-SASL
install_pkg perl-autodie
install_pkg perl-B-Hooks-EndOfScope
install_pkg perl-B-Lint
install_pkg perl-BSD-Resource
install_pkg perl-Business-ISBN
install_pkg perl-Business-ISBN-Data
install_pkg perl-Cache-Cache
install_pkg perl-Cache-Memcached
install_pkg perl-Carp
install_pkg perl-Carp-Always
install_pkg perl-CGI
install_pkg perl-Class-Data-Inheritable
install_pkg perl-Class-Inspector
install_pkg perl-Class-ISA
install_pkg perl-Class-Load
install_pkg perl-Class-Method-Modifiers
install_pkg perl-Class-Singleton
install_pkg perl-Compress-Raw-Bzip2
install_pkg perl-Compress-Raw-Zlib
install_pkg perl-constant
install_pkg perl-CPAN
install_pkg perl-CPAN-Meta
install_pkg perl-CPAN-Meta-Requirements
install_pkg perl-CPAN-Meta-YAML
install_pkg perl-Crypt-DES
install_pkg perl-Data-Dump
install_pkg perl-Data-Dumper
install_pkg perl-Data-OptList
install_pkg perl-Data-Section
install_pkg perl-Date-ISO8601
install_pkg perl-Date-Manip
install_pkg perl-DateTime
install_pkg perl-DateTime-Locale
install_pkg perl-DateTime-TimeZone
install_pkg perl-DateTime-TimeZone-SystemV
install_pkg perl-DateTime-TimeZone-Tzfile
install_pkg perl-DBD-MySQL
install_pkg perl-DBD-Pg
install_pkg perl-DBD-SQLite
install_pkg perl-DB_File
install_pkg perl-DBI
install_pkg perl-devel
install_pkg perl-Devel-CallChecker
install_pkg perl-Devel-Caller
install_pkg perl-Devel-GlobalDestruction
install_pkg perl-Devel-LexAlias
install_pkg perl-Devel-StackTrace
install_pkg perl-Digest
install_pkg perl-Digest-HMAC
install_pkg perl-Digest-MD5
install_pkg perl-Digest-SHA
install_pkg perl-Digest-SHA1
install_pkg perl-Dist-CheckConflicts
install_pkg perl-DynaLoader-Functions
install_pkg perl-Email-Date-Format
install_pkg perl-Encode
install_pkg perl-Encode-Detect
install_pkg perl-Encode-Locale
install_pkg perl-Env
install_pkg perl-Error
install_pkg perl-Eval-Closure
install_pkg perl-Exception-Class
install_pkg perl-experimental
install_pkg perl-Exporter
install_pkg perl-Exporter-Tiny
install_pkg perl-ExtUtils-CBuilder
install_pkg perl-ExtUtils-Embed
install_pkg perl-ExtUtils-Install
install_pkg perl-ExtUtils-MakeMaker
install_pkg perl-ExtUtils-Manifest
install_pkg perl-ExtUtils-ParseXS
install_pkg perl-FCGI
install_pkg perl-File-CheckTree
install_pkg perl-File-Copy-Recursive
install_pkg perl-File-Fetch
install_pkg perl-File-HomeDir
install_pkg perl-File-Listing
install_pkg perl-File-Path
install_pkg perl-File-ShareDir
install_pkg perl-File-Temp
install_pkg perl-File-Which
install_pkg perl-Filter
install_pkg perl-GD
install_pkg perl-GD-Barcode
install_pkg perl-generators
install_pkg perl-Geo-IP
install_pkg perl-Getopt-Long
install_pkg perl-GSSAPI
install_pkg perl-HTML-Parser
install_pkg perl-HTML-Tagset
install_pkg perl-HTML-Template
install_pkg perl-HTTP-Cookies
install_pkg perl-HTTP-Daemon
install_pkg perl-HTTP-Date
install_pkg perl-HTTP-Message
install_pkg perl-HTTP-Negotiate
install_pkg perl-HTTP-ProxyAutoConfig
install_pkg perl-HTTP-Tiny
install_pkg perl-interpreter
install_pkg perl-IO-Compress
install_pkg perl-IO-HTML
install_pkg perl-IO-Multiplex
install_pkg perl-IO-Socket-INET6
install_pkg perl-IO-Socket-IP
install_pkg perl-IO-Socket-SSL
install_pkg perl-IO-Tty
install_pkg perl-IO-Zlib
install_pkg perl-IPC-Cmd
install_pkg perl-IPC-ShareLite
install_pkg perl-IPC-System-Simple
install_pkg perl-JSON-PP
install_pkg perl-libintl
install_pkg perl-libs
install_pkg perl-libwww-perl
install_pkg perl-Linux-Pid
install_pkg perl-List-MoreUtils
install_pkg perl-Locale-Codes
install_pkg perl-Locale-Maketext
install_pkg perl-Locale-Maketext-Simple
install_pkg perl-local-lib
install_pkg perl-Log-Dispatch
install_pkg perl-Log-Dispatch-FileRotate
install_pkg perl-Log-Log4perl
install_pkg perl-LWP-MediaTypes
install_pkg perl-macros
install_pkg perl-Mail-Sender
install_pkg perl-Mail-Sendmail
install_pkg perl-MailTools
install_pkg perl-MIME-Lite
install_pkg perl-MIME-Types
install_pkg perl-Module-Build
install_pkg perl-Module-CoreList
install_pkg perl-Module-Implementation
install_pkg perl-Module-Load
install_pkg perl-Module-Load-Conditional
install_pkg perl-Module-Loaded
install_pkg perl-Module-Metadata
install_pkg perl-Module-Pluggable
install_pkg perl-Module-Runtime
install_pkg perl-Mozilla-CA
install_pkg perl-MRO-Compat
install_pkg perl-namespace-autoclean
install_pkg perl-namespace-clean
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
install_pkg perl-Net-XMPP
install_pkg perl-NTLM
install_pkg perl-Package-Constants
install_pkg perl-Package-DeprecationManager
install_pkg perl-Package-Generator
install_pkg perl-Package-Stash
install_pkg perl-Package-Stash-XS
install_pkg perl-PadWalker
install_pkg perl-Params-Check
install_pkg perl-Params-Classify
install_pkg perl-Params-Util
install_pkg perl-Params-Validate
install_pkg perl-parent
install_pkg perl-Parse-CPAN-Meta
install_pkg perl-PathTools
install_pkg perl-Perl-OSType
install_pkg perl-PlRPC
install_pkg perl-Pod-Checker
install_pkg perl-Pod-Escapes
install_pkg perl-Pod-LaTeX
install_pkg perl-podlators
install_pkg perl-Pod-Parser
install_pkg perl-Pod-Perldoc
install_pkg perl-Pod-Plainer
install_pkg perl-Pod-Simple
install_pkg perl-Pod-Usage
install_pkg perl-Ref-Util
install_pkg perl-Ref-Util-XS
install_pkg perl-Role-Tiny
install_pkg perl-Scalar-List-Utils
install_pkg perl-SGMLSpm
install_pkg perl-SNMP_Session
install_pkg perl-Socket
install_pkg perl-Socket6
install_pkg perl-Software-License
install_pkg perl-srpm-macros
install_pkg perl-Storable
install_pkg perl-String-CRC32
install_pkg perl-Sub-Exporter
install_pkg perl-Sub-Exporter-Progressive
install_pkg perl-Sub-Identify
install_pkg perl-Sub-Install
install_pkg perl-Sub-Name
install_pkg perl-Switch
install_pkg perl-Sys-Syslog
install_pkg perl-Taint-Runtime
install_pkg perl-TermReadKey
install_pkg perl-Test-Harness
install_pkg perl-Test-Simple
install_pkg perl-Text-Diff
install_pkg perl-Text-Glob
install_pkg perl-Text-ParseWords
install_pkg perl-Text-Soundex
install_pkg perl-Text-Template
install_pkg perl-Text-Unidecode
install_pkg perl-Thread-Queue
install_pkg perl-threads
install_pkg perl-threads-shared
install_pkg perltidy
install_pkg perl-TimeDate
install_pkg perl-Time-HiRes
install_pkg perl-Time-Local
install_pkg perl-Time-Piece
install_pkg perl-Try-Tiny
install_pkg perl-URI
install_pkg perl-Variable-Magic
install_pkg perl-version
install_pkg perl-WWW-RobotRules
install_pkg perl-XML-DOM
install_pkg perl-XML-LibXML
install_pkg perl-XML-NamespaceSupport
install_pkg perl-XML-Parser
install_pkg perl-XML-RegExp
install_pkg perl-XML-SAX
install_pkg perl-XML-SAX-Base
install_pkg perl-XML-Stream
install_pkg php
install_pkg php-cli
install_pkg php-common
install_pkg php-composer-ca-bundle
install_pkg php-composer-semver
install_pkg php-composer-spdx-licenses
install_pkg php-composer-xdebug-handler
install_pkg php-devel
install_pkg php-embedded
install_pkg php-fedora-autoloader
install_pkg php-fpm
install_pkg php-gd
install_pkg php-gmp
install_pkg php-intl
install_pkg php-json
install_pkg php-jsonlint
install_pkg php-justinrainbow-json-schema5
install_pkg php-mbstring
install_pkg php-mysqlnd
install_pkg php-opcache
install_pkg php-paragonie-random-compat
install_pkg php-password-compat
install_pkg php-pdo
install_pkg php-pecl-geoip
install_pkg php-pecl-zip
install_pkg php-pgsql
install_pkg php-process
install_pkg php-PsrLog
install_pkg php-seld-phar-utils
install_pkg php-symfony-browser-kit
install_pkg php-symfony-class-loader
install_pkg php-symfony-common
install_pkg php-symfony-config
install_pkg php-symfony-console
install_pkg php-symfony-css-selector
install_pkg php-symfony-debug
install_pkg php-symfony-dependency-injection
install_pkg php-symfony-dom-crawler
install_pkg php-symfony-event-dispatcher
install_pkg php-symfony-expression-language
install_pkg php-symfony-filesystem
install_pkg php-symfony-finder
install_pkg php-symfony-http-foundation
install_pkg php-symfony-http-kernel
install_pkg php-symfony-polyfill
install_pkg php-symfony-process
install_pkg php-symfony-var-dumper
install_pkg php-symfony-yaml
install_pkg php-xml
install_pkg pinentry
install_pkg pinfo
install_pkg pixman
install_pkg pixman-devel
install_pkg pkgconfig
install_pkg plexus-archiver
install_pkg plexus-build-api
install_pkg plexus-cipher
install_pkg plexus-classworlds
install_pkg plexus-cli
install_pkg plexus-compiler
install_pkg plexus-component-api
install_pkg plexus-components-pom
install_pkg plexus-containers-component-annotations
install_pkg plexus-containers-component-metadata
install_pkg plexus-containers-container-default
install_pkg plexus-i18n
install_pkg plexus-interactivity
install_pkg plexus-interpolation
install_pkg plexus-io
install_pkg plexus-pom
install_pkg plexus-resources
install_pkg plexus-sec-dispatcher
install_pkg plexus-tools-pom
install_pkg plexus-utils
install_pkg plexus-velocity
install_pkg plymouth
install_pkg plymouth-core-libs
install_pkg plymouth-scripts
install_pkg policycoreutils
install_pkg policycoreutils-devel
install_pkg policycoreutils-python
install_pkg polkit
install_pkg polkit-pkla-compat
install_pkg ponysay
install_pkg poppler-data
install_pkg popt
install_pkg popt-devel
install_pkg postfix
install_pkg postgresql
install_pkg postgresql-devel
install_pkg postgresql-libs
install_pkg ppp
install_pkg procps-ng
install_pkg proftpd
install_pkg psacct
install_pkg psmisc
install_pkg pth
install_pkg pulseaudio-libs
install_pkg pulseaudio-libs-devel
install_pkg pulseaudio-libs-glib2
install_pkg pycairo
install_pkg pygobject2
install_pkg pygpgme
install_pkg pygtk2
install_pkg pygtk2-libglade
install_pkg pyliblzma
install_pkg pyOpenSSL
install_pkg pyparsing
install_pkg pytalloc
install_pkg python
install_pkg python2-acme
install_pkg python2-certbot
install_pkg python2-certbot-apache
install_pkg python2-certbot-dns-rfc2136
install_pkg python2-configargparse
install_pkg python2-cryptography
install_pkg python2-dialog
install_pkg python2-enum34
install_pkg python2-funcsigs
install_pkg python2-future
install_pkg python2-idna
install_pkg python2-josepy
install_pkg python2-mock
install_pkg python2-parsedatetime
install_pkg python2-pbr
install_pkg python2-pip
install_pkg python2-psutil
install_pkg python2-pyasn1
install_pkg python2-pyrfc3339
install_pkg python2-pysocks
install_pkg python2-requests
install_pkg python2-six
install_pkg python2-speedtest-cli
install_pkg python2-zope-interface
install_pkg python34
install_pkg python34-devel
install_pkg python34-libs
install_pkg python3-rpm-macros
install_pkg python-augeas
install_pkg python-backports
install_pkg python-backports-ssl_match_hostname
install_pkg python-cffi
install_pkg python-chardet
install_pkg python-configobj
install_pkg python-dateutil
install_pkg python-decorator
install_pkg python-deltarpm
install_pkg python-devel
install_pkg python-dmidecode
install_pkg python-dns
install_pkg python-enum34
install_pkg python-ethtool
install_pkg python-firewall
install_pkg python-gobject-base
install_pkg python-idna
install_pkg python-iniparse
install_pkg python-inotify
install_pkg python-ipaddress
install_pkg python-IPy
install_pkg python-javapackages
install_pkg python-kitchen
install_pkg python-libs
install_pkg python-linux-procfs
install_pkg python-lxml
install_pkg python-ndg_httpsclient
install_pkg python-perf
install_pkg python-ply
install_pkg python-pwquality
install_pkg python-pycparser
install_pkg python-pycurl
install_pkg python-pyudev
install_pkg python-requests
install_pkg python-requests-toolbelt
install_pkg python-rpm-macros
install_pkg python-schedutils
install_pkg python-setuptools
install_pkg python-six
install_pkg python-slip
install_pkg python-slip-dbus
install_pkg python-srpm-macros
install_pkg python-sssdconfig
install_pkg python-urlgrabber
install_pkg python-urllib3
install_pkg python-zope-component
install_pkg python-zope-event
install_pkg python-zope-interface
install_pkg pytz
install_pkg pyxattr
install_pkg qdox
install_pkg qrencode-libs
install_pkg qt
install_pkg qt3
install_pkg qt-settings
install_pkg qt-x11
install_pkg quota
install_pkg quota-nls
install_pkg rarian
install_pkg rarian-compat
install_pkg rcs
install_pkg rdma-core
install_pkg readline
install_pkg realmd
install_pkg recode
install_pkg redhat-lsb
install_pkg redhat-lsb-core
install_pkg redhat-lsb-cxx
install_pkg redhat-lsb-desktop
install_pkg redhat-lsb-languages
install_pkg redhat-lsb-printing
install_pkg redhat-lsb-submod-multimedia
install_pkg redhat-lsb-submod-security
install_pkg redhat-rpm-config
install_pkg regexp
install_pkg relaxngDatatype
install_pkg rest
install_pkg rhino
install_pkg rootfiles
install_pkg rpcbind
install_pkg rpm
install_pkg rpm-build
install_pkg rpm-build-libs
install_pkg rpm-devel
install_pkg rpmdevtools
install_pkg rpm-libs
install_pkg rpmlint
install_pkg rpm-plugin-systemd-inhibit
install_pkg rpm-python
install_pkg rpm-sign
install_pkg rrdtool
install_pkg rrdtool-perl
install_pkg rsync
install_pkg rsync-daemon
install_pkg rsyslog
install_pkg sac
install_pkg samba
install_pkg samba-client
install_pkg samba-client-libs
install_pkg samba-common
install_pkg samba-common-libs
install_pkg samba-common-tools
install_pkg samba-dc-libs
install_pkg samba-devel
install_pkg samba-libs
install_pkg samba-winbind
install_pkg samba-winbind-clients
install_pkg samba-winbind-modules
install_pkg satyr
install_pkg schroedinger
install_pkg screen
install_pkg SDL
install_pkg sed
install_pkg selinux-policy
install_pkg selinux-policy-devel
install_pkg selinux-policy-targeted
install_pkg sendxmpp
install_pkg setools-libs
install_pkg setup
install_pkg setuptool
install_pkg sg3_utils
install_pkg sg3_utils-libs
install_pkg sgml-common
install_pkg shadow-utils
install_pkg shared-mime-info
install_pkg shorewall
install_pkg shorewall6
install_pkg shorewall-core
install_pkg sisu-inject-bean
install_pkg sisu-inject-plexus
install_pkg slang
install_pkg slf4j
install_pkg smartmontools
install_pkg snakeyaml
install_pkg snappy
install_pkg sonatype-oss-parent
install_pkg sos
install_pkg sound-theme-freedesktop
install_pkg source-highlight
install_pkg soxr
install_pkg spax
install_pkg speex
install_pkg speex-devel
install_pkg spice-parent
install_pkg sqlite
install_pkg sqlite-devel
install_pkg sscg
install_pkg stax2-api
install_pkg stix-fonts
install_pkg subversion
install_pkg subversion-libs
install_pkg subversion-perl
install_pkg sudo
install_pkg swig
install_pkg symlinks
install_pkg sysstat
install_pkg system-config-users
install_pkg system-config-users-docs
install_pkg systemd
install_pkg systemd-devel
install_pkg systemd-libs
install_pkg systemd-python
install_pkg systemd-sysv
install_pkg systemtap
install_pkg systemtap-client
install_pkg systemtap-devel
install_pkg systemtap-runtime
install_pkg systemtap-sdt-devel
install_pkg sysvinit-tools
install_pkg t1lib
install_pkg tar
install_pkg tcl
install_pkg tcpdump
install_pkg tcp_wrappers
install_pkg tcp_wrappers-libs
install_pkg teamd
install_pkg telnet
install_pkg terminus-fonts
install_pkg testng
install_pkg texinfo
install_pkg time
install_pkg tk
install_pkg tmpwatch
install_pkg tomcat
install_pkg tomcat-admin-webapps
install_pkg tomcat-el-2.2-api
install_pkg tomcat-jsp-2.2-api
install_pkg tomcat-lib
install_pkg tomcat-servlet-3.0-api
install_pkg tomcat-taglibs-parent
install_pkg tomcat-webapps
install_pkg traceroute
install_pkg tree
install_pkg trousers
install_pkg ttmkfdir
install_pkg tuned
install_pkg tzdata
install_pkg tzdata-java
install_pkg udisks2
install_pkg udisks2-iscsi
install_pkg udisks2-lvm2
install_pkg unbound-libs
install_pkg unibilium
install_pkg unixODBC
install_pkg unixODBC-devel
install_pkg unzip
install_pkg uptimed
install_pkg urw-fonts
install_pkg usb_modeswitch
install_pkg usb_modeswitch-data
install_pkg usbutils
install_pkg usermode
install_pkg ustr
install_pkg util-linux
install_pkg uuid
install_pkg uuid-devel
install_pkg uwsgi
install_pkg vconfig
install_pkg velocity
install_pkg vim-common
install_pkg vim-enhanced
install_pkg vim-filesystem
install_pkg vim-minimal
install_pkg virt-what
install_pkg vnstat
install_pkg vo-amrwbenc
install_pkg volume_key-libs
install_pkg wayland-devel
install_pkg wayland-protocols-devel
install_pkg webalizer
install_pkg web-assets-filesystem
install_pkg webkitgtk4
install_pkg webkitgtk4-jsc
install_pkg webkitgtk4-plugin-process-gtk2
install_pkg weld-parent
install_pkg wget
install_pkg which
install_pkg whois
install_pkg wireless-tools
install_pkg woodstox-core
install_pkg words
install_pkg wpa_supplicant
install_pkg wsdl4j
install_pkg ws-jaxme
install_pkg x264-libs
install_pkg x265-libs
install_pkg xalan-j2
install_pkg xbean
install_pkg xdg-utils
install_pkg xerces-j2
install_pkg xfsprogs
install_pkg xkeyboard-config
install_pkg xml-common
install_pkg xml-commons-apis
install_pkg xml-commons-resolver
install_pkg xmlgraphics-commons
install_pkg xmlrpc-c
install_pkg xmlrpc-c-client
install_pkg xmlsec1
install_pkg xmlsec1-openssl
install_pkg xmlto
install_pkg xmvn
install_pkg xorg-x11-fonts-Type1
install_pkg xorg-x11-font-utils
install_pkg xorg-x11-proto-devel
install_pkg xorg-x11-xauth
install_pkg xpp3
install_pkg xvidcore
install_pkg xz
install_pkg xz-devel
install_pkg xz-java
install_pkg xz-libs
install_pkg yarn
install_pkg yelp
install_pkg yelp-libs
install_pkg yelp-xsl
install_pkg yum
install_pkg yum-metadata-parser
install_pkg yum-plugin-fastestmirror
install_pkg yum-utils
install_pkg zip
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
#devnull rm -Rf /tmp/configs/etc/{fail2ban,shorewall,shorewall6}
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

##################################################################################################################
printf_head "Cleaning up"
##################################################################################################################
system_service_enable httpd
system_service_enable nginx
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
