# Creación de un punto de enlace de AWS Client VPN
El presente documento muestra cómo se puede configurar un punto de enlace de AWS Client VPN

![AWS Client VPN](/images/client-vpn.png)

## Requerimientos
* Disponer de el software easyrsa (https://github.com/OpenVPN/easy-rsa) instalado en la máquina cliente
* Disponer de un acceso programático configurado a los servicios de AWS

## Instrucciones
1. Si no se ha realizado ya, es necesario crear una nueva PKI (<em>Public Key Infrastructure</em>) y una CA (<em>Certificate Authority</em>) para emitir certificados de confianza.
    
        /usr/share/easy-rsa/easyrsa init-pki
        /usr/share/easy-rsa/easyrsa build-ca nopass
        
    Completar el proceso indicando el <em>Common Name</em>
    
2. Generar las claves RSA privada y pública para el servicio de AWS Client VPN:

        /usr/share/easy-rsa/easyrsa build-server-full server nopass
        
3. Generar las claves RSA privada y pública para el cliente OpenVPN:

        /usr/share/easy-rsa/easyrsa build-client-full client.domain.tld nopass 
    
3. Organizar la estructura de los certificados y claves generados:

        mkdir ~/certs/
        cp pki/ca.crt ~/certs/
        cp pki/issued/server.crt ~/certs/
        cp pki/private/server.key ~/certs/
        cp pki/issued/client.domain.tld.crt ~/certs/
        cp pki/private/client.domain.tld.key ~/certs/
        cd ~/certs/
        
4. 
