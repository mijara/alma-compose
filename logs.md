# Logs

## Logs Routing

For logs routing we use:

    https://github.com/gliderlabs/logspout/
    https://github.com/looplab/logspout-logstash

### Logspout

You can refer to the documentation for more information, but as a resume:

This software routes logs from containers to some routing module, using the
Docker Logs API

```
GET /containers/(id or name)/logs
```

This is a pluggable software, and does not support Logstash by default, so we
will use Logspout-Logstash module for this.

### Logspout-Logstash

Routes logs to Logstash. We use TCP and UDP connections on port 5000.

#### Build Logspout-Logstash Image

To compile a version of Logspout-Logstash go to `src/logspout-logstash` on this
directory and execute:

```
docker build -t logspout-logstash .
```

After that, you can use the generated image as `logspout-logstash` (would be a
good idea to upload it to a registry).

    If that failed:

    On ALMA Ethernet Internet the build process failed, but on WiFi it didn't,
    so the firewall could be the issue.

    If that's not the issue, then check Logspout repository issues, at the
    moment the build is broken since the project uses Go 1.7 dependencies but
    compiles with 1.6 ...

    https://github.com/gliderlabs/logspout/issues/262

## Logstash

ALMA uses the docker hostname to specify metadata, to be able to parse and index
this metadata to Elasticsearch in a search-able way, we will extract it using
a simple Grok regular expression:

```
grok {
    match => {
        "host" => "%{USERNAME:app}-%{USERNAME:stage}-%{USERNAME:release}"
    }
}
```

A complete `logstash.conf` file can be found on the `compose/` directory:

The conf file is located in:
```
/etc/logstash/conf.d/
```

For a simple test, comment the elasticsearch output, and add the following
output:
```
stdout {
  codec => rubydebug
}
```

To run it:
```
/usr/share/logstash/bin/logstash -f docker.conf
```

If everything is working properly, restart the Logstash daemon.

## Running the service

First make sure you have an image of logspout-logstash, if not, refer to
`Build Logspout-Logstash Image` section.

A Docker run command would look like:

```
docker run -d -p 8000:80 --name=logspout \
    -e DOCKER_HOST=tcp://<SWARM_MANAGER>:4000 \
    logspout-logstash logstash://<LOGSTASH_HOST>:5000
```

If you are testing the system, use `ariadne.osf.alma.cl` for `LOGSTASH_HOST` and
`10.200.67.125` for `SWARM_MANAGER`.
