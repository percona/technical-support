#!/bin/bash

#############################################
#
# This script is primarily designed to run sql-bench tests
# and compare the results between two TokuDB builds 
# during a release cycle to check for performance
# regressions. It requires two tar.gz tarballs as arguments 
# that are placed into an empty runtime directory
# and pct-diff.pl which will process the summary files.
# Upon executing benchpress_compare.sh, the first tarball
# will be extracted, tests will be run whose results
# will be concatenated to a tracefile and upon completion,
# a summary report of the tracefile will be generated and placed
# in the sql-bench directory. Subsequently,
# the second tarball will be extracted, the same tests will be run
# whose results will be concatenated to a tracefile and upon completion,
# a summary report of the tracefile will be generated and placed
# in the sql-bench directory. At the end, a file named results.diff
# will highlight any differences (i.e. performance improvements or regressions).
# The script pct-diff.pl is the script that processes the two summary
# files. 

if [ $# -eq 0 ]; then
  echo "usage: benchpress_compare.sh <tarball_1.tar.gz> <tarball_2.tar.gz>"
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

# Declare the two basedirs after extraction.

basedir_1=`echo $tarball_1 | sed -r 's/\.[[:alnum:]]+\.[[:alnum:]]+$//'`
basedir_2=`echo $tarball_2 | sed -r 's/\.[[:alnum:]]+\.[[:alnum:]]+$//'`

# Delete any existing directories
find . -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} \;

# Unpack both tarballs consecutively.  This is done since
# we may have to copy a modified test into the sql-bench
# directory before the test execution phase.
tar xzf $tarball_1
tar xzf $tarball_2

# Change to basedir_1.
pushd $basedir_1

#################################################
# This block creates a custom my.cnf which ensures
# the TokuDB and InnoDB cache/pool sizes are
# configured such that performance comparisons
# are valid and interesting.
#################################################
socket=/tmp/benchmark_1.sock
port=22666
echo "[client]
port=$port
socket=$socket

[mysqld] 
port=$port 
socket=$socket

# specific : innodb
innodb_buffer_pool_size=2G

# specific : tokudb
tokudb_cache_size=2G
tokudb_directio=ON

[mysqladmin]
port=$port
socket=$socket
" > my.cnf

# Initialize mysql
scripts/mysql_install_db --basedir=$PWD

# Adding a sleep statement to ensure all plugin tables are created
sleep 6

# Start mysqld.
bin/mysqld_safe --defaults-file=my.cnf --basedir=$PWD --core-file &

# Adding a sleep statement to allow MySQL to start cleanly
sleep 6

##############################################
# Run benchmarks.
#

pushd sql-bench

# Setup temp output directories.
toku_output=toku_output
mkdir $toku_output
inno_output=inno_output
mkdir $inno_output

# Define the user that will be used to execute the tests.
user=root

# Define the sql-bench directory and the location
# where the test results will be written.
testresultsdir_1=$PWD

