#!/bin/bash
apt-get update -y && apt-get install -y nginx awscli curl
echo "<h1>NovaSphere - ${environment}</h1><p>$(hostname)</p>" > /var/www/html/index.html
systemctl enable --now nginx
curl -fsSL -o /tmp/ssm.deb https://s3.${region}.amazonaws.com/amazon-ssm-${region}/latest/debian_amd64/amazon-ssm-agent.deb && dpkg -i /tmp/ssm.deb && systemctl enable --now amazon-ssm-agent
mkdir -p /etc/novasphere
aws ssm get-parameter --region ${region} --name /novasphere/${environment}/db_password \
  --with-decryption --query Parameter.Value --output text > /etc/novasphere/app.conf
chmod 0640 /etc/novasphere/app.conf
