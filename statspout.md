# Statspout

The statspout program/framework is used in the architecture to route statistics
from Docker container to InfluxDB.

## Discovery

Container are discovered in a batch when Statspout starts, using the Docker
Remote API:

```
GET /containers/json
```

Which returns a list of all container currently active (only running ones).

After the system is up and running, we ask the Docker Events API to discover new
started containers and stop listening to the ones that were stopped. That
endpoint is a HTTP Stream and notifies conveniently when start, stop and rename
(etc) events happen.

Because of this nature, Statspout doesn't need to be restarted for changes to
take effect.

## Routing Mechanism

The routing is achieved using the Docker Remote API for stats:

```
GET /containers/(id or name)/stats
```

Which returns stats for Network and Block IO, CPU, Memory, etc., but in this
software we only route CPU, MEM and Network, which are the important to our
system, but adding new ones is relatively easy.

The result from the API endpoint returns a HTTP stream, which we only request
the first result for each container, since the interval can be longer than
Docker's.

## Repositories

A repository is any module that actually routes the stats to some database or
system, the system includes by default:

- InfluxDB
- MongoDB
- Prometheus
- RestAPI
- Stdout

In ALMA the InfluxDB repo is used, but with some customizations. New
repositories can be created, using the system as a framework.

## How to use

This software can be run as a standalone application and as a framework.

### As a Standalone application

Refer to https://github.com/mijara/statspout README (recommended read before the
rest of the document as well).

### As a framework

The software is coded in Go, here we will assume that the reader already knows
this language.

#### Environment

First setup your environment for development with Statspout, assuming that you
already have a proper path for your project and the recommended layout, execute:

```
go get github.com/mijara/statspout
```

To install the framework libraries, dependencies should be installed
automatically, but if not, install them one by one (how? easiest way: just run
the project cmd/main.go file and check the import errors, the `go get` each
one).

For the next steps you should have a Docker instance running and at least one
container (does not matter which one).

Test that everything is working properly:

```
cd into the statspout's cmd directory.
go run main.go
```

This will run the system with the default configurations, that for most cases
should be enough, if you see stats every X seconds, then everything is working
properly, but if not, check your GOPATH and dependencies.

Still now working?, file an issue at

    https://github.com/mijara/statspout/issues

Working? then create a separate directory for your module, something like:

```
your-path/
    pkg/
    bin/
    src/
        ...
        github.com/
            mijara/
                statspout/
            your-github-username/
                your-project/
                    customrepo/         # structs and utils for your module.
                        customrepo.go   # contains the repository impl.
                    main.go             # init the framework and configures it.
```

#### Main

The first step is to configure the main file for your new project:

```go
package main

import (
	"github.com/mijara/statspout"
	"github.com/mijara/statspout/common"
	"github.com/mijara/statspout/opts"
)

func main() {
	cfg := opts.NewConfig()

	cfg.AddRepository(&common.Stdout{}, nil)

	cfg.AddRepository(&common.Rest{}, common.CreateRestOpts())

	cfg.AddRepository(&common.Prometheus{}, common.CreatePrometheusOpts())
	cfg.AddRepository(&common.InfluxDB{}, common.CreateInfluxDBOpts())
	cfg.AddRepository(&common.Mongo{}, common.CreateMongoOpts())

	statspout.Start(cfg)
}
```

This is an example of the actual main file of the software, which loads every
common repository, and listens to cmd arguments to chose which one to use.

Every repository that you want to use must be added to the configuration, for
example:

```go
cfg.AddRepository(&common.Mongo{}, common.CreateMongoOpts())
```

The first argument is a struct that represents an unloaded version of the
repository (an empty structure instance), the second ones is used to parse
custom command line arguments for the repository.

#### Create a simple repository

Here we will demonstrate how to create a Repository for an imaginary database
called IDB (replace customrepo for idb in the above file tree). Assume that
there's a library called `idbcli` that does all the hard work your us.

In your project directory open the `idb/idb.go` file and paste:

```go
package idb

import (
    "flag"

	"github.com/mijara/statspout/repo"
	"github.com/mijara/statspout/stats"
    "github.com/mijara/idbcli"
)

type IDB struct {
}

func NewIDB() (*IDB, error) {
	// TODO: see below.
}

func (*IDB) Name() string {
	return "idb"
}

func (*IDB) Create(v interface{}) (repo.Interface, error) {
	return NewIDB()
}

func (*IDB) Clear(name string) {
    // see the Rest repository to check what is this used for.
}

func (repo *IDB) Push(s *stats.Stats) error {
    // TODO: see below.
	return nil
}

func (repo *IDB) Close() {
    // TODO: see below.
}
```

You can check what each method does in the official documentation at godoc.org:

    https://godoc.org/github.com/mijara/statspout/repo

For this repository, we would need a client connection:

```go
type IDB struct {
    cli *idbcli.Client
}
```

The client receives some arguments, and since we want our repository to be
configurable with command line arguments, we will use the Opts feature, add
this:

```go
struct IDBOpts {
    Address string
}

func CreateIDBOpts() *IDBOpts {
    o := &IDBOpts{}

	flag.StringVar(&o.Address,
		"idb.address",                 // property name.
		"localhost:4242/statspout",    // default value.
		"Address of the IDB Endpoint") // help text.

	return o
}
```

Then we should initialize the client, for this we will use the Create and NewIDB
functions to receive the options and actually create the repository:

```go
func (*IDB) Create(v interface{}) (repo.Interface, error) {
    opts := v.(*IDBOpts)
	return NewIDB(opts.Address)
}
```

```go
func NewIDB(address string) (*IDB, error) {
    cli, err := idbcli.NewClient(address)
    if err != nil {
        return nil, err
    }

	return &IDB{
        cli: cli,
    }, nil
}
```

IDB needs to be closed when exiting, so:

```go
func (repo *IDB) Close() {
    repo.cli.Close()
}
```

To actually push the stats, we may use:
```go
func (repo *IDB) Push(s *stats.Stats) error {
    data := make(map[string]float64)

    data["cpu_usage"] = float64(s.CpuPercent)
    data["mem_usage"] = float64(s.MemoryUsage)
    data["tx_bytes"] = float64(s.TxBytesTotal)
    data["rx_bytes"] = float64(s.RxBytesTotal)

    // `s` also contains container Labels for extra metadata, example:
    data["state"] = s.Labels["state"]

    err := repo.cli.Send(s.Name, s.Timestamp, data)

    // here you could check the error details.

    // if there's an error, the core will catch it and log it without closing
    // the whole system. It will also catch panics from this method and recover
    // from them.
	return err
}
```

Note: you can use the statspout log package to properly display information of
      the Push process. Errors will be automatically logged, but other DEBUG
      information could be useful to log as well.

      See https://godoc.org/github.com/mijara/statspout/log for more
      information.

With this done and working, go back to the `main.go` file and add it:

```go
cfg.AddRepository(&idb.IDB{}, idb.CreateIDBOpts())
```

Note: Remember to import the necessary modules.

Execute your main file with:

```
go run main.go --repository=idb --idb.address=localhost:4242/mystats
```

And everything should work fine, if not, please contact:

    <marcelo.jara.13@sansano.usm.cl> (Marcelo Jara Almeyda)

Do not file an issue about this tutorial since this is a guide only for ALMA
usage.
