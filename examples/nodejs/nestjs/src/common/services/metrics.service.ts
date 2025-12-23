import { Injectable, OnModuleInit } from '@nestjs/common';
import * as promClient from 'prom-client';

@Injectable()
export class MetricsService implements OnModuleInit {
  private readonly registry: promClient.Registry;
  private httpRequestHistogram: promClient.Histogram<string>;
  private graphqlOperationHistogram: promClient.Histogram<string>;

  constructor() {
    this.registry = new promClient.Registry();

    (this.registry as any).setContentType(
      promClient.Registry.OPENMETRICS_CONTENT_TYPE,
    )

    // Initialize HTTP request duration histogram
    this.httpRequestHistogram = new promClient.Histogram({
      name: 'http_server_requests_seconds',
      help: 'HTTP server request duration in seconds',
      labelNames: ['method', 'status', 'uri', 'outcome', 'exception', 'error'],
      buckets: [0.001, 0.005, 0.015, 0.05, 0.1, 0.2, 0.3, 0.4, 0.5, 1.0, 2.0, 5.0, 10.0],
      registers: [this.registry],
      enableExemplars: true,
    });

    // Initialize GraphQL operation duration histogram
    this.graphqlOperationHistogram = new promClient.Histogram({
      name: 'graphql_operations_seconds',
      help: 'GraphQL operation duration in seconds',
      labelNames: ['operation_name', 'operation_type', 'status', 'outcome', 'exception', 'phase'],
      buckets: [0.001, 0.005, 0.015, 0.05, 0.1, 0.2, 0.3, 0.4, 0.5, 1.0, 2.0, 5.0, 10.0],
      registers: [this.registry],
      enableExemplars: true,
    });
  }

  onModuleInit() {
    // Enable default Node.js runtime metrics
    promClient.collectDefaultMetrics({
      register: this.registry,
    });
  }

  getHttpRequestHistogram(): promClient.Histogram<string> {
    return this.httpRequestHistogram;
  }

  getGraphqlOperationHistogram(): promClient.Histogram<string> {
    return this.graphqlOperationHistogram;
  }

  async getMetrics(): Promise<string> {
    return this.registry.metrics();
  }
}
