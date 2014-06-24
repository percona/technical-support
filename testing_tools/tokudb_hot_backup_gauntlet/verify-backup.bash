#!/bin/bash

if [ -z "$DB_DIR" ]; then
    echo "Need to set DB_DIR"
    exit 1
fi
if [ -z "$MYSQL_SOCKET" ]; then
    echo "Need to set MYSQL_SOCKET"
    exit 1
fi
if [ -z "$HOT_BACKUP_DIR" ]; then
    echo "Need to set HOT_BACKUP_DIR"
    exit 1
fi

export MYSQL_USER=root
export MYSQL_PASSWORD=""

testDir=testDir

rm -rf ${testDir}
mkdir ${testDir}

# dump the running server
./v.bash ${testDir}/master 
mstop

# dump the backup
pushd $DB_DIR
mstart-backup ${HOT_BACKUP_DIR}
popd
./v.bash ${testDir}/backup
mstop

echo "performing diff of master vs. backup"
diff -r ${testDir}/master ${testDir}/backup
if [ $? == 0 ]; then
    echo "NO DIFFERENCES, GOOD STUFF!"
fi
#meld ${testDir}/master ${testDir}/backup

echo ""
echo "*********************************************"
echo "you can remove testDir/*"
echo "*********************************************"
echo ""
