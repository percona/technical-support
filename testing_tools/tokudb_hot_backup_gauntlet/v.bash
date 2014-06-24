#! /bin/bash

if [ -z "$DB_DIR" ]; then
    echo "Need to set DB_DIR"
    exit 1
fi
if [ -z "$MYSQL_SOCKET" ]; then
    echo "Need to set MYSQL_SOCKET"
    exit 1
fi
if [ -z "$MYSQL_USER" ]; then
    echo "Need to set MYSQL_USER"
    exit 1
fi

testDir=$1
mkdir ${testDir}

dbList=`$DB_DIR/bin/mysql --user=${MYSQL_USER} --socket=${MYSQL_SOCKET} --skip-column-names test -e "show databases" | awk '{print $c}' c=${1:-1} | sort`

skipList="information_schema performance_schema"

for thisDb in ${dbList} ; do
    if [[ $skipList =~ ${thisDb} ]] ; then
        echo "skipping database ${thisDb}"
    else
        echo "processing database ${thisDb}"
        pushd ${testDir}
        mkdir ${thisDb}
        cd ${thisDb}
        $DB_DIR/bin/mysqldump -u ${MYSQL_USER} --password=${MYSQL_PASSWORD} -S ${MYSQL_SOCKET} ${thisDb} --fields-terminated-by=, --fields-enclosed-by=\" --tab ./

        count=`ls -1 *.sql 2>/dev/null | wc -l`
        if [ $count != 0 ]; then
            # only execute sed if files exist, warnings are ugly
            sed --in-place '/^-- Dump completed on/d' *.sql
        fi
        popd
    fi
done

