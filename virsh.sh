#!/usr/bin/env bash
#Autor: María Jesús Alloza
#Versión: 1.0
#Descripción: Virtualización en Linux 
#Fecha de Creación: 24-10-2022
#Fecha de Modificación: 1/11/2022

#Zona de declaración de funciones.

#Fin de declaración de funciones.

#Función finalizar script
function f_inicio {
    echo " "
    echo "###########################################################################"
    echo "############################### Bienvenid@ ################################"
    echo "###########################################################################"
    echo " "
    echo " En este script vamos a configurar una máquina virtual."
    echo " ¡Comencemos! "
    echo " "
}

#Función comprobar conexión.
function f_internet {
    echo "##########################################################################"
    echo "######################## Comprobando conexión... #########################"
    echo "##########################################################################"
    echo " "
    ping -c 1 8.8.8.8 &> /dev/null
    if  [[ $? -eq 0 ]]; then
        echo "Conexión establecida."
        sleep 1
        return 0;
    else
        echo "No hay conexión a internet."
        exit 1;
    fi
}

#Función comprobar virsh instalado
function f_virsh {
    echo " "
    echo "##########################################################################"
    echo "################# Comprobando si virsh está instalado... #################"
    echo "##########################################################################"
    echo " "
    virsh -v &> /dev/null
    if [[ $? -eq 0 ]]; then
        echo "Virsh está instalado."
        sleep 1
        return 0;
    else
        echo "Virsh no está instalado."
        read -p "El paquete QEMU/KVM + libvirt no esta instalado. ¿Quieres instarlarlo? (Y/N): " var    
                if [[ $var = "Y" ]]; then
                if f_internet ; then
                        if apt update -y qemu-system libvirt-clients libvirt-daemon-system &> /dev/null ; then
                                apt install -y  &> /dev/null
                                echo "Paquete instalado."
                        else
                                echo "No es posible conectar con el repositorios."
                                exit 1;
                        fi
                fi
            else
                echo "Necesita el paquete para continuar."
                exit 1;
            fi
    fi
}

#Function redimensionar qcow2
function f_redimensionar {
    echo " "
    echo "##########################################################################"
    echo "################## Redimensionamos la imagen qcow2... ####################"
    echo "##########################################################################"
    echo " "
    qemu-img create -f qcow2 -b bullseye-spare.qcow2 maquina1.qcow2 5G &> /dev/null
    cp maquina1.qcow2 newmaquina1.qcow2 &> /dev/null
    virt-resize --expand /dev/sda1 maquina1.qcow2 newmaquina1.qcow2 &> /dev/null
    mv newmaquina1.qcow2 maquina1.qcow2 &> /dev/null
    echo "Imagen redimensionada."
}

#Función crear red interna
function f_crear_red {
    echo " "
    echo "##########################################################################"
    echo "########################  Creando red interna... #########################"
    echo "##########################################################################"
    echo " "
    virsh net-list --all | grep -i "intra" &> /dev/null
    if [[ $? -eq 0 ]]; then
        echo "La red intra existe."
        return 0;
    else
        echo "La red intra no existe."
        echo "Creando red intra..."
        echo "<network>
        <name>intra</name>
        <bridge name='virb30'/>
        <forward/>
        <ip address='10.10.20.1' netmask='255.255.255.0'>
        <dhcp>
            <range start='10.10.20.2' end='10.10.20.254'/>
        </dhcp>
        </ip>
        </network>" > intra.xml
        virsh -c qemu:///system net-define intra.xml
        virsh -c qemu:///system net-start intra
        virsh -c qemu:///system net-autostart intra
        echo "Red intra creada."
    fi
}

#Función crear imagen con 5 GB
function f_crear_imagen {
    echo " "
    echo "###########################################################################"
    echo "##################### Creando imagen maquina1.qcow2... ####################"
    echo "###########################################################################"
    echo " "
    virt-install --connect qemu:///system \
    --noautoconsole \
    --name maquina1 \
    --os-variant debian10 \
    --memory 1024 \
    --vcpus 1 \
    --disk path=maquina1.qcow2 \
    --network default \
    --network network=intra \
    --import
    if [ -d $maquina1 ]; then
        echo "La imagen se ha creado correctamente."
        return 0;
    else
        echo "No se ha podido crear la imagen."
        exit 1;
    fi
}

#Función arrancar la máquina
function f_iniciar_máquina {
    echo " "
    echo "##########################################################################"
    echo "######################### Arrancando máquina... ########################## "
    echo "##########################################################################"
    echo " "
    virsh -c qemu:///system autostart maquina1
    sleep 20
        echo "La máquina se ha arrancado correctamente."
        return 0;
}

