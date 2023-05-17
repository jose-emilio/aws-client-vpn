#!/bin/bash
echo "<cert>" >> mivpn2.ovpn
cat mivpn2.ovpn certs/client.domain.tld.crt > aux.ovpn
echo "</cert>" >> aux.ovpn
echo "<key>" >> aux.ovpn
cat aux.ovpn certs/client.domain.tld.key > mivpn2.ovpn
echo "</key>" >> mivpn2.ovpn
echo "route 0.0.0.0/0" >> mivpn2.ovpn
echo "dhcp-option DNS 8.8.8.8" >> mivpn2.ovpn
rm aux.ovpn