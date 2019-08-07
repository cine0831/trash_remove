#!/bin/bash
# -*-Shell-script-*-
#
#/**
# * Title    : remove tool for /home/_trash
# * Auther   : Alex, Lee
# * Created  : 2018-12-19 
# * Modified : 2019-05-13
# * E-mail   : cine0831@gmail.com
#**/
#
#set -e
#set -x

pid=$$
_trash_home="/usr/mgmt/trash_remove"
_trash_conf="${_trash_home}/trash_remove.conf"
_trash_log="${_trash_home}/logs"
pidfile="${_trash_log}/trash_remove.pid"
_date=$(date +%Y%m%d)
_config="_root:root.root:700
_nobody:root.nobody:770"

if [ -f "$_trash_conf" ]; then
    . $_trash_conf
else
    day=7
fi

# define directory
_workdir="/home/_trash"
_workperm="700"
_rmdir="/home/___rmdir"


function _pid_check() {
    local pidfile=${1}
    local retval=1

    if [ -f "${pidfile}" ]; then
        local pid=`cat ${pidfile} 2>/dev/null`

        if [ "x${pid}" != x -a "x${pid}" = "x${pid}" ]; then
            if [ "${pid}" -eq "${pid}" 2>/dev/null ]; then
                if [ -d "/proc/${pid}" ]; then
                    retval=0
                fi
            fi
        fi
    fi

    echo "pidcheck : ${retval}"

    return ${retval}
}

function _pid_diff() {
    local pid=${1}
    local oldtime=`date '+%s' -d "$(ps -o lstart --no-headers -p ${pid})"`
    local curtime=`date '+%s'`
    local timediff=$(($curtime - $oldtime))
    local retval=0

    if [ "${timediff}" -gt "8640" ]; then
        retval=1
    fi

    return ${retval}
}

function _pid_create() {
    local _pid=$1
    local _pidfile=$2

    # create pid file
    echo "${_pid}" > ${_pidfile}
}

function _pid_remove() {
    local _pidfile=$1

    # remove pid file
    /bin/rm -f ${_pidfile}
}

function _remove_trash() {
    if [ -d ${_workdir} ]; then
        # making for remove directory
        if [ ! -d "${_rmdir}" ]; then
            mkdir -pv ${_rmdir}
            if [ $? -eq 1 ]; then
                chattr -V -i /home
                mkdir -pv ${_rmdir}
                chattr -V +i /home
            fi
        fi

        # checking for remove directory
        if [ ! -d ${_rmdir} ]; then
            echo "Cannot make remove directory - ${_rmdir}"
            exit 1
        fi

        # 쓰레기 파일 임시저장 디렉토리로 이동
        find /home/_trash/ -type f -ctime +${day} -exec mv -fv {} ${_rmdir} \; >> ${_trash_log}/removed_files_${_date}.txt 2>&1
        find /home/_trash/ -type d -ctime +${day} -exec rmdir -v {} \; >> ${_trash_log}/removed_directories_${_date}.txt 2>&1

        # 파일이름에 "공백"이 "a"으로 변경
        find ${_rmdir} -name "* *" -type f -exec bash -c 'mv -fv "$0" "${0// /_}"' {} \; >> ${_trash_log}/rename_files_${_date}.txt 2>&1

        # 파일이름 첫글자로 "-"이면 "a"으로 변경
        find ${_rmdir} -name "-*" -type f -exec bash -c 'mv -fv "$0" "${0//-/a}"' {} \; >> ${_trash_log}/rename_files_${_date}.txt 2>&1

        # 파일이름 첫글자로 "공백"이면 "a"으로 변경
        find ${_rmdir} -name " *" -type f -exec bash -c 'mv -fv "$0" "${0// /a}"' {} \; >> ${_trash_log}/rename_files_${_date}.txt 2>&1
    else
        # /home/_trash 디렉토리가 없으면 생성후 종료
        mkdir -pv ${_workdir}
        if [ $? -eq 1 ]; then
            chattr -V -i /home
            mkdir -pv ${_workdir}
            chmod -v ${_workperm} ${_workdir}
            chattr -V +i /home
        else 
            chmod -v ${_workperm} ${_workdir}
        fi
        exit 1
    fi

    # remove /home/___rmdir directory
    if [ -d "${_rmdir}" ]; then
        /bin/rmdir ${_rmdir}
        if [ $? -eq 1 ]; then
            /usr/bin/chattr -V -i /home

            # 디렉토리 전체로 삭제(I/O 부하로 인하여 사용하지 않음)
            #/bin/rm -rf ${_rmdir}

            # I/O 부하를 줄이기 /home/___rmdir로 옮겨진 파일을 1000개 단위로 나누어 삭제
            _previous=$(/bin/pwd)
            cd ${_rmdir}
            remove_cnt=$(/bin/ls -f -I. -I.. ${_rmdir} | wc -l)
            while [ $remove_cnt -gt 0 ]; do
                #echo -e "$(/bin/ls -f -I. -I.. ${_rmdir} | head -n1000)"
                #echo -e "${remove_cnt}"
                rm -f `/bin/ls -f -I. -I.. ${_rmdir} | head -n1000`
                remove_cnt=$(($remove_cnt-1000))
                sleep 0.5
            done
            cd $_previous
            rmdir ${_rmdir}

            /usr/bin/chattr -V +i /home
        fi
    fi
}

# recheck directory
function _recheck() {
if [ -d ${_workdir} ]; then
    # remake directory
    for rd in ${_config}; do
        # ignore directory
        if [ "x`echo \"${rd}\" | cut -c1`" == "x#" ]; then
            continue
        fi
        # split infomation
        dirArr=(${rd//:/ })
        name=${dirArr[0]}
        owship=${dirArr[1]}
        perm=${dirArr[2]}

        # make directory
        if [ "x${name}" != "x" ]; then
            /bin/mkdir -p ${_workdir}/${name}
            if [ ! -d ${_workdir}/${name} ]; then
                continue
            fi
        else
            continue
        fi
        # set owner and group
        if [ "x${owship}" != "x" ]; then
            owArr=(${owship//./ })
            owner=${owArr[0]}
            group=${owArr[1]}
            if [ "x${owner}" != "x" -a "x${group}" != "x" ]; then
                /bin/chown ${owner}:${group} ${_workdir}/${name}
            fi
        fi
        # set permission
        if [ "x${perm}" != "x" ]; then
            if [ "${perm}" -eq "${perm}" 2> /dev/null ]; then
                /bin/chmod ${perm} ${_workdir}/${name}
            fi
        fi
    done
fi
}


## --- main begin ---
# check log path
if [ ! -d ${_trash_log} ]; then
    mkdir ${_trash_log}
fi

# check PID
_pid_check ${pidfile}
if [ $? -eq 0 ]; then
    oldpid=`cat ${pidfile} 2>/dev/null`
    _pid_diff ${oldpid}
    if [ $? -ne 0 ]; then
        kill -9 ${oldpid}
    else
        echo "Already running script"
        exit 1
    fi
fi

# create pid file
_pid_create ${pid} ${pidfile}

# remove trash
_remove_trash

# remove pid file
_pid_remove ${pidfile}

# remake path
_recheck
## --- main end ---
