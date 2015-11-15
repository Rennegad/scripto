#!/bin/bash

# TotalBackup.cfg обязательный, в нем настройки
# 
# aliases.tbk список алиасов рабочих станций
#
# exclude.tbk список файлов, не подлежащих копированию
# include.tbk список файлов, подлежащих копированию
# include.$alias список файлов, подлежащих копированию для хоста $alias (пробелы заменяются на _ )
#
# pc-exclude.tbk список хостов, с которых НЕ идет копирование (MAC, IP, Netbios, Alias)
# pc-include.tbk список хостов, с которых идет копирование (MAC, IP, Netbios, Alias)
# check push-cronpull

cd `dirname $0`

################################################
# включим логирование всего
LogPrefix="./logs/"`date +%Y-%m-%d.%H-%M-%S`
mkdir -p $LogPrefix
log=$LogPrefix/total.log
BadLog=bad.log
if [ -f $BadLog ]; then rm $BadLog; fi
mailMe=$LogPrefix/mail.txt
if [ -f $mailMe ]; then rm $mailMe; fi
###############################################
FreeSpaceLimit=100000000
BackupArchiveLimit=30
##########
 
# зададим пробелы для выравнивания и ширину колонок в таблице
Spac='                                                                       '
Line='-----------------------------------------------------------------------'
Width1=-35
Width2=-6
Width3=-18
Width4=-18
Width5=-10
Width6=-16
Width7=-16
Width8=-15
Width9=-18
############################################################################################################################

#############################################################################################################################
# итак, поехали
#echo This Total Backup started at `date +"%m-%d-%Y %T"`  >>$log
# начало архивирования
StartTime=$(date +%s)
StartTimeF=$(date +"%d-%m-%y %T")

#,thtv настройки
source TotalBackup.cfg

if [ -z "$MountPath" ]; then
   echo Не определен MountPath. Принимаем по  умолчанию /mnt/users >>$log
   # сюда будем монтировать шары пользователей
   MountPath=/mnt/users 
fi

if [ -z "$BackupPath" ]; then
   echo Не определен BackupPath. Это проблема. Работа невозможна, выходим. >>$log
   exit
fi

if [ -z "$Network" ]; then
   echo Не определена Network. Принимаем по умолчанию 192.168.0.0/24 >>$log
   # диапазон сетевых адресов
   Network=192.168.0.0/24
fi

if [ -z "$User" ]; then
   echo Не определена пара User/Password. Принимаем по умолчанию backup/911 >>$log
   User=backup
   Password=911
fi

if [ ! -d $MountPath ]; then
   echo Error with MountPath. $MountPath does not exists. Exiting now. >>$log
   exit
fi

if [ ! -d $BackupPath ]; then
   echo Error with BackupPath. $BackupPath does not exists. Exiting now. >>$log
   exit
fi

####################################################################################
IncrementDir=`date +%Y-%m-%d`
Current=files
####################################################################################

# все на месте ? тогда поехали

#вычислим размер папки с архивами ДО архивирования
StartSize=`du $BackupPath -s -b|cut -d/ -f1`
StartSizeF=$(printf "%'.0d" $StartSize)
#свободное место ДО архивирования
StartFree=`df $BackupPath --block-size=1 |tail -n 1 |tr -s "\t " ":" |cut -f4 -d ":"` 
StartFreeF=$(printf "%'.0d" $StartFree)

echo So, lets do it now                                                                                                                                                                            >$log
echo '['"${Line:$Width1}"'+'"${Line:$Width2}"'+'"${Line:$Width3}"'+'"${Line:$Width4}"'+'"${Line:$Width5}"'+'"${Line:$Width6}"'+'"${Line:$Width7}"'+'"${Line:$Width8}"'+'"${Line:$Width9}"']'       >>$log
echo '['"${Spac:$Width1}"':'"${Spac:$Width2}"':'"${Spac:Width3+${#StartTimeF}}"$StartTimeF':'"${Spac:$Width4}"':'"${Spac:$Width5}"':'"${Spac:$Width6+${#StartSizeF}}"$StartSizeF':'"${Spac:$Width7}"':'"${Spac:$Width8}"':'"${Spac:$Width9+${#StartFreeF}}"$StartFreeF']' >>$log
echo '['"${Line:$Width1}"'+'"${Line:$Width2}"'+'"${Line:$Width3}"'+'"${Line:$Width4}"'+'"${Line:$Width5}"'+'"${Line:$Width6}"'+'"${Line:$Width7}"'+'"${Line:$Width8}"'+'"${Line:$Width9}"']'       >>$log

