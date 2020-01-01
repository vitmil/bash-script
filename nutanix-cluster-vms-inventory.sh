#!/bin/bash
##
## @Descr  :  Use REST API to gather VMs information on Nutanix cluster
##            CSV with inventory of the VMs will be create on : $HOME/NutanixClusterInventory/Nutanix-VMs-Inventory-$TODAY.csv
##
## @Author :  Vittorio Milazzo
##
## @Ver   :   0.1-beta1 - 27/12/2019
#
##
## Link all API ver explaination and examples
## https://www.nutanix.dev/2019/01/15/nutanix-api-versions-what-are-they-and-what-does-each-one-do/
##
##
#######################
## Official APIs doc: #
#######################
##
## API v2
## https://www.nutanix.dev/reference/prism_element/v2/
## URI : https://$ClusterIp:$TcpPort/api/nutanix/v2.0/vms/...
##
##
## API v3
## https://www.nutanix.dev/reference/prism_central/v3/
## URI : https://$PrismCentralIp:$TcpPort/api/nutanix/v3/vms/...
##
## Requisites packages:
##
## Jq : Command-line JSON processor
##
##
############
## <ToDo> ##
############
##
## In case of multiple results for each query (two disks, two Nic then two Subnets and two <Ip Type>,
## counts the index of the title array, and creates numbered element (IP Add[1], IP add[2], etc..) and adding numbered field to HeadTitle.
##
#########################
## Inventory creation  ##
#########################
##
## 1. The list of VMs is created using API v2 (because only need to get VmName and UUID). Then using array to process it.
##
## 2. All the details of the VMs (Clustername, IP address, mac address, time zone, DNS, NGT, etc.) are extracted by querying with API v3,
##   creating many unique json files for each VM including all the details inside.
##
## 3. Extract (jq) necessary info from each file by creating a final .csv file with the inventory.



###########
# Globals #
###########

## Auth Var
## Insert your cluster Ip address and user login here
ClusterLogin=""
ClusterPwd= # For security reasons don't insert password here! You will be asked to enter it when the script is run
PrismCentralIp="192.168.100.101" # v3 APIs
ClusterIp="192.168.100.100"
TcpPort="9440"

## Called commands
CURL=$(which curl | grep -v alias | sed 's/[[:space:]]//'g 2>/dev/null)
JQ=$(which jq | grep -v alias | sed 's/[[:space:]]//'g 2>/dev/null)
RM=$(which rm | grep -v alias | sed 's/[[:space:]]//'g)
DATE=$(which date  | grep -v alias | sed 's/[[:space:]]//'g)


## Set today (to append on inventory file)
TODAY=$($DATE -I)

## Directory where write results
DirName="$HOME/NutanixClusterInventory"

