#!/bin/bash

# http://nagios.sourceforge.net/docs/nagioscore/4/en/quickstart-ubuntu.html

LogFile=~/nagiosInstall.log

echo '#### Поехали! ####' > $LogFile
echo 'Обновим пакеты' >> $LogFile

START=$(date +%s)
apt-get -y update
echo 'на apt-get -y update потрачено '$(( $(date +%s) - $START )) ' сек.' >> $LogFile   

START=$(date +%s)
apt-get -y upgrade
echo 'на apt-get -y upgrade потрачено '$(( $(date +%s) - $START )) ' сек.' >> $LogFile   




echo '#' >> $LogFile   
echo 'Скачиваем Nagios и его комопоненты' >> $LogFile   
# http://www.nagios.org/download/core/thanks/?t=1382782730
ver_nagios=4.0.7

# отсюда http://sourceforge.net/projects/nagiosplug/files/nagiosplug/
# http://www.nagios.org/download/plugins/
# https://www.nagios-plugins.org/download.html
# https://www.nagios-plugins.org/download/nagios-plugins-1.5.tar.gz
ver_plugins=2.0.3

# PNP is an addon for the Nagios Network Monitoring System. 
# PNP provides easy to use, easy to configure RRDTools based performance charts 
# feeded by the performance data output of the Nagios Plugins.
# отсюда http://sourceforge.net/projects/pnp4nagios/files/PNP-0.6/
ver_pnp4nagios=0.6.24


# отсюда http://sourceforge.net/projects/nconf/files/nconf
# http://citylan.dl.sourceforge.net/project/nconf/nconf/1.3.0-0/nconf-1.3.0-0.tgz
ver_nconf=1.3.0-0

nagios_file=nagios-${ver_nagios}.tar.gz
plugins_file=nagios-plugins-${ver_plugins}.tar.gz
pnp4nagios_file=pnp4nagios-${ver_pnp4nagios}.tar.gz
nconf_file=nconf-${ver_nconf}.tgz

mkdir nagios-install
cd nagios-install

#######################################################################
# Скачиваем
#######################################################################
echo 'Скачиваем Nagios'
START=$(date +%s)
if [ ! -e $nagios_file ]; then
   wget http://prdownloads.sourceforge.net/sourceforge/nagios/$nagios_file
   echo 'Скачали '$nagios_file $?>> $LogFile    
else
   echo $nagios_file 'уже есть'>> $LogFile
fi
##
echo 'Скачиваем NagiosPlugins'
START=$(date +%s)
if [ ! -e $plugins_file ]; then
   wget https://www.nagios-plugins.org/download/$plugins_file
   echo 'Скачали '$plugins_file $?>> $LogFile
else
   echo $plugins_file 'уже есть'>> $LogFile
fi
##
echo 'Скачиваем pnp4Nagios'
START=$(date +%s)
if [ ! -e $pnp4nagios_file ]; then
   #wget http://citylan.dl.sourceforge.net/project/pnp4nagios/PNP-0.6/$pnp4nagios_file
   wget   http://downloads.sourceforge.net/project/pnp4nagios/PNP-0.6/$pnp4nagios_file
   echo 'Скачали '$pnp4nagios_file $?>> $LogFile
else
   echo $pnp4nagios_file 'уже есть'>> $LogFile
fi
##
echo 'Скачиваем NConf'
START=$(date +%s)
if [ ! -e $nconf_file ]; then
   wget http://citylan.dl.sourceforge.net/project/nconf/nconf/$ver_nconf/$nconf_file
   echo 'Скачали '$nconf_file $?>> $LogFile
else
   echo $nconf_file 'уже есть'>> $LogFile
fi
#######################################################################
# Скачали, работаем дальше?
#######################################################################
if [ -e ~/OnlyDownload ]; then
   exit 1
fi


#######################################################################
echo 'Установим требующиеся пакеты' >> $LogFile
START=$(date +%s)
#apt-get -y install build-essential apache2 php5-gd libgd2-xpm-dev php5 libapache2-mod-php5 libssl-dev apache2-utils
# libgd2-xpm ???

