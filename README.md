# Creación de un punto de enlace de AWS Client VPN
El presente documento muestra cómo se puede configurar un punto de enlace de AWS Client VPN para realizar conexiones mediante clientes OpenVPN

![AWS Client VPN](/images/client-vpn.png)

## Requerimientos
* Disponer de el software `easyrsa` (https://github.com/OpenVPN/easy-rsa) instalado en la máquina cliente
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

        
4. Se define la región donde se va crear la infraestructura:

        REGION=us-east-1

5. Se importan los certificados de cliente y del servicio Client VPN a AWS Certificate Manager (ACM):

        certserver=$(aws acm import-certificate --certificate fileb://~/certs/server.crt --private-key fileb://~/certs/server.key --certificate-chain fileb://~/certs/ca.crt --output text --region $REGION)
        certclient=$(aws acm import-certificate --certificate fileb://~/certs/client.domain.tld.crt --private-key fileb://~/certs/client.domain.tld.key --certificate-chain fileb://~/certs/ca.crt --output text --region $REGION)

6. Modificamos el archivo authentication.json para incluir el certificado del cliente. Utilizaremos este archivo durante el proceso de creación del punto de enlace de Client VPN:

        cd aws-client-vpn
        sed -i 's|<certificado-cliente>|'$certclient'|g' conf/authentication.json

7. A continuación, crearemos un grupo de logs en Amazon CloudWatch para registrar las conexiones de los clientes VPN:

        aws logs create-log-group --log-group-name client-vpn-log --region $REGION

8. Ahora se creará una infraestructura de VPC altamente disponible (en dos zonas de disponibilidad) para, posteriormente, definir dos interfaces de red para el punto de enlace de ClientVPN. Esta infraestructura dispondrá de dos subredes privadas, dos subredes públicas y dos Gatewa NAT. Para simplificar la tarea, se utilizará una plantilla de AWS CloudFormation (ubicada en `vpc/vpc.yaml`). Si no se tie

        aws cloudformation deploy --template-file vpc/vpc.yaml --stack client-vpn-stack --parameter-overrides file://vpc/client-vpn.json --region $REGION

9. A continuación, se define el punto de enlace de Client VPN en la VPC por defecto. El punto de enlace aceptará conexiones por el puerto 1194 UDP (OpenVPN). Se utilizará la red 10.8.0.0/24 para el túnel:

        vpcId=$(aws cloudformation describe-stacks --stack-name client-vpn-stack --query 'Stacks[].Outputs[?OutputKey==`VPC`].OutputValue' --output text --region $REGION)
        vpnId=$(aws ec2 create-client-vpn-endpoint --client-cidr-block 10.8.0.0/22 --server-certificate-arn $certserver --authentication-options file://conf/authentication.json --connection-log-options file://conf/log-options.json --transport-protocol udp --vpn-port 1194 --vpc-id $vpcId --query ClientVpnEndpointId --output text --region $REGION)

10. Ahora falta asociar las subredes donde residirán la interfaces de red del punto de enlace. Es una buena práctica crear múltiples asociaciones en subredes (de preferencia privadas) en diferentes zonas de disponibilidad para crear múltiples interfaces para el punto de enlace de Client VPN:
        
        subnet1=$(aws cloudformation describe-stacks --stack-name client-vpn-stack --query 'Stacks[].Outputs[?OutputKey==`Privada1`].OutputValue' --output text --region $REGION)

        subnet2=$(aws cloudformation describe-stacks --stack-name client-vpn-stack --query 'Stacks[].Outputs[?OutputKey==`Privada2`].OutputValue' --output text --region $REGION)

        aws ec2 associate-client-vpn-target-network --client-vpn-endpoint $vpnId --subnet-id $subnet1 --region $REGION

        aws ec2 associate-client-vpn-target-network --client-vpn-endpoint $vpnId --subnet-id $subnet2 --region $REGION
        
11. En unos minutos, se habrán vinculado las interfaces de red en las subredes anteriores al punto de enlace de Client VPN. Sin embargo no se tendrá acceso a ninguna ubicación. Es por ello que se necesita añadir una autorización a un bloque CIDR; en este caso se va a permitir todo el direccionamiento hacia Internet (`0.0.0.0/0`):

        aws ec2 authorize-client-vpn-ingress --client-vpn-endpoint-id $vpnId --target-network-cidr 0.0.0.0/0 --authorize-all-groups --region $REGION 

12. Ahora falta añadir las rutas estáticas a la tabla de rutas del punto de enlace de Client VPN. Para ello, vinculamos la ruta estática `0.0.0.0/0` en cada una de las subredes (privadas) donde exista un interfaz del punto de enlace de Client VPN:

        aws ec2 create-client-vpn-route --client-vpn-endpoint-id $vpnId --destination-cidr-block 0.0.0.0/0 --target-vpc-subnet-id $subnet1 --region $REGION

        aws ec2 create-client-vpn-route --client-vpn-endpoint-id $vpnId --destination-cidr-block 0.0.0.0/0 --target-vpc-subnet-id $subnet2 --region $REGION

13. Tras realizar los pasos anteriores, ya estaría configurado el punto de enlace de Client VPN. A continuación, se descarga el archivo de configuración para el cliente de OpenVPN:

        aws ec2 export-client-vpn-client-configuration --client-vpn-endpoint-id $vpnId --output text --region $REGION > mivpn.ovpn

14. El archivo descargado necesita algunas modificaciones, entre otras incorporar el certificado de cliente y la clave privada de cliente. Para ello, hay configurado un <em>script</em> `ovpn.sh`. Para ejecutar el script anterior:

        chmod 750 ovpn.sh
    
        ./ovpn.sh
        
15. Por último, importar el perfil del archivo mivpn.ovpn con el cliente OpenVPN elegido.

16. Lanzar una instancia EC2 en la VPC creada (asignándole el grupo de seguridad default) y comprobar la conectividad desde la máquina local.  

17. Ejecutar el comando `route -n` para comprobar que la ruta por defecto tiene como puerta de enlace la IP del túnel creado por la conexión contra el punto de enlace de Client VPN. 
