#!/bin/bash

test=true;
while $test;
do
  rm bb.sh
  if [ $? == 0 ]; then
	echo "success"
  else 
	echo "failed"
  fi
  me=true;
  while $me;
  do
   rm dd.sh
   if [ $? == 0 ]; then
        test=false
   else
	echo "failure";
        test=true
   fi
   me=false;
   done
test=false;
done
