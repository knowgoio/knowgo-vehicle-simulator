# Architecture

The Simulator itself consists of several different components:

- The Vehicle Simulation model
- An `Event loop` for generating vehicle events, run as either
  an Isolate or Web Worker depending upon the target platform.
- An optional `HTTP Server isolate` for exposing a REST API with basic
  vehicle controls - starting/stopping the vehicle, updating the
  vehicle state, handling vehicle notifications, and querying vehicle
  events.

As the simulation state can not be shared directly across the isolates,
the simulation model in the main isolate acts as the source of truth
across the system:

- Updates from the `Event loop` are applied to the simulation model
  periodically, in line with the event generation frequency: once
  per second by default.
- The `HTTP Server isolate` maintains its own cached copy of the
  simulation state, which is updated with changes from the Event
  isolate, UI interaction, and the REST API. Changes received through
  the REST API are cached in the `HTTP Server isolate` and proxied back
  to the simulation model directly.
- The UI in the `main isolate` is redrawn based on changes to the
  simulation model, triggered by UI interaction and updates from the
  `Event loop` or `HTTP Server isolate`.

An overview of the overall interactivity patterns for the different
target platforms is provided below.

## Web

When running as a Web-based instance, the `Event Loop` is implemented
in a dedicated Web Worker, analogous to the isolate-driven approach
used by the other platforms. In this case, the Simulation is run
entirely within the browser:

![Web Worker-driven Simulation Flow](images/overview-web.png)

!!! note
    At present, it's not possible to serve the REST API from web-based
    instances, though a WebSocket implementation may be added in the
    future.

## Other Target Platforms

For all other target platforms, the `Event Loop` is run in a dedicated
isolate, and the REST API is directly exposed:

![Isolate-driven Simulation Flow](images/overview.png)