#!/bin/bash

# Author: Murray Brown <mbrown@splicemachine.com>

usage() {
  echo "Usage: $0 { -h host | -u url } [-b benchmark] [-s scale] [-S set] [-m mode] [-L logdir] [-l label] [-n name] [-i iterations] [-t timeout] [-D] [-V] [-H]"
}

help() {
  usage
  echo -e "\n\ta program to run a benchmark validation queryset against a Splice Machine database"
  echo -e "\t -h host\t\t the hostname of your database. One of host or url is required."
  echo -e "\t -u url\t\t a jdbc url for your database. One of host or url is required."
  echo -e "\t -b benchmark \t\t a benchmark to run. (default: TPCH) {valid: TPCH, TPCC}"
  echo -e "\t -s scale \t\t scale of (default: 1) {valid scales 1, 10, 100, 1000}"
  echo -e "\t -S set \t\t which query set to run (default: good) {valid: good, all, errors}"
  echo -e "\t -m mode \t\t mode for setup (default: bulk) {valid: bulk or linear}"
  echo -e "\t -L logdir \t\t a directory to base the logs (default: /logs)"
  echo -e "\t -l label \t\t a label to identify the output (default: scale and date)"
  echo -e "\t -n name \t\t a suffix to add to a schema name"
  echo -e "\t -i iterations \t\t how many iterations to run (default: 1)"
  echo -e "\t -t timeout \t\t how many seconds to allow each query to run (default: forever)"
  echo -e "\t -D debug mode \t\t prints debug messaging"
  echo -e "\t -V verbose mode \t prints helpful messaging"
  echo -e "\t -H help \t\t prints this help"
}

debug() {
  local msg="$*"

  if (( $DEBUG )); then
    echo "DEBUG: $msg" >&2
  fi
}

message() {
  local msg="$*"

  if (( $VERBOSE )); then
    echo "$msg"
  fi
}

# ensure a path ends in /
fixPath() {
  local path=$1

  local dirlen=${#path}
  local lastchar=${path:dirlen-1:1}
  [[ $lastchar != "/" ]] && path="${path}/";

  echo $path
}

now() {
  date +%Y%m%d-%H%M
}

START=$(now)

#Defaults
HOST=""
URL=""
BENCH="TPCH"
INTERACTIVE=0
SCALE=1
SET="good"
MODE="bulk"
LOGBASE=""
LABEL=""
SUFFIX=""
declare -i ITER=0
declare -i TIMEOUT=0
DEBUG=0
VERBOSE=0

# Option Parsing
OPTIND=1
while getopts ":h:u:b:s:S:m:L:l:n:i:t:DVH" opt; do
  case $opt in
    h) HOST=$OPTARG
       ;;
    u) URL=$OPTARG
       ;;
    b) BENCH=$OPTARG
       ;;
    s) SCALE=$OPTARG
       ;;
    S) SET=$OPTARG
       ;;
    m) MODE=$OPTARG
       ;;
    L) LOGBASE=$OPTARG
       ;;
    l) LABEL=$OPTARG
       ;;
    n) SUFFIX=$OPTARG
       ;;
    i) ITER=$OPTARG
       ;;
    t) TIMEOUT=$OPTARG
       ;;
    D) DEBUG=1
       ;;
    V) VERBOSE=1
       ;;
    H) help
       exit 0
       ;;
    \?) 
       echo "Error: Invalid option: -$OPTARG" 
       usage
       exit 1 
      ;;
    :) echo "Option -$OPTARG requires an argument." >&2
      usage
      exit 1
      ;;
  esac
done
shift $((OPTIND-1))

# concoct schema name from inputs
SCHEMA="${BENCH}${SCALE}${SUFFIX}"

# setup BASEDIR
BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
BASEDIR=$(fixPath $BASEDIR)
debug basedir ends in / $BASEDIR

# query directory
SQLDIR="${BASEDIR}${SCHEMA}-queries"
if [[ ! -d $SQLDIR ]]; then
  debug making orig sqldir $SQLDIR
  mkdir -p $SQLDIR
