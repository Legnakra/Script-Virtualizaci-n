# Script-Virtualización

# Virtualización en Linux por medio de script

## ¡Empezamos!
Lo primero que deberemos hacer es:
- Crear la imagen llamada 'bullseye-base.qcow2' con las siguientes características
    - 3GB de tamaño
    - Sistema de ficheros XFS
    - 2 interfaces de red por dhcp
    - Usuario *debian* identificado con contraseña *debian*
    - El usuario no necesita contraseña para utilizar *sudo*

~~~
virt-install --connect qemu:///system
--virt-type kvm \
--name bullseye-base \
--cdrom ISO/debian-11.5.0-amd64-netinst.iso \
--os-variant debian10 \
--disk size=3 \
--network network=default \
--network network=default \
--memory 1024 \
--vcpus 1
~~~

- Modificar el fichero */etc/sudoers* y añadimos:
~~~
debian ALL=(ALL) NOPASSWD: ALL
~~~

- Crear un par de claves con formato edcsa sin frase de paso y agregando la clave pública al usuario debian.
~~~
ssh-keygen -t edcsa -f /home/debian/.ssh/id_edcsa -N
ssh-copy-id -i /home/debian/.ssh/id_edcsa.pub debian@192.168.122.X
~~~

- Instalar el paquete *openssh-server* y reiniciamos el servicio.
~~~
apt install openssh-server
~~~

- Reducir el tamaño de la imagen con *qemu-img*.
~~~
virt-sparsify --compress /var/lib/libvirt/images/bullseye-base.qcow2 /var/lib/libvirt/images/bullseye-spare.qcow2
~~~

## ./virsh.sh
Lo que debe hacer el script es:
1. Crear una imagen que use la imagen reducida de Debian 11 que hemos creado en el paso anterior con 5GB denominada *maquina1-qcow2*.
2. Crear una red llamada *intra* con salida al exterior mediante NAT y su direccionamiento sea 10.10.20.0/24
3. Crear una máquina virtual llamada *maquina1* conectada a la red intra, con 1 GiB de RAM, que utilice como disco raíz maquina1.qcow2 y que se inicie automáticamente. 
4. Modifica el fichero */etc/hostname* con para que la máquina se llame *maquina1*.
5. Crear un volumen adicional de 1 GiB de tamaño en formato RAW ubicado en el pool por defecto.
6. Conectar el volumen a la máquina, con sistema de ficheros XFS 
7. Montar volumen en el directorio /var/www/html.
8. Instalar apache2 y reiniciar el servicio.
9. Copiar un fichero *index.html* en el directorio /var/www/html.
10. Mostrar la ip de la máquina y pausar la ejecución del script. 
11. Comprobar que el fichero *index.html* se puede acceder desde el navegador.
12. Instalar LXC y crear un contenedor llamado *contenedor1*.
13. Anadir interfaz de red conectada a br0.
14. Mostrar ip del br0.
15. Aumentar la memoria RAM de la máquina a 2GB.
16. Crear una snapshot de la máquina llalmada *snapshot1*.

## Una vez ejecutado y finalizado...
1. Comprobar que la máquina tienen montado el disco en */var/www/html*.
~~~
ssh -i ~/.ssh/id_edcsa debian@10.10.20.X "df -h"
~~~

2. Mostrar que se ha ampliado la RAM de la máquina.
~~~
ssh -i ~/.ssh/id_edcsa debian@10.10.20.X "free -h"
~~~

3. Mostrar que se puede acceder a contenedor1.
~~~
ssh debian@10.10.20.X "sudo lxc-start -n contenedor1 && sudo lxc-attach -n contenedor1"
~~~

4. Mostrar que se ha creado snapshot1.
~~~
virsh -c qemu:///system snapshot-list maquina1
~~~

## Para que funcione...
- El script debe tener permisos de ejecución.
- El script debe estar en el mismo directorio que el fichero bullseye-spare.qcow2.

## Autora :computer:
* María Jesús Alloza Rodríguez
* :school:I.E.S. Gonzalo Nazareno :round_pushpin:(Dos Hermanas, Sevilla).
