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
