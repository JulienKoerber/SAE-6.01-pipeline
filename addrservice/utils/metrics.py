# Copyright (c) 2020. All rights reserved.

from prometheus_client import Counter, Histogram, Gauge

# Métriques HTTP
http_requests_total = Counter(
    'addrservice_http_requests_total',
    'Total HTTP requests by method and endpoint',
    ['method', 'endpoint', 'status']
)

http_request_duration_seconds = Histogram(
    'addrservice_http_request_duration_seconds',
    'HTTP request latency in seconds',
    ['method', 'endpoint'],
    buckets=(0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1.0, 2.5, 5.0, 7.5, 10.0)
)

# Métriques métier
addresses_total = Gauge(
    'addrservice_addresses_total',
    'Total number of addresses in the database'
)

addresses_created_total = Counter(
    'addrservice_addresses_created_total',
    'Total addresses created'
)

addresses_deleted_total = Counter(
    'addrservice_addresses_deleted_total',
    'Total addresses deleted'
)

# Erreurs
errors_total = Counter(
    'addrservice_errors_total',
    'Total errors by type',
    ['error_type']
)