apt-get -y install apache2 libapache2-mod-php5 build-essential daemon apache2-utils php5-gd php5 libssl-dev apache2-utils
echo 'ServerName MyApache' >> /etc/apache2/apache2.conf

Code=$?
echo 'Пакеты установили.  Код '$Code >> $LogFile
if [ $Code -ne 0 ]; then echo 'Ошибка '$Code'! Смотри в лог!'; exit 1; fi



#######################################################################
# Скачали, разархивируем
#######################################################################
if [ -e $nagios_file ]; then
   START=$(date +%s)
   gzip -dc $nagios_file         | tar xvf -
   echo 'Развернули файл '$nagios_file $?>> $LogFile
else
   echo 'Файла '$nagios_file' нет' >> $LogFile   
fi
###
if [ -e $plugins_file ]; then
   START=$(date +%s) 
   gzip -dc $plugins_file| tar xvf -
   echo 'развернули файл '$plugins_file $?>> $LogFile
else
   echo 'Файла '$plugins_file' нет' >> $LogFile   
fi
###
if [ -e $pnp4nagios_file ]; then
   START=$(date +%s)
   gzip -dc $pnp4nagios_file    | tar xvf -
   echo 'развернули файл '$pnp4nagios_file $?>> $LogFile
else
   echo 'Файла '$pnp4nagios_file' нет' >> $LogFile   
fi
###
if [ -e $nconf_file ]; then
   START=$(date +%s)
   tar -zxvf $nconf_file -C /var/www
   echo 'Развернули файл '$nconf_file $?>> $LogFile
   exit
else
   echo 'Файла '$nconf_file' нет' >> $LogFile   
fi
#######################################################################


## теперь создаем пользователя Nagios
START=$(date +%s)
echo 'Создаем пользователя nagios' >> $LogFile   
echo 'Создаем пользователя nagios, задаем пароль'
/usr/sbin/useradd -m -s /bin/bash nagios >> $LogFile   
echo 'Введи пароль пользователя Nagios, тупица!'
#passwd nagios
groupadd nagcmd                   >> $LogFile   
usermod -a -G nagcmd nagios       >> $LogFile   
usermod -a -G nagcmd www-data     >> $LogFile   

#######################################################################
## Ставим ssmtp
#######################################################################
START=$(date +%s)
sudo apt-get -y install ssmtp
Code=$?
echo 'Поставили ssmtp' $Code>> $LogFile   
if [ $Code -ne 0 ]; then echo 'Ошибка '$Code'! Смотри в лог!'; exit 1; fi

echo mailhub=smtp.rambler.ru     >  /etc/ssmtp/ssmtp.conf
echo hostname=MyTestNagiosServer >> /etc/ssmtp/ssmtp.conf
echo FromLineOverride=YES        >> /etc/ssmtp/ssmtp.conf
echo UseTLS=NO                   >> /etc/ssmtp/ssmtp.conf
echo AuthUser=atvnord@rambler.ru >> /etc/ssmtp/ssmtp.conf
echo AuthPass=12341234           >> /etc/ssmtp/ssmtp.conf

# для отсылки из командной строки
echo root:atvnord@rambler.ru:smtp.rambler.ru   >  /etc/ssmtp/revaliases
# для отсылки из под нагиоса сраного, два дня 
echo nagios:atvnord@rambler.ru:smtp.rambler.ru >> /etc/ssmtp/revaliases

mv /usr/sbin/sendmail /usr/sbin/sendmail.original
ln -s /usr/sbin/ssmtp /usr/sbin/sendmail

echo 'Отправляем тестовое письмо' >> $LogFile   
printf test | /usr/sbin/ssmtp  adkins@nwgsm.ru -r This-Is-A-Test -s TestLetter
Code=$?
echo 'тестовое письмо отправлено '$Code >> $LogFile   
if [ $Code -ne 0 ]; then echo 'Ошибка '$Code'! Смотри в лог!'; exit 1; fi

