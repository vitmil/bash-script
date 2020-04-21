#!/bin/bash
##
## Descr    : Script to gather some system information related to network configuration
## Author   : Vittorio Milazzo - vittorio.milazzo@gmail.com
## Ver      : 0.1 - 21/11/2017
## Ver      : 0.2 - 26/12/2019 - added associative array to check missing requisites commands
##
##
## Other ways to show you Ip address:
##
## link rif: https://unix.stackexchange.com/questions/22615/how-can-i-get-my-external-ip-address-in-a-shell-script
##
## dig +short myPubIp.opendns.com @resolver1.opendns.com
## curl -s http://whatismyPubIp.akamai.com/
## curl -s https://4.ifcfg.me/
## nc 4.ifcfg.me 23 | grep IPv4 | cut -d' ' -f4
##


## Global Vars
##
ExCode=
GW=

## Cmds full path
WGET=$(which wget | grep -v alias | sed 's/[[:space:]]//'g 2>/dev/null)
WHOIS=$(which whois | grep -v alias | sed 's/[[:space:]]//'g 2>/dev/null)
NSLOOKUP=$(which nslookup | grep -v alias | sed 's/[[:space:]]//'g 2>/dev/null)
IP=$(which ip | grep -v alias | sed 's/[[:space:]]//'g 2>/dev/null)

## Other Network info gathering
NicMain=$($IP r 2>/dev/null | grep default | awk '{ print $5 }' | uniq)
IpMain=$($IP addr show "${NicMain}" | grep -w "inet" | awk '{ print $2 }')


## Funcs
##
function checkDefRoute() {
  if [[ -n "$IP" ]] ; then
    GW=$(ip r 2>/dev/null | grep default | awk '{ print $3 }' | uniq)
  else
    echo -e "Warning: missing ip command. Please install iproute2 package"
    ExCode=101
    return $ExCode
  fi

  if [[ -z $GW ]] ; then
    echo -e "\nWarning: No default route found"
    ExCode=102
    return $ExCode
  fi
}

## check for required packages
function checkRequired () {
  local AuditPkg=true
  local required
  declare -A required=( [wget]="$WGET" [whois]="$WHOIS" [nslookup]="$NSLOOKUP" )

  for i in "${!required[@]}" ; do
    if [[ -z ${required[$i]} ]] ; then
      echo "Warning: $i not installed"
      local AuditPkg=false
    fi
  done

  if ! $AuditPkg ;
    then
      echo -e "\nMissing packages are required to run script\n"
      ExCode=103
      return $ExCode
    fi
}

## Show Info
function showInfo () {

  local NameServer="8.8.8.8"
  local myPubIp=$($WGET http://ipinfo.io/ip -qO -)
  local netName=$($WHOIS $myPubIp | grep "netname" | awk  '{ print $2 }')
  local nslookupRes=$($NSLOOKUP $myPubIp $NameServer | grep "name[[:space:]]=[[:space:]]" | awk '{ print $NF }')

  echo -e "\nHostname\t\t->\t$(hostname -f)"
  echo -e "Main Ip address\t\t->\t$IpMain"
  echo -e "Default gateway\t\t->\t$GW"
  echo -e "Main nic\t\t->\t$NicMain"
  echo -e "DNS Server[1]\t\t->\t$(grep "nameserver" /etc/resolv.conf | awk '{ print $2 }' | head -1)"
  echo -e "DNS Server[2]\t\t->\t$(grep "nameserver" /etc/resolv.conf | awk '{ print $2 }' | head -2 | tail -1)"

  echo -e "\nPublic Ip address\t->\t$myPubIp"
  echo -e "DNS resolution\t\t->\t$nslookupRes"
  echo -e "Netname\t\t\t->\t$netName\n"
}

## Main
##
echo
if ! checkDefRoute ; then
  exit $ExCode
fi

if ! checkRequired ; then
  exit $ExCode
fi

showInfo

exit 0
