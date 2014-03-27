#!/bin/bash

#############################################
# Setup MySQL Environment.
#

# Where are we?
working_dir=$PWD

# Find taball.
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

# Unpack tarball.
tar xzf $MYSQL_VERSION.tar.gz

# Change to MySQL dir.
pushd $MYSQL_VERSION

# Create custom my.cnf
socket=/tmp/benchmark.sock
port=22666
echo "
[mysqld] 
port=$port 
socket=$socket
" > my.cnf

# Initialize mysql
scripts/mysql_install_db --defaults-file=my.cnf --basedir=$PWD

# Start mysqld.
bin/mysqld_safe --defaults-file=my.cnf --basedir=$PWD &

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
run-all-tests --log --dir=$inno_output --socket=$socket --create-options=ENGINE=InnoDB
run-all-tests --log --dir=$toku_output --socket=$socket --create-options=ENGINE=TokuDB
#--connect-options=mysql_read_default_file=my.cnf

# Create result file by comparing output with given output file.
cd $toku_output
for f in *.result
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
bin/mysqladmin --user=root --defaults-file=my.cnf shutdown

# Erase MySQL dir.
popd # exit mysql directory.
#rm -rf $MYSQL_VERSION
