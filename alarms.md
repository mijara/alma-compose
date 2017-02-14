# Alarms

A good use of the statistics inspection is being able to notify alerts if
some of them aren't going smoothly. For that scenario, we developed a Statspout
module that detects values exceeding maximums and activates a notification
mechanism.

## How to specify the maximums

At the moment, there's support for CPU and Memory maximums, each one is
specified for each container (or can be ignored) using Docker Container Labels.

- CPU: cl.alma.max-cpu
- MEM: cl.alma.max-mem

Each one receives a value in the range ]0, 100] (a percentage), that the module
will use to raise alerts.

Example:

```
docker run -p 80:80 -l cl.alma.max-cpu=50 nginx
```

In this case, the module will alert whenever the usage of cpu is exceeding 50%,
and there will be no restriction for memory (a value of zero is also
interpreted as no restriction).

## An alarm example

```
Max 5.000000% CPU exceeded: [nginx] {13 Feb 17 18:09:27 UTC} CPU: 17.358405%,
    MEM: 0.097502% [2043904 B] Tx/Rx: 9386317/2047081
```

This example shows every bit of information at the time the detection was made,
in this strict format:

```
Max [MAX_CPU] CPU exceeded: [CONTAINER_NAME] [UTC Timestamp] CPU: [CURRENT_CPU],
    MEM: [CURRENT_MEM] [MEM_IN_BYTES] Tx/Rx: [TX_BYTES]/[RX_BYTES]
```

This is useful to quickly check how bad the situation is.

## Excluding duplicates

To ignore duplicates of the same alarm the system uses two mechanisms:

- Ignore every peak that follows an initial alarm raise, until it is fixed.
- After a peak, we will rest for a number of cycles, ignoring every value.
  This is useful in cases where a container has lots of peaks constantly
  increasing and decreasing.

## Where do alarms go?

The AlarmDetector repository supports multiple notifiers, at the moment there're
two: standard output and RabbitMQ, the former is used as a backup and the latter
is used to send logs to further analysis (and maybe Jenkins).

Options for these two are:

```
--alarm.cycles int
    Cycles of cooldown after a the detection stopped. (default 10)
--alarm.rabbitmq
    Enable or disable the RabbitMQ notifier. (default false)
--alarm.rabbitmq.queue string
    Queue for alarms raised. (default "alarms")
--alarm.rabbitmq.uri string
    Broker URI. See https://www.rabbitmq.com/uri-spec.html (default
        "amqp://localhost:5672/")
--alarm.stdout
    Enable or disable the Stdout notifier. (default true)
```

See the Statspout `How to use` section for further information.

## Can we set the maximums after starting the container?

No, Statspout is not capable of detecting such changes at the moment.
