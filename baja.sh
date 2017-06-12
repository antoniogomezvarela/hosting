#!/bin/bash
read -p "Nombre de dominio a eliminar(dominio.com): " dominio

noexistedominio=$(mysql -u proftpd -pproftpd -D hosting -s -N -e "select ftpuser.dominio from ftpuser where ftpuser.dominio='$dominio'")

if [ -z $noexistedominio ];
then
	echo "El dominio no existe"
else
	echo "Dominio existente"

	#Base de datos
	usuario=$(mysql -u proftpd -pproftpd -D hosting -s -N -e "select ftpuser.userid from ftpuser where ftpuser.dominio='$dominio'")
	mysql -u root -proot -D hosting -s -N -e "drop database $usuario"
	mysql -u root -proot -D hosting -s -N -e "drop user '$usuario'@'%'"
	mysql -u root -proot -D hosting -s -N -e "delete from ftpuser where userid='$usuario' limit 1"
	mysql -u root -proot -D hosting -s -N -e "delete from ftpgroup where members='$usuario' limit 1"
	echo "Datos de MySQL borrados"
	
	#DNS
	rm /var/cache/bind/db.$usuario
	sed -i "/$dominio/d" /etc/bind/named.conf.local
	rm /etc/bind/$dominio.conf
	systemctl restart bind9
	echo "Dominio borrado"

	#Apache
	a2dissite $dominio
	rm -rf /var/www/$usuario
	rm /etc/apache2/sites-available/$dominio.conf
	systemctl restart apache2
	echo "VirtualHost borrado"
fi