#!/bin/bash

#############################################
#
# This script is designed to run sql-bench tests
# and compare the results between TokuDB and InnoDB
# as well as compare versions of TokuDB to TokuDB
# during a release cycle to check for performance
# regressions.  To run, simply copy benchpress.sh 
# into a desired directory alongside a valid tar.gz
# tarball.  Upon executing benchpress.sh, the tarball
# will be extracted and tests will be run using TokuDB
# and InnoDB tables. Upon completion, comparison reports
# for each test will be generated in the same directory.
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
echo "[mysqld] 
port=$port 
socket=$socket

# specific : innodb
innodb_buffer_pool_size=2G

# specific : tokudb
tokudb_cache_size=2G
tokudb_directio=ON

" > my.cnf

# Initialize mysql
scripts/mysql_install_db --defaults-file=my.cnf --basedir=$PWD

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

# actually run ALL the benchmarks.
./run-all-tests --log --dir=$inno_output --socket=$socket --create-options=ENGINE=InnoDB
./run-all-tests --log --dir=$toku_output --socket=$socket --create-options=ENGINE=TokuDB
#--connect-options=mysql_read_default_file=my.cnf

##############################################
# Compare results.
#

# Create result file by comparing output with given output file.
cd $toku_output
# We assume that ALL files in the new output directory are result files.
for f in `ls`
do
  result=`find ../$inno_output -name $f`
  echo "f = $f, result = $result"
# Copy output file to parent directory.
  diff $f $result > $working_dir/"$f".diff
done
cd .. # exit output directory.
popd # exit sql-bench directory.

#############################################
# Cleanup:
#

# Shutdown the database
bin/mysqladmin --user=root --socket=$socket shutdown

# Erase MySQL dir.
popd # exit mysql directory.
#rm -rf $MYSQL_VERSION
