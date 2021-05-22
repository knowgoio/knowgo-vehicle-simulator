# Getting Started

!!! note
    In case you run into any problems, [contact us][contact] directly
    or open an issue in the [issue tracker][tracker].

[contact]: mailto:labs@adaptant.io
[tracker]: https://github.com/knowgoio/knowgo-vehicle-simulator/issues

## Installation

Installation from a binary release is recommended. Regular releases are
made to various app stores, please refer to the one appropriate for
your platform:

[![Get it from the Snap Store](https://snapcraft.io/static/images/badges/en/snap-store-black.svg)](https://snapcraft.io/knowgo-vehicle-simulator)

Releases can also be obtained directly from [GitHub][releases].

[releases]: https://github.com/knowgoio/knowgo-vehicle-simulator/releases

## Usage

![Usage Example](images/usage-example.gif)

## Configuration

Configuration of the simulator can be tuned through a `config.yaml` file,
which will be parsed and updated by configuration changes within the UI.
The format of the file is:

```yaml
sessionLogging: true
eventLogging: true

# Optional KnowGo Backend Configuration
knowgo:
  server: <knowgo-API-server>
  apiKey: <knowgo-API-Key>

# Optional Kafka Broker Configuration
kafka:
  broker: <kafka-broker-address>
  topic: <kafka-topic>

# Optional MQTT Broker Configuration
mqtt:
  broker: <MQTT-broker-address>
  topic: <MQTT-topic>
```

A number of environment variables can also be set:

Environment Variable | Description | Default value
:-------------------|:-----------|:-------------
*KNOWGO_SIMULATOR_CONFIG* | Location of `config.yaml` file | `config.yaml`
*KNOWGO_SIMULATOR_PORT* | HTTP port to bind for REST API | 8086
