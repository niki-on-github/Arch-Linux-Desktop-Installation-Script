#!/bin/bash

echo -n "read ./pkg.csv ... "
while IFS=, read -r gid tag program preCommands postCommands comment; do
    n=$((n+1))
    [ -z "$gid" ] && echo "Syntax error in line $n" && exit 1
    [ -z "$tag" ] && echo "Syntax error in line $n" && exit 1
    [ -z "$program" ] && echo "Syntax error in line $n" && exit 1
    [ -z "$comment" ] && echo "Syntax error in line $n" && exit 1

    if [ "$tag" = "R" ]; then
        pacman -Ss $program >/dev/null || ( echo "Package not found: $program (line $n)" && exit 1 )
    fi

    if [ "$tag" = "A" ]; then
        yay --aur -Ss $program >/dev/null 2>&1 || ( echo "Package not found: $program (line $n)" && exit 1 )
    fi

    # NOTE: currently only repo and aur packages are checked

done < ./pkg.csv
unset IFS
echo "OK"