########################################################################


#######################################################################
## начинается компиляция NAGIOS
#######################################################################
cd nagios-${ver_nagios}
echo '#### Настраиваем Nagios ####'>> $LogFile   
START=$(date +%s)
./configure --with-nagios-group=nagios    \
            --with-command-group=nagcmd   \
            --with-mail=/usr/bin/sendmail \
            --with-httpd-conf=/etc/apache2/conf-enabled 

Code=$?
echo 'Настроили Nagios '$Code >> $LogFile   
if [ $Code -ne 0 ]; then echo 'Ошибка '$Code'! Смотри в лог!'; exit 1; fi

echo '### Компилим Nagios ###' >> $LogFile   
START=$(date +%s)
make all
Code=$?
echo 'Компиляция Nagios all завершена '$Code >> $LogFile   
if [ $Code -ne 0 ]; then echo 'Ошибка '$Code'! Смотри в лог!'; exit 1; fi

START=$(date +%s)
make install
Code=$?
echo 'Компиляция Nagios install завершена '$Code >> $LogFile   
if [ $Code -ne 0 ]; then echo 'Ошибка '$Code'! Смотри в лог!'; exit 1; fi

START=$(date +%s)
make install-init
Code=$?
echo 'Компиляция Nagios instll-init завершена '$Code >> $LogFile   
if [ $Code -ne 0 ]; then echo 'Ошибка '$Code'! Смотри в лог!'; exit 1; fi

START=$(date +%s)
make install-config
Code=$?
echo 'Компиляция Nagios install-config завершена '$Code >> $LogFile   
if [ $Code -ne 0 ]; then echo 'Ошибка '$Code'! Смотри в лог!'; exit 1; fi

make install-commandmode
Code=$?
echo 'Компиляция Nagios install-commandmode завершена '$Code >> $LogFile   
if [ $Code -ne 0 ]; then echo 'Ошибка '$Code'! Смотри в лог!'; exit 1; fi

make install-webconf
Code=$?
echo 'Компиляция Nagios install-webconf завершена '$Code >> $LogFile   
if [ $Code -ne 0 ]; then echo 'Ошибка '$Code'! Смотри в лог!'; exit 1; fi

echo 'Добавим  cgi_module в апач '$Code >> $LogFile   
echo 'LoadModule cgi_module /usr/lib/apache2/modules/mod_cgi.so' >> /etc/apache2/conf-enabled/nagios.conf
if [ $Code -ne 0 ]; then echo 'Ошибка '$Code'! Смотри в лог!'; exit 1; fi


###############################################################################

cp -R contrib/eventhandlers/ /usr/local/nagios/libexec/
chown -R nagios:nagios /usr/local/nagios/libexec/eventhandlers

echo 'Создаем пользователя nagiosadmin' >> $LogFile   
htpasswd -c -b /usr/local/nagios/etc/htpasswd.users nagiosadmin 12341234
Code=$?
echo 'Создали пользователя nagiosadmin '$Code >> $LogFile   
if [ $Code -ne 0 ]; then echo 'Ошибка '$Code'! Смотри в лог!'; exit 1; fi

ln -s /etc/init.d/nagios /etc/rcS.d/S99nagios
Code=$?
echo 'регистрация сервиса nagios '$Code >> $LogFile   
if [ $Code -ne 0 ]; then echo 'Ошибка '$Code'! Смотри в лог!'; exit 1; fi


#######################################################################
## начинается компиляция NAGIOS-Plugins
#######################################################################

cd ../nagios-plugins-${ver_plugins}

echo 'Настраиваем Nagios Plugins' >> $LogFile   
./configure --with-nagios-user=nagios --with-nagios-group=nagios
Code=$?
echo 'Настроили Nagios Plugins '$Code >> $LogFile   
if [ $Code -ne 0 ]; then echo 'Ошибка '$Code'! Смотри в лог!'; exit 1; fi

