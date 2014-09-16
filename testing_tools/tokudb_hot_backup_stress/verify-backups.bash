#!/bin/bash

if [ -z "$DB_DIR" ]; then
    echo "Need to set DB_DIR"
    exit 1
fi
if [ -z "$TOKUDB_LOG_DIR" ]; then
    echo "Need to set TOKUDB_LOG_DIR"
    exit 1
fi
if [ -z "$TOKUDB_DATA_DIR" ]; then
    echo "Need to set TOKUDB_DATA_DIR"
    exit 1
fi
if [ -z "$TOKUDB_BINLOG" ]; then
    echo "Need to set TOKUDB_BINLOG"
    exit 1
fi
if [ -z "$MYSQL_DATA_DIR" ]; then
    echo "Need to set MYSQL_DATA_DIR"
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
if [ -z "$VERIFY_LOG_NAME" ]; then
    echo "Need to set VERIFY_LOG_NAME"
    exit 1
fi

MYSQL_SOCKET=$MYSQL_SOCKET

MYSQL_DATABASE=sbtest
MYSQL_USER=root

NUM_TABLES=$1
deleteFinalBackup=Y

# remove the last backup since it doesn't finish before the database is shutdown
if [ ${deleteFinalBackup} == "Y" ] ; then
    numBackupDirs=0
    deleteBackupDir=""

    for backupDir in ${HOT_BACKUP_DIR}/* ; do
        let numBackupDirs=numBackupDirs+1
        deleteBackupDir=${backupDir}
    done

    if ! [ ${numBackupDirs} == 0 ] ; then
        # we have a backup directory to kill
        echo "deleteting backup directory ${deleteBackupDir}" | tee -a ${VERIFY_LOG_NAME}
        rm -rf ${deleteBackupDir}
    fi
fi

for backupDir in ${HOT_BACKUP_DIR}/* ; do
    if [ -d "${backupDir}" ]; then
        echo "" | tee -a ${VERIFY_LOG_NAME}
        echo "" | tee -a ${VERIFY_LOG_NAME}
        echo "--------------------------------------------------------------------------------------" | tee -a ${VERIFY_LOG_NAME}
        echo "--------------------------------------------------------------------------------------" | tee -a ${VERIFY_LOG_NAME}
        echo "--------------------------------------------------------------------------------------" | tee -a ${VERIFY_LOG_NAME}
        echo "checking backup directory : ${backupDir}" | tee -a ${VERIFY_LOG_NAME}
    fi

    pushd ${DB_DIR}
    
    # stop mysql if it is currently running
    mstop
    
    # This is the section that encapsulates trying to start the BACKUP set of files!!! 
    # This is where we first move all the original data, log and bin directories OUT OF THE WAY into
    # directories called <dir_name>.ORIGINAL so that they can be examined later if necessary.

    if [ ${MYSQL_MULTI_DIR} == 1 ]; then
        rm -r ${TOKUDB_LOG_DIR}.ORIGINAL
        mv ${TOKUDB_LOG_DIR} ${TOKUDB_LOG_DIR}.ORIGINAL
        mkdir ${TOKUDB_LOG_DIR}
        rm -r ${TOKUDB_DATA_DIR}.ORIGINAL
        mv ${TOKUDB_DATA_DIR} ${TOKUDB_DATA_DIR}.ORIGINAL
        mkdir ${TOKUDB_DATA_DIR}
        rm -r  ${TOKUDB_BINLOG}.ORIGINAL
        mv ${TOKUDB_BINLOG} ${TOKUDB_BINLOG}.ORIGINAL
        mkdir ${TOKUDB_BINLOG}
        rm -r ${MYSQL_DATA_DIR}.ORIGINAL
        mv ${MYSQL_DATA_DIR} ${MYSQL_DATA_DIR}.ORIGINAL
        mkdir ${MYSQL_DATA_DIR}
        pushd ${backupDir}

        # This is where we reassemble or replace the original data with the data that was backed up.
        # Unfortunately, in a multidir scenario, some of the files have absolute paths embedded in them
        # and therefore need to be put back in the SAME location.  And the backup cannot be started by
        # simply pointing mstart at the location of the backup.

        mv tokudb_log_dir/* ${TOKUDB_LOG_DIR}
        mv tokudb_data_dir/* ${TOKUDB_DATA_DIR}
        mv mysql_log_bin/* ${TOKUDB_BINLOG}
        mv mysql_data_dir/* ${MYSQL_DATA_DIR}
        popd
        mstart
    else
        mstart-backup ${backupDir}
    fi
    
    popd
    
    ./verify.bash ${NUM_TABLES} ${VERIFY_LOG_NAME}
done

mstop
