#!/bin/bash

# $1=NombreUsuario
# $2=ftp/sql
# $3=contraseña

noexisteusuario=$(mysql -u proftpd -pproftpd -D hosting -s -N -e "select ftpuser.userid from ftpuser where ftpuser.userid='$1'")

if [ -z $noexisteusuario ];
then
    # Usuario valido
    echo "El usuario no existe"
else
	# Usuario existente
	if [ $2="-sql" ];
	then
		echo "Cambiando contraseña sql del usuario" $1
		mysql -u root -proot -s -N -e "set password for '$1'@'%' = password('$3')"
		echo "Contraseña sql cambiada"
	elif [ $2="-ftp" ]
	then
		echo "Cambiando contraseña ftp del usuario" $1
		passmd5=$(/bin/echo "{md5}"`/bin/echo -n "$3" | openssl dgst -binary -md5 | openssl enc -base64`)
		mysql -u proftpd -pproftpd -D hosting -s -N -e "update ftpuser set passwd='$passmd5' where userid='$1'"
		echo "Contraseña ftp cambiada"
	else
		echo "Se necesita el argumento -sql o -ftp"
	fi
fi