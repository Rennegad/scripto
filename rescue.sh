mount -o loop SystemRescueCd.iso /mnt/

cp /mnt/sysrcd.* /var/www/

cp /mnt/isolinux/initram.igz /tftpboot/

cp /mnt/isolinux/rescuecd /tftpboot/
