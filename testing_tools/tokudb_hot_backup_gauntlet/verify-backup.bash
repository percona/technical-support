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
if [ -z "$MYSQL_MULTI_DIR" ]; then
    echo "Need to set MONGO_MULTI_DIR"
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

# Adding logic to recognize the references 
# to multi-dir backup directory structure.
if [ ${MYSQL_MULTI_DIR} == 1 ]; then
    mv ${TOKUDB_LOG_DIR} ${TOKUDB_LOG_DIR}.ORIGINAL
    mkdir ${TOKUDB_LOG_DIR}
    mv ${TOKUDB_DATA_DIR} ${TOKUDB_DATA_DIR}.ORIGINAL
    mkdir ${TOKUDB_DATA_DIR}
    mv ${TOKUDB_BINLOG} ${TOKUDB_BINLOG}.ORIGINAL
    mkdir ${TOKUDB_BINLOG}
    mv ${MYSQL_DATA_DIR} ${MYSQL_DATA_DIR}.ORIGINAL
    mkdir ${MYSQL_DATA_DIR}
    pushd ${HOT_BACKUP_DIR}
    mv ${TOKUDB_LOG_BACKUP}/* ${TOKUDB_LOG_DIR}
    mv ${TOKUDB_DATA_BACKUP}/* ${TOKUDB_DATA_DIR}
    mv ${TOKUDB_BINLOG_BACKUP}/* ${TOKUDB_BINLOG}
    mv ${MYSQL_DATA_BACKUP}/* ${MYSQL_DATA_DIR}
    popd
    mstart-backup ${MYSQL_DATA_DIR}
else
    mstart-backup ${HOT_BACKUP_DIR}
fi

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
