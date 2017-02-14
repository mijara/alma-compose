# Portainer

Portainer is the system used in ALMA to manage a Docker Swarm.

Full documentation can be found in the repository:

    https://github.com/portainer/portainer

## Improvements

ALMA requires that the system displays historical logs and stats, since this is
not currently supported by default, a fork was made:

    https://github.com/mijara/portainer/tree/master

Which implements graphic displays for said stats and logs, connecting to
ElasticSearch for logs and InfluxDB for stats. See
https://github.com/mijara/alma-docs/tree/master/src for source code.

The fork has to be maintained manually to update to different Portainer version,
to make this easier, the actual implementation was coded in different files
and, hopefully, each one will work with no modifications, but in order to
activate those modules, we need to modify some files to include the features.

## Updating the module

This guide will cover from creating a fork until the creation of a Docker Image
for the forked Portainer.

### Environment

If you already have a fork and you have to update it, these steps can be
skipped. This guide will not tell you how to merge, but it will help you to know
where each piece of code go. Note that we will always use the master branch,
in order to use a stable version of Portainer (1.11.3 at the moment).

First step is to create a fork, head to Github a create one under your account
from:

    https://github.com/portainer/portainer

To setup the development environment, we need these tools (this guide was tested
on a clean CentOS 7 installation):

```
yum install -y git epel-release
yum install -y npm docker

npm install -g grunt-cli
```

**NOTE: npm does not work under the root user, create a non-privileged user to
continue.**

Clone the fork and checkout:

```
git clone git@github.com:<GITHUB_ACCOUNT>/portainer.git fork
cd fork
git checkout master
```

Install modules:

```
npm install
```

At this point, we need to build the Golang Portainer binary, to do this make
sure docker is running and execute one of the following commands, depending on
your OS:

```
grunt shell:buildBinary       # Linux
grunt shell:buildDarwinBinary # MacOS
```

This will download some images from Docker Hub, and then Go dependencies.
After a while, it should say `Done, without errors.`, and generate the binary at
`dist/portainer`.

    If that fails:

    It may fail saying that we couldn't find the docker daemon, this happens
    when the user is not privileged enough to do so. We will create a new group
    called Docker and add the user to that so we can actually run docker
    commands:

    With the root user:

    groupadd docker
    gpasswd -a <USER> docker

    Restart the Docker daemon, login again with the user for changes to take
    effect and run the grunt command again.


    If that fails:

    The build process may fail with a permission denied error, it is often times
    caused by SELinux, you can try to fix it, but probably is better for
    development to just disable it with `setenforce 0`.


    If that fails:

    The build process may fail, with an error like:

    ...
    /bin/sh: shasum: command not found
     Use --force to continue

    We do have shasum installed, but with other name, so create a symlink:

    # find the location of sha1sum.
    which sha1sum
    ln -s <SHA1SUM_PATH> /usr/local/bin/shasum

    Then execute the grunt command again.


    If that fails:

    The process may fail telling us that it can't resolve github.com, this is
    due to Docker not being able to resolve it, a quick fix is to change the
    DNS Docker uses, open /etc/sysconfig/docker and add:

    DOCKER_OPTS="--dns 8.8.8.8 --dns 8.8.4.4"

    at the end, then run the grunt command again.

To generate the compressed JS and CSS code, run

```
grunt build
```

Finally, execute:

```
cd dist
./portainer
```

    If that fails:

    The command may fail with an error like:

    [...] mkdir /data/tls: no such file or directory

    This happens when the /data folder is not created and the user is not
    privileged enough to create it.

    With a privileged user:

    mkdir /data
    chown <USER>:docker /data -R

    Then execute the portainer binary again.

In a browser, head to http://localhost:9000 and check that everything is working
properly.

### Add the new modules

Download the module files from

    https://github.com/mijara/alma-docs/tree/master/src/api
    https://github.com/mijara/alma-docs/tree/master/src/app

Copy files to proper folders (you could make symlinks too if you which):

```
fork/
|-- api/http/
|   `-- monitor_handler.go
|
`-- app/components/
    |-- monitor/
    |   |-- monitor.html
    |   `-- monitorController.js
    |
    `-- monitorList/
        |-- monitorList.html
        `-- monitorListController.js
