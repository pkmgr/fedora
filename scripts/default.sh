#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version       : 202111041659-git
# @Author        : Jason Hempstead
# @Contact       : jason@casjaysdev.pro
# @License       : WTFPL
# @ReadME        : default.sh --help
# @Copyright     : Copyright: (c) 2021 Jason Hempstead, Casjays Developments
# @Created       : Thursday, Nov 04, 2021 16:59 EDT
# @File          : default.sh
# @Description   : default installer for Fedora
# @TODO          :
# @Other         :
# @Resource      :
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
APPNAME="$(basename "$0")"
VERSION="202111041659-git"
USER="${SUDO_USER:-${USER}}"
HOME="${USER_HOME:-${HOME}}"
SRC_DIR="${BASH_SOURCE%/*}"
SCRIPT_DESCRIBE="all installations"
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
system_service_enable() { systemctl status "$1" 2>&1 | grep -iq -- 'inactive' && __execute "systemctl enable $1" "Enabling service: $1" || return 1; }
system_service_disable() { systemctl status "$1" 2>&1 | grep -iq -- 'active' && __execute "systemctl disable --now $1" "Disabling service: $1" || return 1; }
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
system_service_enable vnstat
__install_pkg net-tools
__install_pkg wget
__install_pkg curl
__install_pkg git
__install_pkg nail
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
__install_pkg apr
__install_pkg apr-util
__install_pkg at
__install_pkg attr
__install_pkg authconfig
__install_pkg autogen-libopts
__install_pkg avahi
__install_pkg awffull
__install_pkg awstats
__install_pkg basesystem
__install_pkg bash
__install_pkg bash-completion
__install_pkg bc
__install_pkg bind
__install_pkg bind-libs
__install_pkg bind-libs-lite
__install_pkg bind-license
__install_pkg bind-utils
__install_pkg binutils
__install_pkg biosdevname
__install_pkg bison
__install_pkg bridge-utils
__install_pkg byobu
__install_pkg bzip2
__install_pkg bzip2-libs
__install_pkg ca-certificates
__install_pkg centos-indexhtml
__install_pkg centos-logos
__install_pkg centos-release
__install_pkg certbot
__install_pkg checkpolicy
__install_pkg chkconfig
__install_pkg chrony
__install_pkg cifs-utils
__install_pkg cockpit
__install_pkg cockpit-bridge
__install_pkg cockpit-system
__install_pkg cockpit-ws
__install_pkg composer
__install_pkg comps-extras
__install_pkg coolkey
__install_pkg coreutils
__install_pkg cowsay
__install_pkg cpio
__install_pkg cpp
__install_pkg cracklib
__install_pkg cracklib-dicts
__install_pkg createrepo
__install_pkg cronie
__install_pkg cronie-noanacron
__install_pkg crontabs
__install_pkg cryptsetup
__install_pkg cryptsetup-libs
__install_pkg cups-libs
__install_pkg curl
__install_pkg cyrus-sasl-gssapi
__install_pkg cyrus-sasl-lib
__install_pkg cyrus-sasl-plain
__install_pkg dbus
__install_pkg dbus-glib
__install_pkg dbus-libs
__install_pkg dbus-python
__install_pkg dejavu-fonts-common
__install_pkg dejavu-sans-mono-fonts
__install_pkg deltarpm
__install_pkg desktop-file-utils
__install_pkg dhclient
__install_pkg dhcp-common
__install_pkg dhcp-libs
__install_pkg dialog
__install_pkg diffutils
__install_pkg dmidecode
__install_pkg dnsmasq
__install_pkg dos2unix
__install_pkg dosfstools
__install_pkg downtimed
__install_pkg dracut
__install_pkg dracut-config-rescue
__install_pkg dracut-network
__install_pkg dwz
__install_pkg ed
__install_pkg elfutils
__install_pkg elfutils-default-yama-scope
__install_pkg elfutils-libelf
__install_pkg elfutils-libs
__install_pkg emacs-filesystem
__install_pkg ethtool
__install_pkg expat
__install_pkg file
__install_pkg file-libs
__install_pkg filesystem
__install_pkg findutils
__install_pkg fipscheck
__install_pkg fipscheck-lib
__install_pkg firewalld
__install_pkg firewalld-filesystem
__install_pkg fontconfig
__install_pkg fontpackages-filesystem
__install_pkg fortune-mod
__install_pkg fpaste
__install_pkg freetype
__install_pkg fuse
__install_pkg fuse-libs
__install_pkg fuse-sshfs
__install_pkg fxload
__install_pkg gawk
__install_pkg gc
__install_pkg gcc
__install_pkg gd
__install_pkg gdbm
__install_pkg gdbm-devel
__install_pkg gdisk
__install_pkg gdk-pixbuf2
__install_pkg gd-last
__install_pkg GeoIP
__install_pkg GeoIP-data
__install_pkg gettext
__install_pkg gettext-libs
__install_pkg git
__install_pkg glib2
__install_pkg glibc
__install_pkg glibc-common
__install_pkg glibc-devel
__install_pkg glibc-headers
__install_pkg glib-networking
__install_pkg gmp
__install_pkg gnupg2
__install_pkg gnupg2-smime
__install_pkg gnutls
__install_pkg gobject-introspection
__install_pkg golang
__install_pkg golang-bin
__install_pkg golang-src
__install_pkg gpgme
__install_pkg gpm-libs
__install_pkg grep
__install_pkg groff-base
__install_pkg grub2
__install_pkg grub2-common
__install_pkg grub2-pc
__install_pkg grub2-pc-modules
__install_pkg grub2-tools
__install_pkg grub2-tools-extra
__install_pkg grub2-tools-minimal
__install_pkg grubby
__install_pkg gssproxy
__install_pkg guile
__install_pkg gzip
__install_pkg hardlink
__install_pkg harfbuzz
__install_pkg hdparm
__install_pkg hostname
__install_pkg htop
__install_pkg httpd
__install_pkg hunspell
__install_pkg hunspell-en-US
__install_pkg hwdata
__install_pkg iftop
__install_pkg info
__install_pkg initscripts
__install_pkg iproute
__install_pkg iprutils
__install_pkg ipset
__install_pkg ipset-libs
__install_pkg iptables
__install_pkg iptstate
__install_pkg iputils
__install_pkg jasper-libs
__install_pkg jbigkit-libs
__install_pkg js-jquery
__install_pkg json-c
__install_pkg json-glib
__install_pkg jwhois
__install_pkg kexec-tools
__install_pkg keyutils
__install_pkg keyutils-libs
__install_pkg kpartx
__install_pkg krb5-libs
__install_pkg less
__install_pkg lm_sensors-libs
__install_pkg logrotate
__install_pkg lsof
__install_pkg lua
__install_pkg lvm2
__install_pkg lvm2-libs
__install_pkg lynx
__install_pkg lyx-fonts
__install_pkg lz4
__install_pkg lzo
__install_pkg m4
__install_pkg mailcap
__install_pkg mailx
__install_pkg make
__install_pkg man-db
__install_pkg man-pages
__install_pkg mesa-libEGL
__install_pkg mesa-libgbm
__install_pkg mesa-libGL
__install_pkg mesa-libglapi
__install_pkg mlocate
__install_pkg mozjs17
__install_pkg mrtg
__install_pkg mtr
__install_pkg munin
__install_pkg munin-common
__install_pkg munin-node
__install_pkg nano
__install_pkg ncurses
__install_pkg ncurses-base
__install_pkg ncurses-libs
__install_pkg neofetch
__install_pkg net-snmp
__install_pkg net-snmp-agent-libs
__install_pkg net-snmp-libs
__install_pkg net-snmp-utils
__install_pkg nettle
__install_pkg net-tools
__install_pkg newt
__install_pkg newt-python
__install_pkg nfs-utils
__install_pkg nginx
__install_pkg nmap-ncat
__install_pkg nodejs
__install_pkg nspr
__install_pkg nss
__install_pkg nss-pem
__install_pkg nss-softokn
__install_pkg nss-softokn-freebl
__install_pkg nss-sysinit
__install_pkg nss-tools
__install_pkg nss-util
__install_pkg oddjob
__install_pkg oddjob-mkhomedir
__install_pkg openssh
__install_pkg openssh-clients
__install_pkg openssh-server
__install_pkg openssl
__install_pkg openssl-libs
__install_pkg os-prober
__install_pkg p11-kit
__install_pkg p11-kit-trust
__install_pkg PackageKit
__install_pkg PackageKit-glib
__install_pkg PackageKit-yum
__install_pkg pam
__install_pkg pango
__install_pkg parted
__install_pkg passwd
__install_pkg pcre
__install_pkg pcre2
__install_pkg perl
__install_pkg perl-Algorithm-Diff
__install_pkg perl-Archive-Tar
__install_pkg perl-Archive-Zip
__install_pkg perl-Authen-SASL
__install_pkg perl-autodie
__install_pkg perl-B-Hooks-EndOfScope
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
__install_pkg perl-Geo-IP
__install_pkg perl-Getopt-Long
__install_pkg perl-Git
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
__install_pkg perl-IO-Zlib
__install_pkg perl-IPC-Cmd
__install_pkg perl-IPC-ShareLite
__install_pkg perl-IPC-System-Simple
__install_pkg perl-JSON-PP
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
__install_pkg perl-LWP-Protocol-https
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
__install_pkg perl-podlators
__install_pkg perl-Pod-Parser
__install_pkg perl-Pod-Perldoc
__install_pkg perl-Pod-Simple
__install_pkg perl-Pod-Usage
__install_pkg perl-Ref-Util
__install_pkg perl-Ref-Util-XS
__install_pkg perl-Role-Tiny
__install_pkg perl-Scalar-List-Utils
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
__install_pkg perl-Text-Template
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
__install_pkg php-fpm
__install_pkg php-gd
__install_pkg php-gmp
__install_pkg php-intl
__install_pkg php-mbstring
__install_pkg php-mysqlnd
__install_pkg php-pdo
__install_pkg php-pecl-geoip
__install_pkg php-pecl-zendopcache
__install_pkg php-pgsql
__install_pkg php-xml
__install_pkg pinentry
__install_pkg pinfo
__install_pkg pixman
__install_pkg pkgconfig
__install_pkg plymouth
__install_pkg plymouth-core-libs
__install_pkg plymouth-scripts
__install_pkg ponysay
__install_pkg popt
__install_pkg postfix
__install_pkg proftpd
__install_pkg psacct
__install_pkg pygobject2
__install_pkg pygpgme
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
__install_pkg python-augeas
__install_pkg python-backports
__install_pkg python-backports-ssl_match_hostname
__install_pkg python-cffi
__install_pkg python-chardet
__install_pkg python-configobj
__install_pkg python-dateutil
__install_pkg python-decorator
__install_pkg python-deltarpm
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
__install_pkg python-kitchen
__install_pkg python-libs
__install_pkg python-ndg_httpsclient
__install_pkg python-perf
__install_pkg python-ply
__install_pkg python-pycparser
__install_pkg python-pycurl
__install_pkg python-pyudev
__install_pkg python-requests
__install_pkg python-requests-toolbelt
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
__install_pkg qrencode-libs
__install_pkg quota
__install_pkg quota-nls
__install_pkg rdma-core
__install_pkg readline
__install_pkg realmd
__install_pkg recode
__install_pkg redhat-rpm-config
__install_pkg rootfiles
__install_pkg rpm
__install_pkg rpm-build-libs
__install_pkg rpm-libs
__install_pkg rpm-plugin-systemd-inhibit
__install_pkg rpm-python
__install_pkg rrdtool
__install_pkg rrdtool-perl
__install_pkg rsync
__install_pkg rsync-daemon
__install_pkg rsyslog
__install_pkg samba
__install_pkg satyr
__install_pkg screen
__install_pkg sed
__install_pkg sendxmpp
__install_pkg setools-libs
__install_pkg setup
__install_pkg setuptool
__install_pkg shadow-utils
__install_pkg shared-mime-info
__install_pkg slang
__install_pkg smartmontools
__install_pkg snappy
__install_pkg sos
__install_pkg sqlite
__install_pkg stix-fonts
__install_pkg sudo
__install_pkg symlinks
__install_pkg system-config-users
__install_pkg sysstat
__install_pkg systemd
__install_pkg systemd-libs
__install_pkg systemd-python
__install_pkg systemd-sysv
__install_pkg systemtap-sdt-devel
__install_pkg sysvinit-tools
__install_pkg t1lib
__install_pkg tar
__install_pkg tcpdump
__install_pkg tcp_wrappers
__install_pkg tcp_wrappers-libs
__install_pkg telnet
__install_pkg time
__install_pkg tmux
__install_pkg tmux-powerline
__install_pkg tmux-top
__install_pkg tor
__install_pkg traceroute
__install_pkg tree
__install_pkg trousers
__install_pkg tzdata
__install_pkg udisks2
__install_pkg udisks2-iscsi
__install_pkg udisks2-lvm2
__install_pkg unzip
__install_pkg uptimed
__install_pkg usb_modeswitch
__install_pkg usb_modeswitch-data
__install_pkg usbutils
__install_pkg usermode
__install_pkg util-linux
__install_pkg vconfig
__install_pkg vim
__install_pkg vim-common
__install_pkg vim-enhanced
__install_pkg vim-filesystem
__install_pkg vim-minimal
__install_pkg vim-powerline
__install_pkg vnstat
__install_pkg volume_key-libs
__install_pkg webalizer
__install_pkg wget
__install_pkg which
__install_pkg whois
__install_pkg wireless-tools
__install_pkg words
__install_pkg wpa_supplicant
__install_pkg xdg-utils
__install_pkg xfsprogs
__install_pkg xkeyboard-config
__install_pkg xmlrpc-c
__install_pkg xmlrpc-c-client
__install_pkg xorg-x11-xauth
__install_pkg xz
__install_pkg xz-libs
__install_pkg yarn
__install_pkg yum
__install_pkg yum-metadata-parser
__install_pkg yum-plugin-fastestmirror
__install_pkg yum-utils
__install_pkg zip
__install_pkg zlib

##################################################################################################################
__printf_head "Fixing packages"
##################################################################################################################
__run_grub
rm -Rf /etc/named* /var/named/* /etc/ntp* /etc/cron*/0* /etc/cron*/dailyjobs /var/ftp/uploads /etc/httpd/conf.d/ssl.conf /tmp/configs

##################################################################################################################
__printf_head "setting up config files"
##################################################################################################################
__devnull git clone -q https://github.com/phpsysinfo/phpsysinfo /var/www/html/sysinfo
__devnull git clone -q https://github.com/casjay-base/fedora /tmp/configs
__devnull find /tmp/configs -type f -iname "*.sh" -exec chmod 755 {} \;
__devnull find /tmp/configs -type f -iname "*.pl" -exec chmod 755 {} \;
__devnull find /tmp/configs -type f -iname "*.cgi" -exec chmod 755 {} \;
__devnull find /tmp/configs -type f -exec sed -i "s#myserverhostname#$(hostname -f)#g" {} \;
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
__printf_head "Enabling services"
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
__printf_head "Cleaning up"
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
