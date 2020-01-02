#!/bin/bash
##
## Author: Vittorio Milazzo - vittorio.milazzo@gmail.com
##
## Descr:
## script creates backup on tar archive for files and directories inside path "$SrcData", only for data which was last modified n* X days ago.
## (value of days is declared on variable "$NumbDays" inside function 'startBackup').
##
## Then, if $REMOVE variable is setted to 'true', and if tar archives was created successfully, data from "$SrcData" are removed.
##
## Outcome of backup will be written on /var/log/backup-$SrcData.log with details, including md5 signatures for each tar archive created.
##
##
## Exit Codes:
##
## 0   : Archive created successfully or no files older than $NumbDays days
## 101 : Destination path (where to backup data) not foundm and unable to create it
## 102 : Backup error during archive creation
## 111 : You don't have read permission on $SrcData"
## 112 : You don't have write permission on $DstBkp
##
## To test quickly the script, you can set variable value "NumbDays=-1" and then
## create content (directories and files), using the following commands:
##
## SrcData="/CorporateData"
##
## mkdir -p $SrcData/data{1..5}
##
## Count=1
## MaxCount=5
##
## while [[ $Count < $MaxCount ]] ; do
##   echo "I'm data$Count.txt" > $SrcData/data$Count/data$count.txt
##   let Count++
## done
##
## echo "file1.txt" >  $SrcData/file1.txt
##


#############
## Globals ##
#############
##
## Customizable Variables
##
## value 'true' if you want delete source data after backup
## value 'false' if you want to leave source data after backup
REMOVE=false

## Insert path of directory to backup
##
SrcData="/CorporateData"

## Insert path of destination where tar archives backup will be create
##
DstBkp="/DestBkp"
##
## / End of customizable variables

## Log file
##
LogFname="$(sed 's/\//-/g' <<<$SrcData)"
LogFile="/var/log/backup$LogFname.log"
DATE=$(which date  | grep -v alias | sed 's/[[:space:]]//'g)
Today=$($DATE -I)
Timestamp=$($DATE +"%T")
LOG="tee -a $LogFile"

## Other called commands
##
TAR=$(which tar | grep -v alias | sed 's/[[:space:]]//'g)
CP=$(which cp | grep -v alias | sed 's/[[:space:]]//'g)
RM=$(which rm  | grep -v alias | sed 's/[[:space:]]//'g)

## It will be populated inside function startBackup
SRC=


############
## Arrays ##
############
##
## Content (files and dir.) of $SrcData
##
declare -a Content=( $(ls $SrcData) )

## Distinguished name to assign to tar archive
##
declare -a TarArchives=( "${Content[@]}" )


###############
## Functions ##
###############
##
function msg()
{
  echo -e "$1"
}


function checkDstBkp ()
{
## Check if Destination Dir exists
if [[ ! -d "$DstBkp" ]] ; then
  if mkdir -p "$DstBkp" ; then
    msg "Ok: Directory  $DstBkp created successfully" | $LOG
  else
    msg "Error: Unable to create directory $DstBkp" | $LOG
    ExCode=101
    return $ExCode
  fi
fi
}


function startBackup ()
{
  if ! $REMOVE ; then
   Today=$Today-$Timestamp
  fi

  local NumbDays=-1
  declare -i MaxCount="${#Content[@]}"

  for ((Count = 0 ; Count < MaxCount ; Count++))
  do
    SRC="$SrcData/${Content[$Count]}"
    DST="$DstBkp/${TarArchives[$Count]}-$Today.tar"

    ## Check if Source path is directory and if it's empty
    if [[ -d "${SRC}" ]] ; then
      if [[ $(find "${SRC}" | wc -l) -le 1 ]] ; then
        msg "\nSource path "${SRC}" is empty\n" | $LOG
        continue
      fi
    fi

    ## Check if there are files older than $NumbDays
    ##
    if [[ $(find "${SRC}" -type f -mtime +"$NumbDays" | wc -l) -eq 0 ]]
    then
      msg "\n${SRC} : No files older than $NumbDays days" | $LOG
      continue
    else

      ## $NumbDays meets the requirements, so start backup
      msg "\n## $(expr $Count + 1). Archiving ${SRC} to "${DST}" in progress..." | $LOG
      find "${SRC}" -type f -mtime +"$NumbDays" -exec "$TAR" -rvf "${DST}" {} \;

      if [[ $? -eq 0 ]]
      then
        msg "Archive ${DST} created successfully" | $LOG
        Signature=$(md5sum ${DST} | awk '{ print $1 }')
        msg "MD5 signature : $Signature" | $LOG

        ## Source data is removed only if $REMOVE=true
        if $REMOVE ; then
          find "${SRC}" -type f -mtime +"$NumbDays" -exec "$RM" {} \;
        fi
      else
        msg "Warning: Backup error during archive creation from ${SRC} to ${DST}. Source data ${SRC} will be not removed" | $LOG
        ExCode=102
        return $ExCode
      fi
    fi
  done
}


function checkPerms () {
  if [[ ! -r "$SrcData" ]] ; then
    msg "\nError: You don't have read permission on $SrcData\n"
    ExCode=111
    return $ExCode
  fi

  if [[ ! -w "$DstBkp" ]] ; then
    msg "\nError: You don't have write permission on $DstBkp\n"
    ExCode=112
    return $ExCode
  fi
}


function startScript ()
{
  if ! checkPerms ; then
    exit $ExCode
  fi

  if [[ $(find "$SrcData" | wc -l) -le 1 ]] ; then
    msg "\nSource path $SrcData is empty. Nothing to backup!\n" | $LOG
    exit 0
  fi

  msg "\n\n#### $Today-$Timestamp" | $LOG
  if ! checkDstBkp ; then
    exit $ExCode
  else
    startBackup
  fi
}


##################
## Start Script ##
##################

startScript

exit 0
