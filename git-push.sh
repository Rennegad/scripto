#!/bin/sh

cd /var/big/scripts
date                   >>git.log
git commit -a -m "No comment yet" >>git.log
git push origin master >>git.log
echo .                 >>git.log
