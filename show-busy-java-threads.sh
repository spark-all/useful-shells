#!/bin/bash
# @Function
# Find out the highest cpu consumed threads of java, and print the stack of these threads.
#
# @Usage
#   $ ./show-busy-java-threads.sh
#
# @author Jerry Lee

PROG=`basename $0`

usage() {
    cat <<EOF
Usage: ${PROG} [OPTION]...
Find out the highest cpu consumed threads of java, and print the stack of these threads.
Example: ${PROG} -c 10

Options:
    -p, --pid       find out the highest cpu consumed threads from the specifed java process,
                    default from all java process.
    -c, --count     set the thread count to show, default is 5
    -h, --help      display this help and exit
EOF
    exit $1
}

ARGS=`getopt -a -o c:p:h -l count:,pid:,help -- "$@"`
[ $? -ne 0 ] && usage 1
eval set -- "${ARGS}"

while true; do
    case "$1" in
    -c|--count)
        count="$2"
        shift 2
        ;;
    -p|--pid)
        pid="$2"
        shift 2
        ;;
    -h|--help)
        usage
        ;;
    --)
        shift
        break
        ;;
    esac
done
count=${count:-5}

redEcho() {
    if [ -c /dev/stdout ] ; then
        # if stdout is console, turn on color output.
        echo -ne "\033[1;31m"
        echo -n "$@"
        echo -e "\033[0m"
    else
        echo "$@"
    fi
}

## Check the existence of jstack command!
if ! which jstack &> /dev/null; then
    if [ -n "$JAVA_HOME" ] && [ -x "$JAVA_HOME/bin/jstack" ]; then
        export PATH=$PATH:$JAVA_HOME/bin
    else
        redEcho "Error: jstack not found on PATH and JAVA_HOME!"
        exit 1
    fi
fi

uuid=`date +%s`_${RANDOM}_$$

cleanupWhenExit() {
    rm /tmp/${uuid}_* > /dev/null
}
trap "cleanupWhenExit" EXIT

printStackOfThreads() {
    while read threadLine ; do
        pid=`echo ${threadLine} | awk '{print $1}'`
        threadId=`echo ${threadLine} | awk '{print $2}'`
        threadId0x=`printf %x ${threadId}`
        user=`echo ${threadLine} | awk '{print $3}'`
        pcpu=`echo ${threadLine} | awk '{print $5}'`
        
        jstackFile=/tmp/${uuid}_${pid}
        
        [ ! -f "${jstackFile}" ] && {
            jstack ${pid} > ${jstackFile} || {
                redEcho "Fail to jstack java process ${pid}"
                rm ${jstackFile}
                continue
            }
        }
        
        redEcho "The stack of busy(${pcpu}%) thread(${threadId}/0x${threadId0x}) of java process(${pid}) of user(${user}):"
        sed "/nid=0x${threadId0x}/,/^$/p" -n ${jstackFile}
    done
}

if [ -z ${pid} ] ; then 
    ps -Leo pid,lwp,user,comm,pcpu --no-headers | awk '$4=="java"{print $0}' |
    sort -k5 -r -n | head --lines "${count}" | printStackOfThreads
else
    ps -Leo pid,lwp,user,comm,pcpu --no-headers | awk -v "pid=${pid}" '$1==pid,$4=="java"{print $0}' |
    sort -k5 -r -n | head --lines "${count}" | printStackOfThreads
fi
