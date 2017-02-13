#!/bin/sh
curl -XPOST http://influxdb:8086/query --data-urlencode 'q=CREATE DATABASE statspout'
