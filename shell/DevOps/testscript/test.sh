#!/bin/bash
echo "Hello World !"

your_name="rounoob"

RUNOOB="www.runoob.com"
LD_LIBRARY_PATH="/bin"
_var="123"
var2="abc"

# shellcheck disable=SC1073
# shellcheck disable=SC1058
# shellcheck disable=SC2045
for file in $(ls /etc)
do
    echo "$file"
done