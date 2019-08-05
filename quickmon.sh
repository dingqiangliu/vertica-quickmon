#!/bin/bash

showUsage ()
{
cat <<-EOF >&2
Usage: $(basename ${0}) [options]
Options:
    -n interval
       Specify update interval seconds, only positive integer accepted.
    -h show this usage info.

Prerequisites: 
1. Please set VSQL environment parameter before run this tool, eg. export VSQL='/opt/vertica/bin/vsql [-h verticaHost] [-u username] [-w password] [databaseName]'
2. Install util "column", eg. "yum install util-linux" on CentOS/RHEL
EOF
}

#options and parameters
interval=3

while getopts ":hn:" opt; do
  case $opt in
    n)
      interval="$OPTARG"
      ;;
    h | ?)
      showUsage
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      showUsage
      exit 1
      ;;
  esac
done
shift $(($OPTIND -1))

test "${interval}" -gt 0 2>/dev/null
if [ "$?" -ne 0 ] ; then
  echo $'ERROR: parameter [-n interval] should be positive integer!\n' >&2
  showUsage
  exit 1
fi

if [ -z "$(which column 2>/dev/null)" -o -z "${VSQL}" ] ; then
  showUsage
  exit 1
fi

VSQL="$(sed '
    s/ *-e */ /g
    s/ *-a */ /g
    s/ *-E */ /g
    s/ *-o *.*/ /g
    s/ *-s */ /g
    s/ *-S */ /g
    s/ *-H */ /g
    s/ *-T *.*/ /g
    s/ *-x */ /g
    s/ *-Q */ /g
    s/ *-F *.*/ /g
    s/ *-R *.*/ /g
    s/ *-i */ /g
  ' <<< "${VSQL}")"

if ! grep "Vertica Analytic Database" >/dev/null <<< "$($VSQL -c "select version()")" ; then
  echo "ERROR: $0 only works for Vertica! Please correct your VSQL environment parameter before run it."$'\n' >&2
  showUsage
  exit 1
fi

curDir=$(pwd)
scriptDir=$(cd "$(dirname $0)"; pwd)

SAMPLER="$(which sampler 2>/dev/null)"
if [ -z "${SAMPLER}" ] ; then
  if [ "$(uname)" == "Darwin" ] ; then
    SAMPLER="${scriptDir}/sampler-*-darwin-amd64"
  elif [ "$(uname)" == "Linux" ] ; then
    SAMPLER="${scriptDir}/sampler-*-linux-amd64"
  else
    echo "Unkown operation system!" >&2
    exit 1
  fi
fi

(cd ${scriptDir}; ${SAMPLER} --disable-telemetry -c <(sed "s/rate-ms:.*/rate-ms: ${interval}000/g" quickmon.yml) )
if [ "$(uname)" == "Linux" ] ; then
  reset
  echo
fi

