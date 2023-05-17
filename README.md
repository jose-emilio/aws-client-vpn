# Creación de un punto de enlace de AWS Client VPN
El presente documento muestra cómo se puede configurar un punto de enlace de AWS Client VPN para realizar conexiones mediante clientes OpenVPN

![AWS Client VPN](/images/client-vpn.png)

## Requerimientos
* Disponer de el software easyrsa (https://github.com/OpenVPN/easy-rsa) instalado en la máquina cliente
* Disponer de un entorno Linux con acceso programático configurado a los servicios de AWS

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


4. Importar los certificados de cliente y del servicio Client VPN a AWS Certificate Manager (ACM):

        cd ~/certs/
        certserver=$(aws acm import-certificate --certificate fileb://certs/server.crt --private-key fileb://certs/server.key --certificate-chain fileb://certs/ca.crt --output text)
        certclient=$(aws acm import-certificate --certificate fileb://certs/client.domain.tld.crt --private-key fileb://certs/client.domain.tld.key --certificate-chain fileb://certs/ca.crt --output text)

5. Modificamos el archivo authentication.json para incluir el certificado del cliente. Utilizaremos este archivo durante el proceso de creación del punto de enlace de Client VPN:

        sed -i 's|<certificado-cliente>|'$certclient'|g' authentication.json

6. A continuación, crearemos un grupo de logs en Amazon CloudWatch para registrar las conexiones de los clientes VPN:

        aws logs create-log-group --log-group-name client-vpn-log

7. A continuación, se define el punto de enlace de Client VPN en la VPC por defecto. El punto de enlace aceptará conexiones por el puerto 1194 UDP (OpenVP
