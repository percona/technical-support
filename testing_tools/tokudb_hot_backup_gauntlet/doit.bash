#!/bin/bash

if [ -z "$DB_DIR" ]; then
    echo "Need to set DB_DIR"
    exit 1
fi
if [ ! -d "$DB_DIR" ]; then
    echo "Need to create directory DB_DIR"
    exit 1
fi


export HOT_BACKUP_DIR=$DB_DIR/hot-backup-dir
echo "creating hot backup directory in $HOT_BACKUP_DIR"
# WE CREATE THIS DIRECTORY TWICE, ONCE TO PASS THE FOLLOWING TEST BUT AGAIN LATER SINCE
#   mkdb-quiet REMOVES IT
mkdir $HOT_BACKUP_DIR


if [ -z "$HOT_BACKUP_DIR" ]; then
    echo "Need to set HOT_BACKUP_DIR"
    exit 1
fi
if [ ! -d "$HOT_BACKUP_DIR" ]; then
    echo "Need to create directory HOT_BACKUP_DIR"
    exit 1
fi

echo "`date` | *** removing all files from $HOT_BACKUP_DIR"
rm -rf $HOT_BACKUP_DIR/*

if [ -z "$MYSQL_NAME" ]; then
    export MYSQL_NAME=mysql
fi
if [ -z "$MYSQL_VERSION" ]; then
    export MYSQL_VERSION=5.5.37
fi
if [ -z "$MYSQL_STORAGE_ENGINE" ]; then
    export MYSQL_STORAGE_ENGINE=tokudb
fi
if [ -z "$TARBALL" ]; then
    export TARBALL=blank-toku716.e-mysql-5.5.37
    #export TARBALL=blank-toku715.e-mysql-5.5.36
    #export TARBALL=blank-toku715.e-mariadb-5.5.36
fi
if [ -z "$TOKUDB_COMPRESSION" ]; then
    export TOKUDB_COMPRESSION=zlib
fi
if [ -z "$BENCH_ID" ]; then
    export BENCH_ID=715.e.${TOKUDB_COMPRESSION}.${TARBALL}
fi
if [ -z "$TOKUDB_READ_BLOCK_SIZE" ]; then
    export TOKUDB_READ_BLOCK_SIZE=64K
fi
if [ -z "$TOKUDB_BACKUP_THROTTLE" ]; then
    # 1 MB/s
    export BACKUP_MBPS=1
    let TOKUDB_BACKUP_THROTTLE=BACKUP_MBPS*1024*1024
    export TOKUDB_BACKUP_THROTTLE
fi
if [ -z "$TOKUDB_DIRECTIO" ]; then
    export TOKUDB_DIRECTIO=1
fi

export MYSQL_DATABASE=sbtest
export MYSQL_USER=root
export TOKUDB_ROW_FORMAT=tokudb_${TOKUDB_COMPRESSION}

echo "`date` | Creating database from ${TARBALL} in ${DB_DIR}"
pushd $DB_DIR
mkdb-quiet $TARBALL
popd


mkdir $HOT_BACKUP_DIR


echo "`date` | Configuring my.cnf and starting database"
pushd $DB_DIR

echo "tokudb_read_block_size=${TOKUDB_READ_BLOCK_SIZE}" >> my.cnf
echo "tokudb_row_format=${TOKUDB_ROW_FORMAT}" >> my.cnf
echo "tokudb_backup_throttle=${TOKUDB_BACKUP_THROTTLE}" >> my.cnf
echo "tokudb_cache_size=${TOKUDB_DIRECTIO_CACHE}" >> my.cnf
echo "tokudb_directio=${TOKUDB_DIRECTIO}" >> my.cnf
mstart
popd

# size of the dummy file
export DUMMY_FILE_MB=100

echo "`date` | Creating a $DUMMY_FILE_MB MB file to slow down the copier"
dd if=/dev/urandom of=$DB_DIR/data/dummy-file.txt bs=1048576 count=$DUMMY_FILE_MB

pauseSeconds=10

echo "`date` | Starting the backup"
mysql-run-backup ${BACKUP_MBPS} > backup.log &

echo "`date` | Pausing for ${pauseSeconds} second(s)"
sleep ${pauseSeconds}

echo "`date` | Executing the gauntlet"
#$DB_DIR/bin/mysql --user=${MYSQL_USER} --socket=${MYSQL_SOCKET} test < gauntlet.sql > /dev/null
$DB_DIR/bin/mysql --user=${MYSQL_USER} --socket=${MYSQL_SOCKET} test < gauntlet.sql

echo "`date` | Checking that backup is still running"
$DB_DIR/bin/mysql --user=${MYSQL_USER} --socket=${MYSQL_SOCKET} test -e "show processlist" | grep "backup to" > /dev/null
retVal=$?
if [ ${retVal} -ne 0 ] ; then
    echo "backup either finished too fast or didn't run at all, exiting"
    exit 1
fi

echo "`date` | Speeding up the backup copier"
$DB_DIR/bin/mysql --user=${MYSQL_USER} --socket=${MYSQL_SOCKET} test -e "set global tokudb_backup_throttle=999999999"

echo "`date` | Waiting for backup to finish"
backupDone=0
while [ ${backupDone} == 0 ] ; do
    $DB_DIR/bin/mysql --user=${MYSQL_USER} --socket=${MYSQL_SOCKET} test -e "show processlist" | grep "backup to" > /dev/null
    retVal=$?
    if [ ${retVal} -eq 1 ] ; then
        backupDone=1
    fi
    sleep 10
done

echo "Performing backup verification"
./verify-backup.bash
