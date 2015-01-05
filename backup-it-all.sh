#!/bin/bash

# TotalBackup.cfg обязательный, в нем настройки
# 
# aliases.tbk список алиасов рабочих станций
#
# exclude.tbk список файлов, не подлежащих копированию
# include.tbk список файлов, подлежащих копированию
# include.$alias список файлов, подлежащих копированию для хоста $alias
#
# pc-exclude.tbk список хостов, с которых НЕ идет копирование (MAC, IP, Netbios, Alias)
# pc-include.tbk список хостов, с которых идет копирование (MAC, IP, Netbios, Alias)
#

cd `dirname $0`

################################################
# включим логирование всего
LogPrefix="./logs/"`date +%Y-%m-%d.%H-%M-%S`
mkdir -p $LogPrefix
log=$LogPrefix/total.log
mail=$LogPrefix/mail.txt
###############################################
 
# зададим пробелы для выравнивания 
sp='____________________________'


#############################################################################################################################
# итак, поехали
echo This Total Backup started at `date +"%m-%d-%Y %T"`  >>$log
# начало архивирования
StartTime=$(date +%s)

if [ -f TotalBackup.cfg ]; then
   MountPath= `grep -i MountPath=  TotalBackup.cfg | cut -d'=' -f2`
   BackupPath=`grep -i BackupPath= TotalBackup.cfg | cut -d'=' -f2`
   Network=   `grep -i Network=    TotalBackup.cfg | cut -d'=' -f2`
   User=      `grep -i User=       TotalBackup.cfg | cut -d'=' -f2`
   Password=  `grep -i Password=   TotalBackup.cfg | cut -d'=' -f2`
   #
   
fi

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

# все на месте ? тогда поехали

#вычислим размер папки с архивами ДО архивирования
StartSize=`du $BackupPath -s -b|cut -d/ -f1`
#свободное место ДО архивирования
FreeSize1=`df $BackupPath --block-size=1048576 |tail -n 1 |tr -s "\t " ":" |cut -f4 -d ":"`
echo \* FreeSize of $BackupPath is `printf "%'.0d" $FreeSize1` MB        >>$log
echo \* TotalSize of $BackupPath is [`printf "%'.0d" $StartSize`] bytes >>$log

echo "############$User##############$Password##############################"    >>$log

# сначала сделаем обзор сети, получим список всех пингуемых хостов
nmap -sP $Network -n >$LogPrefix/HostList.lst 2>&1

