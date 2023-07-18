#!/bin/bash

# default:
# path to current audit-policy.yaml
AUDIT_POLICY_FILE_PATH=/etc/kubernetes/audit-policy.yaml
# path to golden audit-policy.yaml (from configmap)
GOLDEN_POLICY_FILE_PATH=/config/kube/audit-policy.yaml
# interval in seconds between compare files
INTERVAL=60

while getopts c:g:t: flag
do
    case "${flag}" in
        c) AUDIT_POLICY_FILE_PATH=${OPTARG};;
        g) GOLDEN_POLICY_FILE_PATH=${OPTARG};;
        t) INTERVAL=${OPTARG};;
    esac
done

log() {
    echo "[$(date -Is)]" "$@"
}

test(){
    if [ ! -f "$1" ]; then
        log "File $1 does not exist."
        quit
    fi
}

quit(){
    log "audit-keeper is stopped"
    exit 1
}

log "audit-keeper is started"

# used bin files
CMP_BIN=/usr/bin/cmp
CAT_BIN=/bin/cat
SHUF_BIN=/usr/bin/shuf
PRINTF_BIN=/usr/bin/printf
PGREP_BIN=/usr/bin/pgrep 
KILL_BIN=/bin/kill
SLEEP_BIN=/bin/sleep

# check bin files exist
test $CMP_BIN
test $CAT_BIN
test $SHUF_BIN
test $PRINTF_BIN
test $PGREP_BIN
test $KILL_BIN
test $SLEEP_BIN

while true    
do
    # check AUDIT_POLICY_FILE
    test $AUDIT_POLICY_FILE_PATH
    # check GOLDEN_POLICY_FILE
    test $GOLDEN_POLICY_FILE_PATH
    # compare files
    $CMP_BIN -s $AUDIT_POLICY_FILE_PATH $GOLDEN_POLICY_FILE_PATH
    if [ $? -eq 0 ]; then
        log `$PRINTF_BIN 'the file %s is the same as %s' "$AUDIT_POLICY_FILE_PATH" "$GOLDEN_POLICY_FILE_PATH"`
    else
        # TO DO:
        # validate golden yaml
        # 
        # check kube-apiserver is running
        PID=""
        PID=$($PGREP_BIN -x kube-apiserver)
        if [[ "" !=  "$PID" ]]; then
            # do update
            log `$PRINTF_BIN 'the file %s is different from %s' "$AUDIT_POLICY_FILE_PATH" "$GOLDEN_POLICY_FILE_PATH"`
            log "writing content of golden file to current audit policy file"
            # cp -f $GOLDEN_POLICY_FILE_PATH $AUDIT_POLICY_FILE_PATH
            $CAT_BIN $GOLDEN_POLICY_FILE_PATH > $AUDIT_POLICY_FILE_PATH
            if [ $? -eq 0 ]; then
                log `$PRINTF_BIN 'updating file %s is executed successfully' "$AUDIT_POLICY_FILE_PATH"`
                log "restarting kube-apiserver..."
                # prevent to kill all kube-apiservers at the some time
                KILL_TIMEOUT=$($SHUF_BIN -i 1-60 -n 1)
                log "kube-apiserver is $PID, send a SIGTERM signal after $KILL_TIMEOUT second..."
                $SLEEP_BIN $KILL_TIMEOUT
                log "send a SIGTERM to kube-apiserver"
                # kill kube-apiserver
                while $KILL_BIN -s SIGTERM $PID; do
                    log "waiting stop kube-apiserver..."
                    $SLEEP_BIN 1
                done
                log "kube-apiserver is killed successfully"
            else
                log `$PRINTF_BIN 'file %s was not updated correctly' "$AUDIT_POLICY_FILE_PATH"`
                quit
            fi
        else
            log "kube-apiserver PID is unknown, may be kube-apiserver is not running now"
            log "trying again..."
        fi
    fi
    $SLEEP_BIN $INTERVAL
done