# Creación de un punto de enlace de AWS Client VPN
El presente documento muestra cómo se puede configurar un punto de enlace de AWS Client VPN

![AWS Client VPN](/images/client-vpn.png)

## Requerimientos
Disponer de el software easyrsa (https://github.com/OpenVPN/easy-rsa) instalado en la máquina cliente

## Instrucciones
1. Si no se ha realizado ya, es necesario crear una nueva PKI (Public Key Infrastructure) y una CA (Certificate Authority) para emitir certificados de confianza:
    $ easyrsa init
    $ easyrsa build-ca nopass
3. 
