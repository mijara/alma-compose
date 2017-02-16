# Deployment

## Guide Depencencies

This guide must be followed after every other guide in this manual, you will
need the images and products released in them:

- Custom Portainer Docker Image
- Custom Logspout-Logstash Image
- Logstash configuration in place

## Creating the Alma Setup Image

In https://github.com/mijara/alma-docs, open the `compose` directory. First
we need the alma-setup container that helps us running setup scripts for all
containers after they're started.

```
cd setup
./build.sh
```

## Development deployment

This will guide you through a complete deployment of the system, in a
development environment.

We need the `logsput-logstash` image, refer to the `logs` guide for more info
on how to generate it (the `src` dir is located alongside the `compose`
dir).

These steps will make use of `docker-compose` utility, in this repository you
will find the `compose` directory with all files you need for this.

CD into the `compose` directory, copy the example file
`docker-compose.yml.example` to `docker-compose.yml` and fill the missing
information marked by `<`, `>`, then save and execute:

```
docker-compose up -d
```

    If that fails:

    On CentOS 7 it may fail because docker-compose does not exists, to install
    it use:

    yum install -y python-pip
    pip install docker-compose

    You may need to upgrade python:

    yum upgrade python*
    pip install --upgrade pip

After it finished, execute `docker ps` to check that everything is up and
running (logspout, logstash, statspout, elasticsearch, influxdb).

Quick check InfluxDB and ElasticSearch with:

```
# InfluxDB
http://localhost:8086/query?db=statspout&q=select%20*%20from%20cpu_usage%20where%20container=%27influxdb%27

# ElasticSearch
http://localhost:9200/offline-*/_search?q=*
```
