#!/bin/bash
echo "<cert>" >> mivpn.ovpn
cat mivpn.ovpn ~/certs/client.domain.tld.crt > aux.ovpn
echo "</cert>" >> aux.ovpn
echo "<key>" >> aux.ovpn
cat aux.ovpn ~/certs/client.domain.tld.key > mivpn.ovpn
echo "</key>" >> mivpn.ovpn
echo "route 0.0.0.0/0" >> mivpn.ovpn
echo "dhcp-option DNS 8.8.8.8" >> mivpn.ovpn
rm aux.ovpn
