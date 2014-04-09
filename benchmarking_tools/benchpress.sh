#!/bin/bash

#############################################
#
# This script is primarily designed to run sql-bench tests
# and compare the results between TokuDB builds 
# during a release cycle to check for performance
# regressions. It can also be used to verify performance
# metrics in comparison to InnoDB. To run, simply copy 
# benchpress.sh and sql.bench.summary.py (result parsing python script)
# into an empty runtime directory alongside a valid tar.gz
# tarball.  Upon executing benchpress.sh, the tarball
# will be extracted, tests will be run, all results
# will be concatenated to a tracefile, and, upon completion, 
# a summary report of the tracefile will be generated 
# and placed in the sql-bench directory.
# 

#############################################
# Setup MySQL Environment.
#

# Where are we?
working_dir=$PWD

# Find the tarball.
num_found=0
for i in *.tar.gz; do
  MYSQL_VERSION=${i%.tar.gz}
  echo "found $MYSQL_VERSION"
  ((num_found++))
  if [ $num_found -gt 1 ]; then
      echo "found more than 1 tarball, exiting!"
      exit 1
  fi
done

# Delete any existing directories
find . -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} \;

# Unpack the tarball.
tar xzf $MYSQL_VERSION.tar.gz

# Change to MySQL dir.
pushd $MYSQL_VERSION

#################################################
# This block creates a custom my.cnf which ensures
# the TokuDB and InnoDB cache/pool sizes are
# configured such that performance comparisons
# are valid and interesting.
#################################################
socket=/tmp/benchmark.sock
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
bin/mysqld_safe --defaults-file=my.cnf --basedir=$PWD &

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

bindir=.
testresultsdir=.

engine=TokuDB
system=`uname -s | tr [:upper:] [:lower:]`
arch=`uname -m | tr [:upper:] [:lower:]`
date=`date +%Y%m%d`

# Run the tests.
releasename=$MYSQL_VERSION
tracefile=sql-bench-$releasename.trace
summaryfile=sql-bench-$releasename.summary

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

>$testresultsdir/$tracefile

runtests --create-options=engine=$engine --socket=$socket --user=$user --verbose --small-test         >> $testresultsdir/$tracefile 2>&1
runtests --create-options=engine=$engine --socket=$socket --user=$user --verbose --small-test --fast  >> $testresultsdir/$tracefile 2>&1
runtests --create-options=engine=$engine --socket=$socket --user=$user --verbose                      >> $testresultsdir/$tracefile 2>&1
runtests --create-options=engine=$engine --socket=$socket --user=$user --verbose              --fast  >> $testresultsdir/$tracefile 2>&1
runtests --create-options=engine=$engine --socket=$socket --user=$user --verbose              --fast --lock-tables >> $testresultsdir/$tracefile 2>&1

../sql.bench.summary.py < $testresultsdir/$tracefile > $testresultsdir/$summaryfile

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

# Erase MySQL dir. This is probably not a good idea since you may lose the log files.
popd # exit mysql directory.
#rm -rf $MYSQL_VERSION
