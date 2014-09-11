#!/bin/bash

#############################################
#
# This script is primarily designed to run a dirty and clean upgrade 
# between two tarball builds of TokuDB to verify that a dirty or clean 
# upgrade will work or not work as expected. Currently (9/8/2014), dirty upgrade
# is designed to work with 7.1.5 and forward.  7.1.0 will upgrade only
# following a clean shutdown. This script requires a copy of tdb_logprint
# to be located in the workingdir so that it can process the binlog and verify 
# a true dirty shutdown which is important as this feature is designed to
# verify a successful dirty upgrade. Please note that tdb_logprint
# is not shipped with TokuDB and a new version may need to be built
# to support reading the bin log that may be parsed by this test. 
# This script also requires a workload, or .sql file, that can be specified
# to execute and manipulate the data such that an upgrade issue could be 
# further diagnosed. This script does NOT perform any checksum operations 
# against a known data set.  Use upgrade_dirty_clean.sh to verify correctness.

if [ $# -eq 0 ]; then
  echo "usage: upgrade_workload.sh <tarball_1.tar.gz> <tarball_2.tar.gz> <workload.sql>"
  exit 1
fi


#############################################
# Setup MySQL Environment.
#

# Where are we?
workingdir=$PWD

# Find the two builds.

tarball_1=${1}
tarball_2=${2}
workload=${3}

# Declare the two basedirs after extraction.

basedir_1=`echo $tarball_1 | sed -r 's/\.[[:alnum:]]+\.[[:alnum:]]+$//'`
basedir_2=`echo $tarball_2 | sed -r 's/\.[[:alnum:]]+\.[[:alnum:]]+$//'`

# Unpack the tarball of the build that will be shutdown "dirty"
tar xzf $tarball_1

# Change to basedir_1.
echo
echo "Moving to the base directory named --> ${basedir_1}"
echo
pushd $basedir_1 > /dev/null

# Print some useful output as the test begins
echo "###############################################################################"
echo
echo "Now starting ${basedir_1} with the ultimate goal of simulating a DIRTY upgrade to ${basedir_2}"
echo
echo "###############################################################################"

# Initialize mysql
scripts/mysql_install_db --basedir=$PWD

# Adding a sleep statement to ensure all plugin tables are created
sleep 6

# Start mysqld.
bin/mysqld --basedir=$PWD --datadir=./data --socket=/tmp/dirty_upgrade_1.sock &
my_mysqld_pid=$!

# Adding a sleep statement to allow MySQL to start cleanly
sleep 6

# Run some operations against the MySQL DB
echo
echo "Running the designated workload against the DB"
echo
bin/mysql --user=root --socket=/tmp/dirty_upgrade_1.sock test < ${workingdir}/${workload}

# Kill mysqld to effectively create a "dirty" shutdown
kill -9 $my_mysqld_pid

# Adding a sleep statement to ensure that the mysqld process dies completely
sleep 6

# Run tdb_logprint to ensure that the shutdown was indeed dirty
echo
echo "######################################"
echo
echo "Here is the output from the binlog to verify that a shutdown message is NOT PRESENT:"
echo
${workingdir}/tdb_logprint < data/log*.tokulog* | tail -100
echo
echo "######################################"
echo

popd > /dev/null

# Unpack the tarball to the upgraded build.
tar xzf $tarball_2

# Change to basedir_2.
echo
echo "Moving to the base directory named --> ${basedir_2}"
echo
pushd $basedir_2 > /dev/null

# It is not necessary to initialize mysql since we are starting with a pre-existing datadir

# Start the upgraded TokuDB build
bin/mysqld --basedir=$PWD --datadir=${workingdir}/${basedir_1}/data --socket=/tmp/dirty_upgrade_2.sock &
my_dirty_upgraded_mysqld_pid=$!

# Adding a sleep statement to allow MySQL the opportunity to start cleanly
sleep 10

my_dirty_upgraded_mysqld_verification=`ps -ef | grep mysqld | grep ${my_dirty_upgraded_mysqld_pid} | awk '{print$2}'`

if [ -z "${my_dirty_upgraded_mysqld_verification}" ]; then
    echo
    echo "###############################################################################"
    echo
    echo "MySQL did not start. The DIRTY upgrade FAILED. See the MySQL error log to diagnose further."
    echo
    echo "###############################################################################"
    echo
    echo 
fi

if [ "${my_dirty_upgraded_mysqld_pid}" == "${my_dirty_upgraded_mysqld_verification}" ]; then
    echo
    echo "###############################################################################"
    echo
    echo "The DIRTY upgrade of TokuDB PASSED and was successful.  The PID of your new mysqld process is: "$my_dirty_upgraded_mysqld_pid
    echo
    echo "###############################################################################"
    echo
    echo

    # Shutdown the server
    echo "Shutting down the MySQL DB process gracefully..."
    echo
    bin/mysqladmin shutdown --socket=/tmp/dirty_upgrade_2.sock --user=root


   # Adding a sleep statement to allow MySQL to shut down cleanly
   sleep 8
fi

popd > /dev/null

# Remove the extracted directories to verify that a clean shutdown works properly
if [ -z "${workingdir}" ]; then
    echo "workingdir does not exist. Exiting..."
    echo
    exit 1
fi

if [ -z "${basedir_1}" ]; then
    echo "basedir_1 does not exist. Exiting..."
    echo
    exit 1
fi

if [ -z "${basedir_2}" ]; then
    echo "basedir_2 does not exist. Exiting..."
    echo
    exit 1
fi

echo "Removing the base directories from the dirty upgrade test..."
echo

rm -rf ${workingdir}/${basedir_1}
rm -rf ${workingdir}/${basedir_2}

echo "##################################"
echo
echo "Now verifying that a CLEAN upgrade of TokuDB between ${basedir_1} and ${basedir_2} works as designed."
echo
 
# Unpack the tarball of the build that will be shutdown "dirty"
tar xzf $tarball_1

# Print some useful output as the test begins
echo
echo "Now starting ${basedir_1} with the ultimate goal of simulating a CLEAN upgrade to ${basedir_2}"
echo

# Change to basedir_1.
echo
echo "Moving to the base directory named --> ${basedir_1}"
echo
pushd $basedir_1 > /dev/null

# Initialize mysql
scripts/mysql_install_db --basedir=$PWD

# Adding a sleep statement to ensure all plugin tables are created
sleep 6

# Start mysqld.
bin/mysqld --basedir=$PWD --datadir=./data --socket=/tmp/clean_upgrade_1.sock &

# Adding a sleep statement to allow MySQL the opportunity to start cleanly
sleep 10

# Run some operations against the MySQL DB
echo
echo "Running some operations against the DB"
echo
bin/mysql --user=root --socket=/tmp/clean_upgrade_1.sock test < ${workingdir}/${workload}

# Shutdown mysqld cleanly (correctly)
bin/mysqladmin shutdown --socket=/tmp/clean_upgrade_1.sock --user=root

# Adding a sleep statement to allow MySQL to shut down cleanly
sleep 8

# Run tdb_logprint to ensure that the shutdown was indeed clean
echo
echo "######################################"
echo
echo "Here is the output from the binlog to verify that a shutdown message IS PRESENT:"
echo
${workingdir}/tdb_logprint < data/log*.tokulog* | tail -10
echo
echo "######################################"
echo

popd > /dev/null

# Unpack the tarball to the upgraded build.
tar xzf $tarball_2

# Change to basedir_2.
echo
echo "Moving to the base directory named --> ${basedir_2}"
echo
pushd $basedir_2 > /dev/null

# It is not necessary to initialize mysql since we are starting with a pre-existing datadir

# Start the upgraded TokuDB build
bin/mysqld --basedir=$PWD --datadir=${workingdir}/${basedir_1}/data --socket=/tmp/clean_upgrade_2.sock &
my_clean_upgraded_mysqld_pid=$!

# Adding a sleep statement to allow MySQL the opportunity to start cleanly
sleep 10

if [ -z "${my_clean_upgraded_mysqld_pid}" ]; then
    echo "MySQL did not start. The CLEAN upgrade FAILED. See the MySQL error log to diagnose further."
    echo
    echo 

    exit 1
fi

echo
echo "###############################################################################"
echo
echo "The CLEAN upgrade of TokuDB PASSED and was successful.  The PID of your new mysqld process is: "$my_clean_upgraded_mysqld_pid
echo
echo "###############################################################################"
echo

# Shutdown the server
echo "Shutting down the MySQL DB process gracefully..."
echo
bin/mysqladmin shutdown --socket=/tmp/clean_upgrade_2.sock --user=root

# Adding a sleep statement to allow MySQL to shut down cleanly
sleep 8

popd > /dev/null

# Cleaning up the extracted directories after verifying that a clean shutdown worked properly
if [ -z "${workingdir}" ]; then
    echo "workingdir does not exist. Exiting..."
    echo
    exit 1
fi

if [ -z "${basedir_1}" ]; then
    echo "basedir_1 does not exist. Exiting..."
    echo
    exit 1
fi

if [ -z "${basedir_2}" ]; then
    echo "basedir_2 does not exist. Exiting..."
    echo
    exit 1
fi

echo "Removing the base directories from the clean upgrade test..."
echo

rm -rf ${workingdir}/${basedir_1}
rm -rf ${workingdir}/${basedir_2}