echo 'Компилим Nagios Plugins' >> $LogFile   
make
Code=$?
echo 'Компиляция Nagios Plugins '$Code >> $LogFile   
if [ $Code -ne 0 ]; then echo 'Ошибка '$Code'! Смотри в лог!'; exit 1; fi

make install
Code=$?
echo 'Компиляция Nagios Plugins install '$Code >> $LogFile   
if [ $Code -ne 0 ]; then echo 'Ошибка '$Code'! Смотри в лог!'; exit 1; fi

############  Установка RRD #######################################################################
echo 'Установка RRD ' >> $LogFile   
apt-get -y install rrdtool
Code=$?
echo 'Установили RRD '$Code >> $LogFile   
if [ $Code -ne 0 ]; then echo 'Ошибка '$Code'! Смотри в лог!'; exit 1; fi


#######################################################################
## начинается компиляция pnp4NAGIOS
#######################################################################
cd ../pnp4nagios-${ver_pnp4nagios}

echo 'Настраиваем pnp4Nagios' >> $LogFile   
./configure
Code=$?
echo 'Настроили pnp4Nagios '$Code >> $LogFile   
if [ $Code -ne 0 ]; then echo 'Ошибка '$Code'! Смотри в лог!'; exit 1; fi

echo 'Компилим pnp4Nagios all' >> $LogFile   
make all
Code=$?
echo 'Компиляция pnp4Nagios '$Code >> $LogFile   
if [ $Code -ne 0 ]; then echo 'Ошибка '$Code'! Смотри в лог!'; exit 1; fi

make install
Code=$?
echo 'Компиляция pnp4Nagios install '$Code >> $LogFile   
if [ $Code -ne 0 ]; then echo 'Ошибка '$Code'! Смотри в лог!'; exit 1; fi

make install-config
Code=$?
echo 'Компиляция pnp4Nagios install-config '$Code >> $LogFile   
if [ $Code -ne 0 ]; then echo 'Ошибка '$Code'! Смотри в лог!'; exit 1; fi

cp ./sample-config/httpd.conf /etc/apache2/conf-enabled/pnp4nagios.conf

#######################################################################

### первичная настройка nagios
echo '#'                                >> /usr/local/nagios/etc/nagios.cfg
echo '###'                              >> /usr/local/nagios/etc/nagios.cfg
echo '### Ну, добавим своего, пожалуй ' >> /usr/local/nagios/etc/nagios.cfg
echo '###'                              >> /usr/local/nagios/etc/nagios.cfg
echo process_performance_data=1         >> /usr/local/nagios/etc/nagios.cfg
echo service_perfdata_file=/usr/local/pnp4nagios/var/service-perfdata >> /usr/local/nagios/etc/nagios.cfg
echo service_perfdata_file_template=DATATYPE::SERVICEPERFDATA\\tTIMET::\$TIMET\$\\tHOSTNAME::\$HOSTNAME\$\\tSERVICEDESC::\$SERVICEDESC\$\\tSERVICEPERFDATA::\$SERVICEPERFDATA\$\\tSERVICECHECKCOMMAND::\$SERVICECHECKCOMMAND\$\\tHOSTSTATE::\$HOSTSTATE\$\\tHOSTSTATETYPE::\$HOSTSTATETYPE\$\\tSERVICESTATE::\$SERVICESTATE\$\\tSERVICESTATETYPE::\$SERVICESTATETYPE\$ >> /usr/local/nagios/etc/nagios.cfg
echo service_perfdata_file_mode=a                                              >> /usr/local/nagios/etc/nagios.cfg
echo service_perfdata_file_processing_interval=15                              >> /usr/local/nagios/etc/nagios.cfg
echo service_perfdata_file_processing_command=process-service-perfdata-file    >> /usr/local/nagios/etc/nagios.cfg

