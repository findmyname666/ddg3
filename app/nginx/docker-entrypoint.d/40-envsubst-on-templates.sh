#!/bin/sh
set -eu

if [ -f /etc/nginx/conf.d/feedduck.conf.template ]; then
  envsubst "\$FQDN" < /etc/nginx/conf.d/feedduck.conf.template > /etc/nginx/conf.d/feedduck.conf
fi
