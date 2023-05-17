# Creación de un punto de enlace de AWS Client VPN
El presente documento muestra cómo se puede configurar un punto de enlace de AWS Client VPN para realizar conexiones mediante clientes OpenVPN

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

        
4. Importar los certificados de cliente y del servicio Client VPN a AWS Certificate Manager (ACM):

        cd ~/certs/
        certserver=$(aws acm import-certificate --certificate fileb://certs/server.crt --private-key fileb://certs/server.key --certificate-chain fileb://certs/ca.crt --output text)
        certclient=$(aws acm import-certificate --certificate fileb://certs/client.domain.tld.crt --private-key fileb://certs/client.domain.tld.key --certificate-chain fileb://certs/ca.crt --output text)

5. Modificamos el archivo authentication.json para incluir el certificado del cliente. Utilizaremos este archivo durante el proceso de creación del punto de enlace de Client VPN:

        sed -i 's|<certificado-cliente>|'$certclient'|g' authentication.json

6. A continuación, crearemos un grupo de logs en Amazon CloudWatch para registrar las conexiones de los clientes VPN:

        aws logs create-log-group --log-group-name client-vpn-log

7. A continuación, se define el punto de enlace de Client VPN en la VPC por defecto. El punto de enlace aceptará conexiones por el puerto 1194 UDP (OpenVPN). Se utilizará la red 10.8.0.0/24 para el túnel:

        vpc=aws ec2 describe-vpcs --filters Name=is-default,Values=true --query Vpcs[].VpcId --output text
        vpnid=$(aws ec2 create-client-vpn-endpoint --client-cidr-block 10.8.0.0/22 --server-certificate-arn $certserver --authentication-options file://authentication.json --connection-log-options file://log-options.json --transport-protocol udp --vpn-port 1194 --vpc-id $vpc --query ClientVpnEndpointId --output text)

8. Ahora falta asociar la subred donde residirá la interfaz de red del punto de enlace. Aunque en este ejemplo sólo se asociará una subred, es una buena práctica crear múltiples asociaciones en subredes en diferentes zonas de disponibilidad para crear múltiples interfaces para el punto de enlace de Client VPN:
        
        subnet=$(aws ec2 describe-subnets --filter Name=vpc-id,Values=$vpc --query Subnets[0].SubnetId --output text)
        aws ec2 associate-client-vpn-target-network --client-vpn-endpoint $vpnid --subnet-id $subnet
        
10. Ya estaría creado el punto de enlace, sin embargo no se tendrá acceso a ninguna ubicación. Es por ello que se necesita añadir una autorización a un bloque CIDR; en este caso se permitirá el acceso a la VPC por defecto (172.31.0.0/16):

        aws ec2 authorize-client-vpn-ingress --client-vpn-endpoint-id $vpnid --target-network-cidr 172.31.0.0/16 --authorize-all-groups 

11. A continuación, se descarga el archivo de configuración para el cliente de OpenVPN:

        aws ec2 export-client-vpn-client-configuration --client-vpn-endpoint-id $vpnid --output text > mivpn.ovpn

13. El archivo descargado necesita algunas modificaciones. Por ello hay que editar el archivo mivpn.ovpn y realizar las siguientes modificaciones:

    Añadir una línea para enrutar el tráfico con destino al bloque CIDR de la VPC:
    
        route 172.31.0.0/16
        
    Añadir un bloque con el contenido del archivo del certificado del cliente, ubicado en ~/certs/client.domain.tld.crt :
        
        <cert>
        -----BEGIN CERTIFICATE-----
        -----END CERTIFICATE-------
        </cert>
 
    Añadir un bloque con el contenido del archivo de la clave privada del cliente, ubicado en ~/certs/client.domain.tld.key :
        
        <key>
        -----BEGIN PRIVATE KEY-----
        -----END PRIVATE KEY-------
        </key>
        
14. Por último, importar el perfil del archivo mivpn.ovpn con el cliente OpenVPN elegido.

15. Lanzar una instancia EC2 en la VPC por defecto (asignándole el grupo de seguridad default) y comprobar la conectividad desde la máquina local.  