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

**TODO**

## Excluding duplicates

To ignore duplicates of the same alarm the system uses two mechanisms:

- Ignore every peak that follows an initial alarm raise, until it is fixed.
- After a peak, we will `rest` for a number of cycles, ignoring every value.
  This is useful in cases where a container has lots of peaks constantly
  increasing and decreasing. Although it is not a perfect solution, it is good
  enough for most cases.

## Where do alarms go?

Alarms are thrown to two places, first it is logged in Statspout as a backup,
and then it is sent to a alarm system in order to broadcast an email or
something else.

**TODO RabbitMQ?**

## Can we set the maximums after starting the container?

No, Statspout is not capable of detecting such changes at the moment.