## Check if dir already exists, if not create it
DirResults="`if [[ ! -d $DirName ]] ;
                    then
                      mkdir $DirName
                      echo $DirName
                      else
                        echo $DirName
                    fi`"

## Place to save results from curl query
## Replaced by array (below)
#VMsList="$DirResults/vms-list.json"


##########
# Arrays #
##########

## array inizialization
## used inside function 'makeArrayVmIdName'
declare -a VMsList


#############
# Functions #
#############

function showLogo {
	echo "
╔═══════════════════════════╗
║ Nutanix Cluster Inventory ║
╚═══════════════════════════╝

Create csv file with inventory of VMs inside cluster
"
}


function checkRequired () {
  local AuditPkg=true
  local required
  declare -A required=( [jq]="$JQ" [curl]="$CURL" )

  for i in "${!required[@]}" ; do
    if [[ -z ${required[$i]} ]] ; then
      echo "Warning: $i not installed"
      local AuditPkg=false
    fi
  done

  if ! $AuditPkg ; then
    echo -e "\nMissing packages are required to run script\n"
    ExCode=200
    return $ExCode
  fi
}

function validateIp () {
  if [[ ! $ClusterIp =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] ; then
    echo -e "\nError: ClusterIp not valid: $ClusterIp\n"
    ExCode=113
    return $ExCode
  fi

  if [[ ! $PrismCentralIp =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] ; then
    echo -e "\nError: PrismCentralIp not valid: $PrismCentralIp\n"
    ExCode=114
    return $ExCode
  fi
}


function validateLogin () {
  if [[ -z $ClusterLogin ]] ; then
    echo -e "\nNutanix username not yet defined. Insert username with wich you want to connect to cluster"
    read ClusterLogin
    if [[ -z $ClusterLogin ]] ; then
      echo -e "\nError: Username can't be emtpy"
      ExCode=115
      return $ExCode
      exit
    fi
 fi

 echo -e "\nInsert Nutanix password for user $ClusterLogin"
 read -s ClusterPwd
 if [[ -z $ClusterPwd ]] ; then
   echo -e "\nError: Password can't be emtpy"
   ExCode=116
   return $ExCode
 fi
}


## <File write Version> (replaced from array usage)
########################################################################################################
## Get all VMs list with basic info (VM_name and UUID basically)                                      ##
## and generate file with results                                                                     ##
##                                                                                                    ##
## for specific Cluster (restricted to only one cluster because of <$ClusterIp>  query pointer)       ##
########################################################################################################
#function getListVms () {
#  echo > $VMsList # Clean file content
#  ## query con API v2
#  $CURL -X GET \
#  https://$ClusterIp:$TcpPort/api/nutanix/v2.0/vms \
#  -H 'Accept: application/json' \
#  -H 'Content-Type: application/json' \
#  --insecure \
#  --basic --user $ClusterLogin:$ClusterPwd \
#  | $JQ '.' >> $VMsList
#}


########################################################################################################
## Get all VMs list with basic info (VM_name and UUID basically)                                      ##
## for specific Cluster (restricted to only one cluster because of <$ClusterIp>  query pointer)      ##
##                                                                                                    ##
## <Array version>                                                                                    ##
########################################################################################################

function getListVms () {
  if ! curl --insecure --connect-timeout 5 https://$ClusterIp:$TcpPort > /dev/null 2>&1 ; then
    echo -e "\nWarning: Unable to established connection to Cluster Ip $ClusterIp\n"
    ExCode=111
    return $ExCode
  fi
  ## API v.2 query
  VMsList=( \
  "$($CURL -X GET \
  https://$ClusterIp:"$TcpPort"/api/nutanix/v2.0/vms \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  --insecure \
  --basic --user $ClusterLogin:$ClusterPwd \
  | $JQ '.')" )
}


function makeArrayVmIdName () {
  ## <Notes>
  ## Function depends from above function 'getListVms', because array "${VMsList[@]}" is created from this function.
  ## Each element will be : name of VM <"${VM_NAME[@]}"> - and - UUID <"${VM_UUID[@]}">
  ## The array <"${VM_UUID[@]}"> is used to pass UUID to next one query (curl API v3) in order to obtain details of each VM (ip address, mac address, gateway, vlan, etc...)
  ## The array <"${VM_NAME[@]}"> is used only to identify name of VM on output results.

  ## File write syntax : In case of usage of <function getListVms> file write version.
  #VM_UUID=( $(while read line; do echo $line | grep -w "uuid" | awk '{ print $2 }' | sed 's/"//g ; s/,//g' ; done < $VMsList) )
  #VM_NAME=( $(while read line; do echo $line | grep -w "name" | awk '{ print $2 }' | sed 's/"//g ; s/,//g' ; done < $FileVMsList) )

  ## Array usage (replace the use of file)
  VM_UUID=( $(printf '%s\n' "${VMsList[@]}" | grep -w "uuid" | awk '{ print $2 }' | sed 's/"//g ; s/,//g') )
  VM_NAME=( $(printf '%s\n' "${VMsList[@]}" | grep -w "name" | awk '{ print $2 }' | sed 's/"//g ; s/,//g') )
}



## Get all VM details (API v3) and for each VM it create a unique file with results
function splitVmDetails () {
  if ! curl --insecure --connect-timeout 5 https://$PrismCentralIp:$TcpPort > /dev/null 2>&1 ; then
    echo -e "\nWarning: Cluster Ip $ClusterIp unreachable"
    ExCode=112
    return $ExCode
  fi

  declare -i Count=0

  for uuids in "${VM_UUID[@]}"
  do
    $CURL -X GET \
    https://$PrismCentralIp:"$TcpPort"/api/nutanix/v3/vms/$uuids \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    --insecure \
    --basic --user $ClusterLogin:$ClusterPwd | $JQ '.' > $DirResults/"${VM_NAME[$Count]}"-details.json

    let Count++
  done
}

## Create final file .csv with results of all VMs
function createInventory () {
  declare -a AllJsonFiles=( $(ls $DirResults/*.json) )

  ## In case of use <function GetDetailsAllVms> (no longer used),
  ## to exclude file <all-vms-details.json>
  ## delete it  (<$AllVMsDetails>) from element's array
  ##
  # AllJsonFiles=("${AllJsonFiles[@]/$AllVMsDetails}")

  declare -i Count=0
  declare -i MaxCount=$(printf '%s\n' "${#AllJsonFiles[@]}")

  while [[ $Count -lt "$MaxCount" ]]
  do

    ## Queries (raw)
    ## For each .json file (contains unique VM details), valorize each of the following variables (one by one)
    ## and write results on unique .csv file (each for unique VM)

    local VmName=$($JQ '.status.name' "${AllJsonFiles[$Count]}")
    local State=$($JQ '.status.resources.power_state' "${AllJsonFiles[$Count]}")
    local VmUuid=$($JQ '.metadata.uuid' "${AllJsonFiles[$Count]}")
    local OsVer=$($JQ '.status.resources.guest_tools.nutanix_guest_tools.guest_os_version' "${AllJsonFiles[$Count]}")
    local CreationTime=$($JQ '.metadata.creation_time' "${AllJsonFiles[$Count]}")
    local Descr=$($JQ '.status.description' "${AllJsonFiles[$Count]}")
    local ClusterRef=$($JQ '.status.cluster_reference.name' "${AllJsonFiles[$Count]}")
    local HyperVisor=$($JQ '.status.resources.host_reference.name' "${AllJsonFiles[$Count]}")
    local Disk=$($JQ '.status.resources.disk_list[]?' "${AllJsonFiles[$Count]}" | grep -e "\"device_type\"*:[[:space:]]*\"DISK\"" -A 4 | grep "disk_size_mib" | awk '{ print $2 }')
    local Ip=$($JQ '.status.resources.nic_list[].ip_endpoint_list[]?.ip' "${AllJsonFiles[$Count]}")
    local SubnetName=$($JQ '.status.resources.nic_list[].subnet_reference.name' "${AllJsonFiles[$Count]}")
    local IpType=$($JQ '.status.resources.nic_list[].ip_endpoint_list[]?.ip_type' "${AllJsonFiles[$Count]}")
    local BitMask=$($JQ '.status.resources.nic_list[].ip_endpoint_list[]?.prefix_length' "${AllJsonFiles[$Count]}")
    local VlanMode=$($JQ '.status.resources.nic_list[].vlan_mode' "${AllJsonFiles[$Count]}")
    local Gateway=$($JQ '.status.resources.nic_list[].ip_endpoint_list[]?.gateway_address_list[]?' "${AllJsonFiles[$Count]}")
    local DnsSvr=$($JQ '.status.resources.nic_list[].dns_ip_addresses_list[]?' "${AllJsonFiles[$Count]}")
    local NgtState1=$($JQ '.status.resources.guest_tools.nutanix_guest_tools.ngt_state' "${AllJsonFiles[$Count]}")
    local NgtState2=$($JQ '.status.resources.guest_tools.nutanix_guest_tools.state' "${AllJsonFiles[$Count]}")
    local NgtVer=$($JQ '.status.resources.guest_tools.nutanix_guest_tools.version' "${AllJsonFiles[$Count]}")
    local NgtFeatures=$($JQ '.status.resources.guest_tools.nutanix_guest_tools.enabled_capability_list[]?' "${AllJsonFiles[$Count]}")
    local NgtIsoCd=$($JQ '.status.resources.guest_tools.nutanix_guest_tools.iso_mount_state' "${AllJsonFiles[$Count]}")
    local MemorySize=$($JQ '.status.resources.memory_size_mib' "${AllJsonFiles[$Count]}")
    local VcpuPerSocket=$($JQ '.status.resources.num_vcpus_per_socket' "${AllJsonFiles[$Count]}")



    ###################################################################################################
    ## < Cleaning Queries / >                                                                         #
    ##                                                                                                #
    ## What the alghoritm does :                                                                      #
    ##                                                                                                #
    ## Reults from above <$JQ queries on json files> are raw and contains:                            #
    ## results in vertical order                                                                      #
    ## strings are between ""                                                                         #
    ##                                                                                                #
    ## To adjust results in order to have approriate output to create a .csv file:                    #
    ##                                                                                                #
    ## - for values that contains more results, separates them using <;>                              #
    ## - add comma at the end of line (because of .csv format                                         #
    ## - add value  <no value,> to empty variables (query wich returns empty value),                  #
    ##  (because this causes misalignment on csv file fields)                                         #
    ## - put them horizontal (csv format)                                                             #
    ##                                                                                                #
    ###################################################################################################

## 1. Create Array wich include all Variables name (the same Vars created above and populated with $JQ raw queries)
## 2. For loop wich uses Pointer to $VarName elements (array) in order to clean raw results

declare -a VarName=\
( \
VmName \
State \
VmUuid \
OsVer \
CreationTime \
Descr \
ClusterRef \
HyperVisor \
Disk \
Ip \
SubnetName \
IpType \
BitMask \
VlanMode \
Gateway \
DnsSvr \
NgtState1 \
NgtState2 \
NgtVer \
NgtFeatures \
NgtIsoCd \
MemorySize \
VcpuPerSocket \
)

  declare -i MaxCountVar="${#VarName[@]}"

  for ((CountVar = 0 ; CountVar < MaxCountVar ; CountVar++))
  do
    local VarName[$CountVar]=$(echo "${!VarName[$CountVar]}" | sed 's/"//g' | sed '$!s/$/ ; /' | tr -d "\n" | sed -e '$a\' | sed '$s/$/,/')

    ## Debug
    # echo "${VarName[$CountVar]}"
    #
    #if [[ "${VarName[$CountVar]}" =~ ";" ]]
    #then
    #  echo "found: ${VarName[$CountVar]}"
    #  read
    #fi

    if [[ -z "${VarName[$CountVar]}" ]]
    then
      echo "no value," >> $DirResults/$Count.csv
    else
      echo "${VarName[$CountVar]}" >> $DirResults/$Count.csv
    fi
  done

  let Count++
done

## < /End Cleaning Queries >



## Create Single csv File (from previous multiple files)
##
  local InventoryFile="$DirResults/Nutanix-VMs-Inventory-$TODAY.csv"

  ## Remove previous version of $InventoryFile file (if exists)
  if [[ -e $InventoryFile ]] ; then $RM -f $InventoryFile ; fi

  ## Convert vertical output result (for each single csv file with VM results) to horizontal,
  ## and write results on unique final file <$InventoryFile>.
  for i in $(ls -1 $DirResults/*.csv)
  do
    cat "$i" | paste -s -d' ' >> $InventoryFile
  done

  ## List of fields for each column
  HeadTitle=$(echo "VM Name,State,VM uuid,OS Ver,Creation Time,VM Descr,Cluster,Hypervisor,Disk Mb,IP add,Subnet Name,Ip Type,Subnet Mask,Vlan Mode,Gateway,DNS Server,NGT installation,NGT state,NGT ver,NGT features,NGT iso cd,Memory,Vcpu per socket")

  ## Insert $HeadTitle in the beggining of file
  sed -i "1s/^/$HeadTitle\n/" $InventoryFile
}


## Start Script

showLogo

if ! checkRequired ; then
  exit $ExCode
fi

if ! validateLogin ; then
  exit $ExCode
fi

if ! validateIp ; then
  exit $ExCode
fi

## Run curl queries
if ! getListVms ; then
  exit $ExCode
fi

makeArrayVmIdName

## Not longer used (replaced with below function <splitVmDetails>
# GetDetailsAllVms

if ! splitVmDetails ; then
  exit $ExCode
fi

createInventory

exit 0