fi


# TOODO: implement actual benchmark

#============
# Argument Checking

# Either HOST or URL are required
HOSTORURL=""
if [[ "$HOST" == "" && "$URL" == "" ]]; then
  echo "Error: One of host or url must be supplied!"
  usage
  exit 1
elif [[ "$HOST" != "" ]]; then
  HOSTORURL="-h $HOST" 
else
  HOSTORURL="-U ${URL}" 
fi
debug host-or-url is ${HOSTORURL}

# TOODO: figure out if URL is 'well-formed'

# check valid benchmark
if [[ "$BENCH" != "TPCH" && "$BENCH" != "TPCC" ]]; then
   echo "Error: benchmark $BENCH is not supported!"
   usage
   exit 2
fi

# fix for TPCH query 11 needing scale factor constant
# TOODO: write a routine for this calculation if it is reusable
QRY11="0.0001000000" # defaults to tpch1g

# check for only valid scales
if [[ "$BENCH" == "TPCH" && "$SCALE" != "1" && "$SCALE" != "10" && "$SCALE" != "100" && "$SCALE" != "1000" ]]; then
   echo "Error: scale of $SCALE is not supported for $BENCH!"
   usage
   exit 2
elif [[ "$SCALE" == "1" ]]; then
  QRY11="0.0001000000"
elif [[ "$SCALE" == "10" ]]; then
  QRY11="0.0000100000"
elif [[ "$SCALE" == "100" ]]; then
  QRY11="0.0000010000"
elif [[ "$SCALE" == "1000" ]]; then
  QRY11="0.0000001000"
fi

# check SET (good, all, errors, ??)
if [[ "$SET" != "good" && "$SET" != "all" && "$SET" != "errors" ]]; then
   echo "Error: set argument $SET is not supported. Valid values: [ good, all, errors ]"
   usage
   exit 2
fi

# TODO: implement specific query selection using SET
TPCHMIN=1
TPCHMAX=22

# check MODE (bulk, linear)
if [[ "$MODE" != "bulk" && "$MODE" != "linear" ]]; then
   echo "Error: mode argument $MODE is not supported. Valid values: [ bulk, linear ]"
   usage
   exit 2
fi


# optionally start log directory at a base 
# e.g. /mnt/mesos/sandbox for docker
if [[ "$LOGBASE" != "" ]]; then
   LOGBASE=$(fixPath $LOGBASE)
   if [[ ! -d $LOGBASE ]]; then 
      echo "Error: specified logdir does not exist: $LOGBASE"
      exit 2
   fi
   LOGDIR="${LOGBASE}logs/$SCHEMA-queries-$START"
else
   LOGBASE=$BASEDIR
   LOGDIR="${LOGBASE}logs/$SCHEMA-queries-$START"
fi

if [[ ! -d $LOGDIR ]]; then
  debug making orig logdir $LOGDIR
  mkdir -p $LOGDIR
fi

#  check if label is blank else generate it
if [[ "$LABEL" == "" ]]; then
  LABEL="$BENCH-$SCALE benchmark run started $START"
  debug generated label $LABEL 
fi

# check that count is an integer
case $ITER in
  0|[1-9]|[1-9][0-9]|[1-9][0-9][0-9]|[1-9][0-9][0-9][0-9]|[1-9][0-9][0-9][0-9][0-9]) ;;
  *)
    echo "Error: iterations must be an integer: $ITER"
    usage
    exit 2
  ;;
esac

# check that TIMEOUT is an integer
case $TIMEOUT in
  0|[1-9]|[1-9][0-9]|[1-9][0-9][0-9]|[1-9][0-9][0-9][0-9]|[1-9][0-9][0-9][0-9][0-9]) ;;
  *)
    echo "Error: timeout must be an integer: $TIMEOUT"
    usage
    exit 2
  ;;
esac

#if [[ $TIMEOUT != 0 ]]; then
   ## TOODO: test non-zero timeout handling
   #echo "umm... i have not tested that yet"
   #exit 127
#fi

debug exiting arg checks

#============
# Subroutines

