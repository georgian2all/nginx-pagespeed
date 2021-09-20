#https://www.modpagespeed.com/doc/build_ngx_pagespeed_from_source
# real nginx and nginx pagespeed version
# nginx version which we want to install
NGX_VERSION=1.20.1
# nginx pagespeed version which we want to install
NPS_VERSION=1.13.35.2-stable

# customize nginx display name and version
CUSTOM_SERVER_NAME=berlioz
CUSTOM_NGX_VERSION=ProjectMirela

# nginx modulles to be installed
NGX_MODULES=(with-http_ssl_module with-http_v2_module \
             with-http_gzip_static_module with-threads \
             with-http_realip_module with-http_addition_module \
             with-compat with-http_slice_module)
