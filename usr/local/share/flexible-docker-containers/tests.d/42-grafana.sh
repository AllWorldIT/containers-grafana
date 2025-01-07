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


fdc_test_start grafana "Testing default configuration"
for c in \
	"data = /var/lib/grafana" \
	"plugins = /var/lib/grafana/plugins" \
	"provisioning = /var/lib/grafana/conf/provisioning" \
	"logs = /var/log/grafana" \
	"path = db/grafana.db" \
	"reporting_enabled = false" \
	"check_for_updates = false" \
	"feedback_links_enabled = false" \
	"content_security_policy = true" \
	"verify_email_enabled = true" \
	"mode = console\$" \
	"hide_version = true\$" \
	"http_addr = ::\$" \
	; do

		fdc_test_progress grafana "Checking default config: $c"
		if ! grep -q "$c" /usr/local/share/grafana/conf/defaults.ini; then
			fdc_test_fail grafana "Failed default config: $c"
			false
		fi
done
fdc_test_pass grafana "Default configuration tests passed"
