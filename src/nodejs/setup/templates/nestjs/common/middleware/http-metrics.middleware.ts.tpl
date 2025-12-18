import { Injectable, NestMiddleware } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';
import { trace } from '@opentelemetry/api';
import { MetricsService } from '../services/metrics.service';

@Injectable()
export class HttpMetricsMiddleware implements NestMiddleware {
  private readonly excludedPaths = ['/metrics', '/health'];

  constructor(private readonly metricsService: MetricsService) {}

  use(req: Request, res: Response, next: NextFunction) {
    if (this.shouldExcludePath(req.path)) {
      return next();
    }

    const start = process.hrtime.bigint();

    res.on('finish', () => {
      const durationSeconds = Number(process.hrtime.bigint() - start) / 1e9;
      const labels = {
        method: req.method,
        status: res.statusCode.toString(),
        uri: this.parameterizeRoute(req),
        outcome: this.determineOutcome(res.statusCode),
        exception: this.extractException(res),
        error: 'none',
      } as const;

      const { traceId, spanId } = this.getTraceContext();

      this.metricsService.getHttpRequestHistogram().observe({
        value: durationSeconds,
        labels,
        exemplarLabels: {
          trace_id: traceId,
          span_id: spanId,
        },
      });
    });

    next();
  }

  private shouldExcludePath(path: string): boolean {
    return this.excludedPaths.some(
      (excluded) => path === excluded || path.startsWith(`${excluded}/`),
    );
  }

  private parameterizeRoute(req: Request): string {
    const base = req.baseUrl || '';
    const routePath = req.route?.path;
    if (routePath) {
      return `${base}${routePath}`.replace(/:(\w+)/g, '{$1}');
    }
    return this.heuristicParameterization(req.path);
  }

  private heuristicParameterization(path: string): string {
    return path
      .split('/')
      .map((segment) => {
        if (!segment) return segment;
        if (/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(segment)) {
          return '{id}';
        }
        if (/^[0-9a-f]{24}$/i.test(segment)) {
          return '{id}';
        }
        if (/^\d+$/.test(segment)) {
          return '{id}';
        }
        return segment;
      })
      .join('/');
  }

  private determineOutcome(statusCode: number): string {
    if (statusCode >= 100 && statusCode < 200) return 'INFORMATIONAL';
    if (statusCode >= 200 && statusCode < 300) return 'SUCCESS';
    if (statusCode >= 300 && statusCode < 400) return 'REDIRECTION';
    if (statusCode >= 400 && statusCode < 500) return 'CLIENT_ERROR';
    if (statusCode >= 500) return 'SERVER_ERROR';
    return 'UNKNOWN';
  }

  private extractException(res: Response): string {
    const locals = res.locals as { exception?: Error };
    const exception = locals?.exception;
    if (exception) {
      return exception.constructor?.name || 'Error';
    }
    if (res.statusCode >= 500) return 'InternalServerErrorException';
    if (res.statusCode >= 400) return 'HttpException';
    return 'none';
  }

  private getTraceContext(): { traceId: string; spanId: string } {
    const activeSpan = trace.getActiveSpan();
    const spanContext = activeSpan?.spanContext();
    if (spanContext?.traceId && spanContext?.spanId) {
      return { traceId: spanContext.traceId, spanId: spanContext.spanId };
    }
    return { traceId: 'none', spanId: 'none' };
  }
}
