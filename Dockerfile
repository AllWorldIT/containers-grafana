# Copyright (c) 2022-2023, AllWorldIT.
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


FROM registry.conarx.tech/containers/postfix/edge as builder


ENV GRAFANA_VER=10.1.5
ENV GRAFANA_ZABBIX_VER=4.4.3


COPY patches /build/patches


# Install libs we need
RUN set -eux; \
	true "Installing build dependencies"; \
# from https://git.alpinelinux.org/aports/tree/main/pdns/APKBUILD
	apk add --no-cache \
		build-base \
		\
		git \
		go \
		sqlite-dev \
		wire-go \
		nodejs \
		yarn \
		\
		freetype \
		fontconfig \
		ghostscript-fonts


# Download packages
RUN set -eux; \
	mkdir -p build; \
	true "Download Grafana..."; \
	cd build; \
	wget "https://github.com/grafana/grafana/archive/refs/tags/v${GRAFANA_VER}.tar.gz" -O "grafana-${GRAFANA_VER}.tar.gz"; \
	tar -zxf "grafana-${GRAFANA_VER}.tar.gz"; \
	true "Download the Grafana Zabbix plugin..."; \
	wget "https://github.com/alexanderzobnin/grafana-zabbix/archive/v${GRAFANA_ZABBIX_VER}.tar.gz" -O "grafana-zabbix-${GRAFANA_ZABBIX_VER}.tar.gz"; \
	tar -zxf "grafana-zabbix-${GRAFANA_ZABBIX_VER}.tar.gz"; \
	# Clone mage which we need for grafana-zabbix
	git clone --depth=1 https://github.com/magefile/mage


# Patch
RUN set -eux; \
	cd build; \
	true "Patching Grafana..."; \
	cd "grafana-${GRAFANA_VER}"; \
	patch -p1 < ../patches/grafana-10.1.0_remove-advertising.patch; \
	patch -p1 < ../patches/grafana-10.1.0_remove-footer.patch; \
	patch -p1 < ../patches/grafana-10.1.0_remove-enterprise-cloud-plugins.patch