echo '#'                                                        >> /usr/local/nagios/etc/nagios.cfg
echo '###'                                                      >> /usr/local/nagios/etc/nagios.cfg
echo host_perfdata_file=/usr/local/pnp4nagios/var/host-perfdata >> /usr/local/nagios/etc/nagios.cfg
echo host_perfdata_file_template=DATATYPE::HOSTPERFDATA\\tTIMET::\$TIMET\$\\tHOSTNAME::\$HOSTNAME\$\\tHOSTPERFDATA::\$HOSTPERFDATA\$\\tHOSTCHECKCOMMAND::\$HOSTCHECKCOMMAND\$\\tHOSTSTATE::\$HOSTSTATE\$\\tHOSTSTATETYPE::\$HOSTSTATETYPE\$ >> /usr/local/nagios/etc/nagios.cfg
echo host_perfdata_file_mode=a                                                 >> /usr/local/nagios/etc/nagios.cfg
echo host_perfdata_file_processing_interval=15                                 >> /usr/local/nagios/etc/nagios.cfg
echo host_perfdata_file_processing_command=process-host-perfdata-file          >> /usr/local/nagios/etc/nagios.cfg

echo '#'                                                     >> /usr/local/nagios/etc/nagios.cfg
echo '###'                                                   >> /usr/local/nagios/etc/nagios.cfg
echo define command{                                         >>/usr/local/nagios/etc/objects/my-commands.cfg 
echo       command_name process-service-perfdata-file        >>/usr/local/nagios/etc/objects/my-commands.cfg
echo        command_line /usr/local/pnp4nagios/libexec/process_perfdata.pl --bulk=/usr/local/pnp4nagios/var/service-perfdata >>/usr/local/nagios/etc/objects/my-commands.cfg
echo }                                                       >>/usr/local/nagios/etc/objects/my-commands.cfg  
echo define command{                                         >>/usr/local/nagios/etc/objects/my-commands.cfg
echo        command_name process-host-perfdata-file          >>/usr/local/nagios/etc/objects/my-commands.cfg
echo       command_line /usr/local/pnp4nagios/libexec/process_perfdata.pl --bulk=/usr/local/pnp4nagios/var/host-perfdata >>/usr/local/nagios/etc/objects/my-commands.cfg
echo }                                                       >>/usr/local/nagios/etc/objects/my-commands.cfg
echo '################################################'      >> /usr/local/nagios/etc/nagios.cfg
echo '#'                                                     >> /usr/local/nagios/etc/nagios.cfg

###############################################################################
###  ставим MySQL
echo 'ставим MySQL' >> $LogFile   
# задаем админский пароль на доступ к MySql
apt-get -y install mysql-server
Code=$?
echo 'Поставили MySQL '$Code >> $LogFile   
if [ $Code -ne 0 ]; then echo 'Ошибка '$Code'! Смотри в лог!'; exit 1; fi


###############################################################################
###  ставим phpMyAdmin
echo 'ставим phpMyAdmin' >> $LogFile   
# введем пароли доступа к MySql и зададим пароль доступа к PhpMyAdmin
apt-get -y install phpmyadmin
Code=$?
echo 'Поставили phpMyAdmin '$Code >> $LogFile   
if [ $Code -ne 0 ]; then echo 'Ошибка '$Code'! Смотри в лог!'; exit 1; fi
###############################################################################



###############################################################################
###  Немножко шаманства!!
###############################################################################
# 1
# отсюда http://blog.nicolargo.com/2013/10/nagios-4-resoudre-lerreur-cant-open-etcrc-dinit-dfunctions.html

sudo sed -i 's/^\.\ \/etc\/rc.d\/init.d\/functions$/\.\ \/lib\/lsb\/init-functions/g' /etc/init.d/nagios
sudo sed -i 's/status\ /status_of_proc\ /g' /etc/init.d/nagios
sudo sed -i 's/daemon\ --user=\$user\ \$exec\ -ud\ \$config/daemon\ --user=\$user\ --\ \$exec\ -d\ \$config/g' /etc/init.d/nagios
sudo sed -i 's/\/var\/lock\/subsys\/\$prog/\/var\/lock\/\$prog/g' /etc/init.d/nagios
sudo sed -i 's/\/sbin\/service\ nagios\ configtest/\/usr\/sbin\/service\ nagios\ configtest/g' /etc/init.d/nagios

