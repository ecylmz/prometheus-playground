export DEBIAN_FRONTEND=noninteractive

# prometheus & node_exporter user
useradd --no-create-home --shell /bin/false prometheus
useradd --no-create-home --shell /bin/false node_exporter

cd /tmp

# standart
echo "Standart packages installing..."
apt-get install -y vim git build-essential curl apt-transport-https > /dev/null 2>&1

# prometheus
echo "Prometheus installing..."
echo "3aa063498ab3b4d1bee103d80098ba33d02b3fed63cb46e47e1d16290356db8a prometheus-2.4.3.linux-amd64.tar.gz" > prometheus-2.4.3.linux-amd64.tar.gz.sha256
wget --quiet https://github.com/prometheus/prometheus/releases/download/v2.4.3/prometheus-2.4.3.linux-amd64.tar.gz

CHECKSUM_STATE=$(echo -n "$(sha256sum -c prometheus-2.4.3.linux-amd64.tar.gz.sha256)" | tail -c 2)
if [ "$CHECKSUM_STATE" != "OK"  ]
then
	echo "Warning! Checksum does not match!"
	exit 1
else
	tar xvfz prometheus-2.4.3.linux-amd64.tar.gz > /dev/null 2>&1
fi

# copy binary prometheus files
cp prometheus-2.4.3.linux-amd64/prometheus /usr/local/bin/
cp prometheus-2.4.3.linux-amd64/promtool /usr/local/bin/

chown prometheus:prometheus /usr/local/bin/prometheus
chown prometheus:prometheus /usr/local/bin/promtool

# alertmanager
echo "Alertmanager installing..."
echo "79ee23ab2f0444f592051995728ba9e0a7547cc3b9162301e3152dbeaf568d2e alertmanager-0.15.2.linux-amd64.tar.gz" > alertmanager-0.15.2.linux-amd64.tar.gz.sha256
wget --quiet https://github.com/prometheus/alertmanager/releases/download/v0.15.2/alertmanager-0.15.2.linux-amd64.tar.gz

CHECKSUM_STATE=$(echo -n "$(sha256sum -c alertmanager-0.15.2.linux-amd64.tar.gz.sha256)" | tail -c 2)
if [ "$CHECKSUM_STATE" != "OK"  ]
then
	echo "Warning! Checksum does not match!"
	exit 1
else
	tar xvfz alertmanager-0.15.2.linux-amd64.tar.gz > /dev/null 2>&1
fi

# copy binary prometheus files
cp alertmanager-0.15.2.linux-amd64/alertmanager /usr/local/bin/
cp alertmanager-0.15.2.linux-amd64/amtool /usr/local/bin/

chown prometheus:prometheus /usr/local/bin/alertmanager
chown prometheus:prometheus /usr/local/bin/amtool

mkdir /var/lib/prometheus
mkdir /var/lib/prometheus_alertmanager

chown -R prometheus:prometheus /var/lib/prometheus
chown -R prometheus:prometheus /var/lib/prometheus_alertmanager

ln -s /vagrant/prometheus /etc/prometheus

chown -R prometheus:prometheus /etc/prometheus/

ln -s /vagrant/systemd/prometheus.service /etc/systemd/system/prometheus.service
ln -s /vagrant/systemd/alertmanager.service /etc/systemd/system/alertmanager.service
systemctl daemon-reload

systemctl start prometheus
systemctl enable prometheus > /dev/null 2>&1
systemctl start alertmanager
systemctl enable alertmanager > /dev/null 2>&1

# node_exporter
echo "node_exporter installing..."
echo "e92a601a5ef4f77cce967266b488a978711dabc527a720bea26505cba426c029 node_exporter-0.16.0.linux-amd64.tar.gz" > node_exporter-0.16.0.linux-amd64.tar.gz.sha256
wget --quiet https://github.com/prometheus/node_exporter/releases/download/v0.16.0/node_exporter-0.16.0.linux-amd64.tar.gz

CHECKSUM_STATE=$(echo -n "$(sha256sum -c node_exporter-0.16.0.linux-amd64.tar.gz.sha256)" | tail -c 2)
if [ "$CHECKSUM_STATE" != "OK"  ]
then
    echo "Warning! Checksum does not match!"
    exit 1
else
    tar xvfz node_exporter-0.16.0.linux-amd64.tar.gz > /dev/null 2>&1
fi

cp node_exporter-0.16.0.linux-amd64/node_exporter /usr/local/bin
chown node_exporter:node_exporter /usr/local/bin/node_exporter

ln -s /vagrant/systemd/node_exporter.service /etc/systemd/system/node_exporter.service
systemctl daemon-reload
systemctl start node_exporter
systemctl enable node_exporter > /dev/null 2>&1

# securing
apt-get install -y nginx apache2-utils > /dev/null 2>&1
ln -s /vagrant/nginx/htpasswd /etc/nginx/.htpasswd
ln -s /vagrant/nginx/prometheus /etc/nginx/sites-available/

rm /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/prometheus /etc/nginx/sites-enabled/
systemctl reload nginx

# grafana
echo "Grafana installing..."
echo "deb https://packagecloud.io/grafana/stable/debian/ stretch main" > /etc/apt/sources.list.d/grafana.list
curl -s https://packagecloud.io/gpg.key | sudo apt-key add - > /dev/null 2>&1
apt-get update -qq
apt-get install -y grafana > /dev/null 2>&1
systemctl start grafana-server
systemctl enable grafana-server > /dev/null 2>&1

# just in case
sleep 3

# add data source
curl -X POST -H "Content-Type: application/json" -d '{
  "name": "Prometheus",
  "type": "prometheus",
  "url": "http://192.168.50.5:9090",
  "access": "direct",
  "basicAuth": false
}' http://admin:admin@localhost:3000/api/datasources

# add examples dashboards
curl -X POST -H "Content-Type: application/json" -d \
	@/vagrant/grafana/host-stats_rev1.json \
	http://admin:admin@localhost:3000/api/dashboards/db

curl -X POST -H "Content-Type: application/json" -d \
	@/vagrant/grafana/node-exporter-full_rev7.json \
	http://admin:admin@localhost:3000/api/dashboards/db

curl -X POST -H "Content-Type: application/json" -d \
	@/vagrant/grafana/node-exporter-single-server_rev7.json \
	http://admin:admin@localhost:3000/api/dashboards/db
