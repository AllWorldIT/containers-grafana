#!/bin/bash
# Copyright (c) 2022-2025, AllWorldIT.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.


fdc_notice "Setting up Grafana permissions"

# Make our run directory if it doesn't already exist
if [ ! -d /run/grafana ]; then
	mkdir /run/grafana
fi
chown grafana:grafana /run/grafana
chmod 0750 /run/grafana

for i in \
		/var/lib/grafana/conf/provisioning{,/datasources,/plugins,/notifiers,/alerting,/dashboards} \
		/var/lib/grafana/{alerting,grafana-apiserver,csv,db,plugins,png} \
		; do
	if [ ! -d "$i" ]; then
		mkdir -p "$i"
	fi
	chown grafana:grafana "$i"
	chmod 0750 "$i"
done
chown root:grafana /etc/grafana
chmod 750 /etc/grafana


fdc_notice "Initializing Grafana settings"

if [ ! -e /etc/grafana/grafana.ini ]; then
	cp /usr/local/share/grafana/conf/sample.ini /etc/grafana/grafana.ini
	# Fix issue where Grafana fails to start, we need to listen on [::]
	sed -i -e 's/^;http_addr\s*=.*/http_addr = ::/' /etc/grafana/grafana.ini
fi
chown grafana:grafana /etc/grafana/grafana.ini
chmod 0640 /etc/grafana/grafana.ini


# Default to disable snapshots
GRAFANA_SNAPSHOTS_ENABLED=${GRAFANA_SNAPSHOTS_ENABLED:false}

if [ -z "$GRAFANA_SECURITY_SECRET_KEY" ] && ! grep -q "^secret_key\s*=" /etc/grafana/grafana.ini; then
		fdc_error "Grafana secret key MUST be specified, ie. using GRAFANA_SECURITY_SECRET_KEY env"
		false
fi

# Write out environment and fix perms of the config file
set | grep -E '^GRAFANA_' | sed -e 's/^GRAFANA_/GF_/' > /run/grafana/grafana.env || true
chown root:grafana /run/grafana/grafana.env
chmod 0640 /run/grafana/grafana.env

fdc_notice "Setting up Grafana permissions"
chown -R root:grafana /var/lib/grafana
find /var/lib/grafana -type d -print0 | xargs -0 -r chmod 0775
find /var/lib/grafana -type f -print0 | xargs -0 -r chmod 0664
find /var/lib/grafana -type f -print0 | xargs -0 -r chown grafana:grafana