# сначала сделаем обзор сети, получим список всех пингуемых хостов
nmap -sP $Network -n >$LogPrefix/HostList.lst 2>&1

HostCount=0
HostLive=0

# теперь пробежимся по спиcку хостов
while read line
do
  if [[ $line =~ "Nmap scan report for" ]]; then
     hostStartTime=$(date +%s)
     hostStartTimeF=$(date +"%d-%m-%y %T")
     HostCount=$((HostCount+1))
     IP=${line:21}
     echo .                                      >>$LogPrefix/StationParse.$IP     
     echo Берем строчку {$line}                  >>$LogPrefix/StationParse.$IP
     echo Получили из нее IP-адрес хоста [$IP]   >>$LogPrefix/StationParse.$IP
     nmblookup -A $IP                            >station
     echo Посмотрим, что за хост по адресу [$IP] >>$LogPrefix/StationParse.$IP
     cat station                                  >>$LogPrefix/StationParse.$IP
     echo Ну, теперь все ясно с этим хостом:      >>$LogPrefix/StationParse.$IP
     cat station | grep '<20>' |grep -v '<GROUP>' >>$LogPrefix/StationParse.$IP
     NetbiosName=`grep '<20>' station | grep -v '<GROUP>' |cut -d" " -f1 | sed 's/.*/\L&/' |sed 's/^[ \t]*//'`
     Alias=$NetbiosName
     echo Получается, Netbios имя хоста [$NetbiosName]>>$LogPrefix/StationParse.$IP
     grep MAC station                     >>$LogPrefix/StationParse.$IP
     MAC=$(grep 'MAC' station | cut -d" " -f4 | sed 's/-/:/g')
     echo Получается, MAC-адрес хоста [$MAC]     >>$LogPrefix/StationParse.$IP          
     rm station
     #
     if [[ $MAC = '00:00:00:00:00:00' || -z $MAC  || -z $NetbiosName ]]; then         
        echo [$IP] Это какой-то плохой хост. Мы не будем с ним работать >>$LogPrefix/StationParse.$IP
     else
        echo Отлично, дальше работаем с хостом $NetbiosName, [$IP], [$MAC] >>$LogPrefix/StationParse.$IP
        # запишем хост в список хостов, на долгую память
        if [[    $(grep -c -i ^$MAC TotalHostList.tbk ) -eq 0 ]]; then
           echo $MAC $IP"${Spac:0:13-${#IP}}" $NetbiosName $(date +"%d-%m-%y %T")  >>TotalHostList.tbk
        fi
        # вычислим алиас станции. если он есть
        if [ -f aliases.tbk ] ;then
           # попробуем вычислить алиас компа
           echo Определим Alias, например >>$LogPrefix/StationParse.$IP
           # начнем с MAC адреса                      
           if [[ $(grep -c -i ^$MAC= aliases.tbk ) -ne 0 ]]; then
              Alias=$(grep -i ^$MAC= aliases.tbk)              
              Alias=${Alias#$MAC=}
              echo Получили алиас по MAC [$Alias] >>$LogPrefix/StationParse.$IP              
           elif  [[ $(grep -c -w ^$IP= aliases.tbk) -ne 0 ]]; then
              Alias=$(grep    -w ^$IP= aliases.tbk)
              Alias=${Alias#$IP=}
              echo Получили алиас по IP [$Alias] >>$LogPrefix/StationParse.$IP                                       
           elif  [[ $(grep -c -i $NetbiosName aliases.tbk) -ne 0 ]]; then
              # сначала берем строку
              Alias=$(grep -i ^$NetbiosName= aliases.tbk)
              Alias=${Alias#$NetbiosName=}
              echo Получили алиас по Netbios [$Alias] >>$LogPrefix/StationParse.$IP                                       
           fi
           if [[ -n $Alias ]]; then 
              # Избавляемся от двойных и больше пробелов
              Alias=$(echo $Alias)
              # и заменим пробелы на _
              Alias=${Alias// /_} 
           else # если Алиас присвоился пустой - обратно сделаем его равным NetbiosName
               Alias=$NetbiosName
           fi
        fi
        # Проверим, не в черном ли списке станция
        # черный список - все станции, кроме этих
        if [ -f pc-exclude.tbk ]; then
           if [[ $(grep -c -w  ^$IP          pc-exclude.tbk) -ne 0 || \
                 $(grep -c -i  ^$MAC         pc-exclude.tbk) -ne 0 || \
                 $(grep -c -i  ^$NetbiosName' ' pc-exclude.tbk) -ne 0 || \
                 $(grep -c -i  ^$Alias' '       pc-exclude.tbk) -ne 0 ]]; then
              echo ОПА! IP-[$IP:$(grep -c -w ^$IP pc-exclude.tbk)] \
                        MAC-[$MAC:$(grep -c -i ^$MAC pc-exclude.tbk)] \
                        Netbios-[$NetbiosName:$(grep -c -i ^$NetbiosName' ' pc-exclude.tbk)] \
                        Alias-[$Alias:$(grep -c -i ^$Alias' ' pc-exclude.tbk)] в черном списке! Проходим мимо этого хоста.... >>$LogPrefix/StationParse.$IP
              Alias=''
           fi
        fi                      
        # На всякий случай проверим, в белом ли списке станция
        # белый список - только станции из этого списка
        if [ -f pc-include.tbk ]; then
           if [[ $(grep -c -w ^$IP          pc-include.tbk) -ne 0 ||\
                 $(grep -c -i ^$MAC         pc-include.tbk) -ne 0 ||\
                 $(grep -c -i ^$NetbiosName' ' pc-include.tbk) -ne 0 ||\
                 $(grep -c -i ^$Alias' '       pc-include.tbk) -ne 0 ]]; then
              echo УРА! IP-[$IP $(grep -c ^$IP pc-include.tbk)] \
                        MAC-[$MAC $(grep -c -i ^$MAC pc-include.tbk)] \
                        Netbios-[$NetbiosName $(grep -c -i ^$NetbiosName' ' pc-include.tbk)] \
                        Alias-[$Alias $(grep -c -i ^$Alias' ' pc-include.tbk)] в белом списке! Это удача, работаем с этим хостом!>>$LogPrefix/StationParse.$IP
           else
              Alias=''
              echo Как же так? IP-[$IP] MAC-[$MAC] Netbios-[$NetbiosName] Alias-[$Alias] НЕ в белом списке! проходим мимо этого хоста... >>$LogPrefix/StationParse.$IP
           fi
        fi
        # Алиас задан? значит имеется имя хоста и он в белом списке или не в черном! РАБОТАЕМ!
        if [[ -n $Alias ]]; then
           HostLive=$((HostLive+1))
           # создадим  папочку, куда будем бэкапить именно этот хост  (если еще нет такой папки)
           if [ ! -d $BackupPath/$Alias ]; then  mkdir -p $BackupPath/$Alias; fi
           #
           # теперь посмотрим, что расшарено на этом хосте 
           echo Список файловых шар на $IP для $User:                       >>$LogPrefix/StationParse.$IP
           smbclient -L $IP -U $User%$Password -g | grep Disk | grep -v '$|'> shares.lst 2>>$LogPrefix/StationParse.$IP
           echo ----------------------------------------------------------- >>$LogPrefix/StationParse.$IP
           cat shares.lst                                                   >>$LogPrefix/StationParse.$IP
           echo ----------------------------------------------------------- >>$LogPrefix/StationParse.$IP
           # теперь пробежимся по полученному списку дисковых шар
           ShareLive=0
           ShareCount=0
           #
           while read shareline
           do
               ShareCount=$((ShareCount+1))
               ShareName=$(echo $shareline | cut --delimiter="|" -f2)
               Share_Name=${ShareName// /_}
               #
               echo создаем папку $MountPath/$Alias/$Share_Name >>$LogPrefix/StationParse.$IP
               # создадим папочку, куда будем монтировать для каждой шары (если еще нет такой папки)
               if [ ! -d $MountPath/$Alias/$Share_Name ];  then mkdir -p $MountPath/$Alias/$Share_Name ; fi
               #
               # ну чо, теперь смонтируем эту шару. то есть хотя бы попробуем
               echo Пробуем монтировать $User:$Password //$IP/$ShareName $MountPath/$Alias/$Share_Name                     >>$LogPrefix/StationParse.$IP
               mount "//$IP/$ShareName" "$MountPath/$Alias/$Share_Name" -o user=$User,password=$Password,iocharset=utf8,ro >>$LogPrefix/StationParse.$IP 2>&1
               Code=$?
               echo Код монтирования $Code >>$LogPrefix/StationParse.$IP
               MountSize=$(du $MountPath/$Alias/$Share_Name -s -b|cut -d/ -f1)
               BackupSize=$(du $BackupPath/$Alias/$Current/$Share_Name -s -b|cut -d/ -f1)
               if [[ $Code -eq 0 ]];  then
                  ShareLive=$((ShareLive+1))
                  ShareNames[$ShareLive]=${Share_Name:0:-$Width1}
                  #
                  # Размер папки, которую мы будем копировать (без учета фильтров) 
                  ShareSize[$ShareLive]=$MountSize
                  ShareSizeF[$ShareLive]=$(printf "%'.0d" ${ShareSize[$ShareLive]})
                  # это размер уже скопированного
                  BackupShareStartSize[$ShareLive]=$BackupSize
                  BackupShareStartSizeF[$ShareLive]=$(printf "%'.0d" ${BackupShareStartSize[$ShareLive]})
                  #
                  echo //$IP/$ShareName смонтирован в $MountPath/$Alias/$Share_Name, его размер ${ShareSizeF[$ShareLive]} >>$LogPrefix/StationParse.$IP
                  echo а размер $BackupPath/$Alias/$Current/$Share_Name до копировани составляет ${BackupShareStartSizeF[$ShareLive]} >>$LogPrefix/StationParse.$IP
               else 
                  echo [!!==ERROR==!!] Монтирование //$IP/$ShareName в $MountPath/$Alias/$Share_Name неудачно, код $Code >>$LogPrefix/StationParse.$IP
                  echo [!!==ERROR==!!] Монтирование "//$IP/$ShareName" в $MountPath/$Alias/$Share_Name неудачно, код $Code >>$BadLog
                  ## надо удалить папочку тогда, зачем она пустая ?
                  if [[ $MountSize -gt 0 ]]; then
                     echo Это странно, $MountPath/$Alias/$Share_Name все-таки смонтирован, его размер [$MountSize] >>$LogPrefix/StationParse.$IP
                  else
                     rm -r $MountPath/$Alias/$Share_Name
                  fi
               fi
           done < shares.lst
           rm shares.lst
           #
           # если было хотя бы одно успешное монтирование - БЭКАААААП!!
           if [[ $ShareLive -gt 0 ]]; then
              #
              ArchiveRoot=$BackupPath/$Alias
              SyncOptions="-avr -d --force --ignore-errors --delete --delete-excluded --backup --backup-dir=$ArchiveRoot/$IncrementDir -h --log-file=$LogPrefix/rsync-$Alias.log"
              ## проверим, есть ли условия фильтрации
              if [ -f include.$Alias ]; then
                 # !!!! елки палки!! http://superuser.com/questions/256751/make-rsync-case-insensitive
                 perl -pe 's/([a-z])/[\U$1\E$1]/g' include.$Alias >include
                 #
                 SyncOptions=$SyncOptions" --include-from include "
              elif [ -f include.tbk ]; then
                 perl -pe 's/([a-z])/[\U$1\E$1]/g' include.tbk >include
                 SyncOptions=$SyncOptions" --include-from include "
              fi
              ## проверим опции копирования для этого хоста
              if [[ -n $SpeedLimit ]]; then
                 SyncOptions=$SyncOptions" --bwlimit "$SpeedLimit
              fi
              # 
              # измерим размер папочки с имеющимся архивом (без учета бэкапов) до начала архивации. ХЗ зачем.
              if [ -d $BackupPath/$Alias/$Current ]; then
                 hostStartSize=$(du $BackupPath/$Alias/$Current -s -b|cut -d/ -f1) 
                 hostStartSizeF=$(printf "%'.0d" $hostStartSize)
              fi
              ########## http://wiki.dieg.info/rsync
              ########## http://www.sanfoundry.com/rsync-command-usage-examples-in-linux/
              #              
              echo Поехали! RSYNC $SyncOptions $MountPath/$Alias/ $ArchiveRoot/$Current >$LogPrefix/StationRSync.$IP
              cat include                                                               >>$LogPrefix/StationRSync.$IP
              ####################
              #                  #
              ####################
              rsync $SyncOptions $MountPath/$Alias/ $ArchiveRoot/$Current               >>$LogPrefix/StationRSync.$IP 2>&1
              Code=$?
              if [ $Code -ne 0 ]; then echo `date` Ошибка Rsync code is $Code!          >>$LogPrefix/StationBadRSync.$Alias ; fi
              ####################
              #                  #
              ####################
              #
              # и теперь не забыть все размонтировать!
              mount | grep -i $MountPath | while read mountline
              do
                mountline=$MountPath${mountline##*$MountPath}
                mountline=$(echo $mountline | cut -d' ' -f1)
                echo Размонтируем [$mountline] >>$LogPrefix/StationParse.$IP 2>&1
                umount $mountline              >>$LogPrefix/StationParse.$IP 2>&1
              done                            
              #
              hostStopTime=$(date +%s)
              hostStopTimeF=$(date +"%d-%m-%y %T")
              hostTime=$((hostStopTime-hostStartTime))
              hostTimeF=$(printf "%'.0d" $hostTime)
              #
              hostStopSize=$(du $BackupPath/$Alias/$Current -s -b|cut -d/ -f1)
              hostStopSizeF=$(printf "%'.0d" $hostStopSize)
              #
              hostSize=$((hostStopSize-hostStartSize))
              hostSizeF=$(printf "%'.0d" $hostSize)
              #
              Col1=$(echo $IP"${Spac:0:13-${#IP}}"' '$NetbiosName)              
              if [ $NetbiosName != $Alias ]; then Col1=$Col1' '"$Alias"; fi
              Col1=${Col1:0:-$Width1-1}
              Col2=$ShareLive'/'$ShareCount
              echo '['"$Col1""${Spac:$Width1+${#Col1}}"':'"${Spac:$Width2+${#Col2}}"$Col2':'"${Spac:$Width3+${#hostStartTimeF}}"$hostStartTimeF':'"${Spac:$Width4+${#hostStopTimeF}}"$hostStopTimeF':'"${Spac:$Width5+${#hostTimeF}}"$hostTimeF':'"${Spac:$Width6+${#hostStartSizeF}}"$hostStartSizeF':'"${Spac:$Width7+${#hostStopSizeF}}"$hostStopSizeF':'"${Spac:$Width8+${#hostSizeF}}"$hostSizeF':'"${Spac:$Width9+${#MAC}}"$MAC']'  >>$log              
              #
              # посчитаем самую длинную шару этого хоста
              MaxShareLen=0
              MaxSize1Len=0
              MaxSize2len=0
              for I in `seq 1 $ShareLive`
              do
                if [[ ${#ShareNames[$I]} -gt $MaxShareLen ]]; then
                   MaxShareLen=${#ShareNames[$I]}
                fi
                if [[ ${#ShareSizeF[$I]} -gt $MaxSize1Len ]]; then
                   MaxSize1Len=${#ShareSizeF[$I]}
                fi
                if [[ ${#BackupShareStartSizeF[$I]} -gt $MaxSize2Len ]]; then
                   MaxSize2Len=${#BackupShareStartSizeF[$I]}
                fi
              done
              #
              str=$ShareLive'/'$ShareCount
              if [[ $ShareLive -gt 0 ]]; then
              echo '['"${Line:$Width1}"'+'"${Line:$Width2}"'+'"${Line:$Width3}"'+'"${Line:$Width4}"'+'"${Line:$Width5}"'+'"${Line:$Width6}"'+'"${Line:$Width7}"'+'"${Line:$Width8}"'+'"${Line:$Width9}"']'       >>$log
              fi
              for I in `seq 1 $ShareLive`
              do
                BackupShareStopSize=$(du $BackupPath/$Alias/$Current/${ShareNames[$I]} -s -b|cut -d/ -f1)
                BackupShareStopSizeF=$(printf "%'.0d" $BackupShareStopSize)    
                BackupShareSize=$((BackupShareStopSize - BackupShareStartSize[$I]))
                BackupShareSizeF=$(printf "%'.0d" $BackupShareSize)                
                echo '['"${Spac:0:$((MaxShareLen+1-${#ShareNames[$I]}))}"${ShareNames[$I]}':'"${Spac:0:$((MaxSize1Len+1-${#ShareSizeF[$I]}))}"${ShareSizeF[$I]}':'"${Spac:0:$((MaxSize2Len+1-${#BackupShareStartSizeF[$I]}))}"${BackupShareStartSizeF[$I]}':'"${Spac:$Width3+${#BackupShareStopSizeF}}"$BackupShareStopSizeF':'$BackupShareSizeF"${Spac:$Width8+${#BackupShareSizeF}}"']' >>shares.lst
                if [ $I -eq 1 ]; then echo Shares on $Alias $IP >>AllShares.lst; fi
                 # теперь надо бы посчитать в каждой шаре фавйлы по маскам
                #if [ -f include ]; then 
                #   while read mask
                #   do
                #     if [[ ${mask:0:1} == '+' ]]; then
                #        mask=${mask:2}
                #        echo маска $mask "$mask" >>shares.lst
                #        echo путь с маской $BackupPath/$Alias/$Current/${ShareNames[$I]}/$mask >>shares.lst
                #        #du -ch $BackupPath/$Alias/$Current/${ShareNames[$I]}/$mask | tail -n 1 >>shares.lst
                #        Size1=$(find $BackupPath/$Alias/$Current/${ShareNames[$I]} -type f -name $mask -exec du -k {} \;|awk '{s+=$1}END{print s}')
                #        echo $Size1 >>shares.lst
                #        echo $(printf "%'.0d" $Size1) >>shares.lst
                #     fi
                #   done < include
                #fi   
              done              
              cat shares.lst >>$LogPrefix/StationParse.$IP
              cat shares.lst >>AllShares.lst
              if [ -f include ];then rm include; fi
              #
              ######
              # настало время разобраться с архивами
              # сначала заархивируем самый свежий бакап
              LastBackup=`ls $BackupPath/$Alias | grep ^20 |tail -1`
              echo LastBackup is $LastBackup >>$LogPrefix/StationParse.$IP                 
              if [ ! -e $BackupPath/$Alias/$LastBackup/$Alias-$LastBackup.7z ]; then 
                 Is7Z=`which  p7zip | wc -l`
                 if [ $Is7Z -eq 0 ]; then
                    apt-get install p7zip-full -y
                 fi
                 StartTime=$(date +%s)
                 7z a -r -mx1 $BackupPath/$Alias/$Alias-$LastBackup.7z $BackupPath/$Alias/$LastBackup
                 echo  $(($(date +%s)-$StartTime))' секунд для '$Alias-$LastBackup.7z >>$LogPrefix/StationParse.$IP                 
                 # 
                 if [ -e $BackupPath/$Alias/$Alias-$LastBackup.7z ]; then
                    # теперь надо удалить все, кроме самого архива конечно
                    echo 'удалим '$BackupPath/$Alias/$LastBackup >>$LogPrefix/StationParse.$IP                 
                    rm -r $BackupPath/$Alias/$LastBackup >>$LogPrefix/StationParse.$IP                 
                    echo 'Удалили с кодом '$?', создадим заново '>>$LogPrefix/StationParse.$IP                 
                    mkdir $BackupPath/$Alias/$LastBackup >>$LogPrefix/StationParse.$IP                 
                    mv $BackupPath/$Alias/$Alias-$LastBackup.7z $BackupPath/$Alias/$LastBackup 
                 fi
              fi         
              # В этом месяце бэкапов еще не было ?
              Mask=`date +%Y`-`date +%m`
              if [ ! -e $BackupPath/$Alias/Monthly/$Alias-$Mask.7z ]; then
                 if [ ! -d $BackupPath/$Alias/Monthly ];then
                    mkdir $BackupPath/$Alias/Monthly                 
                 fi
                 echo First backup in Month $Mask  >>$LogPrefix/StationParse.$IP
                 echo  7z a -r -mx1 $BackupPath/$Alias/Monthly/$Alias-$Mask.7z $BackupPath/$Alias/$Current >>$LogPrefix/StationParse.$IP
                 StartTime=$(date +%s)
                 #7z a -r -mx1 $BackupPath/$Alias/Monthly/$Alias-$Mask.7z $BackupPath/$Alias/$Current
                 echo  $(($(date +%s)-$StartTime))' секунд для Monthly/'$Alias-$Mask.7z >>$LogPrefix/StationParse.$IP                 
              fi              
              # ну теперь оставим только нужное количество бэкапов
              if [ -n $LastBackupsCount ]; then
                 echo это я когда нибуль потом сделаю
              fi
              # позаботимся о свободном месте 
              if [ -n $MinFreeSpace ]; then
                 # наконец проверим свободное место и если его мало - пошлем письмо и удалим старые бакапы
                 FreeSpace=`df $BackupPath --block-size=1 |tail -n 1 |tr -s "\t " ":" |cut -f4 -d ":"` 
                 echo "так. Свободное место "$FreeSpace", а нам надо "$MinFreeSpace >>$LogPrefix/StationParse.$IP
                 # удалим самые старые бакапы
                 while [ $FreeSpace -lt $MinFreeSpace ]; do
                       OlderDir=`ls -1 -t $BackupPath/$Alias | grep ^20 | tail -1`
                       echo 'Эээээй, нужно удалить старый бакап '$BackupPath/$Alias/$OlderDir
                       rm -r $BackupPath/$Alias/$OlderDir
                       FreeSpace=`df $BackupPath --block-size=1 |tail -n 1 |tr -s "\t " ":" |cut -f4 -d ":"`          
                       echo $OlderDir" удален, свободное место "$FreeSpace", а нам надо "$MinFreeSpace >>$LogPrefix/StationParse.$IP                       
                 done
                 ## если все еще мало места - надо удалять Monthly
                 
              fi
              ########################################
           else
              echo Alas, $MountPath/$Alias has no shares, sad but true. Perhaps move it to Blacklist?  >>$LogPrefix/StationParse.$IP
              echo $Alias [$IP] have no opened shares>>$BadLog
           fi
        fi # Alias is Empty
     fi # Mac or IP or Netbiosname is empty
  fi
done < $LogPrefix/HostList.lst
#
StopTime=$(date +%s)
StopTimeF=$(date +"%d-%m-%y %T")
Time=$((StopTime-StartTime))
TimeF=$(printf "%'.0d" $Time)
#
StopSize=`du $BackupPath -s -b|cut -d/ -f1`
StopSizeF=$(printf "%'.0d" $StopSize)
Size=$((StopSize-StartSize))
SizeF=$(printf "%'.0d" $Size)
#свободное место ПОСЛЕ архивирования
StopFree=`df $BackupPath --block-size=1 |tail -n 1 |tr -s "\t " ":" |cut -f4 -d ":"` 
StopFreeF=$(printf "%'.0d" $StopFree)
#
Col2=$HostLive'/'$HostCount
echo '[ Итого'"${Spac:$Width1+6}"':'"${Spac:$Width2+${#Col2}}"$Col2':'"${Spac:Width3}"':'"${Spac:$Width4+${#StopTimeF}}"$StopTimeF':'"${Spac:$Width5+${#TimeF}}"$TimeF':'"${Spac:$Width6}"':'"${Spac:$Width7+${#StopSizeF}}"$StopSizeF':'"${Spac:$Width8+${#SizeF}}"$SizeF':'"${Spac:$Width9+${#StopFreeF}}"$StopFreeF']' $(printf "%'.0d" $((StartFree-StopFree))) >>$log
echo '['"${Line:$Width1}"'+'"${Line:$Width2}"'+'"${Line:$Width3}"'+'"${Line:$Width4}"'+'"${Line:$Width5}"'+'"${Line:$Width6}"'+'"${Line:$Width7}"'+'"${Line:$Width8}"'+'"${Line:$Width9}"']'       >>$log
#
if [ -f AllShares.lst ]; then
   echo Now some info about host shares >>$log
   cat AllShares.lst                    >>$log
   rm AllShares.lst
fi
echo That\'s all, folks!             >>$log
if [ -f $BadLog ]; then    
  echo                                                       >>$log
  echo Oh wait.                                              >>$log
  echo Look, there is some additional info about backup:     >>$log
  cat $BadLog >>$log
  rm $BadLog
fi
########################################
   # заархивируем логи, вдруг пригодится
   mkdir -p ./arclogs/`date +%Y`/`date +%m`
   tar -cvzf ./arclogs/`date +%Y`/`date +%m`/`date +%Y-%m-%d.%H-%M-%S`.tar.gz $LogPrefix >  /dev/null
########################################
   # и теперь оставим только последние 5 логов. остальное же в архиве
   WatchedDir="./logs"
   DirCnt=`ls -1 $WatchedDir | wc -l`
   MaxDirCnt=5
   while [ $DirCnt -gt $MaxDirCnt ]; do
         OlderFile=$(ls -1 -t $WatchedDir | tail -1)
         rm -rf $WatchedDir/$OlderFile
         DirCnt=`ls -1 $WatchedDir | wc -l`
   done
########################################
#                                      #
########################################