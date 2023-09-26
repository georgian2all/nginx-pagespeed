#!/usr/bin/env bash


source config.inc
source utils.inc


SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
WORKDIR=${SCRIPTPATH}"/nginx-setup"

# necessary packages
needed_pkgs=(build-essential libpcre3 libpcre3-dev zlib1g zlib1g-dev libssl-dev libgd-dev libxml2 libxml2-dev uuid-dev)
existing_pkgs=""
missing_pkgs=""

for pkg in ${needed_pkgs[@]}; do
    IsInstalled ${pkg}
    result=$?
    if [[ "${result}" == "1" ]] ; then
        missing_pkgs+=" $pkg"
    else
        existing_pkgs+=" $pkg"
    fi
done

if [ ! -z "$existing_pkgs" ]; then
    echo $(green "This packages are allready installed")
    echo ${existing_pkgs}
fi

if [ ! -z "$missing_pkgs" ]; then
    echo $( red "This packages needs to be installed")
    echo ${missing_pkgs}
    sudo apt install -y $missing_pkgs
fi

if  [ ! -z "$existing_pkgs"  ] && [ -z "$missing_pkgs" ]; then
    echo $( green "We don't need to install any packages.")
    echo $(blue "Proceed to get data from mainstream.")
fi

if [[ -d "${WORKDIR}" ]]; then
    echo $(red "Removing existent work location")
    rm -rf ${WORKDIR}
    echo $(green "Creating new work directory")
    mkdir -p ${WORKDIR}
else
    echo $(green "Creating work directory")
    mkdir -p ${WORKDIR}

fi
echo $(green "Creating work directory")
mkdir -p ${WORKDIR}

cd ${WORKDIR}
#get nginx pagespeed
wget -O- https://github.com/apache/incubator-pagespeed-ngx/archive/v${NPS_VERSION}.tar.gz | tar -xz
nps_dir=$(find ${PWD} -name "*pagespeed-ngx-${NPS_VERSION}" -type d)

cd ${nps_dir}
echo "We are working in ${nps_dir}"
NPS_RELEASE_NUMBER=${NPS_VERSION/beta/}
NPS_RELEASE_NUMBER=${NPS_VERSION/stable/}
psol_url=https://dl.google.com/dl/page-speed/psol/${NPS_RELEASE_NUMBER}.tar.gz
[ -e scripts/format_binary_url.sh ] && psol_url=$(scripts/format_binary_url.sh PSOL_BINARY_URL)
wget -O- ${psol_url} | tar -xz  # extracts to psol/

cd ${WORKDIR}
echo "We are working in ${WORKDIR}"
#get nginx
wget -O- https://nginx.org/download/nginx-${NGX_VERSION}.tar.gz | tar -xz
ngx_dir=$(find ${PWD} -name "*nginx-${NGX_VERSION}" -type d)

cd ${ngx_dir}
echo "We are working in ${ngx_dir}"
CHANGING_FILE_PATH=${ngx_dir}"/src/http/ngx_http_header_filter_module.c"
sed -i "s/Server: nginx/Server: $CUSTOM_SERVER_NAME/g" ${CHANGING_FILE_PATH}

CHANGING_FILE_PATH=${ngx_dir}"/src/core/nginx.h"
# changing delimiter from / to = for a cleaner structure
sed -i "s=nginx/=$CUSTOM_NGX_VERSION/=g" ${CHANGING_FILE_PATH}
sed -i "s=$NGX_VERSION=5891/=g" ${CHANGING_FILE_PATH}
nginx_modules=""

if [ ! -z "${NGX_MODULES}" ]; then
    for module in ${NGX_MODULES[@]}; do
        nginx_modules+=" --$module"
    done
fi
echo $(green "Configure nginx before compile")
./configure --add-dynamic-module=$nps_dir ${PS_NGX_EXTRA_FLAGS} --prefix=/etc/nginx \
            --modules-path=/etc/nginx/modules \
            --sbin-path=/usr/sbin/nginx \
            --conf-path=/etc/nginx/nginx.conf \
            --error-log-path=/var/log/nginx/error.log \
            --http-log-path=/var/log/nginx/access.log \
            --pid-path=/run/nginx.pid \
            --lock-path=/run/nginx.lock \
            --user=nginx \
            --group=nginx \
            --http-client-body-temp-path=/var/cache/nginx/client_temp \
            --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
            --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
            --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
            --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
            ${nginx_modules}
make

sudo make install

if [ $? != 0 ]; then
   echo $(red "Failed to finish installing procedure")
   exit 1
fi

echo $(green "Finished compiling custom nginx with google pagespeed")

rm -rf ${WORKDIR}

echo $(green "Adding nginx user and group")
sudo adduser --system --home /nonexistent --shell /bin/false --no-create-home \
            --disabled-login --disabled-password \
            --gecos "nginx user" --group nginx

echo $(green "Create cache locations")
sudo mkdir -p /var/cache/nginx/client_temp /var/cache/nginx/fastcgi_temp \
              /var/cache/nginx/proxy_temp /var/cache/nginx/scgi_temp \
              /var/cache/nginx/uwsgi_temp
sudo chmod 700 /var/cache/nginx/*
sudo chown nginx:root /var/cache/nginx/*
sudo nginx -t

echo $(green "Create conf.d,snippets,sites-available,sites-enabled folders")
sudo mkdir /etc/nginx/{conf.d,snippets,sites-available,sites-enabled}
if [ $? != 0 ]; then
   echo $(red  "Folders allready in place!")
   echo $(green  "Recreate necessary folders")
   sudo rm -rf /etc/nginx/{conf.d,snippets,sites-available,sites-enabled}
   sudo mkdir /etc/nginx/{conf.d,snippets,sites-available,sites-enabled}
fi

echo $(green "Change permissions and group ownership of nginx log files")
sudo chmod 640 /var/log/nginx/*
sudo chown nginx:adm /var/log/nginx/access.log /var/log/nginx/error.log

echo $(green "Create logrotation config for nginx.")
sudo cp ${SCRIPTPATH}/files/nginx /etc/logrotate.d/nginx

echo $(green "Copy our custom config file in place")
sudo cp ${SCRIPTPATH}/files/nginx.conf /etc/nginx/nginx.conf

echo $(green "Copy our default site config file in place")
sudo cp ${SCRIPTPATH}/files/default /etc/nginx/sites-available/default

if [ $? != 0 ]; then
   echo $(red  "Failed to copy default site config file !")
fi

echo $(green "Enabling default site")
sudo ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
if [ $? != 0 ]; then
   echo $(red  "Default site configuration file allready in place!")
   echo $(green  "Recreate link")
   sudo unlink /etc/nginx/sites-enabled/default
   sudo ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
fi

echo $(green "nginx details")
nginx -V
echo

echo $(green "Service file ... copied in place")
sudo cp ${SCRIPTPATH}/files/nginx.service /lib/systemd/system/nginx.service

if [ $? != 0 ]; then
   echo $(red  "Failed to create service file!")
   exit 1
fi

echo $(green "Reloading daemon")
sudo systemctl daemon-reload
echo $(green "Enabling nginx service")
sudo systemctl enable nginx.service
echo $(green "Starting nginx server")
sudo systemctl start  nginx
echo $(green "Make sure to turn of apache2 server")
sudo service apache2 stop
echo $(green "WE ARE DONE nginx WAS SUCCESFULLY DEPLOYED ON YOUR SYSTEM !")
echo
