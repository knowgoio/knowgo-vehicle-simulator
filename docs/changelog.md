# ChangeLog

## Latest

- Ensure new webhooks are listed through the `/simulator/webhooks` REST
  API endpoint.
- Fix up responsive scaling for smaller displays.

## 1.1.1

- Split event updates into sub-topics nested under the vehicle ID when
  publishing to MQTT.
- Add [SAE J3016] automation level support and notification webhook.
- Add support for vehicle event export direct to CSV.
- Fix fuel consumption rate calculation.
- Allow Webhooks to be configured directly from the simulator UI.
- Add `journey_begin`, `journey_end`, and `driver_changed` webhooks.
- Include driver ID in event data model.
- Add `brakePedalPositions` and `automationLevels` to ExVe API.

[SAE J3016]: https://www.sae.org/standards/content/j3016_202104/

## 1.1.0

- Preparation for null safety (disabled by default, until all dependent
  packages have been migrated - currently blocked by [dart-kafka]).
- Make Event logging configurable.
- Addition of `/simulator/notification` REST API endpoint for delivering
  notifications to the simulator.
- Convert the HTTP server to use the new `shelf` framework.
- Additon of webhook manipulation and [ISO 20078-2:2019] Extended Vehicle
  (ExVe) APIs, corresponding to `v1.1.0` of the [REST API](rest-api.md).

[ISO 20078-2:2019]: https://www.iso.org/standard/67578.html
[dart-kafka]: https://github.com/dart-kafka/kafka

## 1.0.0

- Initial release.
