#!/bin/bash

# This script adds new users given a CSV-format file (Described below).
# It expects that there are some common files located at /home/common_files
# which will be copied to each user's own home directory.

# This is a file where each line has 3 elements, delimited by a comma. No spaces!:
# 0: an email
# 1: a username (needs to be a valid unix username)
# 2: a password 
USER_FILE=$1

if [ -f $USER_FILE ]; then
	echo $USER_FILE exists
fi

while read line;
do
        new_user=$(cut -d',' -f2 <<<$line)
        new_user_pass=$(cut -d',' -f3 <<<$line)
        sudo adduser $new_user --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password
	echo "$new_user:$new_user_pass" | sudo chpasswd
        cp /home/common_files/* /home/$new_user/
        chown -R $new_user:$new_user /home/$new_user/
done < $USER_FILE