#sudo sed -i 's/\"\ \=\=\ \"/\"\ \=\ \"/g' /etc/init.d/nagios
#sudo sed -i 's/\#\#killproc\ \-p\ \$\{pidfile\}\ \-d\ 10/killproc\ \-p \$\{pidfile\}/g' /etc/init.d/nagios

sudo sed -i 's/runuser/su/g' /etc/init.d/nagios

###############################################################################
###  теперь запустим все это
echo 'Запускаем  Nagios' >> $LogFile   
service nagios start
echo 'Запустили Nagios '$? >> $LogFile   

chmod 666 /usr/local/nagios/var/nagios.log

a2enmod rewrite
echo 'Запускаем  Apache' >> $LogFile   
service apache2 start
echo 'Запустили Apache '$? >> $LogFile   



###############################################################################
###  Шаманство продолжается 
###############################################################################










######################################################
echo 'Создаем базу и пользователя nConf' >> $LogFile   
mysql -u root -p12341234 <<EOF
 CREATE USER nconf@localhost IDENTIFIED BY '12341234';
 GRANT USAGE ON * . * TO nconf@localhost IDENTIFIED BY '12341234' WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0 ;
 CREATE DATABASE IF NOT EXISTS nconf;
 GRANT ALL PRIVILEGES ON nconf.* TO nconf@localhost;
 quit 
EOF
Code=$?
echo 'Создали базу (пустую) и пользователя nConf '$Code >> $LogFile   
if [ $Code -ne 0 ]; then echo 'Ошибка '$Code'! Смотри в лог!'; exit 1; fi

####################################################
# создаем полную базу NConf
sed -i "s/CHARSET=latin1/CHARSET=utf8/" /var/www/nconf/INSTALL/create_database.sql
mysql -u root -p12341234 nconf < /var/www/nconf/INSTALL/create_database.sql
Code=$?
echo 'Создали полную базу NConf '$Code >> $LogFile   
if [ $Code -ne 0 ]; then echo 'Ошибка '$Code'! Смотри в лог!'; exit 1; fi


# правим базу Nconf, удаляем из нее лишние хосты
#delete from nconf.ConfigValues where fk_id_item='5341' or fk_id_item='5342';
mysql -u root -p12341234 <<EOF
 update nconf.ConfigValues set attr_value='/usr/bin/printf Alarm! | /usr/sbin/ssmtp $\CONTACTEMAIL$\ -r $\HOSTNAME$\-is-$\HOSTSTATE$ -s Nagios-Alarm!' where fk_id_attr=99 and fk_id_item=5327;
 update nconf.ConfigValues set attr_value='/usr/bin/printf Alarm! | /usr/sbin/ssmtp $\CONTACTEMAIL$\ -r $\SERVICEDESC$\-of-$\HOSTALIAS$\-is-$\SERVICESTATE$\ -s Nagios-Alarm!' where fk_id_attr=99 and fk_id_item=5328;  
 update nconf.ConfigAttrs  set poss_values=replace (poss_values,'/nagios/html/pnp4nagios/index.php?','/pnp4nagios/graph?') where attr_name='action_url'; 
 update nconf.ConfigAttrs  set predef_value='1' where attr_name='check_interval'       ;
 update nconf.ConfigAttrs  set predef_value='1' where attr_name='max_check_attempts'   ;
 update nconf.ConfigAttrs  set predef_value='1' where attr_name='retry_interval'       ;
 update nconf.ConfigAttrs  set predef_value='1' where attr_name='notification_interval'; 
commit;
EOF

Code=$?
echo 'Пофиксили базу NConf '$Code >> $LogFile   
if [ $Code -ne 0 ]; then echo 'Ошибка '$Code'! Смотри в лог!'; exit 1; fi
####################################################


