# Number of downloads:
zgrep -E --no-filename 'kodapp\.com.+/download/' /var/log/lighttpd/access.* | wc -l

# All accesses to the appcast.xml file:
zgrep -E --no-filename 'kodapp\.com.+/appcast\.xml' /var/log/lighttpd/access.* > kod-appcast.log

# Number of 0.0.3 installations (counting unique IPs):
grep 'Kod/0.0.3' kod-appcast2.log | awk '{print $1}' | sort -u | wc -l

