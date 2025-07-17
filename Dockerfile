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


FROM registry.conarx.tech/containers/alpine/3.22 as builder


ENV GRAFANA_VER=12.0.2
#ENV GRAFANA_EXTRA_VER=
#ENV GRAFANA_EXTRA_DIR=
ENV GRAFANA_EXTRA_VER=+security-01
ENV GRAFANA_EXTRA_DIR=-security-01

COPY --from=registry.conarx.tech/containers/go/3.22:1.24.4 /opt/go-1.24.4 /opt/go-1.24.4
COPY --from=registry.conarx.tech/containers/nodejs/3.22:22.16.0 /opt/nodejs-22.16.0 /opt/nodejs-22.16.0

COPY patches /build/patches


# Install libs we need
RUN set -eux; \
	true "Installing build dependencies"; \
# from https://git.alpinelinux.org/aports/tree/main/pdns/APKBUILD
	apk add --no-cache \
		build-base \
		\
		git \
		sqlite-dev \
		\
		freetype \
		fontconfig \
		ghostscript-fonts \
		\
# For NodeJS
		ca-certificates \
		icu-libs \
		libuv

# Download packages for Grafana
RUN set -eux; \
	mkdir -p build; \
	true "Download Grafana..."; \
	cd build; \
	wget "https://github.com/grafana/grafana/archive/refs/tags/v${GRAFANA_VER}${GRAFANA_EXTRA_VER}.tar.gz" -O "grafana-${GRAFANA_VER}.tar.gz"; \
	tar -zxf "grafana-${GRAFANA_VER}.tar.gz"

# Patch Grafana
RUN set -eux; \
	cd build; \
	true "Patching Grafana..."; \
	cd "grafana-${GRAFANA_VER}${GRAFANA_EXTRA_DIR}"; \
	patch -p1 < ../patches/grafana-10.1.0_remove-advertising.patch; \
	patch -p1 < ../patches/grafana-10.1.0_remove-footer.patch; \
	patch -p1 < ../patches/grafana-10.1.0_remove-enterprise-cloud-plugins.patch

# Build and install Grafana
RUN set -eux; \
	cd build; \
	# Setup environment
	for i in /opt/*/ld-musl-x86_64.path; do \
		cat "$i" >> /etc/ld-musl-x86_64.path; \
	done; \
	for i in /opt/*/PATH; do \
		export PATH="$(cat "$i"):$PATH"; \
	done; \
	# Install Yarn
	npm install --global yarn; \
	#
	# Build Grafana
	#
	cd "grafana-${GRAFANA_VER}${GRAFANA_EXTRA_DIR}"; \
	# Compiler flags
	. /etc/buildflags; \
	export GOFLAGS="-buildmode=pie -trimpath -modcacherw"; \
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
	install -dm755 "/build/grafana-root/var/lib/grafana/pdf"; \
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



FROM registry.conarx.tech/containers/postfix/3.22


ARG VERSION_INFO=

LABEL org.opencontainers.image.authors   = "Nigel Kukard <nkukard@conarx.tech>"
LABEL org.opencontainers.image.version   = "3.22"
LABEL org.opencontainers.image.base.name = "registry.conarx.tech/containers/postfix/3.22"


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
