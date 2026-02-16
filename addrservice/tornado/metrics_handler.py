# Copyright (c) 2020. All rights reserved.

import tornado.web
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST


class MetricsHandler(tornado.web.RequestHandler):
    """Endpoint pour exposer les métriques Prometheus"""
    
    def get(self):
        self.set_header('Content-Type', CONTENT_TYPE_LATEST)
        self.write(generate_latest())