# Metrics

When the simulator is running with the HTTP server enabled, performance
and load metrics for [Prometheus] are exposed via the standard
`/metrics` endpoint.

!!! note
    `Pod` and `Service` metrics are scraped automatically when the
    simulator is deployed in a [Kubernetes] environment.

[Prometheus]: https://prometheus.io
[Kubernetes]: https://kubernetes.io

In addition to basic information about the build environment and SDK
versions, the following metrics are exposed:

| <div style="width:280px">Metric Name</div> | Type    | Description            |
|--------------------------------------------|---------|------------------------------------|
| `http_requests_total`                      | Counter | Total number of HTTP requests processed |
| `http_endpoint_requests_total`             | Counter | Total number of HTTP requests per endpoint and request method |
| `simulator_webhook_subscriptions_total`    | Gauge   | Total number of active webhook subscriptions |
| `simulator_webhooks_fired_total`           | Counter | Total number of webhooks that have been fired |
| `simulator_notifications_sent_total`       | Counter | Total number of notifications sent to the simulator |

