#!/bin/sh

dirname=`dirname $0`
files="$dirname/[a-z]*"

if [ "X$1" != X ];then
	files="$*"
fi

for file in $files
do
	x=`basename $file`
	echo "===================="
	echo "FILE: $x"
	echo "// mail body to input "
	if [ -f $file ];then
		cat $file
		echo ""
		echo "// output"
		cp /dev/null log
		cat $file | sh emulfml
		cat log
	else
		echo $file is not found
	fi
	echo ""
done

exit 0