#Función mostrar ip de la máquina1
function f_mostrar_ip {
    echo " "
    echo "##########################################################################"
    echo "##################### Mostrando ip de la máquina1...######################"
    echo "##########################################################################"
    echo " "
    ip=$(virsh -c qemu:///system domifaddr maquina1 | grep '192.168.122' | awk '{print $4}' | cut -d '/' -f1)
    echo "La ip de la máquina1 es $ip"
    return 0;
}

#Función modificar hostname "maquina1"
function f_modificar_hostname {
    echo " "
    echo "##########################################################################"
    echo "################## Modificando hostname... ###############################"
    echo "##########################################################################"
    echo " "
    ssh -i ~/.ssh/id_ecdsa debian@$ip "sudo hostnamectl set-hostname maquina1"
    echo "Nombre modificado correctamente."
        return 0;
}

#Función reinicar máquina
function f_reiniciar_máquina {
    echo " "
    echo "##########################################################################"
    echo "###################### Reiniciando máquina... ############################"
    echo "##########################################################################"
    echo " "
    virsh -c qemu:///system reboot maquina1 &> /dev/null
    sleep 15
    echo "La máquina se ha reiniciado correctamente."
    return 0;
}

#Función crear volumen formato RAW de 1 GB
function f_crear_volumen {
    echo " "
    echo "##########################################################################"
    echo "############ Creando volumen formato RAW de 1GB de tamaño... #############"
    echo "##########################################################################"
    echo " "
    virsh -c qemu:///system vol-create-as default volumen1 1G --format raw
    sleep 5
    if [[ $(virsh -c qemu:///system vol-list default | grep volumen1 | awk '{print $1}') = "volumen1" ]]; then
        echo "El volumen se ha creado correctamente."
        return 0;
    else
        echo "No se ha podido crear el volumen."
        exit 1;
    fi
}

#Función montar volumen en la máquina1 en /var/www/html con formato XFS
function f_montar_volumen {
    echo " "
    echo "###########################################################################"
    echo "### Montando volumen en la máquina1 en /var/www/html con formato XFS... ###"
    echo "###########################################################################"
    echo " "
    virsh -c qemu:///system attach-disk maquina1 /var/lib/libvirt/images/volumen1 vdb --targetbus virtio --persistent &> /dev/null
    ssh -i ~/.ssh/id_ecdsa debian@$ip "sudo mkfs.xfs -f /dev/vdb" &> /dev/null
    sleep 3
    ssh -i ~/.ssh/id_ecdsa debian@$ip "sudo mkdir -p /var/www/html && sudo mount /dev/vdb /var/www/html" &> /dev/null
    ssh -i ~/.ssh/id_ecdsa debian@$ip "sudo chown -R www-data:www-data /var/www/html && sudo chmod -R 755 /var/www/html" &> /dev/null
    ssh -i ~/.ssh/id_ecdsa debian@$ip "sudo su -c 'echo "/dev/vdb /var/www/html xfs defaults 0 0" >> /etc/fstab'" &> /dev/null
    virsh -c qemu:///system reboot maquina1 &> /dev/null
    echo "Volumen montado correctamente."
    sleep 15
    return 0;
}

#Función instalar apache
function f_instalar_apache {
    echo " "
    echo "###########################################################################"
    echo "########################## Instalando apache... ###########################"
    echo "###########################################################################"
    echo " "
    ssh -i ~/.ssh/id_ecdsa debian@$ip "sudo apt update" &> /dev/null
    sleep 8
    if [[ $(ssh -i ~/.ssh/id_ecdsa debian@$ip "sudo apt install apache2 -y" &> /dev/null) ]]; then
        echo "Apache instalado correctamente."
        return 0;
    else
        ssh -i ~/.ssh/id_ecdsa debian@$ip "sudo apt install apache2 -y" &> /dev/null
        echo "Apache instalado correctamente."
        return 0;
    fi
}

#Función copiar index.html en /var/www/html
function f_copiar_index {
    echo " "
    echo "###########################################################################"
    echo "################## Copiando index.html en /var/www/html... ################"
    echo "###########################################################################"
    ssh -i ~/.ssh/id_ecdsa debian@$ip "touch index.html && sudo chmod 755 index.html"
    ssh -i ~/.ssh/id_ecdsa debian@$ip "sudo echo '<html>
    <body>
    <h1>Comprobacion de virtualizacion</h1>
    <p>Esta maquina es virtual</p>
    </body>
    </html>' > index.html"
    echo "Index creado correctamente."
    echo "Copiando index.html en /var/www/html..."
    ssh -i ~/.ssh/id_ecdsa debian@$ip "sudo mv index.html /var/www/html/index.html"
    echo "Index.html copiado correctamente."
        return 0;
}

#Función mostrar ip y pausar script
function f_comprobar_acceso {
    echo " "
    echo "###########################################################################"
    echo "################## Comprobando acceso al servidor web... ##################"
    echo "###########################################################################"
    echo "La ip de la máquina1 es $ip"
    echo "Comprueba que puedes acceder a la máquina1 desde el navegador."
    firefox http://$ip
    echo "Pulsa una tecla para continuar..."
    read
}

#Función instalar LXC y crear contenedor
function f_instalar_lxc {
    echo " "
    echo "###########################################################################"
    echo "################## Instalando LXC y creando contenedor... #################"
    echo "###########################################################################"
    echo " "
    echo "Instalando LXC..."
    echo "Puede tardar unos minutos..."
    ssh -i ~/.ssh/id_ecdsa debian@$ip "sudo apt update && sudo apt upgrade -y" &> /dev/null
    sleep 15
    echo "Solo un momento..."
    ssh -i ~/.ssh/id_ecdsa debian@$ip "sudo apt install -y lxc" &> /dev/null
    if [[ $? -eq 0 ]]; then
        echo "LXC instalado correctamente."
        if [[ $(ssh -i ~/.ssh/id_ecdsa debian@$ip "sudo lxc-ls -f | grep contenedor1 | awk '{print $1}'") = "contenedor1" ]]; then
            echo "El contenedor existe."
            return 0;
        else
            ssh -i ~/.ssh/id_ecdsa debian@$ip "sudo lxc-create -t download -n contenedor1 -- -d debian -r buster -a amd64" &> /dev/null
            echo "Contenedor creado correctamente."
            return 0;
        fi
    else
        echo "No se ha podido instalar LXC."
        exit 1;
    fi
}

#Función añadir br0 a la máquina1
function f_añadir_br0 {
    echo " "
    echo "###########################################################################"
    echo "####################### Añadiendo interfaz de red... ######################"
    echo "###########################################################################"
    echo " "
    virsh -c qemu:///system shutdown maquina1
    sleep 15
    virsh -c qemu:///system attach-interface maquina1 bridge br0 --model virtio --config --persistent
    sleep 5
    virsh -c qemu:///system start maquina1
    sleep 15
    echo "Interfaz de red añadida correctamente."
    echo " "
    echo " Configurando interfaz de red..."
    ssh -i ~/.ssh/id_ecdsa debian@$ip "ip a | grep 'enp8s0' | grep -oP 'inet \K[\d.]+'"
    return 0;
}

#Función mostrar ip de br0
function f_mostrar_ip_br0 {
    br0=$(virsh -c qemu:///system domifaddr maquina1 | grep 'br0' | awk '{print $4}' | cut -d "/" -f 1)
    echo "La dirección ip de br0 es : $br0"
    echo "Pulsa una tecla para continuar..."
    read
}

#Función aumentar RAM máquina1
function f_aumentar_ram {
    echo "Aumentando RAM máquina1..."
    virsh -c qemu:///system shutdown maquina1
    sleep 5
    virsh -c qemu:///system setmaxmem maquina1 2G --config
    virsh -c qemu:///system setmem maquina1 2G --config
    virsh -c qemu:///system start maquina1
    sleep 15
    if [[ $(virsh -c qemu:///system dommemstat maquina1 | grep actual | awk '{print $2}') = "2097152" ]]; then
        echo "RAM aumentada correctamente."
        return 0;
    else
        echo "No se ha podido aumentar la RAM."
        exit 1;
    fi
}

#Función crear snapshot
function f_crear_snapshot {
    echo "Creando snapshot..."
    virsh -c qemu:///system shutdown maquina1
    sleep 5
    virsh -c qemu:///system snapshot-create-as maquina1 --name "snapshot1" --description "Snapshot de máquina1" --disk-only --atomic
    if [[ $(virsh -c qemu:///system snapshot-list maquina1 | grep snapshot1 | awk '{print $1}') = "snapshot1" ]]; then
        echo "Snapshot creado correctamente."
        return 0;
    else
        echo "No se ha podido crear el snapshot."
        exit 1;
    fi
}

#Función finalizar script
function f_finalizar {
    echo " "
    echo "###########################################################################"
    echo "####################### Script finalizado correctamente ###################"
    echo "###########################################################################"
    echo " "
}

#Llamada de funciones.
f_inicio
f_internet
f_virsh
f_redimensionar
f_crear_red
f_crear_imagen
f_iniciar_máquina
f_mostrar_ip
f_modificar_hostname
f_reiniciar_máquina
f_crear_volumen
f_montar_volumen
f_instalar_apache
f_copiar_index
f_comprobar_acceso
f_instalar_lxc
f_añadir_br0
f_mostrar_ip_br0
f_aumentar_ram
f_crear_snapshot
f_finalizar
exit 0;
#Fin llamada de funciones
