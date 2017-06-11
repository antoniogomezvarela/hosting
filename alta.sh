#!/bin/bash

read -p "Nombre de usuario: " usuario

#Comprobamos que tanto el usuario como el dominio no existe.

noexisteusuario=$(mysql -u proftpd -pproftpd -D hosting -s -N -e "select ftpuser.userid from ftpuser where ftpuser.userid='$usuario'")

if [ -z $noexisteusuario ];
then
        # Usuario valido
        echo "Nombre de usuario disponible"
        read -p "Nombre de dominio(dominio.com): " dominio

        noexistedominio=$(mysql -u proftpd -pproftpd -D hosting -s -N -e "select ftpuser.dominio from ftpuser where ftpuser.dominio='$dominio'")

        if [ -z $noexistedominio ];
        then
                #Dominio valido
                echo "Dominio disponible"

                #MySQL
                #Contraseña ftp
		read -p "Introduce la contraseña para el usuario ftp: " passftp 
		ftpmd5=$(/bin/echo "{md5}"`/bin/echo -n "$passftp" | openssl dgst -binary -md5 | openssl enc -base64`)

		#uid usuario
		maxuid=$(mysql -u proftpd -pproftpd -D hosting -s -N -e "select max(uid) from ftpuser")
		uid=$((maxuid+1))

		#Insertamos los datos en mysql

		mysql -u proftpd -pproftpd -D hosting -s -N -e "insert into ftpuser (userid, passwd, uid, gid, homedir, shell,dominio) values ('$usuario','$ftpmd5','$uid','4000','/var/www/$usuario','/sbin/nologin','$dominio')"
		mysql -u proftpd -pproftpd -D hosting -s -N -e "insert into ftpgroup values ('usuario','4000','$usuario')"

		#Creamos la base de datos para el usuario e introducimos los datos
		read -p "Introduce la contraseña para tu base de datos: " passsql
		mysql -u root -proot -D hosting -s -N -e "create database $usuario"
		mysql -u root -proot -D hosting -s -N -e "create user '$usuario'@'%' identified by '$passsql'"
		mysql -u root -proot -D hosting -s -N -e "grant all privileges on $usuario.* to '$usuario'@'%'"

		echo "Base de datos configurada"

		#Apache
		#Creamos el directorio del usuario
		mkdir -p /var/www/$usuario
		chown -R $uid:www-data /var/www/$usuario
		echo "Pagina de $usuario. En contruccion" > /var/www/$usuario/index.html

		#Creamos el fichero de configuración del dominio
		cat <<-EOF > /etc/apache2/sites-available/$dominio.conf
		<VirtualHost *:80>
	        ServerName www.$dominio
	        ServerAdmin webmaster@localhost
	        DocumentRoot /var/www/$usuario
		</VirtualHost>
		EOF

		#Activamos el virtualhost
		a2ensite $dominio

		#Reiniciamos apache
		systemctl restart apache2

		echo "Apache configurado"

		#phpmyadmin
		ln -s /usr/share/phpmyadmin /var/www/$usuario

		echo "phpmyadmin configurado"

		#DNS
		cat <<-EOF >> /etc/bind/named.conf.local
		include "/etc/bind/$dominio.conf";
		EOF

		cat <<-EOF >> /etc/bind/$dominio.conf
		zone "$dominio" {
     		type master;
     		file "db.$dominio";
		};
		EOF

		cat <<-EOF >> /etc/bind/db.$usuario
		@       IN      SOA     hosting.$dominio. root.localhost. (
                         2         ; Serial
                    604800         ; Refresh
                     86400         ; Retry
                   2419200         ; Expire
                    604800 )       ; Negative Cache TTL
		;
		@               IN      NS      hosting.$dominio.
		hosting  IN     A       172.22.201.18
		www             IN      CNAME   hosting.$dominio.
		ftp             IN      A       172.22.201.18
		mysql           IN      A       172.22.201.18
		correo          IN      A       172.22.201.18
		@               IN      MX      10      correo.$dominio.
		EOF

		#Reiniciamos bind
		systemctl restart bind9

		echo "Dominio configurado"
        else
                #Dominio no valido
                echo "Este dominio ya está en uso"
        fi
else
        # Usuario no valido
        echo "Ya existe un usuario con ese nombre"
fi
