#!/usr/bin/env bash

# Based on http://cran.rstudio.com/bin/linux/ubuntu/
# and script on jupyterhub site

# print commands and their expanded arguments
set -x

# Fail if anything goes wrong
set -e 

DOMAIN=${domain}
ADMIN_EMAIL=${admin_email}

# clone this repo so we have any helper scripts (e.g. add_users.sh) available if we SSH onto the VM
# for creation of users and other management.
cd /opt
git clone https://github.com/HSPH-QBRC/JupyteRStudioHub.git

apt-get update

apt install -y --no-install-recommends \
  build-essential \
  software-properties-common \
  dirmngr \
  git \
  nginx \
  libcairo2-dev \
  python3-dev \
  python3-pip \
  pkg-config \
  libjpeg-turbo8-dev \
  libblas-dev \
  liblapack-dev \
  gfortran \
  libxml2-dev \
  libcurl4-openssl-dev \
  cmake \
  libbz2-dev \
  liblzma-dev \
  libharfbuzz-dev \
  libfribidi-dev \
  libfreetype6-dev \
  libpng-dev \
  libtiff5-dev \
  libjpeg-dev \
  libfftw3-dev \
  texlive-fonts-recommended texlive-fonts-extra texlive-latex-extra

################# Install jupyterlab + hub ###################################
cd /opt/JupyteRStudioHub
pip3 install -U pip
pip3 install --no-cache-dir -r ./requirements.txt

# The following allows dynamic 3-d plotting
curl -sL https://deb.nodesource.com/setup_18.x | /usr/bin/bash -
apt-get install -y nodejs
jupyter labextension install @jupyter-widgets/jupyterlab-manager jupyter-matplotlib

npm install -g configurable-http-proxy

cd /opt
mkdir -p /opt/jupyterhub/etc/jupyterhub
cd /opt/jupyterhub/etc/jupyterhub
/usr/local/bin/jupyterhub --generate-config

# Edit the jupyterhub config file:
sed -i "s?^# c.JupyterHub.bind_url = 'http://:8000'?c.JupyterHub.bind_url = 'http://:8000/jupyter'?g" /opt/jupyterhub/etc/jupyterhub/jupyterhub_config.py
sed -i "s?^# c.Spawner.default_url = ''?c.Spawner.default_url = '/lab'?g" /opt/jupyterhub/etc/jupyterhub/jupyterhub_config.py

# Setup jupyterhub as a service
mkdir -p /opt/jupyterhub/etc/systemd
cat > /opt/jupyterhub/etc/systemd/jupyterhub.service<<"EOF"
[Unit]
Description=JupyterHub
After=syslog.target network.target

[Service]
User=root
Environment="PATH=/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin"
ExecStart=/usr/local/bin/jupyterhub -f /opt/jupyterhub/etc/jupyterhub/jupyterhub_config.py

[Install]
WantedBy=multi-user.target
EOF

# Load and start the service
ln -s /opt/jupyterhub/etc/systemd/jupyterhub.service /etc/systemd/system/jupyterhub.service
systemctl daemon-reload
systemctl enable jupyterhub.service
systemctl start jupyterhub.service

################# Install RStudio ###################################

# add the signing key (by Michael Rutter) for these repos
# To verify key, run gpg --show-keys /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc 
# Fingerprint: 298A3A825C0D65DFD57CBB651716619E084DAB9
wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | sudo tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc

# add the R 4.0 repo from CRAN 
add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/"

# Finally, install R
apt-get install -y --no-install-recommends r-base

# Install rstudio
apt-get install gdebi-core
cd /opt
wget https://download2.rstudio.org/server/jammy/amd64/rstudio-server-2023.06.1-524-amd64.deb
gdebi -n rstudio-server-2023.06.1-524-amd64.deb

# Install the R kernel for jupyterlab:
/usr/bin/R -e 'install.packages(c("IRkernel")); IRkernel::installspec(user = FALSE)'


################ nginx server configuration #####################################
# install certbot so we can roll a SSL cert:
snap install core
snap refresh core
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot

# stop nginx, otherwise it's using port 80 and certbot will fail
service nginx stop

# now run certbot
certbot certonly -n --agree-tos --email $ADMIN_EMAIL --standalone --domains $DOMAIN

# The location of the files created by certbot:
SSL_CERT=/etc/letsencrypt/live/$DOMAIN/fullchain.pem
SSL_CERT_KEY=/etc/letsencrypt/live/$DOMAIN/privkey.pem

# Removing the existing default conf and create an nginx conf file
rm /etc/nginx/sites-enabled/default

# Create an nginx config for both sites. Include automatic
# https redirects
cat > /etc/nginx/sites-enabled/jupyterstudio.conf <<EOF

map \$http_upgrade \$connection_upgrade {
  default upgrade;
  ''        close;
}

server {
  listen 80 default_server;
  listen [::]:80 default_server;
  server_name _;
  return 301 https://\$host\$request_uri;
}

server {

  listen                    443 ssl;
  server_name               $DOMAIN;
  ssl_certificate         $SSL_CERT;
  ssl_certificate_key $SSL_CERT_KEY;

  location /rstudio/ {    
      rewrite ^/rstudio/(.*)\$ /\$1 break;
      proxy_pass http://localhost:8787;
      proxy_redirect http://localhost:8787/ \$scheme://\$host/rstudio/;
      proxy_http_version 1.1;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection \$connection_upgrade;
      proxy_read_timeout 20d;
      proxy_set_header X-Forwarded-Host \$host;
  }

  location /jupyter/ {    
    # NOTE important to also set base url of jupyterhub to /jupyter in its config
    proxy_pass http://localhost:8000;
    proxy_redirect http://localhost:8000/ \$scheme://\$host/jupyter/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$connection_upgrade;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
  }
}
EOF

service nginx restart