# теперь пробежимся по спиcку хостов
cat $LogPrefix/HostList.lst| while read line
do 
  if [[ $line =~ "Nmap scan report for" ]]; then
     pcStartTime=$(date +%s)
     IP=${line:21}
     echo .                                      >>$LogPrefix/StationParse.$IP     
     echo Берем строчку {$line}                  >>$LogPrefix/StationParse.$IP
     echo Получили из нее IP-адрес хоста [$IP]   >>$LogPrefix/StationParse.$IP
     nmblookup -A $IP                            >station
     echo Посмотрим, что за хост по адресу [$IP] >>$LogPrefix/StationParse.$IP
     cat station                                 >>$LogPrefix/StationParse.$IP
     echo Ну, теперь все ясно с этим хостом      >>$LogPrefix/StationParse.$IP
     cat station | grep '<00>'  |grep -v '<GROUP>'  >>$LogPrefix/StationParse.$IP
     NetbiosName=`grep '<20>' station | grep -v '<GROUP>' |cut -d" " -f1 | sed 's/.*/\L&/' |sed 's/^[ \t]*//'`
     Alias=$NetbiosName
     echo Получается, Netbios имя хоста [$NetbiosName]>>$LogPrefix/StationParse.$IP
     grep MAC station                     >>$LogPrefix/StationParse.$IP
     MAC=`grep 'MAC' station | cut -d" " -f4 | sed 's/-/:/g'`
     echo Получается, MAC-адрес хоста [$MAC]     >>$LogPrefix/StationParse.$IP          
     rm station
     echo -n Start `date +"%m-%d-%Y %T"` ' ' $IP${sp:0:14-${#IP}} ' '  $MAC ' ' $NetbiosName${sp:0:17-${#NetbiosName}} ' ' >>$log
     if [[ $MAC = '00:00:00:00:00:00' || -z $MAC  || -z $NetbiosName ]]; then         
        echo [$IP] Это плохой хост. Мы не будем с ним работать >>$LogPrefix/StationParse.$IP
        echo bad host, exiting! >>$log
     else
        echo Отлично, дальше работаем с $NetbiosName, [$Alias], [$IP], [$MAC] >>$LogPrefix/StationParse.$IP
        # вычислим алиас станции. если он есть
        if [ -f aliases.tbk ] ;then
           # попробуем вычислить алиас компа
           echo Определим Alias, например >>$LogPrefix/StationParse.$IP
           # начнем с MAC адреса           
           if     [ `grep -с -i $MAC aliases.tbk ` -ne 0 ]; then
              Alias=`grep    -i $MAC aliases.tbk | cut -d' ' -f2`
              echo Получили алиас по MAC [$Alias] >>$LogPrefix/StationParse.$IP
           elif   [ `grep -c $IP' ' aliases.tbk ` -ne 0 ]; then
              Alias=`grep    $IP' ' aliases.tbk| cut -d' ' -f2`
              echo Получили алиас по ИП [$Alias] >>$LogPrefix/StationParse.$IP                                       
           elif   [ `grep -c -i -w $NetbiosName' '  aliases.tbk ` -ne 0 ]; then
              Alias=`grep    -i -w $NetbiosName' '  aliases.tbk | cut -d' ' -f2`
              echo Получили алиас по Netbios [$Alias] >>$LogPrefix/StationParse.$IP           
           fi
        fi
        echo -n [$Alias]${sp:0:18-${#Alias}} ' '  >>$log
        # Проверим, не в черном ли списке станция
        # черный список - все станции, кроме этих
        if [ -f pc-exclude.tbk ]; then
           if [[ `grep -c       $IP          pc-exclude.tbk` -ne 0 || \
                 `grep -c -i    $MAC         pc-exclude.tbk` -ne 0 || \
                 `grep -c -i -w $NetbiosName pc-exclude.tbk` -ne 0 || \
                 `grep -c -i -w $Alias       pc-exclude.tbk` -ne 0 ]]; then
              echo ОПА! IP-[$IP] MAC-[$MAC] Netbios-[$NetbiosName] Alias-[$Alias] в черном списке! Проходим мимо этого хоста.... >>$LogPrefix/StationParse.$IP                         
              Alias=''
              echo Black listed, skiping >>$log
           fi
        fi                      
        # На всякий случай проверим, в белом ли списке станция
        # белый список - только станции из этого списка
        if [ -f pc-include.tbk ]; then
           if [[ `grep -c       $IP          pc-include.tbk` -ne 0  ||\
               ! `grep -c -i    $MAC         pc-include.tbk` -ne 0  ||\
               ! `grep -c -i -w $NetbiosName pc-include.tbk` -ne 0  ||\
               ! `grep -c -i -w $Alias       pc-include.tbk` -ne 0 ]]; then
              echo УРА! IP-[$IP] MAC-[$MAC] Netbios-[$NetbiosName] Alias-[$Alias]  в белом списке! >>$LogPrefix/StationParse.$IP
           else
              Alias=''
              echo Но как? IP-[$IP] MAC-[$MAC] Netbios-[$NetbiosName] Alias-[$Alias] НЕ в белом списке! проходим мимо этого хоста... >>$LogPrefix/StationParse.$IP
              echo not in White list, skiping >>$log
           fi                                                                                                                 
        fi        
        # Алиас задан? значит в белом списке или не в черном! РАБОТАЕМ!
        if [[ -n $Alias ]]; then
           # создадим  папочку, куда будем бэкапить именно этот хост  (если еще нет такой папки)
           if [ ! -d $BackupPath/$Alias ]; then  mkdir -p $BackupPath/$Alias; fi                      
           #
           # измерим размер папочки с имеющимся архивом
           BackupSizeBeforeBackup=`du $BackupPath/$Alias -s -b|cut -d/ -f1`
           echo -n $BackupPath/$Alias ${sp:0:50-${#BackupPath}-${#Alias}} size before is `printf "%'.0d" $BackupSizeBeforeBackup` bytes " " >>$log
              
           # теперь посмотрим, что расшарено на этом хосте 
           echo Список шар на $IP для $User:   >>$LogPrefix/StationParse.$IP
           smbclient -L $IP -U $User%$Password >shares.lst 2>&1
           ## -g special for grep !!!!!
           cat shares.lst                 >>$LogPrefix/StationParse.$IP
           # теперь пробежимся по списку шар
           cat shares.lst| while read shareline
              do
                if [[ $shareline =~ "Disk" ]]; then
                   if [[ ! $shareline =~ "$" ]]; then
                      ShareName=`echo $shareline | sed 's/Disk//g' | sed 's/^[ \t]*//;s/[ \t]*$//' | sed 's/ /_/g'`
                      #echo внимание
                      #echo создаем папку $MountPath/$NetbiosName/$ShareName
                      # создадим папочку, куда будем монтировать для каждой шары (если еще нет такой папки)
                      if [ ! -d "$MountPath/$Alias/$ShareName" ];  then mkdir -p "$MountPath/$Alias/$ShareName" ; fi                     
    
                      # ну чо, теперь смонтируем эту шару. то есть хотя бы попробуем
                      echo Пробуем монтировать $User:$Password //$IP/$ShareName $MountPath/$Alias/$ShareName                     >>$LogPrefix/StationParse.$IP
                      mount "//$IP/$ShareName" "$MountPath/$Alias/$ShareName" -o user=$User,password=$Password,iocharset=utf8,ro >>$LogPrefix/StationParse.$IP 2>&1
                      Code=$?                      
                      if [ $Code -eq 0 ];  then                 
                         echo //$IP/$ShareName смонтирован в $MountPath/$Alias/$ShareName! >>$LogPrefix/StationParse.$IP
                      else 
                         echo Мониторование //$IP/$ShareName в $MountPath/$Alias неудачно, код $Code >>$LogPrefix/StationParse.$IP     
                         ## надо удалить папочку тогда, зачем она пустая ?                         
                         rm -r $MountPath/$Alias/$ShareName
                      fi        
                   fi
                fi
              done            
              rm shares.lst
              # если было хотя бы одно успешное монтирование - БЭКАААААП!!
              if [ -d $MountPath/$Alias ]; then
                 #echo `date` Измерим AliasSize для $Alias
                 AliasSize=`du $MountPath/$Alias -s -b|cut -d/ -f1`              
                 #echo `date` AliasSize для $Alias равен `printf "%'.0d" $AliasSize`                                  
                 if [[ $AliasSize -gt 0 ]]; then
                    echo `date`. Итого размер всех шар для $Alias составляет [$AliasSizeStr] б. Работаем...  >>$LogPrefix/StationParse.$IP
                    #    поехалиииииииии            
                    ArchiveRoot=$BackupPath/$Alias
                    IncrementDir=`date +%Y-%m-%d`
                    SyncOptions="-avzr -d --force --ignore-errors --delete --delete-excluded --backup --backup-dir=$ArchiveRoot/$IncrementDir -h --log-file=$LogPrefix/rsync-$Alias.log"
                    Current=files
                    
                    ## проверим, есть ли условия фильтрации
                    if [ -f include.$Alias ];then
                        # !!!! елки палки!! http://superuser.com/questions/256751/make-rsync-case-insensitive
                        perl -pe 's/([a-z])/[\U$1\E$1]/g' include.$Alias >include
                        #
                        SyncOptions=$SyncOptions" --include-from include "
                    elif [ -f include.tbk ]; then                       
                        perl -pe 's/([a-z])/[\U$1\E$1]/g' include.tbk >include
                        SyncOptions=$SyncOptions" --include-from include"                        
                    fi               
                    
                    ########## http://wiki.dieg.info/rsync
                    ########## http://www.sanfoundry.com/rsync-command-usage-examples-in-linux/
                    
                    echo Поехали! RSYNC $SyncOptions $MountPath/$Alias/ $ArchiveRoot/$Current >$LogPrefix/StationRSync.$IP
                    echo `date` выполним rsync для $Alias >>$log
                    rsync $SyncOptions $MountPath/$Alias/ $ArchiveRoot/$Current >>$LogPrefix/StationRSync.$IP 2>&1
                    Code=$?
                    if [ $Code -ne 0 ]; then echo `date` Ошибка Rsync code is $Code!  >>$LogPrefix/StationBadRSync.$IP ; fi
                    rm include
                    echo `date` выполнили rsync для $Alias >>$log
                    BackupSizeAfterBackup=`du $BackupPath/$Alias -s -b|cut -d/ -f1`
                    echo Size after rsync is `printf "%'.0d" $BackupSizeAfterBackup`, change `printf "%'.0d" $(($BackupSizeAfterBackup  - $BackupSizeBeforeBackup ))`. ALL DONE. >>$log
                    ##########
                    #           
                    # и теперь не забыть все размонтировать!
                    mount | grep -i $MountPath | cut -d' ' -f3 | while read mountline
                    do
                      umount $mountline
                      #echo $mountline
                    done                            
                    echo `date` На работу с $Alias ушло $(( $(date +%s) - $pcStartTime )) сек.   >>$LogPrefix/StationParse.$IP
                 else
                    echo But size $MountPath/$Alias is 0, so exiting. >>$log 
                 fi
              else
                 echo Alas, $MountPath/$Alias has no shares, sad but true. May be move it to Blacklist ? Exiting now.>>$log
              fi
           fi
     fi
  fi
done

echo '######################################################################################' >>$log
echo Finished at `date +"%m-%d-%Y %T"` after [`printf "%'.0d" $(( $(date +%s) - $StartTime ))`] seconds of hard working  >>$log
FreeSize2=`df $BackupPath --block-size=1048576 |tail -n 1 |tr -s "\t " ":" |cut -f4 -d ":"`
NewBackupSize=`du $BackupPath -s -b|cut -d/ -f1`
echo \* Free size of $BackupPath is `printf "%'.0d" $FreeSize2` MB now.  (`printf "%'.0d" $(( $FreeSize1 - $FreeSize2 ))` MB)                           >>$log
echo \* Full size of $BackupPath is `printf "%'.0d" $NewBackupSize` bytes and have delta in [`printf "%'.0d" $(( $NewBackupSize - $StartSize ))`] bytes >>$log
echo That\'s all, folks!                                                                                                                                >>$log
#


   # заархивируем логи, вдруг пригодится
   mkdir -p ./arclogs/`date +%Y`/`date +%m`
   tar -cvzf ./arclogs/`date +%Y`/`date +%m`/`date +%Y-%m-%d.%H-%M-%S`.tar.gz $LogPrefix >  /dev/null

   # оставим только логи за последние 5 дней
   WatchedDir="./logs"
   DirCnt=`ls -1 $WatchedDir | wc -l`
   MaxDirCnt=5

   while [ $DirCnt -gt $MaxDirCnt ]; do
         OlderFile=$(ls -1 -t $WatchedDir | tail -1)
         rm -rf $WatchedDir/$OlderFile
         DirCnt=`ls -1 $WatchedDir | wc -l`
   done