```

### Install module dependencies

In the `bower.json` file, include these two dependencies:

```
"seiyria-bootstrap-slider": "9.7.0",
"eonasdan-bootstrap-datetimepicker": "4.17.45"
```

And install them with

```
npm install
```

Check the installation with:

```
find bower_components/seiyria-bootstrap-slider/dist/bootstrap-slider.js
find bower_components/eonasdan-bootstrap-datetimepicker/build/js/bootstrap-datetimepicker.min.js
```

Check the output for errors, if none, we are OK.

### Activate the modules in Portainer

This is the most `hack-ish` part, in which we must modify the source code of
Portainer to link the new module.

#### JS and CSS

In the `gruntfile.json` file, in the `jsVendor` list, include:

```
bower_components/seiyria-bootstrap-slider/dist/bootstrap-slider.js
bower_components/eonasdan-bootstrap-datetimepicker/build/js/bootstrap-datetimepicker.min.js
```

And in the `cssVendor` list include:

```
bower_components/seiyria-bootstrap-slider/dist/css/bootstrap-slider.css
bower_components/eonasdan-bootstrap-datetimepicker/build/css/bootstrap-datetimepicker.css
```

Execute:

```
grunt build
```

And check everything is working properly (no errors thrown in the console).

#### API Endpoint

Open `api/http/handler.go` with a text editor. There you will find something
like:

```
type Handler struct {
    AuthHandler      *AuthHandler
    UserHandler      *UserHandler
    EndpointHandler  *EndpointHandler
    SettingsHandler  *SettingsHandler
    TemplatesHandler *TemplatesHandler
    DockerHandler    *DockerHandler
    WebSocketHandler *WebSocketHandler
    UploadHandler    *UploadHandler
    FileHandler      *FileHandler
}
```

This contains instances for all endpoint handlers. Add a new member:

```
MonitorHandler   *MonitorHandler
```

Then, find this piece of code:

```
func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    if strings.HasPrefix(r.URL.Path, "/api/auth") {
        http.StripPrefix("/api", h.AuthHandler).ServeHTTP(w, r)
    } else if strings.HasPrefix(r.URL.Path, "/api/users") {
        http.StripPrefix("/api", h.UserHandler).ServeHTTP(w, r)
    } else if strings.HasPrefix(r.URL.Path, "/api/endpoints") {
        http.StripPrefix("/api", h.EndpointHandler).ServeHTTP(w, r)
    } else if strings.HasPrefix(r.URL.Path, "/api/settings") {
        http.StripPrefix("/api", h.SettingsHandler).ServeHTTP(w, r)
    } else if strings.HasPrefix(r.URL.Path, "/api/templates") {
        http.StripPrefix("/api", h.TemplatesHandler).ServeHTTP(w, r)
    } else if strings.HasPrefix(r.URL.Path, "/api/upload") {
        http.StripPrefix("/api", h.UploadHandler).ServeHTTP(w, r)
    } else if strings.HasPrefix(r.URL.Path, "/api/websocket") {
        http.StripPrefix("/api", h.WebSocketHandler).ServeHTTP(w, r)
    } else if strings.HasPrefix(r.URL.Path, "/api/docker") {
        http.StripPrefix("/api/docker", h.DockerHandler).ServeHTTP(w, r)
    } else if strings.HasPrefix(r.URL.Path, "/api/monitor") {
        http.StripPrefix("/api/monitor", h.MonitorHandler).ServeHTTP(w, r)
    } else if strings.HasPrefix(r.URL.Path, "/") {
        h.FileHandler.ServeHTTP(w, r)
    }
}
```

This is the `dispatcher` for each endpoint, we will add a new one:

```
...
} else if strings.HasPrefix(r.URL.Path, "/api/monitor") {
    http.StripPrefix("/api/monitor", h.MonitorHandler).ServeHTTP(w, r)
}
...
```

Use your common sense to find the right place for it between the else if
statements.

Now open `api/http/server.go` with a text editor, and right before this line:

```
server.Handler = &Handler{
...
```

Add:

```
var monitorHandler = NewMonitorHandler(middleWareService, MonitorOpts{
	ES: EsOpts{
		endpoint: "http://<ELASTICSEARCH_HOST>:9200/offline-*/_search",
	},
	Influx: InfluxOpts{
		endpoint: "http://<INFLUXDB_HOST>:8086/query",
	},
})
```

This will create the instance of the monitor module, note that here are defined
the hosts of each database, update them as needed.

Now, right after this line:

```
UploadHandler:    uploadHandler,
```

Add:

```
MonitorHandler:   monitorHandler,
```

And this will finally make the monitor handler available.

Now check it is actually compiling:

```
grunt shell:buildBinary       # Linux
grunt shell:buildDarwinBinary # MacOS
```

*Note: each time you compile, it will download dependencies since it is using
a container to build the binary.*

This should compile fine with a message `Done, without errors.`.

Now check that it actually worked (you don't really need the architecture
working, just checking if a relevant error is returned), run the server again
and open http://localhost:9000/api/monitor/logs in a browser, the error returned
must be:

```
{"err":"got empty value for key: name"}
```

This means that our endpoint is working, but it is not being used correctly,
which is fine!

### APP Frontend

Now we must add the frontend code to activate the JS and HTML modules. Open
`app/app.js` with a text editor, in the `angular.module` dependency list,
add: `monitor` and `monitorList`.

Scroll down a little more and you will find a lot of expressions that begin with
`.state(...`, we must add two more of these:

```
.state('monitor', {
    url: "^/monitor/:id",
    views: {
        "content": {
            templateUrl: 'app/components/monitor/monitor.html',
            controller: 'MonitorController'
        },
        "sidebar": {
            templateUrl: 'app/components/sidebar/sidebar.html',
            controller: 'SidebarController'
        }
    },
    data: {
        requiresLogin: true
    }
})
.state('monitorList', {
    url: "^/monitorList",
    views: {
        "content": {
            templateUrl: 'app/components/monitorList/monitorList.html',
            controller: 'MonitorListController'
        },
        "sidebar": {
            templateUrl: 'app/components/sidebar/sidebar.html',
            controller: 'SidebarController'
        }
    },
    data: {
        requiresLogin: true
    }
})
```

This will use our components when the user goes to `monitor/` and
`monitorList/`.

There's one last thing to modify, open `app/components/sidebar/sidebar.html` and
add right after:

```
<li class="sidebar-list" ng-if="applicationState.endpoint.mode.provider === 'DOCKER_STANDALONE'">
  <a ui-sref="docker" ui-sref-active="active">Docker <span class="menu-icon fa fa-th"></span></a>
</li>
```

Add:

```
<li class="sidebar-list">
  <a ui-sref="monitorList">Monitor <span class="menu-icon fa fa-area-chart"></span></a>
</li>
```

This will add a new button to the sidebar to direct us to the monitorList
component.

Now build again:

```
grunt build
```

It should say `Done, without errors.` at the end. (Also it should be pretty fast,
because it is not generating the binary again. If this is not the case, refer to
the relevant section of this guide and check errors).

### Checking everything

*Note: You can go to https://github.com/mijara/portainer/tree/master to check the
result of this guide at the moment I wrote it. It may help you.*

For this check we do need the architecture working, you can use the docker
compose I used to run the system locally. Make sure the endpoints host are
`0.0.0.0` in ElasticSearch and InfluxDB in your `api/http/server.go` file, and
you may need to rebuild the binary.

Follow the steps in the Deployment guide until before it starts the Portainer
container (Development deployment section).

After every other service is started, go to the `dist` directory and execute:

```
./portainer
```

It should say something like:

```
[...] Starting Portainer on :9000
```

In the sidebar there should be a new `Monitor` section, click it, then click
one of the containers and check logs and stats, and play with it a little to
ensure every bit of functionality works.

*Note: some containers will not work since they're created solely for the
building process, and were stoped BEFORE the system actually acknowledged their
existence.*

If everything is working fine, stop the docker containers with

```
docker-compose down
```

and `Ctrl-C` Portainer.

### General notes of the source code modification

This is strictly a workaround, because Portainer does not support plugins, you
should check if the latest version supports them and adapt the new plugin for
that architecture.

Merging the files may be not as straight forward as this guide tells you,
I recommend you that you learn Go/AngularJS in order to achieve the same as
these steps tell you to, in resume:

- Add a new endpoint into the API.
- Add AngularJS components.
- Add Sidebar link to the monitor list.

### Generating the new Docker Image

    // TODO