# Build and install Grafana
RUN set -eux; \
	cd build; \
	#
	# Build and install mage, required for grafana-zabbix
	#
	cd mage; \
	GOBIN=~/bin GOPATH=~/.go go run bootstrap.go; \
	export PATH=$PATH:~/bin; \
	#
	# Build Grafana
	#
	cd "../grafana-${GRAFANA_VER}"; \
	# Compiler flags
	. /etc/buildflags; \
	export GOFLAGS="$GOFLAGS -tags=libsqlite3"; \
	# Set default paths
	sed -ri 's,^(\s*data\s*=).*,\1 /var/lib/grafana,' conf/defaults.ini; \
	sed -ri 's,^(\s*plugins\s*=).*,\1 /var/lib/grafana/plugins,' conf/defaults.ini; \
	sed -ri 's,^(\s*provisioning\s*=).*,\1 /var/lib/grafana/conf/provisioning,' conf/defaults.ini; \
	sed -ri 's,^(\s*logs\s*=).*,\1 /var/log/grafana,' conf/defaults.ini; \
	sed -ri 's,^(\s*socket\s*=).*,\1 /run/grafana/grafana.sock,' conf/defaults.ini; \
	sed -ri 's,^(\s*path\s*=)\s*grafana\.db,\1 db/grafana.db,' conf/defaults.ini; \
	sed -ri 's,^;?(\s*reporting_enabled\s*=).*,\1 false,' conf/defaults.ini; \
	sed -ri 's,^;?(\s*check_for_updates\s*=).*,\1 false,' conf/defaults.ini; \
	sed -ri 's,^;?(\s*feedback_links_enabled\s*=).*,\1 false,' conf/defaults.ini; \
	sed -ri 's,^;?(\s*content_security_policy\s*=).*,\1 true,' conf/defaults.ini; \
	sed -ri 's,^;?(\s*verify_email_enabled\s*=).*,\1 true,' conf/defaults.ini; \
	sed -ri 's,^;?(\s*mode\s*=)\s*console file.*,\1 console,' conf/defaults.ini; \
	sed -ri 's,^;?(\s*hide_version\s*=).*,\1 true,' conf/defaults.ini; \
	sed -ri 's,^;?(\s*http_addr\s*=).*,\1 ::,' conf/defaults.ini; \
	# Make go-lang
	make gen-go; \
	# Setup and build
	go run build.go setup; \
	go run build.go build; \
	# Build frontend
	export NODE_OPTIONS="--max-old-space-size=16000"; \
	yarn install || cat /tmp/*/build.log; \
	NODE_ENV=production yarn run build; \
	# Install Grafana
    install -dm755 "/build/grafana-root/etc/grafana"; \
	install -dm755 "/build/grafana-root/usr/local/share/grafana"; \
	install -dm755 "/build/grafana-root/usr/local/share/grafana/conf"; \
	install -dm755 "/build/grafana-root/var/log/grafana"; \
	install -dm755 "/build/grafana-root/var/lib/grafana"; \
	install -dm755 "/build/grafana-root/var/lib/grafana/db"; \
	install -dm755 "/build/grafana-root/var/lib/grafana/plugins"; \
	install -dm755 "/build/grafana-root/var/lib/grafana/conf/provisioning"; \
	install -dm755 "/build/grafana-root/var/lib/grafana/conf/provisioning/alerting"; \
	install -dm755 "/build/grafana-root/var/lib/grafana/conf/provisioning/dashboards"; \
	install -dm755 "/build/grafana-root/var/lib/grafana/conf/provisioning/datasources"; \
	install -dm755 "/build/grafana-root/var/lib/grafana/conf/provisioning/notifiers"; \
	install -dm755 "/build/grafana-root/var/lib/grafana/conf/provisioning/plugins"; \
	install -Dsm755 bin/linux-amd64/grafana "/build/grafana-root/usr/local/bin/grafana"; \
	install -Dsm755 bin/linux-amd64/grafana-server "/build/grafana-rootr/usr/local/bin/grafana-server"; \
	install -Dsm755 bin/linux-amd64/grafana-cli "/build/grafana-root/usr/local/bin/grafana-cli"; \
	cp -r public "/build/grafana-root/usr/local/share/grafana"; \
	cp -r tools "/build/grafana-root/usr/local/share/grafana"; \
	rm -r "/build/grafana-root/usr/local/share/grafana/public/test"; \
	find "/build/grafana-root/usr/local/share/grafana" -name "*.git*" -print0 | xargs -0 rm -v; \
	install -Dm644 conf/defaults.ini "/build/grafana-root/usr/local/share/grafana/conf/defaults.ini"; \
	install -Dm644 conf/sample.ini "/build/grafana-root/usr/local/share/grafana/conf/sample.ini"; \
	install -Dm640 conf/sample.ini "/build/grafana-root/etc/grafana/grafana.ini"; \
	#
	# Build Grafana Zabbix plugin
	# - pulled from grafana-zabbix Makefile
	#
	cd "../grafana-zabbix-${GRAFANA_ZABBIX_VER}"; \
	# Install node and go deps
	yarn install --ignore-engines; \
	go install -v ./pkg/; \
	GO111MODULE=off go get -u golang.org/x/lint/golint; \
	# Build frontend
	NODE_ENV=production yarn run build; \
	# Build backend
	make dist-backend-linux; \
	# Install
	install -dm755 "/build/grafana-root/usr/local/share/grafana/plugins-bundled/alexanderzobnin-zabbix-app"; \
	cp -r dist/* "/build/grafana-root/usr/local/share/grafana/plugins-bundled/alexanderzobnin-zabbix-app"; \
	#
	# Cleanup
	#
	find /build/grafana-root/usr/local/share -name "*.test.*" -print0 | xargs -0 rm -v


RUN set -eux; \
	cd build/grafana-root; \
	scanelf --recursive --nobanner --osabi --etype "ET_DYN,ET_EXEC" .  | awk '{print $3}' | xargs \
		strip \
			--remove-section=.comment \
			--remove-section=.note \
			-R .gnu.lto_* -R .gnu.debuglto_* \
			-N __gnu_lto_slim -N __gnu_lto_v1 \
			--strip-unneeded



FROM registry.conarx.tech/containers/postfix/edge


ARG VERSION_INFO=

LABEL org.opencontainers.image.authors   "Nigel Kukard <nkukard@conarx.tech>"
LABEL org.opencontainers.image.version   "edge"
LABEL org.opencontainers.image.base.name "registry.conarx.tech/containers/postfix/edge"


# Copy in built binaries
COPY --from=builder /build/grafana-root /


RUN set -eux; \
	true "Dependencies"; \
	apk add --no-cache \
		freetype \
		fontconfig \
		ghostscript-fonts; \
	true "Utilities"; \
	apk add --no-cache \
		curl \
		openssl; \
	true "User setup"; \
	addgroup -S grafana 2>/dev/null; \
	adduser -S -D -H -h /var/lib/grafana -s /sbin/nologin -G grafana -g grafana grafana; \
	true "Cleanup"; \
	rm -f /var/cache/apk/*


# Grafana
COPY etc/supervisor/conf.d/grafana.conf /etc/supervisor/conf.d/grafana.conf
COPY usr/local/share/flexible-docker-containers/healthcheck.d/42-grafana.sh /usr/local/share/flexible-docker-containers/healthcheck.d
COPY usr/local/share/flexible-docker-containers/init.d/42-grafana.sh /usr/local/share/flexible-docker-containers/init.d
COPY usr/local/share/flexible-docker-containers/pre-init-tests.d/42-grafana.sh /usr/local/share/flexible-docker-containers/pre-init-tests.d
COPY usr/local/share/flexible-docker-containers/tests.d/42-grafana.sh /usr/local/share/flexible-docker-containers/tests.d
COPY usr/bin/start-grafana /usr/local/bin/start-grafana
RUN set -eux; \
	true "Flexible Docker Containers"; \
	if [ -n "$VERSION_INFO" ]; then echo "$VERSION_INFO" >> /.VERSION_INFO; fi; \
	chown root:root \
		/usr/local/bin/start-grafana; \
	chmod 0755 \
		/usr/local/bin/start-grafana; \
	fdc set-perms

VOLUME ["/var/lib/grafana"]

EXPOSE 3000:3000
