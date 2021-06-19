# Webhooks and Notifications

![Webhooks Integration](images/webhooks.png)

## Webhooks

While services are able to analyze vehicle telemetry accessible to them
directly and look for changes of interest, `knowgo-vehicle-simulator`
supports a number of event triggers that allow custom webhooks to be
fired whenever a trigger condition is satisfied, making it easier for
services to receive only the information they are interested in.

The different trigger conditions together with a brief explanation of
when they are triggered are outlined in the table below:

| <div style="width:180px">Trigger</div> | Description            |
|----------------------------|------------------------------------|
| `automation_level_changed` | Triggered when the [SAE J3016] level of driving automation changes. |
| `journey_begin`            | Triggered when a new Journey is started. Each time the vehicle simulation model is started, a new Journey is begun. |
| `journey_end`              | Triggered when a Journey is completed. This will be triggered each time the simulation model is stopped. |
| `location_changed`         | Triggered each time the vehicle location (latitude/longitude) changes. This can be chained together with a reverse geocoding service in order to detect country changes. |
| `ignition_changed`         | Triggered any time the ignition status changes. |
| `harsh_acceleration`       | Triggered any time a harsh acceleration event is detected. This is assessed by looking for abrupt changes in the accelerator pedal position across a configurable time interval. |
| `harsh_braking`            | Triggered any time a harsh braking event is detected. As with `harsh_acceleration` detection, this is triggered by analyzing changes in brake pedal position over time. |

Users may define fixed REST API endpoints for specific triggers as part
of the simulator [configuration](getting-started.md#configuration), or
services may register callback URLs dynamically at run-time via the
simulator [REST API](rest-api.md).

[SAE J3016]: https://www.sae.org/standards/content/j3016_202104/

## Notifications

In addition to their use for external API endpoint notification,
triggers can also be configured by the user to raise a visible alert
directly within the simulator UI.

Notifications *to the simulator* are also supported via the
`/simulator/notification` and `/exve/vehicles/<vehicleId>/notification`
REST API endpoints for external services and applications that wish to
raise alerts in the simulator UI directly. This provides a general
approximation of head unit integration applications can expect to find
in production environments.
