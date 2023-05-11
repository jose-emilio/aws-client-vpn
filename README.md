# Creación de un punto de enlace de AWS Client VPN
El presente documento muestra cómo se puede configurar un punto de enlace de AWS Client VPN

![AWS Client VPN](/images/client-vpn.png)

## Requerimientos
* Disponer de el software easyrsa (https://github.com/OpenVPN/easy-rsa) instalado en la máquina cliente
* Disponer de un acceso programático configurado a los servicios de AWS

## Instrucciones
1. Si no se ha realizado ya, es necesario crear una nueva PKI (<em>Public Key Infrastructure</em>) y una CA (<em>Certificate Authority</em>) para emitir certificados de confianza.
    
        $ /usr/share/easy-rsa/easyrsa init-pki
        $ /usr/share/easy-rsa/easyrsa build-ca nopass
2. Generar las claves RSA privada y la clave pública para el servicio de AWS Client VPN:

        $ easyrsa build-server-full server nopass
        $ easyrsa build-client-full client.domain.tld nopass

    Completar el proceso indicando el Common Name
    
3. Ordenar los certificados
