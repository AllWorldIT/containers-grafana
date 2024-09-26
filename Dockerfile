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


FROM registry.conarx.tech/containers/postfix/3.20 as builder


ENV GRAFANA_VER=11.2.1
ENV GRAFANA_ZABBIX_VER=4.5.4
ENV GO_VER=1.22.7
ENV NODEJS_VER=20.17.0


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
# For Go
		go-bootstrap \
		\
# For NodeJS
		ca-certificates \
		brotli-dev c-ares-dev icu-dev linux-headers nghttp2-dev openssl-dev python3 py3-jinja2 samurai zlib-dev

# Download Go package
RUN set -eux; \
	mkdir -p build; \
	true "Download Go..."; \
	cd build; \
	wget "https://go.dev/dl/go${GO_VER}.src.tar.gz" -O "go-${GO_VER}.src.tar.gz"; \
	tar -zxf "go-${GO_VER}.src.tar.gz"

# Patch Go
RUN set -eux; \
	cd build; \
	true "Patching Go..."; \
	cd "go"; \
	patch -p1 < ../patches/0001-cmd-link-prefer-musl-s-over-glibc-s-ld.so-during-dyn.patch

# Build Go
# ref: https://git.alpinelinux.org/aports/tree/community/go/APKBUILD
RUN set -eux; \
	cd build; \
	cd "go/src"; \
	\
	export GOOS="linux"; \
	\
	if command -v gccgo >/dev/null 2>&1; then \
		export GOROOT_BOOTSTRAP=/usr; \
	else \
		export GOROOT_BOOTSTRAP=/usr/lib/go; \
	fi; \
	\
	./make.bash -v; \
	\
	apk del go-bootstrap

# Install Go
# ref: https://git.alpinelinux.org/aports/tree/community/go/APKBUILD
RUN set -eux; \
	cd build; \
	cd "go"; \
	ls; \
	pkgdir=""; \
	mkdir -p "$pkgdir"/usr/bin "$pkgdir"/usr/lib/go/bin; \
	\
	for binary in go gofmt; do \
		install -Dm755 bin/"$binary" "$pkgdir"/usr/lib/go/bin/"$binary"; \
		ln -s /usr/lib/go/bin/"$binary" "$pkgdir"/usr/bin/; \
	done; \
	\
	cp -a pkg lib "$pkgdir"/usr/lib/go; \
	\
	mkdir -p "$pkgdir"/usr/lib/go/; \
	cp -a src "$pkgdir"/usr/lib/go; \
	\
	install -Dm644 go.env "$pkgdir"/usr/lib/go/go.env; \
	install -Dm644 VERSION "$pkgdir/usr/lib/go/VERSION"


# Download NodeJS packages
RUN set -eux; \
	mkdir -p build; \
	cd build; \
	wget "https://nodejs.org/dist/v$NODEJS_VER/node-v$NODEJS_VER.tar.gz"; \
	tar -xf "node-v${NODEJS_VER}.tar.gz"

# Build and install Nodejs
# build copied from Mastodon image
RUN set -eux; \
	cd build; \
	cd node-v${NODEJS_VER}; \
# Remove bundled dependencies that we're not using.
# ref: https://git.alpinelinux.org/aports/tree/main/nodejs/APKBUILD
	# openssl.cnf is required for build.
	mv deps/openssl/nodejs-openssl.cnf .; \
	\
	# Remove bundled dependencies that we're not using.
	rm -rf deps/brotli \
		deps/cares \
		deps/corepack \
		deps/openssl/* \
		deps/v8/third_party/jinja2 \
		deps/zlib \
		tools/inspector_protocol/jinja2; \
	\
	mv nodejs-openssl.cnf deps/openssl/; \
# Patching
	patch -p1 < ../patches/nodejs-fix-build-with-system-c-ares.patch; \
# Compiler flags
	export CFLAGS="-D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64"; \
	export CXXFLAGS="-D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64"; \
	export CPPFLAGS="-D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64"; \
	\
# NOTE: We use bundled libuv because they don't care much about backward
# compatibility and it has happened several times in past that we
# couldn't upgrade nodejs package in stable branches to fix CVEs due to
# libuv incompatibility.
#
# NOTE: We don't package the bundled npm - it's a separate project with
# its own release cycle and version numbering, so it's better to keep
# it in a standalone aport.
#
# TODO: Fix and enable corepack.
	python3 configure.py --prefix=/usr \
		--shared-brotli \
		--shared-zlib \
		--shared-openssl \
		--shared-cares \
		--shared-nghttp2 \
		--ninja \
		--openssl-use-def-ca-store \
		--with-icu-default-data-dir=$(icu-config --icudatadir) \
		--with-intl=system-icu; \
	\
# Build, must build without -j or it will fail
	make -l 8 VERBOSE=1 BUILDTYPE=Release; \
# Test
	./node -e 'console.log("Hello, world!")'; \
	./node -e "require('assert').equal(process.versions.node, '$NODEJS_VER')"; \
# Install
	pkgdir=""; \
	make DESTDIR="$pkgdir" install; \
	# Install yarn
	npm install --global yarn

# Download packages for Grafana
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

# Patch Grafana
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
	# Build Grafana Zabbix plugin
	# - pulled from grafana-zabbix Makefile
	#
	cd "../grafana-zabbix-${GRAFANA_ZABBIX_VER}"; \
	# Install node and go deps
	yarn install --ignore-engines; \
	go install -v ./pkg/; \
	go get -u golang.org/x/lint/golint; \
	go get -u golang.org/x/net/idna; \
	# Work around issue
	#   memory_amd64 missing go.sum entry
	go get -u github.com/apache/arrow/go/v15/arrow/memory; \
	go get -u github.com/grafana/grafana-plugin-sdk-go; \
	go get -u go.opentelemetry.io/proto/otlp/common/v1; \
	go get -u github.com/grpc-ecosystem/grpc-gateway/v2/runtime; \
	# Build frontend
	NODE_ENV=production yarn run build; \
	# Build backend
	go get github.com/prometheus/common/expfmt; \
	go get google.golang.org/grpc/internal/transport; \
	go get github.com/grafana/grafana-plugin-sdk-go/backend/proxy; \
	go get github.com/apache/arrow/go/v15/arrow/memory; \
	go get github.com/alexanderzobnin/grafana-zabbix/pkg/zabbixapi; \
	go get github.com/alexanderzobnin/grafana-zabbix/pkg/datasource; \
	\
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



FROM registry.conarx.tech/containers/postfix/3.20


ARG VERSION_INFO=

LABEL org.opencontainers.image.authors   "Nigel Kukard <nkukard@conarx.tech>"
LABEL org.opencontainers.image.version   "3.20"
LABEL org.opencontainers.image.base.name "registry.conarx.tech/containers/postfix/3.20"


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
