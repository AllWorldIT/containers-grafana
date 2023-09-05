[![pipeline status](https://gitlab.conarx.tech/containers/grafana/badges/main/pipeline.svg)](https://gitlab.conarx.tech/containers/grafana/-/commits/main)

# Container Information

[Container Source](https://gitlab.conarx.tech/containers/grafana) - [GitHub Mirror](https://github.com/AllWorldIT/containers-grafana)

This is the Conarx Containers Grafana image, it provides the Grafana open source dashboard server.



# Mirrors

|  Provider  |  Repository                             |
|------------|-----------------------------------------|
| DockerHub  | allworldit/grafana                      |
| Conarx     | registry.conarx.tech/containers/grafana |



# Conarx Containers

All our Docker images are part of our Conarx Containers product line. Images are generally based on Alpine Linux and track the
Alpine Linux major and minor version in the format of `vXX.YY`.

Images built from source track both the Alpine Linux major and minor versions in addition to the main software component being
built in the format of `vXX.YY-AA.BB`, where `AA.BB` is the main software component version.

Our images are built using our Flexible Docker Containers framework which includes the below features...

- Flexible container initialization and startup
- Integrated unit testing
- Advanced multi-service health checks
- Native IPv6 support for all containers
- Debugging options



# Community Support

Please use the project [Issue Tracker](https://gitlab.conarx.tech/containers/grafana/-/issues).



# Commercial Support

Commercial support for all our Docker images is available from [Conarx](https://conarx.tech).

We also provide consulting services to create and maintain Docker images to meet your exact needs.



# Environment Variables

Additional environment variables are available from...
* [Conarx Containers Postfix image](https://gitlab.conarx.tech/containers/postfix)
* [Conarx Containers Alpine image](https://gitlab.conarx.tech/containers/alpine)


## GRAFANA_*

Grafana configuration can be specified using the `GRAFANA_section_key` syntax, which differs slightly from the documented
`GF_` on https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/.

Mandatory configuration options...
  * GRAFANA_SECURITY_SECRET_KEY - Must be set to a random string

Strongly suggested configuration options...
  * GRAFANA_SECURITY_COOKIE_SECURE - Must be set to `true` when using HTTPS
  * GRAFANA_STRICT_TRANSPORT_SECURITY - Should be set to `true` when using HTTPS
  * GRAFANA_STRICT_TRANSPORT_SECURITY_PRELOAD - Should be set to `true` when using HTTPS

Configuration items of note are documented below...

Admin user configuration:
  * GRAFANA_ADMIN_USER - Initial admin user, defaults to 'admin'
  * GRAFANA_ADMIN_PASSWORD - Initial admin user password, defaults to 'admin'
  * GRAFANA_ADMIN_EMAIL - Initial admin user email address

Database configuration:
  * GRAFANA_DATABASE_TYPE - Either `postgresql`, `mysql` or `sqlite3`. By default a `sqlite3` database is created in
  `/var/lib/grafana/db`.
  * GRAFANA_DATABASE_HOST - Hostname of database
  * GRAFANA_DATABASE_NAME - Database name
  * GRAFANA_DATABASE_USER - Database user name
  * GRAFANA_DATABASE_PASSWORD - DAtabase user password
  * GRAFANA_DATABASE_URL - Combination of all above options in the format of `mysql://user:secret@host:port/database`

Caching configuration:
  * GRAFANA_REMOTE_CACHE_TYPE - Either `database`, `redis` or `memcached`
  * GRAFANA_REMOTE_CACHE_CONNSTR - Connection string, eg for Redis `addr=127.0.0.1,password=test`



# Volumes


## /var/lib/grafana

Grafana data directory.



# Configuration

Configuration files of note can be found below...

| Path                                                         | Description                                               |
|--------------------------------------------------------------|-----------------------------------------------------------|
| /etc/grafana/grafana.ini                                     | Grafana configuration file                                |


# Customization

Graphics assets can be customized using the below files by bind mounting over them...

| Path                                                         | Description                                               |
|--------------------------------------------------------------|-----------------------------------------------------------|
| /usr/local/share/grafana/public/img/fav32.png                | Favicon                                                   |
| /usr/local/share/grafana/public/img/apple-touch-icon.png     | Favicon                                                   |
| /usr/local/share/grafana/public/img/grafana_icon.svg         | Logo on login page                                        |
| /usr/local/share/grafana/public/img/g8_login_dark.svg        | Login page background image for dark mode                 |
| /usr/local/share/grafana/public/img/g8_login_light.svg       | Login page background image for light mode                |



# Exposed Ports

Grafana port 3000 is exposed.



# Configuration Exampmle


```yaml
version: '3.9'

services:
  grafana:
    image: registry.gitlab.iitsp.com/allworldit/docker/grafana/v3.18:latest
    environment:
      - GRAFANA_SECURITY_SECRET_KEY=12345678901234567890123456789012
    volumes:
      - ./data:/var/lib/grafana
    ports:
      - '3000:3000'
    networks:
      - internal

networks:
  internal:
    driver: bridge
    enable_ipv6: true
```