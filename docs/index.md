# Overview

![KnowGo Vehicle Simulator Logo](images/logo.png)

<center>
<i>A multi-platform Connected Car simulator with realistic streaming
   vehicle telemetry.</i>

[![Build Status](https://travis-ci.com/knowgoio/knowgo-vehicle-simulator.svg?branch=master)](https://travis-ci.com/knowgoio/knowgo-vehicle-simulator)
[![knowgo-vehicle-simulator](https://snapcraft.io/knowgo-vehicle-simulator/badge.svg)](https://snapcraft.io/knowgo-vehicle-simulator)
</center>

``knowgo-vehicle-simulator`` has been developed to aid in the
development and validation of data-driven Connected Car services and
models that require easy access to realistic synthetic driving data,
both for static and streaming applications. It was originally designed
for generating event records for the [KnowGo Car] platform, but has
been generalized so that it may be useful both to Connected Car service
developers and researchers.

The vehicle simulator generates a single unique vehicle, which can
be controlled either directly through the UI or through an optional
[REST API](rest-api.md). This may be further interfaced with
OEM-specific external data sources and models in order to permit the
simulation state to act as an automotive [digital twin]. For fleet
simulation workloads, multiple instances of the simulator may be run in
parallel, with each generated vehicle being manually joined to a
specified fleet.

[digital twin]: https://en.wikipedia.org/wiki/Digital_twin
[KnowGo Car]: https://knowgo.io
