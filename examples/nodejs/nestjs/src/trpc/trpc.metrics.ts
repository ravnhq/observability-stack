import { Injectable } from '@nestjs/common';
import { MetricsService } from '../common/services/metrics.service';
import type * as promClient from 'prom-client';

@Injectable()
export class TrpcMetricsService {
  private readonly histogram: promClient.Histogram<string>;

  constructor(metricsService: MetricsService) {
    this.histogram = new (require('prom-client').Histogram)({
      name: 'trpc_server_handling_seconds',
      help: 'Duration of tRPC procedure handling in seconds',
      labelNames: ['procedure', 'type', 'outcome', 'error'] as const,
      registers: [metricsService.getRegistry()],
      buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
    });
  }

  observe(opts: {
    durationSeconds: number;
    procedure: string;
    type: string;
    outcome: string;
    error: string;
  }) {
    this.histogram.observe(
      {
        procedure: opts.procedure,
        type: opts.type,
        outcome: opts.outcome,
        error: opts.error,
      },
      opts.durationSeconds,
    );
  }
}
