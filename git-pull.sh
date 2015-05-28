#!/bin/sh

# cd
cd `dirname $0`

date                   >>git.log
git reset --hard       >>git.log
git pull origin master >>git.log
echo .                 >>git.log