# Ensure that all files within the sql-bench directory (also
# defined as the $testresultsdir_1) have the execute permission.
chmod +x $testresultsdir_1/*


##############################################
# Specify the engine to be used during the test. The value will stay
# hard-coded as TokuDB since we have established that the script will be 
# used primarily to compare TokuDB to TokuDB, but this value could just
# as easily be toggled to InnoDB and re-run.

engine=TokuDB
#engine=InnoDB

system=`uname -s | tr [:upper:] [:lower:]`
arch=`uname -m | tr [:upper:] [:lower:]`
date=`date +%Y%m%d`

# Run the tests.
releasename_1=$basedir_1
tracefile_1=sql-bench-$releasename_1.trace
summaryfile_1=sql-bench-$releasename_1.summary

function mydate() {
    date +"%Y%m%d %H:%M:%S"
}

function runtests() {
    testargs=""
    skip=""
    for arg in $* ; do
	if [[ $arg =~ "--skip=(.*)" ]] ; then
	    skip=${BASH_REMATCH[1]}
	else
	    testargs="$testargs $arg"
	fi
    done
for testname in test* ; do
	#if [[ $testname =~ "^(.*).sh$" ]] ; then
	#    t=${BASH_REMATCH[1]}
	#else
	#    continue
	#fi
	echo `mydate` $testname $testargs
	if [ "$skip" != "" ] && [[ "$testname" =~ "$skip" ]]; then 
	    echo "skip $testname"
	else
	    ./$testname $testargs
	fi
	echo `mydate`
    done
}

>$testresultsdir_1/$tracefile_1

runtests --create-options=engine=$engine --socket=$socket --user=$user --verbose --small-test         >> $testresultsdir_1/$tracefile_1 2>&1
runtests --create-options=engine=$engine --socket=$socket --user=$user --verbose --small-test --fast  >> $testresultsdir_1/$tracefile_1 2>&1
runtests --create-options=engine=$engine --socket=$socket --user=$user --verbose                      >> $testresultsdir_1/$tracefile_1 2>&1
runtests --create-options=engine=$engine --socket=$socket --user=$user --verbose              --fast  >> $testresultsdir_1/$tracefile_1 2>&1
runtests --create-options=engine=$engine --socket=$socket --user=$user --verbose              --fast --lock-tables >> $testresultsdir_1/$tracefile_1 2>&1

while read l ; do
   if [[ $l =~ ^([0-9]{8}\ [0-9]{2}:[0-9]{2}:[0-9]{2})(.*)$ ]] ; then
        t=${BASH_REMATCH[1]}
        cmd=${BASH_REMATCH[2]}
        if [ -z "$cmd" ] ; then
            let duration=$(date -d "$t" +%s)-$(date -d "$tlast" +%s)
            printf "%4s %s %8d %s\n" "$status" "$tlast" "$duration" "$cmdlast"
        else
            cmdlast=$cmd
            tlast=$t
            status=PASS
        fi
   else
        if [[ $l =~ Got\ error|Died ]] ; then
        status=FAIL
        fi
   fi
done < $testresultsdir_1/$tracefile_1 > $testresultsdir_1/$summaryfile_1


###############################################

# The following commented tests use the default ./run-all-tests wrapper which generate 
# one log per run, or multiple test logs. We have elected to use
# the above runtests function created by Rich Prohaska since the output is directed
# to one single result file and it can be parsed/summarized by the sql.bench.summary.py script.
# It may at some point prove useful to use the ./run-all-tests wrapper scripts so the
# code and subsequent diff calls will be kept (but commented).
#
#./run-all-tests --create-options=ENGINE=TokuDB --log --dir=$toku_output --socket=$socket --user=$user --verbose --small-test
#./run-all-tests --create-options=ENGINE=InnoDB --log --dir=$inno_output --socket=$socket --user=$user --verbose --small-test
#./run-all-tests --create-options=ENGINE=TokuDB --log --dir=$toku_output --socket=$socket --user=$user --verbose --small-test --fast
#./run-all-tests --create-options=ENGINE=InnoDB --log --dir=$inno_output --socket=$socket --user=$user --verbose --small-test --fast
#./run-all-tests --create-options=ENGINE=TokuDB --log --dir=$toku_output --socket=$socket --user=$user --verbose --fast
#./run-all-tests --create-options=ENGINE=InnoDB --log --dir=$inno_output --socket=$socket --user=$user --verbose --fast
#./run-all-tests --create-options=ENGINE=TokuDB --log --dir=$toku_output --socket=$socket --user=$user --verbose --fast --lock-tables
#./run-all-tests --create-options=ENGINE=InnoDB --log --dir=$inno_output --socket=$socket --user=$user --verbose --fast --lock-tables
#./run-all-tests --create-options=ENGINE=TokuDB --log --dir=$toku_output --socket=$socket --user=$user --verbose
#./run-all-tests --create-options=ENGINE=InnoDB --log --dir=$inno_output --socket=$socket --user=$user --verbose

##############################################
#
# This is the block that compares the results from the above
# commented section of ./run-all-tests. It works great for an
# TokuDB to InnoDB table performance comparison.
#

# Create result file by comparing output with given output file.
#cd $toku_output
# We assume that ALL files in the new output directory are result files.
#for f in `ls`
#do
#  result=`find ../$inno_output -name $f`
#  echo "f = $f, result = $result"
# Copy output file to parent directory.
#  diff $f $result > $working_dir/"$f".diff
#done
#cd .. # exit output directory.

#############################################


popd # exit sql-bench directory.

#############################################
# Cleanup:
#

# Shutdown the database (--defaults-file needs to be the FIRST option in an argument list)
bin/mysqladmin --defaults-file=my.cnf --user=root shutdown

# Exit basedir_1.
popd # exit the basedir from the first run upon completion of the tests.

# Change to basedir_2.
pushd $basedir_2

#################################################
# This block creates a custom my.cnf which ensures
# the TokuDB and InnoDB cache/pool sizes are
# configured such that performance comparisons
# are valid and interesting.
#################################################
socket=/tmp/benchmark_2.sock
port=22667
echo "[client]
port=$port
socket=$socket

[mysqld]
port=$port
socket=$socket

# specific : innodb
innodb_buffer_pool_size=2G

# specific : tokudb
tokudb_cache_size=2G
tokudb_directio=ON

[mysqladmin]
port=$port
socket=$socket
" > my.cnf

# Initialize mysql
scripts/mysql_install_db --basedir=$PWD

# Adding a sleep statement to ensure all plugin tables are created
sleep 6

# Start mysqld.
bin/mysqld_safe --defaults-file=my.cnf --basedir=$PWD --core-file &

# Adding a sleep statement to allow MySQL to start cleanly
sleep 6

##############################################
# Run benchmarks.
#

pushd sql-bench

# Setup temp output directories.
toku_output=toku_output
mkdir $toku_output
inno_output=inno_output
mkdir $inno_output

# Define the user that will be used to execute the tests.
user=root

# Define the sql-bench directory and the location
# where the test results will be written.
testresultsdir_2=$PWD

# Ensure that all files within the sql-bench directory (also
# defined as the $testresultsdir_2) have the execute permission.
chmod +x $testresultsdir_2/*


system=`uname -s | tr [:upper:] [:lower:]`
arch=`uname -m | tr [:upper:] [:lower:]`
date=`date +%Y%m%d`

# Run the tests.
releasename_2=$basedir_2
tracefile_2=sql-bench-$releasename_2.trace
summaryfile_2=sql-bench-$releasename_2.summary

function mydate() {
    date +"%Y%m%d %H:%M:%S"
}

function runtests() {
    testargs=""
    skip=""
    for arg in $* ; do
        if [[ $arg =~ "--skip=(.*)" ]] ; then
            skip=${BASH_REMATCH[1]}
        else
            testargs="$testargs $arg"
        fi
    done
for testname in test* ; do
        #if [[ $testname =~ "^(.*).sh$" ]] ; then
        #    t=${BASH_REMATCH[1]}
        #else
        #    continue
        #fi
        echo `mydate` $testname $testargs
        if [ "$skip" != "" ] && [[ "$testname" =~ "$skip" ]]; then
            echo "skip $testname"
        else
            ./$testname $testargs
        fi
        echo `mydate`
    done
}

>$testresultsdir_2/$tracefile_2

runtests --create-options=engine=$engine --socket=$socket --user=$user --verbose --small-test         >> $testresultsdir_2/$tracefile_2 2>&1
runtests --create-options=engine=$engine --socket=$socket --user=$user --verbose --small-test --fast  >> $testresultsdir_2/$tracefile_2 2>&1
runtests --create-options=engine=$engine --socket=$socket --user=$user --verbose                      >> $testresultsdir_2/$tracefile_2 2>&1
runtests --create-options=engine=$engine --socket=$socket --user=$user --verbose              --fast  >> $testresultsdir_2/$tracefile_2 2>&1
runtests --create-options=engine=$engine --socket=$socket --user=$user --verbose              --fast --lock-tables >> $testresultsdir_2/$tracefile_2 2>&1

while read l ; do
   if [[ $l =~ ^([0-9]{8}\ [0-9]{2}:[0-9]{2}:[0-9]{2})(.*)$ ]] ; then
        t=${BASH_REMATCH[1]}
        cmd=${BASH_REMATCH[2]}
        if [ -z "$cmd" ] ; then
            let duration=$(date -d "$t" +%s)-$(date -d "$tlast" +%s)
            printf "%4s %s %8d %s\n" "$status" "$tlast" "$duration" "$cmdlast"
        else
            cmdlast=$cmd
            tlast=$t
            status=PASS
        fi
   else
        if [[ $l =~ Got\ error|Died ]] ; then
        status=FAIL
        fi
   fi
done < $testresultsdir_2/$tracefile_2 > $testresultsdir_2/$summaryfile_2

popd # exit sql-bench directory.

#############################################
# Cleanup:
#

# Shutdown the database (--defaults-file needs to be the FIRST option in an argument list)
bin/mysqladmin --defaults-file=my.cnf --user=root shutdown

# Exit basedir_2.
popd # exit the basedir from the second run upon completion of the tests.

# Use Tim's script to diff the two files
$workingdir/pct-diff.pl $testresultsdir_1/$summaryfile_1 $testresultsdir_2/$summaryfile_2 > $workingdir/results.diff
