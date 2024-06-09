#!/bin/bash

# Check if the number of arguments is exactly 1
if [ $# -ne 1 ]; then
    echo "Error: You must provide exactly one file List IP argument"
    exit 1
fi

# Check if the provided argument is a file
if [ ! -f $1 ]; then
    echo Error: The argument must be a file.
    exit 1
fi

# Create an empty output file
output=result-check-nodex.csv
> $output

IP_FILE=$1

USERS=(
    ubuntu
    cloud-user
    centos
)

EXPORTER_PATH=(
    "/usr/local/bin/node_exporter"
    "/usr/bin/node_exporter"
    "/usr/local/bin/node_exporter-1.2.2.linux-amd64/node_exporter"
)

nodex_ver() {
    local ip=$1
    local user=$2
    local check_ver
    local check_ver_status

    for path in "${EXPORTER_PATH[@]}"; do
        echo PATH: $path

        # get both stderr and stdout with 2>&1
        check_ver=$(ssh -i key.pem -l $user \
            -o ConnectTimeout=10 \
            -o ServerAliveInterval=3 \
            -o GSSAPIAuthentication=no \
            -o PasswordAuthentication=no \
            -o StrictHostKeyChecking=no \
            $ip $path --version 2>&1)

        check_ver_status=$?
        echo check version STATUS: $check_ver_status

        # if check_ver exit status SUCCESS
        if [ $check_ver_status -eq 0 ]; then
            ver=$(echo $check_ver | grep -oP 'version \K[^ ]+')
            echo FOUND with version $ver
            break
        fi
    done
}

for ip in $(cat $IP_FILE); do
    echo START: $ip

    # unset previous $ver value
    ver=""

    for user in "${USERS[@]}"; do
        echo USER: $user

        # remove previous SSH EXIT STATUS value
        ssh_status=""

        # `-o ServerAliveInterval`: counting seconds from
        # command start, no matter how the ssh pending
        # to reach server
        # e.g. server high memory usage
        ssh -qi key.pem -l $user \
            -o ConnectTimeout=10 \
            -o ServerAliveInterval=3 \
            -o GSSAPIAuthentication=no \
            -o PasswordAuthentication=no \
            -o StrictHostKeychecking=no \
            $ip exit

        ssh_status=$?
        echo ssh STATUS: $ssh_status

        # if ssh SUCCESS
        if [ $ssh_status -eq 0 ]; then
            echo USER: $user SUCCESS
            nodex_ver $ip $user

            # if ssh status success, then
            # no need to process another user
            break
        else
            echo USER: $user FAILED
        fi
    done
    echo END: $ip
    echo
    echo $ip,$ver >> $output
done

echo DONE, you can check the output at $output