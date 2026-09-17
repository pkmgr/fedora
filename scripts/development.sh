#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version       : 202609131048-git
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
VERSION="202609131048-git"
USER="${SUDO_USER:-${USER}}"
HOME="${USER_HOME:-${HOME}}"
SRC_DIR="${BASH_SOURCE%/*}"
SCRIPT_DESCRIBE="development system"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set bash options
if [[ "$1" == "--debug" ]]; then shift 1 && set -xo pipefail && export SCRIPT_OPTS="--debug" && export _DEBUG="on"; fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set functions
GREEN="\033[0;32m"
BG_GREEN="\[$(tput setab 2 2>/dev/null)\]"
BG_RED="\[$(tput setab 9 2>/dev/null)\]"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Vendored from casjay-dotfiles/scripts system-installer.bash (self-contained,
# no network fetch) - only the functions this script actually calls.
__printf_color() { printf "%b" "$(tput setaf "$2" 2>/dev/null)" "$1" "$(tput sgr0 2>/dev/null)"; }
__printf_green() { __printf_color "$1\n" 2; }
__printf_red() { __printf_color "$1\n" 208; }
__printf_yellow() { __printf_color "$1\n" 3; }
__printf_blue() { __printf_color "$1\n" 33; }
__printf_info() { __printf_color "[ ℹ️ ] $1\n" 3; }
__printf_exit() {
  __printf_color "$1\n" 208 1>&2
  exit 1
}
__printf_head() {
  [[ $1 == ?(-)+([0-9]) ]] && local color="$1" && shift 1 || local color="6"
  local msg="$*"
  shift
  __printf_color "
##################################################
$msg
##################################################\n" "$color"
}
__printf_execute_success() { __printf_color "[ ✔ ] $1 \n" 2; }
__printf_execute_error() { __printf_color "[ ✖ ] $1 $2 \n" 1; }
__printf_execute_error_stream() { while read -r line; do __printf_execute_error "↳ ERROR: $line"; done; }
__printf_execute_result() {
  if [ "$1" -eq 0 ]; then __printf_execute_success "$2"; else __printf_execute_error "$2"; fi
  return "$1"
}
__devnull() { "$@" >/dev/null 2>&1; }
__urlcheck() { __devnull curl --output /dev/null --silent --head --fail "$1"; }
__urlinvalid() { if [ -z "$1" ]; then __printf_red "Invalid URL\n"; else
  __printf_red "Can't find $1\n"
  exit 1
fi; }
__urlverify() { __urlcheck $1 || __urlinvalid $1; }
__set_trap() { trap -p "$1" | grep -- "$2" &>/dev/null || trap "$2" "$1"; }
__setexitstatus() {
  EXIT="${EXIT:-$?}"
  local EXITSTATUS+="$EXIT"
  if [ -z "$EXITSTATUS" ] || [ "$EXITSTATUS" -ne 0 ]; then
    BG_EXIT="${BG_RED}"
    return 1
  else
    BG_EXIT="${BG_GREEN}"
    return 0
  fi
}
__execute() {
  __kill_all_subprocesses() {
    local i=""
    for i in $(jobs -p); do
      kill "$i"
      wait "$i" &>/dev/null
    done
  }
  __show_spinner() {
    local -r FRAMES='/-\|'
    local -r NUMBER_OR_FRAMES=${#FRAMES}
    local -r CMDS="$2"
    local -r MSG="$3"
    local -r PID="$1"
    local i=0
    local frameText=""
    if [ "$TRAVIS" != "true" ]; then
      printf "\n\n\n"
      tput cuu 3
      tput sc
    fi
    while kill -0 "$PID" &>/dev/null; do
      frameText="[ ${FRAMES:i++%NUMBER_OR_FRAMES:1} ] $MSG"
      if [ "$TRAVIS" != "true" ]; then
        printf "%s\n" "$frameText"
      else
        printf "%s" "$frameText"
      fi
      sleep 0.2
      if [ "$TRAVIS" != "true" ]; then
        tput rc
      else
        printf "\r"
      fi
    done
  }
  local -r CMDS="$1"
  local -r MSG="${2:-$1}"
  local -r TMP_FILE="$(mktemp /tmp/XXXXX)"
  local exitCode=0
  local cmdsPID=""
  __set_trap "EXIT" "__kill_all_subprocesses"
  eval "$CMDS" >/dev/null 2>"$TMP_FILE" &
  cmdsPID=$!
  __show_spinner "$cmdsPID" "$CMDS" "$MSG"
  wait "$cmdsPID" &>/dev/null
  exitCode=$?
  __printf_execute_result $exitCode "$MSG"
  if [ $exitCode -ne 0 ]; then
    __printf_execute_error_stream <"$TMP_FILE"
  fi
  rm -rf "$TMP_FILE"
  return $exitCode
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
[[ "$1" == "--help" ]] && __printf_exit "${GREEN}apache installer for Fedora"
cat /etc/*-release | grep -- 'ID_LIKE=' | grep -E -- 'rhel|centos' &>/dev/null && true || __printf_exit "This installer is meant to be run on a CentOS based system"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__system_service_exists() { systemctl status "$1" 2>&1 | grep -iq -- "$1" && return 0 || return 1; }
__system_service_enable() { systemctl is-enabled --quiet "$1" 2>/dev/null || __execute "systemctl enable $1" "Enabling service: $1" || return 1; }
__system_service_disable() { systemctl status "$1" 2>&1 | grep -iq -- 'active' && __execute "systemctl disable --now $1" "Disabling service: $1" || return 1; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__test_pkg() {
  for pkg in "$@"; do
    if rpm -q "$pkg" &>/dev/null; then
      __printf_blue "[ ✔ ] $pkg is already installed"
      return 1
    else
      return 0
    fi
  done
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__remove_pkg() {
  __test_pkg "$*" &>/dev/null || __execute "yum remove -q -y $*" "Removing: $*"
  __test_pkg "$*" &>/dev/null || return 0
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__install_pkg() {
  __test_pkg "$*" && if __execute "yum install -q -y --skip-broken $*" "Installing: $*"; then
    return 0
  else
    return 1
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__detect_selinux() {
  selinuxenabled
  if [ $? -ne 0 ]; then return 0; else return 1; fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__disable_selinux() {
  if selinuxenabled; then
    __printf_blue "Disabling selinux"
    __devnull setenforce 0
  else
    __printf_green "selinux is already disabled"
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__rm_repo_files() { __printf_green "Removing files from /etc/yum.repos.d" && rm -Rf /etc/yum.repos.d/*; }
__run_external() { __printf_green "Executing $*" && eval "$*" >/dev/null 2>&1 || return 1; }
__grab_remote_file() { __urlverify "$1" && curl -q -SLs "$1" || exit 1; }
__save_remote_file() { __urlverify "$1" && curl -q -SLs "$1" | tee "$2" &>/dev/null || exit 1; }
__retrieve_version_file() { __grab_remote_file "https://github.com/casjay-base/fedora/raw/main/version.txt" | head -n1 || echo "Unknown version"; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__retrieve_repo_file() {
  local RELEASE_VER RELEASE_FILE IFS
  RELEASE_FILE="https://github.com/rpm-devel/casjay-release/raw/main/fedora.repo"
  RELEASE_VER="$(cat /etc/*-release | grep -- 'VERSION_ID=' | awk -F '=' '{print $2}' | sed 's#"##g' | awk -F '.' '{print $1}')"
  __save_remote_file "$RELEASE_FILE" "/etc/yum.repos.d/casjay.repo"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__run_grub() {
  __printf_green "Setting up grub"
  rm -Rf /boot/*rescue*
  __devnull grub2-mkconfig -o /boot/grub2/grub.cfg
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__run_post() {
  local e="$*"
  local m="${e//__devnull /}"
  __execute "$e" "executing: $m"
  __setexitstatus
  set --
}
##################################################################################################################
clear
ARGS="$*" && shift $#
##################################################################################################################
__printf_head "Initializing the installer"
##################################################################################################################
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ -f /etc/casjaysdev/updates/versions/default.txt ]; then
  __printf_red "This has already been installed"
  __printf_red "To reinstall please remove the version file in"
  __printf_exit "/etc/casjaysdev/updates/versions/default.txt"
fi
if ! builtin type -P systemmgr &>/dev/null; then
  if [[ -d "/usr/local/share/CasjaysDev/scripts" ]]; then
    __run_external "git -C https://github.com/casjay-dotfiles/scripts pull"
  else
    __run_external "git clone https://github.com/casjay-dotfiles/scripts /usr/local/share/CasjaysDev/scripts"
  fi
  __run_external /usr/local/share/CasjaysDev/scripts/install.sh
  __run_external systemmgr --config &>/dev/null
  __run_external systemmgr install scripts
  __run_external "yum clean all"
fi
if [ "$(hostname -s)" != "pbx" ]; then
  __rm_repo_files
  __retrieve_repo_file
fi

##################################################################################################################
__printf_head "Disabling selinux"
##################################################################################################################
__disable_selinux

##################################################################################################################
__printf_head "Configuring cores for compiling"
##################################################################################################################
numberofcores=$(grep -c -- '^processor' /proc/cpuinfo)
__printf_yellow "Total cores avaliable: $numberofcores"
if [ -f /etc/makepkg.conf ]; then
  if [ $numberofcores -gt 1 ]; then
    sed -i 's/#MAKEFLAGS="-j2"/MAKEFLAGS="-j'$(($numberofcores + 1))'"/g' /etc/makepkg.conf
    sed -i 's/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T '"$numberofcores"' -z -)/g' /etc/makepkg.conf
  fi
fi

##################################################################################################################
__printf_head "Configuring the system"
##################################################################################################################
__run_external yum clean all
__run_external yum update -q -y --skip-broken
__install_pkg vnstat
__system_service_enable vnstat
__install_pkg net-tools
__install_pkg wget
__install_pkg curl
__install_pkg git
__install_pkg s-nail
__install_pkg e2fsprogs
__install_pkg redhat-lsb
__install_pkg neovim
__install_pkg unzip
__run_external rm -Rf /tmp/dotfiles
__run_external timedatectl set-timezone America/New_York
__install_pkg cronie-noanacron
for rpms in echo cronie-anacron sendmail sendmail-cf; do
  rpm -ev --nodeps $rpms &>/dev/null
done
__run_external rm -Rf /root/anaconda-ks.cfg /var/log/anaconda
if [ "$(hostname -s)" != "pbx" ]; then
  __rm_repo_files
  __retrieve_repo_file
fi
__run_external yum clean all
__run_external yum update -q -y --skip-broken
__run_grub

##################################################################################################################
__printf_head "Installing the packages for $SCRIPT_DESCRIBE"
##################################################################################################################
__install_pkg acl
__install_pkg adwaita-cursor-theme
__install_pkg adwaita-icon-theme
__install_pkg aether-api
__install_pkg aether-connector-wagon
__install_pkg aether-impl
__install_pkg aether-spi
__install_pkg aether-util
__install_pkg aic94xx-firmware
__install_pkg alsa-firmware
__install_pkg alsa-lib
__install_pkg alsa-lib-devel
__install_pkg alsa-tools-firmware
__install_pkg ant
__install_pkg antlr-tool
__install_pkg aopalliance
__install_pkg apache-commons-beanutils
__install_pkg apache-commons-cli
__install_pkg apache-commons-codec
__install_pkg apache-commons-collections
__install_pkg apache-commons-compress
__install_pkg apache-commons-configuration
__install_pkg apache-commons-daemon
__install_pkg apache-commons-dbcp
__install_pkg apache-commons-digester
__install_pkg apache-commons-io
__install_pkg apache-commons-jexl
__install_pkg apache-commons-jxpath
__install_pkg apache-commons-lang
__install_pkg apache-commons-lang3
__install_pkg apache-commons-logging
__install_pkg apache-commons-net
__install_pkg apache-commons-parent
__install_pkg apache-commons-pool
__install_pkg apache-commons-validator
__install_pkg apache-commons-vfs
__install_pkg apache-parent
__install_pkg apache-rat
__install_pkg apache-rat-core
__install_pkg apache-rat-plugin
__install_pkg apache-rat-tasks
__install_pkg apache-resource-bundles
__install_pkg apr
__install_pkg apr-devel
__install_pkg apr-util
__install_pkg apr-util-bdb
__install_pkg apr-util-devel
__install_pkg apr-util-ldap
__install_pkg apr-util-mysql
__install_pkg apr-util-nss
__install_pkg apr-util-odbc
__install_pkg apr-util-openssl
__install_pkg apr-util-pgsql
__install_pkg apr-util-sqlite
__install_pkg aqute-bnd
__install_pkg aqute-bndlib
__install_pkg asciidoc
__install_pkg at
__install_pkg atinject
__install_pkg atk
__install_pkg atk-devel
__install_pkg at-spi2-atk
__install_pkg at-spi2-atk-devel
__install_pkg at-spi2-core
__install_pkg at-spi2-core-devel
__install_pkg attr
__install_pkg audit
__install_pkg audit-libs
__install_pkg audit-libs-python
__install_pkg augeas-libs
__install_pkg authconfig
__install_pkg autoconf
__install_pkg autogen-libopts
__install_pkg automake
__install_pkg avahi-autoipd
__install_pkg avahi-glib
__install_pkg avahi-libs
__install_pkg avalon-framework
__install_pkg avalon-logkit
__install_pkg awstats
__install_pkg base64coder
__install_pkg basesystem
__install_pkg bash
__install_pkg bash-completion
__install_pkg batik
__install_pkg bc
__install_pkg bcel
__install_pkg bea-stax
__install_pkg bea-stax-api
__install_pkg beust-jcommander
__install_pkg bind
__install_pkg bind-libs
__install_pkg bind-libs-lite
__install_pkg bind-license
__install_pkg bind-utils
__install_pkg binutils
__install_pkg biosdevname
__install_pkg bison
__install_pkg boost-date-time
__install_pkg boost-program-options
__install_pkg boost-regex
__install_pkg boost-system
__install_pkg boost-thread
__install_pkg bridge-utils
__install_pkg brotli
__install_pkg brotli-devel
__install_pkg bsf
__install_pkg bsh
__install_pkg btrfs-progs
__install_pkg buildnumber-maven-plugin
__install_pkg byacc
__install_pkg bzip2
__install_pkg bzip2-devel
__install_pkg bzip2-libs
__install_pkg ca-certificates
__install_pkg cairo
__install_pkg cairo-devel
__install_pkg cairo-gobject
__install_pkg cairo-gobject-devel
__install_pkg cal10n
__install_pkg c-ares
__install_pkg c-ares-devel
__install_pkg cdi-api
__install_pkg cdparanoia-libs
__install_pkg centos-indexhtml
__install_pkg centos-logos
__install_pkg centos-release
__install_pkg certbot
__install_pkg cglib
__install_pkg checkpolicy
__install_pkg chkconfig
__install_pkg chrony
__install_pkg c-icap
__install_pkg c-icap-devel
__install_pkg c-icap-libs
__install_pkg cifs-utils
__install_pkg cmake
__install_pkg cockpit
__install_pkg cockpit-bridge
__install_pkg cockpit-dashboard
__install_pkg cockpit-packagekit
__install_pkg cockpit-system
__install_pkg cockpit-ws
__install_pkg codehaus-parent
__install_pkg colord-libs
__install_pkg color-filesystem
__install_pkg composer
__install_pkg comps-extras
__install_pkg conntrack-tools
__install_pkg coolkey
__install_pkg copy-jdk-configs
__install_pkg coreutils
__install_pkg cowsay
__install_pkg cpio
__install_pkg cpp
__install_pkg cppunit
__install_pkg cppunit-devel
__install_pkg cracklib
__install_pkg cracklib-dicts
__install_pkg crda
__install_pkg createrepo
__install_pkg cronie
__install_pkg crontabs
__install_pkg cryptsetup
__install_pkg cryptsetup-libs
__install_pkg cscope
__install_pkg ctags
__install_pkg CUnit
__install_pkg CUnit-devel
__install_pkg cups-client
__install_pkg cups-libs
__install_pkg cvs
__install_pkg cvsps
__install_pkg cyrus-sasl
__install_pkg cyrus-sasl-devel
__install_pkg cyrus-sasl-gssapi
__install_pkg cyrus-sasl-lib
__install_pkg cyrus-sasl-plain
__install_pkg dbus
__install_pkg dbus-devel
__install_pkg dbus-glib
__install_pkg dbus-libs
__install_pkg dbus-python
__install_pkg dconf
__install_pkg dejavu-fonts-common
__install_pkg dejavu-sans-mono-fonts
__install_pkg deltarpm
__install_pkg desktop-file-utils
__install_pkg device-mapper
__install_pkg device-mapper-event
__install_pkg device-mapper-event-libs
__install_pkg device-mapper-libs
__install_pkg device-mapper-multipath
__install_pkg device-mapper-multipath-libs
__install_pkg device-mapper-persistent-data
__install_pkg dhclient
__install_pkg dhcp-common
__install_pkg dhcp-libs
__install_pkg dialog
__install_pkg diffstat
__install_pkg diffutils
__install_pkg dmidecode
__install_pkg dnsmasq
__install_pkg docbook-dtds
__install_pkg docbook-style-dsssl
__install_pkg docbook-style-xsl
__install_pkg docbook-utils
__install_pkg dom4j
__install_pkg dos2unix
__install_pkg dosfstools
__install_pkg downtimed
__install_pkg doxygen
__install_pkg dracut
__install_pkg dracut-config-rescue
__install_pkg dracut-network
__install_pkg dwz
__install_pkg dyninst
__install_pkg e2fsprogs-libs
__install_pkg easymock
__install_pkg easymock2
__install_pkg easymock3
__install_pkg ebtables
__install_pkg ecj
__install_pkg ed
__install_pkg efivar-libs
__install_pkg elfutils
__install_pkg elfutils-default-yama-scope
__install_pkg elfutils-libelf
__install_pkg elfutils-libs
__install_pkg emacs
__install_pkg emacs-common
__install_pkg emacs-filesystem
__install_pkg enchant
__install_pkg ethtool
__install_pkg expat
__install_pkg expat-devel
__install_pkg fail2ban
__install_pkg fail2ban-firewalld
__install_pkg fail2ban-mail
__install_pkg fail2ban-sendmail
__install_pkg fail2ban-server
__install_pkg fdupes
__install_pkg felix-bundlerepository
__install_pkg felix-framework
__install_pkg felix-osgi-compendium
__install_pkg felix-osgi-core
__install_pkg felix-osgi-foundation
__install_pkg felix-osgi-obr
__install_pkg felix-shell
__install_pkg felix-utils
__install_pkg ffmpeg-devel
__install_pkg ffmpeg-libs
__install_pkg file
__install_pkg file-libs
__install_pkg filesystem
__install_pkg findutils
__install_pkg fipscheck
__install_pkg fipscheck-lib
__install_pkg firewalld
__install_pkg firewalld-filesystem
__install_pkg flac-libs
__install_pkg flex
__install_pkg fontconfig
__install_pkg fontconfig-devel
__install_pkg fontpackages-filesystem
__install_pkg foomatic-filters
__install_pkg fop
__install_pkg forge-parent
__install_pkg fortune-mod
__install_pkg fpaste
__install_pkg fping
__install_pkg freerdp-devel
__install_pkg freerdp-libs
__install_pkg freetype
__install_pkg freetype-devel
__install_pkg fribidi
__install_pkg fuse
__install_pkg fuse-libs
__install_pkg fuse-sshfs
__install_pkg fxload
__install_pkg galera
__install_pkg gamin
__install_pkg gamin-devel
__install_pkg gawk
__install_pkg gc
__install_pkg gcc
__install_pkg gcc-c++
__install_pkg gcc-gfortran
__install_pkg GConf2
__install_pkg GConf2-devel
__install_pkg gcr
__install_pkg gd
__install_pkg gdb
__install_pkg gdbm
__install_pkg gdbm-devel
__install_pkg gdisk
__install_pkg gdk-pixbuf2
__install_pkg gdk-pixbuf2-devel
__install_pkg gd-last
__install_pkg gd-last-devel
__install_pkg geoclue2
__install_pkg GeoIP
__install_pkg GeoIP-data
__install_pkg GeoIP-devel
__install_pkg GeoIP-update
__install_pkg geronimo-annotation
__install_pkg geronimo-jaxrpc
__install_pkg geronimo-jms
__install_pkg geronimo-jta
__install_pkg geronimo-osgi-support
__install_pkg geronimo-parent-poms
__install_pkg geronimo-saaj
__install_pkg gettext
__install_pkg gettext-common-devel
__install_pkg gettext-devel
__install_pkg gettext-libs
__install_pkg ghostscript
__install_pkg ghostscript-fonts
__install_pkg giflib
__install_pkg git-core
__install_pkg git-core-doc
__install_pkg git-perl-Git
__install_pkg glib2
__install_pkg glib2-devel
__install_pkg glibc
__install_pkg glibc-common
__install_pkg glibc-devel
__install_pkg glibc-headers
__install_pkg glibc-static
__install_pkg glibc-utils
__install_pkg glib-networking
__install_pkg gl-manpages
__install_pkg gmp
__install_pkg gmp-devel
__install_pkg gnome-doc-utils
__install_pkg gnome-doc-utils-stylesheets
__install_pkg gnome-vfs2
__install_pkg gnome-vfs2-devel
__install_pkg gnupg2
__install_pkg gnupg2-smime
__install_pkg gnutls
__install_pkg gnutls-c++
__install_pkg gnutls-dane
__install_pkg gnutls-devel
__install_pkg go-bindata
__install_pkg gobject-introspection
__install_pkg golang
__install_pkg golang-bin
__install_pkg golang-github-golang-sys-devel
__install_pkg golang-github-oschwald-maxminddb-golang-devel
__install_pkg golang-src
__install_pkg google-guice
__install_pkg gpgme
__install_pkg gpg-pubkey
__install_pkg gpm-libs
__install_pkg graphite2
__install_pkg graphite2-devel
__install_pkg graphviz
__install_pkg grep
__install_pkg groff-base
__install_pkg grub2-tools
__install_pkg grub2-common
__install_pkg grub2-pc
__install_pkg grub2-pc-modules
__install_pkg grub2-tools-extra
__install_pkg grub2-tools-minimal
__install_pkg grubby
__install_pkg gsettings-desktop-schemas
__install_pkg gsm
__install_pkg gssproxy
__install_pkg gstreamer1
__install_pkg gstreamer1-plugins-base
__install_pkg gtk2
__install_pkg gtk2-devel
__install_pkg gtk3
__install_pkg gtk3-devel
__install_pkg gtk-doc
__install_pkg gtk-update-icon-cache
__install_pkg guava
__install_pkg guile
__install_pkg gvfs
__install_pkg gvfs-client
__install_pkg gzip
__install_pkg hamcrest
__install_pkg util-linux-core
__install_pkg harfbuzz
__install_pkg harfbuzz-devel
__install_pkg harfbuzz-icu
__install_pkg hdparm
__install_pkg hicolor-icon-theme
__install_pkg highlight
__install_pkg hiredis
__install_pkg hiredis-devel
__install_pkg hostname
__install_pkg hsqldb
__install_pkg htop
__install_pkg httpcomponents-client
__install_pkg httpcomponents-core
__install_pkg httpcomponents-project
__install_pkg httpd
__install_pkg httpd-devel
__install_pkg httpd-filesystem
__install_pkg httpd-manual
__install_pkg httpd-tools
__install_pkg http-parser
__install_pkg hunspell
__install_pkg hunspell-en-US
__install_pkg hwdata
__install_pkg hyphen
__install_pkg icc-profiles-openicc
__install_pkg iftop
__install_pkg ilmbase
__install_pkg ImageMagick
__install_pkg indent
__install_pkg info
__install_pkg initscripts
__install_pkg intltool
__install_pkg iproute
__install_pkg iprutils
__install_pkg ipset
__install_pkg ipset-libs
__install_pkg iptables
__install_pkg iptstate
__install_pkg iputils
__install_pkg irqbalance
__install_pkg iscsi-initiator-utils
__install_pkg iscsi-initiator-utils-iscsiuio
__install_pkg iso-codes
__install_pkg isorelax
__install_pkg ivtv-firmware
__install_pkg iw
__install_pkg iwl1000-firmware
__install_pkg iwl100-firmware
__install_pkg iwl105-firmware
__install_pkg iwl135-firmware
__install_pkg iwl2000-firmware
__install_pkg iwl2030-firmware
__install_pkg iwl3160-firmware
__install_pkg iwl3945-firmware
__install_pkg iwl4965-firmware
__install_pkg iwl5000-firmware
__install_pkg iwl5150-firmware
__install_pkg iwl6000-firmware
__install_pkg iwl6000g2a-firmware
__install_pkg iwl6000g2b-firmware
__install_pkg iwl6050-firmware
__install_pkg iwl7260-firmware
__install_pkg iwl7265-firmware
__install_pkg jai-imageio-core
__install_pkg jakarta-commons-httpclient
__install_pkg jakarta-oro
__install_pkg jakarta-taglibs-standard
__install_pkg jansson
__install_pkg jasper-libs
__install_pkg java-1.8.0-openjdk
__install_pkg java-1.8.0-openjdk-devel
__install_pkg java-1.8.0-openjdk-headless
__install_pkg javamail
__install_pkg javapackages-tools
__install_pkg javassist
__install_pkg jaxen
__install_pkg jbigkit-libs
__install_pkg jboss-ejb-3.1-api
__install_pkg jboss-el-2.2-api
__install_pkg jboss-interceptors-1.1-api
__install_pkg jboss-jaxrpc-1.1-api
__install_pkg jboss-jsp-2.2-api
__install_pkg jboss-parent
__install_pkg jboss-servlet-3.0-api
__install_pkg jboss-transaction-1.1-api
__install_pkg jdom
__install_pkg jemalloc
__install_pkg jline
__install_pkg jna
__install_pkg jsch
__install_pkg js-jquery
__install_pkg json-c
__install_pkg json-glib
__install_pkg jsoup
__install_pkg jsr-305
__install_pkg jss
__install_pkg jtidy
__install_pkg junit
__install_pkg jvnet-parent
__install_pkg jwhois
__install_pkg jzlib
__install_pkg kbd
__install_pkg kbd-legacy
__install_pkg kbd-misc
__install_pkg kernel
__install_pkg kernel-devel
__install_pkg kernel-headers
__install_pkg kernel-tools
__install_pkg kernel-tools-libs
__install_pkg kexec-tools
__install_pkg keyutils
__install_pkg keyutils-libs
__install_pkg keyutils-libs-devel
__install_pkg kmod
__install_pkg kmod-libs
__install_pkg kpartx
__install_pkg krb5-devel
__install_pkg krb5-libs
__install_pkg kxml
__install_pkg lame-devel
__install_pkg lame-libs
__install_pkg lcms2
__install_pkg less
__install_pkg libacl
__install_pkg libacl-devel
__install_pkg libaio
__install_pkg libapreq2
__install_pkg libapreq2-devel
__install_pkg libarchive
__install_pkg libargon2
__install_pkg libart_lgpl
__install_pkg libart_lgpl-devel
__install_pkg libass
__install_pkg libassuan
__install_pkg libasyncns
__install_pkg libatasmart
__install_pkg libattr
__install_pkg libattr-devel
__install_pkg libavdevice
__install_pkg libbasicobjects
__install_pkg libblkid
__install_pkg libblockdev
__install_pkg libblockdev-crypto
__install_pkg libblockdev-fs
__install_pkg libblockdev-loop
__install_pkg libblockdev-lvm
__install_pkg libblockdev-mdraid
__install_pkg libblockdev-part
__install_pkg libblockdev-swap
__install_pkg libblockdev-utils
__install_pkg libbluray
__install_pkg libbonobo
__install_pkg libbonobo-devel
__install_pkg libbonoboui
__install_pkg libbonoboui-devel
__install_pkg libbytesize
__install_pkg libcanberra
__install_pkg libcanberra-devel
__install_pkg libcanberra-gtk2
__install_pkg libcanberra-gtk3
__install_pkg libcap
__install_pkg libcap-devel
__install_pkg libcap-ng
__install_pkg libcdio
__install_pkg libcdio-paranoia
__install_pkg libcgroup
__install_pkg libcollection
__install_pkg libcom_err
__install_pkg libcom_err-devel
__install_pkg libcroco
__install_pkg libcurl
__install_pkg libcurl-devel
__install_pkg libdaemon
__install_pkg libdb
__install_pkg libdb4
__install_pkg libdb4-devel
__install_pkg libdb-devel
__install_pkg libdb-utils
__install_pkg libdc1394
__install_pkg libdnet
__install_pkg libdrm
__install_pkg libdrm-devel
__install_pkg libdwarf
__install_pkg libecap
__install_pkg libecap-devel
__install_pkg libedit
__install_pkg libedit-devel
__install_pkg libepoxy
__install_pkg libepoxy-devel
__install_pkg libestr
__install_pkg libev
__install_pkg libev-devel
__install_pkg libevent
__install_pkg libfastjson
__install_pkg libffi
__install_pkg libfontenc
__install_pkg libgcc
__install_pkg libgcrypt
__install_pkg libgcrypt-devel
__install_pkg libgfortran
__install_pkg libglade2
__install_pkg libglade2-devel
__install_pkg libgnome
__install_pkg libgnomecanvas
__install_pkg libgnomecanvas-devel
__install_pkg libgnome-devel
__install_pkg libgnome-keyring
__install_pkg libgnome-keyring-devel
__install_pkg libgnomeui
__install_pkg libgnomeui-devel
__install_pkg libgomp
__install_pkg libgpg-error
__install_pkg libgpg-error-devel
__install_pkg libguac
__install_pkg libguac-client-rdp
__install_pkg libguac-client-ssh
__install_pkg libguac-client-vnc
__install_pkg libgudev1
__install_pkg libgusb
__install_pkg libICE
__install_pkg libICE-devel
__install_pkg libicu
__install_pkg libicu-devel
__install_pkg libIDL
__install_pkg libIDL-devel
__install_pkg libidn
__install_pkg libidn2
__install_pkg libini_config
__install_pkg libjpeg-turbo
__install_pkg libjpeg-turbo-devel
__install_pkg libkadm5
__install_pkg libksba
__install_pkg libldb
__install_pkg libldb-devel
__install_pkg liblockfile
__install_pkg libmemcached
__install_pkg libmng
__install_pkg libmnl
__install_pkg libmodman
__install_pkg libmount
__install_pkg libmpc
__install_pkg libmspack
__install_pkg libndp
__install_pkg libnetfilter_conntrack
__install_pkg libnetfilter_cthelper
__install_pkg libnetfilter_cttimeout
__install_pkg libnetfilter_queue
__install_pkg libnfnetlink
__install_pkg libnfsidmap
__install_pkg libnghttp2
__install_pkg libnghttp2-devel
__install_pkg libnl
__install_pkg libnl3
__install_pkg libnl3-cli
__install_pkg libnotify
__install_pkg libogg
__install_pkg libogg-devel
__install_pkg libotf
__install_pkg libpath_utils
__install_pkg libpcap
__install_pkg libpcap-devel
__install_pkg libpciaccess
__install_pkg libpipeline
__install_pkg libpng
__install_pkg libpng12
__install_pkg libpng-devel
__install_pkg libproxy
__install_pkg libpwquality
__install_pkg libquadmath
__install_pkg libquadmath-devel
__install_pkg librados2
__install_pkg libraw1394
__install_pkg libref_array
__install_pkg libreport-filesystem
__install_pkg librsvg2
__install_pkg libseccomp
__install_pkg libsecret
__install_pkg libsecret-devel
__install_pkg libselinux
__install_pkg libselinux-devel
__install_pkg libselinux-python
__install_pkg libselinux-utils
__install_pkg libsemanage
__install_pkg libsemanage-python
__install_pkg libsepol
__install_pkg libsepol-devel
__install_pkg libshout
__install_pkg libshout-devel
__install_pkg libSM
__install_pkg libsmbclient
__install_pkg libSM-devel
__install_pkg libsndfile
__install_pkg libsoup
__install_pkg libss
__install_pkg libssh
__install_pkg libssh2
__install_pkg libssh2-devel
__install_pkg libstdc++
__install_pkg libstdc++-devel
__install_pkg libsysfs
__install_pkg libtalloc
__install_pkg libtalloc-devel
__install_pkg libtasn1
__install_pkg libtasn1-devel
__install_pkg libtdb
__install_pkg libtdb-devel
__install_pkg libteam
__install_pkg libtelnet
__install_pkg libtelnet-devel
__install_pkg libtermkey
__install_pkg libtevent
__install_pkg libtevent-devel
__install_pkg libthai
__install_pkg libtheora
__install_pkg libtheora-devel
__install_pkg libtiff
__install_pkg libtiff-devel
__install_pkg libtirpc
__install_pkg libtool
__install_pkg libtool-ltdl
__install_pkg libtool-ltdl-devel
__install_pkg libudisks2
__install_pkg libunistring
__install_pkg libupnp
__install_pkg libupnp-devel
__install_pkg libusb
__install_pkg libusbx
__install_pkg libuser
__install_pkg libuser-python
__install_pkg libutempter
__install_pkg libuuid
__install_pkg libuuid-devel
__install_pkg libuv
__install_pkg libv4l
__install_pkg libva
__install_pkg libverto
__install_pkg libverto-devel
__install_pkg libverto-libevent
__install_pkg libvisual
__install_pkg libvncserver
__install_pkg libvncserver-devel
__install_pkg libvorbis
__install_pkg libvorbis-devel
__install_pkg libvterm
__install_pkg libwayland-client
__install_pkg libwayland-cursor
__install_pkg libwayland-server
__install_pkg libwbclient
__install_pkg libwebp
__install_pkg libwebp-devel
__install_pkg libwmf-lite
__install_pkg libX11
__install_pkg libX11-common
__install_pkg libX11-devel
__install_pkg libXau
__install_pkg libXau-devel
__install_pkg libXaw
__install_pkg libxcb
__install_pkg libxcb-devel
__install_pkg libXcomposite
__install_pkg libXcomposite-devel
__install_pkg libXcursor
__install_pkg libXcursor-devel
__install_pkg libXdamage
__install_pkg libXdamage-devel
__install_pkg libXext
__install_pkg libXext-devel
__install_pkg libXfixes
__install_pkg libXfixes-devel
__install_pkg libXfont
__install_pkg libXft
__install_pkg libXft-devel
__install_pkg libXi
__install_pkg libXi-devel
__install_pkg libXinerama
__install_pkg libXinerama-devel
__install_pkg libxkbcommon
__install_pkg libxkbcommon-devel
__install_pkg libxkbfile
__install_pkg libxml2
__install_pkg libxml2-devel
__install_pkg libxml2-python
__install_pkg libXmu
__install_pkg libXpm
__install_pkg libXpm-devel
__install_pkg libXrandr
__install_pkg libXrandr-devel
__install_pkg libXrender
__install_pkg libXrender-devel
__install_pkg libxshmfence
__install_pkg libxslt
__install_pkg libxslt-devel
__install_pkg libXt
__install_pkg libXtst
__install_pkg libXv
__install_pkg libXxf86vm
__install_pkg libXxf86vm-devel
__install_pkg libyaml
__install_pkg libzip
__install_pkg libzip5
__install_pkg linux-firmware
__install_pkg lksctp-tools
__install_pkg lksctp-tools-devel
__install_pkg lm_sensors-libs
__install_pkg log4j
__install_pkg logrotate
__install_pkg lshw
__install_pkg lsof
__install_pkg lsscsi
__install_pkg lua
__install_pkg lua-bit32
__install_pkg lua-devel
__install_pkg luajit
__install_pkg luajit-devel
__install_pkg lvm2
__install_pkg lvm2-libs
__install_pkg lynx
__install_pkg lyx-fonts
__install_pkg lz4
__install_pkg lzo
__install_pkg lzo-minilzo
__install_pkg m17n-db
__install_pkg m17n-lib
__install_pkg m4
__install_pkg mailcap
__install_pkg make
__install_pkg man-db
__install_pkg man-pages
__install_pkg mariadb
__install_pkg mariadb-devel
__install_pkg mariadb-libs
__install_pkg mariadb-server
__install_pkg maven
__install_pkg maven-antrun-plugin
__install_pkg maven-archiver
__install_pkg maven-artifact
__install_pkg maven-artifact-manager
__install_pkg maven-artifact-resolver
__install_pkg maven-assembly-plugin
__install_pkg maven-common-artifact-filters
__install_pkg maven-compiler-plugin
__install_pkg maven-dependency-tree
__install_pkg maven-doxia-core
__install_pkg maven-doxia-logging-api
__install_pkg maven-doxia-module-apt
__install_pkg maven-doxia-module-fml
__install_pkg maven-doxia-module-fo
__install_pkg maven-doxia-module-xdoc
__install_pkg maven-doxia-module-xhtml
__install_pkg maven-doxia-sink-api
__install_pkg maven-doxia-sitetools
__install_pkg maven-doxia-tools
__install_pkg maven-enforcer-api
__install_pkg maven-enforcer-plugin
__install_pkg maven-enforcer-rules
__install_pkg maven-file-management
__install_pkg maven-filtering
__install_pkg maven-invoker
__install_pkg maven-jar-plugin
__install_pkg maven-javadoc-plugin
__install_pkg maven-local
__install_pkg maven-model
__install_pkg maven-monitor
__install_pkg maven-parent
__install_pkg maven-plugin-annotations
__install_pkg maven-plugin-bundle
__install_pkg maven-plugin-descriptor
__install_pkg maven-plugin-plugin
__install_pkg maven-plugin-registry
__install_pkg maven-plugins-pom
__install_pkg maven-plugin-testing-harness
__install_pkg maven-plugin-tools
__install_pkg maven-plugin-tools-annotations
__install_pkg maven-plugin-tools-api
__install_pkg maven-plugin-tools-beanshell
__install_pkg maven-plugin-tools-generators
__install_pkg maven-plugin-tools-java
__install_pkg maven-plugin-tools-model
__install_pkg maven-profile
__install_pkg maven-project
__install_pkg maven-release
__install_pkg maven-release-manager
__install_pkg maven-release-plugin
__install_pkg maven-remote-resources-plugin
__install_pkg maven-reporting-api
__install_pkg maven-reporting-exec
__install_pkg maven-reporting-impl
__install_pkg maven-repository-builder
__install_pkg maven-resources-plugin
__install_pkg maven-scm
__install_pkg maven-settings
__install_pkg maven-shared-incremental
__install_pkg maven-shared-io
__install_pkg maven-shared-utils
__install_pkg maven-site-plugin
__install_pkg maven-source-plugin
__install_pkg maven-surefire
__install_pkg maven-surefire-plugin
__install_pkg maven-surefire-provider-junit
__install_pkg maven-surefire-provider-testng
__install_pkg maven-toolchain
__install_pkg maven-wagon
__install_pkg mdadm
__install_pkg mesa-libEGL
__install_pkg mesa-libEGL-devel
__install_pkg mesa-libgbm
__install_pkg mesa-libGL
__install_pkg mesa-libglapi
__install_pkg mesa-libGL-devel
__install_pkg mesa-libGLU
__install_pkg mesa-libwayland-egl
__install_pkg mesa-libwayland-egl-devel
__install_pkg mhash
__install_pkg mhash-devel
__install_pkg microcode_ctl
__install_pkg plocate
__install_pkg modello
__install_pkg ModemManager-glib
__install_pkg mod_fcgid
__install_pkg mod_geoip
__install_pkg mod_http2
__install_pkg mod_ldap
__install_pkg mod_perl
__install_pkg mod_proxy_html
__install_pkg mod_proxy_uwsgi
__install_pkg mod_session
__install_pkg mod_ssl
__install_pkg mod_wsgi
__install_pkg mojo-parent
__install_pkg mokutil
__install_pkg mozjs17
__install_pkg mpfr
__install_pkg mrtg
__install_pkg msgpack
__install_pkg msv-msv
__install_pkg msv-xsdlib
__install_pkg mtr
__install_pkg munin
__install_pkg munin-apache
__install_pkg munin-common
__install_pkg munin-node
__install_pkg nano
__install_pkg ncurses
__install_pkg ncurses-base
__install_pkg ncurses-devel
__install_pkg ncurses-libs
__install_pkg nekohtml
__install_pkg neon
__install_pkg net-snmp
__install_pkg net-snmp-agent-libs
__install_pkg net-snmp-libs
__install_pkg net-snmp-utils
__install_pkg nettle
__install_pkg nettle-devel
__install_pkg NetworkManager
__install_pkg NetworkManager-libnm
__install_pkg NetworkManager-team
__install_pkg NetworkManager-tui
__install_pkg newt
__install_pkg newt-python
__install_pkg nfs-utils
__install_pkg nghttp2
__install_pkg nginx
__install_pkg nmap-ncat
__install_pkg nodejs
__install_pkg nodesource-release
__install_pkg nspr
__install_pkg nspr-devel
__install_pkg nss
__install_pkg nss-devel
__install_pkg nss-pem
__install_pkg nss-softokn
__install_pkg nss-softokn-devel
__install_pkg nss-softokn-freebl
__install_pkg nss-softokn-freebl-devel
__install_pkg nss-sysinit
__install_pkg nss-tools
__install_pkg nss-util
__install_pkg nss-util-devel
__install_pkg ntp
__install_pkg ntpdate
__install_pkg numactl-libs
__install_pkg objectweb-asm
__install_pkg objenesis
__install_pkg oddjob
__install_pkg oddjob-mkhomedir
__install_pkg openal-soft
__install_pkg opencore-amr
__install_pkg OpenEXR-libs
__install_pkg openjade
__install_pkg openjpeg-libs
__install_pkg openldap
__install_pkg openldap-devel
__install_pkg opensp
__install_pkg openssh
__install_pkg openssh-clients
__install_pkg openssh-server
__install_pkg openssl
__install_pkg openssl-devel
__install_pkg openssl-libs
__install_pkg open-vm-tools
__install_pkg opus
__install_pkg ORBit2
__install_pkg ORBit2-devel
__install_pkg orc
__install_pkg os-prober
__install_pkg ostree
__install_pkg p11-kit
__install_pkg p11-kit-devel
__install_pkg p11-kit-trust
__install_pkg PackageKit
__install_pkg PackageKit-glib
__install_pkg PackageKit-yum
__install_pkg pakchois
__install_pkg pam
__install_pkg pam-devel
__install_pkg pango
__install_pkg pango-devel
__install_pkg parted
__install_pkg shadow-utils
__install_pkg patch
__install_pkg patchutils
__install_pkg pciutils
__install_pkg pciutils-libs
__install_pkg pcp
__install_pkg pcp-conf
__install_pkg pcp-libs
__install_pkg pcp-selinux
__install_pkg pcre
__install_pkg pcre2
__install_pkg pcre-devel
__install_pkg pcsc-lite
__install_pkg pcsc-lite-ccid
__install_pkg pcsc-lite-libs
__install_pkg perl
__install_pkg perl-Algorithm-Diff
__install_pkg perl-Archive-Tar
__install_pkg perl-Archive-Zip
__install_pkg perl-Authen-SASL
__install_pkg perl-autodie
__install_pkg perl-B-Hooks-EndOfScope
__install_pkg perl-B-Lint
__install_pkg perl-BSD-Resource
__install_pkg perl-Business-ISBN
__install_pkg perl-Business-ISBN-Data
__install_pkg perl-Cache-Cache
__install_pkg perl-Cache-Memcached
__install_pkg perl-Carp
__install_pkg perl-Carp-Always
__install_pkg perl-CGI
__install_pkg perl-Class-Data-Inheritable
__install_pkg perl-Class-Inspector
__install_pkg perl-Class-ISA
__install_pkg perl-Class-Load
__install_pkg perl-Class-Method-Modifiers
__install_pkg perl-Class-Singleton
__install_pkg perl-Compress-Raw-Bzip2
__install_pkg perl-Compress-Raw-Zlib
__install_pkg perl-constant
__install_pkg perl-CPAN
__install_pkg perl-CPAN-Meta
__install_pkg perl-CPAN-Meta-Requirements
__install_pkg perl-CPAN-Meta-YAML
__install_pkg perl-Crypt-DES
__install_pkg perl-Data-Dump
__install_pkg perl-Data-Dumper
__install_pkg perl-Data-OptList
__install_pkg perl-Data-Section
__install_pkg perl-Date-ISO8601
__install_pkg perl-Date-Manip
__install_pkg perl-DateTime
__install_pkg perl-DateTime-Locale
__install_pkg perl-DateTime-TimeZone
__install_pkg perl-DateTime-TimeZone-SystemV
__install_pkg perl-DateTime-TimeZone-Tzfile
__install_pkg perl-DBD-MySQL
__install_pkg perl-DBD-Pg
__install_pkg perl-DBD-SQLite
__install_pkg perl-DB_File
__install_pkg perl-DBI
__install_pkg perl-devel
__install_pkg perl-Devel-CallChecker
__install_pkg perl-Devel-Caller
__install_pkg perl-Devel-GlobalDestruction
__install_pkg perl-Devel-LexAlias
__install_pkg perl-Devel-StackTrace
__install_pkg perl-Digest
__install_pkg perl-Digest-HMAC
__install_pkg perl-Digest-MD5
__install_pkg perl-Digest-SHA
__install_pkg perl-Digest-SHA1
__install_pkg perl-Dist-CheckConflicts
__install_pkg perl-DynaLoader-Functions
__install_pkg perl-Email-Date-Format
__install_pkg perl-Encode
__install_pkg perl-Encode-Detect
__install_pkg perl-Encode-Locale
__install_pkg perl-Env
__install_pkg perl-Error
__install_pkg perl-Eval-Closure
__install_pkg perl-Exception-Class
__install_pkg perl-experimental
__install_pkg perl-Exporter
__install_pkg perl-Exporter-Tiny
__install_pkg perl-ExtUtils-CBuilder
__install_pkg perl-ExtUtils-Embed
__install_pkg perl-ExtUtils-Install
__install_pkg perl-ExtUtils-MakeMaker
__install_pkg perl-ExtUtils-Manifest
__install_pkg perl-ExtUtils-ParseXS
__install_pkg perl-FCGI
__install_pkg perl-File-CheckTree
__install_pkg perl-File-Copy-Recursive
__install_pkg perl-File-Fetch
__install_pkg perl-File-HomeDir
__install_pkg perl-File-Listing
__install_pkg perl-File-Path
__install_pkg perl-File-ShareDir
__install_pkg perl-File-Temp
__install_pkg perl-File-Which
__install_pkg perl-Filter
__install_pkg perl-GD
__install_pkg perl-GD-Barcode
__install_pkg perl-generators
__install_pkg perl-Geo-IP
__install_pkg perl-Getopt-Long
__install_pkg perl-GSSAPI
__install_pkg perl-HTML-Parser
__install_pkg perl-HTML-Tagset
__install_pkg perl-HTML-Template
__install_pkg perl-HTTP-Cookies
__install_pkg perl-HTTP-Daemon
__install_pkg perl-HTTP-Date
__install_pkg perl-HTTP-Message
__install_pkg perl-HTTP-Negotiate
__install_pkg perl-HTTP-ProxyAutoConfig
__install_pkg perl-HTTP-Tiny
__install_pkg perl-interpreter
__install_pkg perl-IO-Compress
__install_pkg perl-IO-HTML
__install_pkg perl-IO-Multiplex
__install_pkg perl-IO-Socket-INET6
__install_pkg perl-IO-Socket-IP
__install_pkg perl-IO-Socket-SSL
__install_pkg perl-IO-Tty
__install_pkg perl-IO-Zlib
__install_pkg perl-IPC-Cmd
__install_pkg perl-IPC-ShareLite
__install_pkg perl-IPC-System-Simple
__install_pkg perl-JSON-PP
__install_pkg perl-libintl
__install_pkg perl-libs
__install_pkg perl-libwww-perl
__install_pkg perl-Linux-Pid
__install_pkg perl-List-MoreUtils
__install_pkg perl-Locale-Codes
__install_pkg perl-Locale-Maketext
__install_pkg perl-Locale-Maketext-Simple
__install_pkg perl-local-lib
__install_pkg perl-Log-Dispatch
__install_pkg perl-Log-Dispatch-FileRotate
__install_pkg perl-Log-Log4perl
__install_pkg perl-LWP-MediaTypes
__install_pkg perl-macros
__install_pkg perl-Mail-Sender
__install_pkg perl-Mail-Sendmail
__install_pkg perl-MailTools
__install_pkg perl-MIME-Lite
__install_pkg perl-MIME-Types
__install_pkg perl-Module-Build
__install_pkg perl-Module-CoreList
__install_pkg perl-Module-Implementation
__install_pkg perl-Module-Load
__install_pkg perl-Module-Load-Conditional
__install_pkg perl-Module-Loaded
__install_pkg perl-Module-Metadata
__install_pkg perl-Module-Pluggable
__install_pkg perl-Module-Runtime
__install_pkg perl-Mozilla-CA
__install_pkg perl-MRO-Compat
__install_pkg perl-namespace-autoclean
__install_pkg perl-namespace-clean
__install_pkg perl-Net-CIDR
__install_pkg perl-Net-Daemon
__install_pkg perl-Net-DNS
__install_pkg perl-Net-HTTP
__install_pkg perl-Net-IP
__install_pkg perl-Net-LibIDN
__install_pkg perl-Net-Server
__install_pkg perl-Net-SMTP-SSL
__install_pkg perl-Net-SNMP
__install_pkg perl-Net-SSLeay
__install_pkg perl-Net-XMPP
__install_pkg perl-NTLM
__install_pkg perl-Package-Constants
__install_pkg perl-Package-DeprecationManager
__install_pkg perl-Package-Generator
__install_pkg perl-Package-Stash
__install_pkg perl-Package-Stash-XS
__install_pkg perl-PadWalker
__install_pkg perl-Params-Check
__install_pkg perl-Params-Classify
__install_pkg perl-Params-Util
__install_pkg perl-Params-Validate
__install_pkg perl-parent
__install_pkg perl-Parse-CPAN-Meta
__install_pkg perl-PathTools
__install_pkg perl-Perl-OSType
__install_pkg perl-PlRPC
__install_pkg perl-Pod-Checker
__install_pkg perl-Pod-Escapes
__install_pkg perl-Pod-LaTeX
__install_pkg perl-podlators
__install_pkg perl-Pod-Parser
__install_pkg perl-Pod-Perldoc
__install_pkg perl-Pod-Plainer
__install_pkg perl-Pod-Simple
__install_pkg perl-Pod-Usage
__install_pkg perl-Ref-Util
__install_pkg perl-Ref-Util-XS
__install_pkg perl-Role-Tiny
__install_pkg perl-Scalar-List-Utils
__install_pkg perl-SGMLSpm
__install_pkg perl-SNMP_Session
__install_pkg perl-Socket
__install_pkg perl-Socket6
__install_pkg perl-Software-License
__install_pkg perl-srpm-macros
__install_pkg perl-Storable
__install_pkg perl-String-CRC32
__install_pkg perl-Sub-Exporter
__install_pkg perl-Sub-Exporter-Progressive
__install_pkg perl-Sub-Identify
__install_pkg perl-Sub-Install
__install_pkg perl-Sub-Name
__install_pkg perl-Switch
__install_pkg perl-Sys-Syslog
__install_pkg perl-Taint-Runtime
__install_pkg perl-TermReadKey
__install_pkg perl-Test-Harness
__install_pkg perl-Test-Simple
__install_pkg perl-Text-Diff
__install_pkg perl-Text-Glob
__install_pkg perl-Text-ParseWords
__install_pkg perl-Text-Soundex
__install_pkg perl-Text-Template
__install_pkg perl-Text-Unidecode
__install_pkg perl-Thread-Queue
__install_pkg perl-threads
__install_pkg perl-threads-shared
__install_pkg perltidy
__install_pkg perl-TimeDate
__install_pkg perl-Time-HiRes
__install_pkg perl-Time-Local
__install_pkg perl-Time-Piece
__install_pkg perl-Try-Tiny
__install_pkg perl-URI
__install_pkg perl-Variable-Magic
__install_pkg perl-version
__install_pkg perl-WWW-RobotRules
__install_pkg perl-XML-DOM
__install_pkg perl-XML-LibXML
__install_pkg perl-XML-NamespaceSupport
__install_pkg perl-XML-Parser
__install_pkg perl-XML-RegExp
__install_pkg perl-XML-SAX
__install_pkg perl-XML-SAX-Base
__install_pkg perl-XML-Stream
__install_pkg php
__install_pkg php-cli
__install_pkg php-common
__install_pkg php-composer-ca-bundle
__install_pkg php-composer-semver
__install_pkg php-composer-spdx-licenses
__install_pkg php-composer-xdebug-handler
__install_pkg php-devel
__install_pkg php-embedded
__install_pkg php-fedora-autoloader
__install_pkg php-fpm
__install_pkg php-gd
__install_pkg php-gmp
__install_pkg php-intl
__install_pkg php-json
__install_pkg php-jsonlint
__install_pkg php-justinrainbow-json-schema5
__install_pkg php-mbstring
__install_pkg php-mysqlnd
__install_pkg php-opcache
__install_pkg php-paragonie-random-compat
__install_pkg php-password-compat
__install_pkg php-pdo
__install_pkg php-pecl-geoip
__install_pkg php-pecl-zip
__install_pkg php-pgsql
__install_pkg php-process
__install_pkg php-PsrLog
__install_pkg php-seld-phar-utils
__install_pkg php-symfony-browser-kit
__install_pkg php-symfony-class-loader
__install_pkg php-symfony-common
__install_pkg php-symfony-config
__install_pkg php-symfony-console
__install_pkg php-symfony-css-selector
__install_pkg php-symfony-debug
__install_pkg php-symfony-dependency-injection
__install_pkg php-symfony-dom-crawler
__install_pkg php-symfony-event-dispatcher
__install_pkg php-symfony-expression-language
__install_pkg php-symfony-filesystem
__install_pkg php-symfony-finder
__install_pkg php-symfony-http-foundation
__install_pkg php-symfony-http-kernel
__install_pkg php-symfony-polyfill
__install_pkg php-symfony-process
__install_pkg php-symfony-var-dumper
__install_pkg php-symfony-yaml
__install_pkg php-xml
__install_pkg pinentry
__install_pkg pinfo
__install_pkg pixman
__install_pkg pixman-devel
__install_pkg pkgconfig
__install_pkg plexus-archiver
__install_pkg plexus-build-api
__install_pkg plexus-cipher
__install_pkg plexus-classworlds
__install_pkg plexus-cli
__install_pkg plexus-compiler
__install_pkg plexus-component-api
__install_pkg plexus-components-pom
__install_pkg plexus-containers-component-annotations
__install_pkg plexus-containers-component-metadata
__install_pkg plexus-containers-container-default
__install_pkg plexus-i18n
__install_pkg plexus-interactivity
__install_pkg plexus-interpolation
__install_pkg plexus-io
__install_pkg plexus-pom
__install_pkg plexus-resources
__install_pkg plexus-sec-dispatcher
__install_pkg plexus-tools-pom
__install_pkg plexus-utils
__install_pkg plexus-velocity
__install_pkg plymouth
__install_pkg plymouth-core-libs
__install_pkg plymouth-scripts
__install_pkg policycoreutils
__install_pkg policycoreutils-devel
__install_pkg policycoreutils-python
__install_pkg polkit
__install_pkg polkit-pkla-compat
__install_pkg ponysay
__install_pkg poppler-data
__install_pkg popt
__install_pkg popt-devel
__install_pkg postfix
__install_pkg postgresql
__install_pkg postgresql-devel
__install_pkg postgresql-libs
__install_pkg ppp
__install_pkg procps-ng
__install_pkg proftpd
__install_pkg psacct
__install_pkg psmisc
__install_pkg pth
__install_pkg pulseaudio-libs
__install_pkg pulseaudio-libs-devel
__install_pkg pulseaudio-libs-glib2
__install_pkg pycairo
__install_pkg pygobject2
__install_pkg pygpgme
__install_pkg pygtk2
__install_pkg pygtk2-libglade
__install_pkg pyliblzma
__install_pkg pyOpenSSL
__install_pkg pyparsing
__install_pkg pytalloc
__install_pkg python
__install_pkg python2-acme
__install_pkg python2-certbot
__install_pkg python2-certbot-apache
__install_pkg python2-certbot-dns-rfc2136
__install_pkg python2-configargparse
__install_pkg python2-cryptography
__install_pkg python2-dialog
__install_pkg python2-enum34
__install_pkg python2-funcsigs
__install_pkg python2-future
__install_pkg python2-idna
__install_pkg python2-josepy
__install_pkg python2-mock
__install_pkg python2-parsedatetime
__install_pkg python2-pbr
__install_pkg python2-pip
__install_pkg python2-psutil
__install_pkg python2-pyasn1
__install_pkg python2-pyrfc3339
__install_pkg python2-pysocks
__install_pkg python2-requests
__install_pkg python2-six
__install_pkg python2-speedtest-cli
__install_pkg python2-zope-interface
__install_pkg python34
__install_pkg python34-devel
__install_pkg python34-libs
__install_pkg python3-rpm-macros
__install_pkg python-augeas
__install_pkg python-backports
__install_pkg python-backports-ssl_match_hostname
__install_pkg python-cffi
__install_pkg python-chardet
__install_pkg python-configobj
__install_pkg python-dateutil
__install_pkg python-decorator
__install_pkg python-deltarpm
__install_pkg python-devel
__install_pkg python-dmidecode
__install_pkg python-dns
__install_pkg python-enum34
__install_pkg python-ethtool
__install_pkg python-firewall
__install_pkg python-gobject-base
__install_pkg python-idna
__install_pkg python-iniparse
__install_pkg python-inotify
__install_pkg python-ipaddress
__install_pkg python-IPy
__install_pkg python-javapackages
__install_pkg python-kitchen
__install_pkg python-libs
__install_pkg python-linux-procfs
__install_pkg python-lxml
__install_pkg python-ndg_httpsclient
__install_pkg python-perf
__install_pkg python-ply
__install_pkg python-pwquality
__install_pkg python-pycparser
__install_pkg python-pycurl
__install_pkg python-pyudev
__install_pkg python-requests
__install_pkg python-requests-toolbelt
__install_pkg python-rpm-macros
__install_pkg python-schedutils
__install_pkg python-setuptools
__install_pkg python-six
__install_pkg python-slip
__install_pkg python-slip-dbus
__install_pkg python-srpm-macros
__install_pkg python-sssdconfig
__install_pkg python-urlgrabber
__install_pkg python-urllib3
__install_pkg python-zope-component
__install_pkg python-zope-event
__install_pkg python-zope-interface
__install_pkg pytz
__install_pkg pyxattr
__install_pkg qdox
__install_pkg qrencode-libs
__install_pkg qt
__install_pkg qt3
__install_pkg qt-settings
__install_pkg qt-x11
__install_pkg quota
__install_pkg quota-nls
__install_pkg rarian
__install_pkg rarian-compat
__install_pkg rcs
__install_pkg rdma-core
__install_pkg readline
__install_pkg realmd
__install_pkg recode
__install_pkg redhat-lsb-core
__install_pkg redhat-lsb-cxx
__install_pkg redhat-lsb-desktop
__install_pkg redhat-lsb-languages
__install_pkg redhat-lsb-printing
__install_pkg redhat-lsb-submod-multimedia
__install_pkg redhat-lsb-submod-security
__install_pkg redhat-rpm-config
__install_pkg regexp
__install_pkg relaxngDatatype
__install_pkg rest
__install_pkg rhino
__install_pkg rootfiles
__install_pkg rpcbind
__install_pkg rpm
__install_pkg rpm-build
__install_pkg rpm-build-libs
__install_pkg rpm-devel
__install_pkg rpmdevtools
__install_pkg rpm-libs
__install_pkg rpmlint
__install_pkg rpm-plugin-systemd-inhibit
__install_pkg rpm-python
__install_pkg rpm-sign
__install_pkg rrdtool
__install_pkg rrdtool-perl
__install_pkg rsync
__install_pkg rsync-daemon
__install_pkg rsyslog
__install_pkg sac
__install_pkg samba
__install_pkg samba-client
__install_pkg samba-client-libs
__install_pkg samba-common
__install_pkg samba-common-libs
__install_pkg samba-common-tools
__install_pkg samba-dc-libs
__install_pkg samba-devel
__install_pkg samba-libs
__install_pkg samba-winbind
__install_pkg samba-winbind-clients
__install_pkg samba-winbind-modules
__install_pkg satyr
__install_pkg schroedinger
__install_pkg screen
__install_pkg SDL
__install_pkg sed
__install_pkg selinux-policy
__install_pkg selinux-policy-devel
__install_pkg selinux-policy-targeted
__install_pkg sendxmpp
__install_pkg setools-libs
__install_pkg setup
__install_pkg setuptool
__install_pkg sg3_utils
__install_pkg sg3_utils-libs
__install_pkg sgml-common
__install_pkg shared-mime-info
__install_pkg shorewall
__install_pkg shorewall6
__install_pkg shorewall-core
__install_pkg sisu-inject-bean
__install_pkg sisu-inject-plexus
__install_pkg slang
__install_pkg slf4j
__install_pkg smartmontools
__install_pkg snakeyaml
__install_pkg snappy
__install_pkg sonatype-oss-parent
__install_pkg sos
__install_pkg sound-theme-freedesktop
__install_pkg source-highlight
__install_pkg soxr
__install_pkg spax
__install_pkg speex
__install_pkg speex-devel
__install_pkg spice-parent
__install_pkg sqlite
__install_pkg sqlite-devel
__install_pkg sscg
__install_pkg stax2-api
__install_pkg stix-fonts
__install_pkg subversion
__install_pkg subversion-libs
__install_pkg subversion-perl
__install_pkg sudo
__install_pkg swig
__install_pkg symlinks
__install_pkg sysstat
__install_pkg system-config-users
__install_pkg system-config-users-docs
__install_pkg systemd
__install_pkg systemd-devel
__install_pkg systemd-libs
__install_pkg systemd-python
__install_pkg systemd-sysv
__install_pkg systemtap
__install_pkg systemtap-client
__install_pkg systemtap-devel
__install_pkg systemtap-runtime
__install_pkg systemtap-sdt-devel
__install_pkg sysvinit-tools
__install_pkg t1lib
__install_pkg tar
__install_pkg tcl
__install_pkg tcpdump
__install_pkg tcp_wrappers
__install_pkg tcp_wrappers-libs
__install_pkg teamd
__install_pkg telnet
__install_pkg terminus-fonts
__install_pkg testng
__install_pkg texinfo
__install_pkg time
__install_pkg tk
__install_pkg tmpwatch
__install_pkg tomcat
__install_pkg tomcat-admin-webapps
__install_pkg tomcat-el-2.2-api
__install_pkg tomcat-jsp-2.2-api
__install_pkg tomcat-lib
__install_pkg tomcat-servlet-3.0-api
__install_pkg tomcat-taglibs-parent
__install_pkg tomcat-webapps
__install_pkg traceroute
__install_pkg tree
__install_pkg trousers
__install_pkg ttmkfdir
__install_pkg tuned
__install_pkg tzdata
__install_pkg tzdata-java
__install_pkg udisks2
__install_pkg udisks2-iscsi
__install_pkg udisks2-lvm2
__install_pkg unbound-libs
__install_pkg unibilium
__install_pkg unixODBC
__install_pkg unixODBC-devel
__install_pkg uptimed
__install_pkg urw-fonts
__install_pkg usb_modeswitch
__install_pkg usb_modeswitch-data
__install_pkg usbutils
__install_pkg usermode
__install_pkg ustr
__install_pkg util-linux
__install_pkg uuid
__install_pkg uuid-devel
__install_pkg uwsgi
__install_pkg vconfig
__install_pkg velocity
__install_pkg vim-common
__install_pkg vim-enhanced
__install_pkg vim-filesystem
__install_pkg vim-minimal
__install_pkg virt-what
__install_pkg vo-amrwbenc
__install_pkg volume_key-libs
__install_pkg wayland-devel
__install_pkg wayland-protocols-devel
__install_pkg webalizer
__install_pkg web-assets-filesystem
__install_pkg webkitgtk4
__install_pkg webkitgtk4-jsc
__install_pkg webkitgtk4-plugin-process-gtk2
__install_pkg weld-parent
__install_pkg which
__install_pkg whois
__install_pkg wireless-tools
__install_pkg woodstox-core
__install_pkg words
__install_pkg wpa_supplicant
__install_pkg wsdl4j
__install_pkg ws-jaxme
__install_pkg x264-libs
__install_pkg x265-libs
__install_pkg xalan-j2
__install_pkg xbean
__install_pkg xdg-utils
__install_pkg xerces-j2
__install_pkg xfsprogs
__install_pkg xkeyboard-config
__install_pkg xml-common
__install_pkg xml-commons-apis
__install_pkg xml-commons-resolver
__install_pkg xmlgraphics-commons
__install_pkg xmlrpc-c
__install_pkg xmlrpc-c-client
__install_pkg xmlsec1
__install_pkg xmlsec1-openssl
__install_pkg xmlto
__install_pkg xmvn
__install_pkg xorg-x11-fonts-Type1
__install_pkg xorg-x11-font-utils
__install_pkg xorg-x11-proto-devel
__install_pkg xorg-x11-xauth
__install_pkg xpp3
__install_pkg xvidcore
__install_pkg xz
__install_pkg xz-devel
__install_pkg xz-java
__install_pkg xz-libs
__install_pkg yarn
__install_pkg yelp
__install_pkg yelp-libs
__install_pkg yelp-xsl
__install_pkg yum
__install_pkg yum-metadata-parser
__install_pkg yum-plugin-fastestmirror
__install_pkg yum-utils
__install_pkg zip
__install_pkg zlib-ng-compat
__install_pkg zlib-devel

##################################################################################################################
__printf_head "Fixing packages"
##################################################################################################################
__run_grub
rm -Rf /etc/named* /var/named/* /etc/ntp* /etc/cron*/0* /etc/cron*/dailyjobs /var/ftp/uploads /etc/httpd/conf.d/ssl.conf /tmp/configs

##################################################################################################################
__printf_head "setting up config files"
##################################################################################################################
__devnull git clone -q https://github.com/phpsysinfo/phpsysinfo /var/www/html/sysinfo
__devnull git clone -q https://github.com/casjay-base/rhel /tmp/configs
__devnull find /tmp/configs -type f -iname "*.sh" -exec chmod 755 {} \;
__devnull find /tmp/configs -type f -iname "*.pl" -exec chmod 755 {} \;
__devnull find /tmp/configs -type f -iname "*.cgi" -exec chmod 755 {} \;
__devnull find /tmp/configs -type f -exec sed -i "s#myserverdomainname#$(hostname -f)#g" {} \;
__devnull find /tmp/configs -type f -exec sed -i "s#myhostnameshort#$(hostname -s)#g" {} \;
__devnull find /tmp/configs -type f -exec sed -i "s#mydomainname#$(hostname -f | awk -F. '{$1="";OFS="." ; print $0}' | sed 's/^.//')#g" {} \;
#__devnull rm -Rf /tmp/configs/etc/{fail2ban,shorewall,shorewall6}
__devnull cp -Rf /tmp/configs/{etc,root,usr,var}* /
__devnull mkdir -p /etc/rsync.d /var/log/named &&
  __devnull chown -Rf named:named /etc/named* /var/named /var/log/named
__devnull chown -Rf apache:apache /var/www /usr/local/share/httpd
__devnull sed -i "s#myserverdomainname#$(echo $HOSTNAME)#g" /etc/sysconfig/network
__devnull sed -i "s#mydomain#$(echo $HOSTNAME | awk -F. '{$1="";OFS="." ; print $0}' | sed 's/^.//')#g" /etc/sysconfig/network
__devnull domainname $(hostname -f | awk -F. '{$1="";OFS="." ; print $0}' | sed 's/^.//') &&
  echo "kernel.domainname=$(domainname)" >>/etc/sysctl.conf
__devnull chmod 644 -Rf /etc/cron.d/* /etc/logrotate.d/*
__devnull touch /etc/postfix/mydomains.pcre
__devnull chattr +i /etc/resolv.conf
if __devnull postmap /etc/postfix/transport /etc/postfix/canonical /etc/postfix/virtual /etc/postfix/mydomains; then
  newaliases &>/dev/null || newaliases.postfix -I &>/dev/null
fi

##################################################################################################################
__printf_head "Disabling services"
##################################################################################################################
__system_service_disable firewalld
__system_service_disable chrony
__system_service_disable kdump
__system_service_disable iscsid.socket
__system_service_disable iscsi
__system_service_disable iscsiuio.socket
__system_service_disable lvm2-lvmetad.socket
__system_service_disable lvm2-lvmpolld.socket
__system_service_disable lvm2-monitor
__system_service_disable mdmonitor
__system_service_disable fail2ban
__system_service_disable shorewall
__system_service_disable shorewall6
__system_service_disable dhcpd
__system_service_disable dhcpd6
__system_service_disable radvd

##################################################################################################################
__printf_head "Enabling services"
##################################################################################################################
__system_service_enable sshd
__system_service_enable tor
__system_service_enable munin-node
__system_service_enable cockpit
__system_service_enable postfix
__system_service_enable uptimed
__system_service_enable php-fpm
__system_service_enable proftpd
__system_service_enable rsyslog
__system_service_enable ntpd
__system_service_enable snmpd
__system_service_enable cockpit.socket
__system_service_enable named

##################################################################################################################
__printf_head "Cleaning up"
##################################################################################################################
__system_service_enable httpd
__system_service_enable nginx
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
  __rm_repo_files
  __retrieve_repo_file
fi
chown -Rf apache:apache /var/www
history -c && history -w

##################################################################################################################
__printf_info "Installer version: $(__retrieve_version_file)"
##################################################################################################################
mkdir -p /etc/casjaysdev/updates/versions
echo "$VERSION" >/etc/casjaysdev/updates/versions/configs.txt
chmod -Rf 664 /etc/casjaysdev/updates/versions/configs.txt

##################################################################################################################
__printf_head "Finished "
echo ""
##################################################################################################################
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
set --
exit 0
# end