# TOODO: global or local file location handling?

# use sqlshell find job id
getJobIds() {
  local outfile="./getJobId.out"

  $SQLSHELL -q $HOSTORURL -o $outfile <<< "call syscs_util.SYSCS_GET_RUNNING_OPERATIONS();"

  grep "|SPLICE" $outfile  | grep -v "SYSCS_GET_RUNNING_OPERATIONS" | awk '{print $1}'
}

killJob() {
  local jobid=$1

  echo killing $jobid
  $SQLSHELL -q $HOSTORURL -o /dev/null <<< "call syscs_util.SYSCS_KILL_OPERATION('${jobid}');" 
}

# takes a single argument -- the name of the query file, prepends SQLDIR
runQuery() {
   local queryfile=${SQLDIR}/${1}
   local outfile=${LOGDIR}/${1//sql/out}

   if [[ $TIMEOUT -eq 0 ]]; then
      $SQLSHELL -q ${HOSTORURL} -f $queryfile -o $outfile 
      return $?
   else
      $SQLSHELL -q ${HOSTORURL} -f $queryfile -o $outfile &
      debug backgrounded shell

      # wait until job finishes or timeout whichever comes first
      qpid=$(jobs -p)
      local queryruntime=0
      while [ "${queryruntime}" -le "${TIMEOUT}" ]; do
         ps ${qpid} >/dev/null
         local jobstatus=$?
         if [[ ${jobstatus} -eq 0 ]]; then
            ((queryruntime++))
         else
            break
         fi
         sleep 1
      done
      ps ${qpid} >/dev/null
      jobrunning=$?
      if [[ ${jobrunning} -eq 0 ]]; then
         debug "decided to kill job at time $queryruntime"
         local jobs=$(getJobIds)
         debug "found job(s) $jobs"
         local id
         for id in $jobs; do
           killJob $id
         done
      fi
   fi
}

# only works on a 'one count' query outputfile
countResults() {
  local outfile=$1

  #if [[ ! -f $outfile ]]; then
  #  debug "Error: countResults: no such file $outfile"
  #  return 0
  #if

  local -i count
  count=$(grep -A1 "[-][-][-][-][-][-]" $outfile | tail -1)

  if [[ "$count" == "" ]]; then
     debug "Error: countResults: no matching result in $outfile"
     return 0
  else
     debug "Success: countResults: returning $count from $outfile"
     return $count
  fi

}

# check if a schema exists
checkSchema() {
   local schema=$1

   local query="checkSchema.sql"
   echo "select count(1) from sys.sysschemas s where s.schemaname='${schema}';" > $SQLDIR/$query
   runQuery $query
   countResults $LOGDIR/${query/sql/out}
   local -i count=$?

   debug "CheckSchema: found $count from $query"
   if [[ "$count" -ne "1" ]]; then
     debug Schema $schema: not present
     return 1
   else
     debug Schema $schema is present
     return 0
   fi
}

# count tables in a schema compare to expect
checkTableCount() {
   local schema=$1
   local -i expect=$2

   local query="checkTableCount.sql"
   echo "select count(1) from sys.systables c join sys.sysschemas s on c.schemaid = s.schemaid where s.schemaname='${schema}';" > $SQLDIR/$query
   runQuery $query
   countResults $LOGDIR/${query/sql/out}
   local -i count=$?

   debug "CheckTableCount: found $count from $query"
   if [[ "$count" -ne "$expect" ]]; then
     debug Schema $schema: incorrect table count $count
     return 1
   else
     debug Schema $schema has $expect tables
     return 0
   fi
}

# check index count
checkIndexCount() {
   local schema=$1
   local -i expect=$2

   local query="checkIndexes.sql"
   echo "select count(1) from sys.sysconglomerates c join sys.sysschemas s on c.schemaid = s.schemaid where s.schemaname='${schema}' and  c.isindex=true;" > $SQLDIR/$query
   runQuery $query
   countResults $LOGDIR/${query/sql/out}
   local -i count=$?

   debug "CheckIndexCount: found $count from $query"
   if [[ "$count" -ne "$expect" ]]; then
     debug Schema $schema: incorrect index count $count
     return 1
   else
     debug Schema $schema has $expect indexes
     return 0
   fi
} 

checkTPCHTablesCounts() {
   local scale=$1
   local outfile=$2

   # TODO: implement getting counts from outfile and comparing

   return 0

}


# validate that a TPCH schema has the right tables
validateTPCHSchema() {
   local schema=$1
   local scale=$2

   # check schema exists
   if ( ! checkSchema $schema ); then
      return 1
   fi

   # check that tables are present
   if ( ! checkTableCount $schema 8 ); then
      debug Schema $schema: missing 8 tables
      return 1
   else
     debug Schema $schema has 8 tables
   fi

   # check that indexes are present
   if ( ! checkIndexCount $schema 4 ); then
      debug Schema $schema: missing 4 indices
      return 1
   else
     debug Schema $schema has 4 indices
   fi

   # TODO: check that non-zero statistics are present
   # "select sum(stats) from sys.statistics where schemaname = '${schema}';"

   # check that all the tables in setup-06-count.out have the 'right' counts
   if ( ! checkTPCHTablesCounts $scale "setup-06-count.out"); then
      debug Schema $schema: counts mismatch
      return 1
   else
      debug Schema $schema: counts match
   fi

   return 0
}

# substitution function for templated queries
fillTemplate() {
  local file=$1
  local schema=$2
  local scale=$3

  local input="${BASEDIR}templates/$file"
  local output="$SQLDIR/$file"

  if [[ ! -f $input ]]; then
    debug "Error: there is no template $file"
    return 1
  fi
  debug copying input $input to output $output
  cat $input | sed \
   -e "s/##SCHEMA##/$schema/g" \
   -e "s/##SCALE##/$scale/g" \
   -e "s/##QRY11##/${QRY11}/g" \
   > $output

}

# create and load the TPCH database for this scale
createTPCHdatabase() {
   local schema=$1
   local scale=$2
   local mode=$3

   local -i errCount
   debug "Creating TPCH at $schema for scale $scale using mode $mode"

   # create the actual database
   message "$schema: Creating tables"
   fillTemplate "setup-01-tables.sql" $schema $scale
   runQuery "setup-01-tables.sql"
   errCount=$(checkQueryError "${LOGDIR}/setup-01-tables.out")
   if [[ $errCount -gt 0 ]]; then
      message "Error: errors seen during table create: $errCount"
   elif ( ! checkTableCount $schema 8 ); then
      message "Error making 8 tables on $schema"
   fi

   if [[ "$mode" == "linear" ]]; then
      fillTemplate "setup-02-linear-import.sql" $schema $scale
      fillTemplate "setup-03-linear-indexes.sql" $schema $scale

      message "$SCHEMA: Loading data"
      runQuery "setup-02-linear-import.sql"
      errCount=$(checkQueryError "${LOGDIR}/setup-02-import.out")
      if [[ $errCount -gt 0 ]]; then
        echo "Error: failure during s3 data load. Is your cluster configured to read from s3?"
        exit 4
      fi

      message "$SCHEMA: Creating indexes"
      runQuery "setup-03-linear-indexes.sql"

      if ( ! checkIndexCount $SCHEMA 4 ); then
         echo "Error: $SCHEMA is missing 4 indices"
         exit 4
      fi

   else # i.e. mode=bulk

      message "$SCHEMA: Pre-creating indexes"
      fillTemplate "setup-02-bulk-splitindex.sql" $schema $scale
      runQuery "setup-02-bulk-splitindex.sql"
      # TOODO: complete pre-split-points for indexes
      errCount=$(checkQueryError "${LOGDIR}/setup-02-bulk-splitindex.out")

      if ( ! checkIndexCount $SCHEMA 4 ); then
         echo "Error: $SCHEMA is missing 4 indices"
         exit 3
      fi

      # hfile bulk load from s3 for faster load
      message "$SCHEMA: Bulk loading data"
      fillTemplate "setup-03-bulk-import.sql" $schema $scale
      runQuery "setup-03-bulk-import.sql"
      errCount=$(checkQueryError "${LOGDIR}/setup-03-bulk-import.out")
      if [[ $errCount -gt 0 ]]; then
        echo "Error: failure during s3 data bulkload. Is your cluster configured to read from s3?"
        exit 4
      fi
   fi

   message "$SCHEMA: Running compaction"
   fillTemplate "setup-04-compact.sql" $schema $scale
   runQuery "setup-04-compact.sql"
   errCount=$(checkQueryError "${LOGDIR}/setup-04-compact.out")
   if [[ $errCount -gt 0 ]]; then
     echo "Error: compaction returned an error?"
     exit 5
   fi

   message "$SCHEMA: Gather stats"
   fillTemplate "setup-05-stats.sql" $schema $scale
   runQuery "setup-05-stats.sql"
   errCount=$(checkQueryError "${LOGDIR}/setup-05-stats.out")
   if [[ $errCount -gt 0 ]]; then
     echo "Error: gathering statistics returned an error?"
     exit 5
   fi
   # TODO: check stats *really* ran


   message "$SCHEMA: Counting tables"
   fillTemplate "setup-06-count.sql" $schema $scale
   runQuery "setup-06-count.sql"
   errCount=$(checkQueryError "${LOGDIR}/setup-06-count.out")
   if [[ $errCount -gt 0 ]]; then
      echo "Error: failure during data load"
      exit 4
   fi

   if ( ! checkTPCHTablesCounts $scale "setup-06-count.out"); then
      debug "counts mismatched on $SCHEMA"
   else
      debug "counts are correct on $SCHEMA at scale $scale"
   fi
}

# check counts
# TOOD: write a routine to check that TPCH was loaded with correct data

# generate query files for this schema
genTPCHqueries() {
  local schema=$1
  local i

  for i in `seq -w $TPCHMIN $TPCHMAX`; do
    #debug adding $schema for ${i}
    fillTemplate "query-${i}.sql" $schema $scale
  done
}

runTPCHQueries() {
  local schema=$1
  local i

  for i in `seq -w $TPCHMIN $TPCHMAX`; do
    if [ "${i}" = "20" ]; then
       message "skipping TPCH query 20"
       continue
    fi
    message "Running TPCH query ${i} at scale $SCALE"
    runQuery "query-${i}.sql"
    # temporary hack
    #echo "no data" > ${LOGDIR}/query-${i}.out
  done
}

# check a query output for error
checkQueryError() {
  local outfile=$1
  local -i errCount=$(grep ERROR $outfile 2>/dev/null | wc -l )

  #debug checkQueryError: error count is $errCount
  echo $errCount
}

# check a query output for execution time
checkQueryTime() {
  local outfile=$1
  local execTime=$(grep "ELAPSED TIME" $outfile 2>/dev/null | awk '{print $4,$5}' )

  #debug checkQueryTime: exec time is $execTime
  echo $execTime
}

checkTPCHresults() {
  local schema=$1
  local iter=$2

  local -a results

  local i 
  local j=0
  for i in `seq -w $TPCHMIN $TPCHMAX`; do
    let j++
    local -i errCount=$(checkQueryError "${LOGDIR}/query-${i}.out")
    #debug checkOneTPCH errCount $errCount
    if [[ $errCount -eq 0 ]]; then
      local time=$(checkQueryTime "${LOGDIR}/query-${i}.out")
      if [[ "$time" != "" ]]; then
        message "$SCHEMA query-${i}.sql took $time"
        results[$j]=$(echo $time|awk '{print $1}')
      else
        message "$SCHEMA query-${i}.sql no errors and no time"
        results[$j]="Nan"
      fi
    else
      message "$SCHEMA query-${i}.sql had $errCount errors"
      results[$j]="Err"
    fi
  done

  # loop over the variable set of results
  echo -n "$SCHEMA results"
  if [[ "$iter" != "0" ]]; then
     echo -n " for run $iter"
  fi
  echo -n ": "
  local -i k=1
  while [ $k -le $j ]; do
    if (( $k == $j )); then
      echo ${results[$k]}
    else 
      echo -ne "${results[$k]}, "
    fi
    let k++
  done

}

# TODO: iterate over many results
# checkTPCHOutputs() {
# compute min/max/avg/stddev
# TODO: consider global results 2-dimensional array?
# RESULTS[$i][0] = name
# RESULTS[$i][1] = count
# RESULTS[$i][2] = sum
# RESULTS[$i][3] = sumsq
# }

# TODO: output result as many-row csv file
# test_run.csv
#Time	Query	Iteration	Status	Error code	Error msg	Elapsed

# TOODO: consider pushing to s3
# s3:splice-performance/ {run,test_run,test_cluster}
# possibly put in a new place to start

# TOODO: consider getting a unique id for build run from groovy script in jenkins

#============
# Sanity Tests

if [[ ! -d ${BASEDIR}templates ]]; then
  echo "Error: ${BASEDIR}templates must be present"
  exit 2
fi

# Test for sqlshell
SQLSHELL="/sqlshell/sqlshell.sh"
if [[ ! -f $SQLSHELL ]]; then
   echo "Error: could not find sqlshell <$SQLSHELL>"
   exit 2
fi

# Test that we can connect to a db
testQry="testQry.sql"
testOut="testOut.txt"
echo -e "elapsedtime on;\nselect count(1) from sys.systables;" > $SQLDIR/$testQry
$SQLSHELL -q ${HOSTORURL} -f $SQLDIR/$testQry -o ${LOGDIR}/$testOut
if [[ "$?" != "0" ]]; then
  echo "Error: sqlshell test failed for $SQLSHELL at $JDBC_URL" 
  exit 3
elif (( $VERBOSE )); then
  echo "Test query results follow"
  cat ${LOGDIR}/$testOut
  echo
fi

debug check that runQuery succeeds
runQuery $testQry
testOut="$LOGDIR/${testQry//sql/out}"
if [[ ! -f $testOut ]]; then
   echo "Error: runQuery did not produce output!"
   exit 3
fi

# check for Errors on testQry
testErr=$(checkQueryError $testOut)
if [[ $testErr -ne  0 ]]; then
   echo "Error: runQuery had errors on testQry"
  if (( $VERBOSE )); then
    cat $testOut
    echo
  fi
  exit 3
fi

#============
# Main

debug $0 entering Main for $BENCH with scale $SCALE schema $SCHEMA iterations $ITER


if [[ "$BENCH" == "TPCH" ]]; then

  # check for SCHEMA; if not present, make it
  if ( ! validateTPCHSchema $SCHEMA ) then
    createTPCHdatabase $SCHEMA $SCALE $MODE
  fi
 
  # bomb out if schema still not present
  if ( ! validateTPCHSchema $SCHEMA ) then
    message "Error: the schema $SCHEMA has failed validation"
    exit 1
  fi
 
  # generate TPCH query files for this SCHEMA
  genTPCHqueries $SCHEMA

  # TOODO: explain queries
  # TOODO: implement TPCH validation checks

  # now start running
  if [[ $ITER -le 1 ]]; then
    echo "Handle single run"
    runTPCHQueries $SCHEMA

    # output single results
    checkTPCHresults $SCHEMA 0

  else # many iterations

    declare -i i=1
    while [ $i -le $ITER ]; do
      loopStart=$(now)

      LOGDIR="${LOGBASE}logs/$SCHEMA-queries-$START-iter$i"
      mkdir -p $LOGDIR

      debug running $SCHEMA iter$i at $loopStart
      runTPCHQueries $SCHEMA
      checkTPCHresults $SCHEMA $i

      let i++
    done
    
    # TODO: behavior: if iterations > 1, provide avg/min/max/stddev
  fi

  # possibly send email?
  # possibly write to a table?

  # TODO: document docker.for.mac.localhost

elif [[ "$BENCH" == "TPCC" ]]; then

  # TOODO: handle benchmark other than TPCH
  echo "Sorry, TPCC is not yet implemented"

fi