# наконец, копируем и правим конфиг NConf
cp /var/www/nconf/config.orig/* /var/www/nconf/config

sed -i "s/nconf/nconf/" /var/www/nconf/config/mysql.php
sed -i "s/NConf/nconf/" /var/www/nconf/config/mysql.php
sed -i "s/link2db/12341234/" /var/www/nconf/config/mysql.php
#
sed -i "s/\$nconfdir/\"\/var\/www\/nconf\"/" /var/www/nconf/config/nconf.php
sed -i "s/\"\/var\/www\/nconf\/bin\/nagios\"/\"\/usr\/local\/nagios\/bin\/nagios\"/" /var/www/nconf/config/nconf.php

# удалим признаки необходимости установки - ведь вроде мы все установили!
rm -fr /var/www/nconf/INSTALL* /var/www/nconf/UPDATE*
# удалим признаки установки pnp4nagios
rm -f /usr/local/pnp4nagios/share/install.php

# здесь будут лежать конфиги, которые создает Nconf 
mkdir /usr/local/nagios/nconfig
chmod 666 /usr/local/nagios/nconfig

# скопируем веселые картинки
cp -R /var/www/nconf/img/logos/base/ /usr/local/nagios/share/images/logos

# чтобы nconf смог записать конфигурацию
chmod -R 666 /var/www/nconf/{config,output,temp,static_cfg}

# это бинарник Nagios, который будет загружать новые конфиги
chmod 777 /usr/local/nagios/bin/nagios

# без этого не проходит deploy
chmod 666 /usr/local/nagios/var/spool/checkresults

# сценарий локального развертывания 
echo [local deploy extract]                               >>/var/www/nconf/config/deployment.ini
echo type        = local                                  >>/var/www/nconf/config/deployment.ini
echo source_file = /var/www/nconf/output/NagiosConfig.tgz >>/var/www/nconf/config/deployment.ini
echo target_file = /usr/local/nagios/nconfig/             >>/var/www/nconf/config/deployment.ini
echo action      = extract                                >>/var/www/nconf/config/deployment.ini
echo reload_command = sudo /etc/init.d/nagios reload      >>/var/www/nconf/config/deployment.ini

##################################################################################################
# отключаем старые конфиги Nagios
sed -i '/#cfg_/!s/cfg_/#cfg_/' /usr/local/nagios/etc/nagios.cfg
#вывод даты ставим европейский
sed -i "s/date_format=us/date_format=euro/" /usr/local/nagios/etc/nagios.cfg

# подключаем новые конфиги Nagios
echo '#'                                                    >> /usr/local/nagios/etc/nagios.cfg
echo '### Подключим свои конфиги'                           >> /usr/local/nagios/etc/nagios.cfg
#echo log_file=/var/log/nagios.log                           >> /usr/local/nagios/etc/nagios.cfg
echo cfg_file=/usr/local/nagios/etc/objects/my-commands.cfg >> /usr/local/nagios/etc/nagios.cfg
echo cfg_dir=/usr/local/nagios/nconfig/global               >> /usr/local/nagios/etc/nagios.cfg
echo cfg_dir=/usr/local/nagios/nconfig/Default_collector    >> /usr/local/nagios/etc/nagios.cfg
##################################################################################################

# это чтобы nagios мог делать config reload 
echo www-data ALL=NOPASSWD: /etc/init.d/nagios reload       >> /etc/sudoers

###
# ну и наконец создадим новые конфиги для Nagios на основе текущих конфигов NConf
###
cd /var/www/nconf/
php include/ajax/exec_generate_config.php >>/dev/null 2>&1
Code=$?
echo 'Генерация конфига NConf '$Code >> $LogFile   
if [ $Code -ne 0 ]; then echo 'Ошибка '$Code'! Смотри в лог!'; exit 1; fi

#############################################################################


###############################################################################
###
###############################################################################

###############################################################################
service apache2 reload >> $LogFile   
echo 'service apache2 restart '$Code >> $LogFile   

service nagios reload   >> $LogFile   
echo 'service nagios reload '$Code   >> $LogFile   
