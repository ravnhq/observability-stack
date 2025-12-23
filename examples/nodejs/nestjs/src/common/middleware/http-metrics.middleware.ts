import { Injectable, NestMiddleware } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';
import { MetricsService } from '../services/metrics.service';
import { trace } from '@opentelemetry/api';

@Injectable()
export class HttpMetricsMiddleware implements NestMiddleware {
  // Endpoints to exclude from metrics collection
  private readonly excludedPaths = ['/metrics', '/health', '/graphql'];

  constructor(private readonly metricsService: MetricsService) { }

  use(req: Request, res: Response, next: NextFunction) {
    // Check if this path should be excluded
    if (this.shouldExcludePath(req.path)) {
      return next();
    }

    // Record start time
    const startTime = Date.now();

    // Extract trace ID and span ID for exemplar labels
    const { traceId, spanId } = this.extractTraceContext(req);

    // Wait for response to finish
    res.on('finish', () => {
      const duration = (Date.now() - startTime) / 1000; // Convert to seconds

      // Extract labels
      const method = req.method;
      const status = res.statusCode.toString();
      const uri = this.parameterizeRoute(req);
      const outcome = this.determineOutcome(res.statusCode);
      const exception = this.extractException(res);
      const error = this.extractError(res);

      // Record histogram metric
      this.metricsService
        .getHttpRequestHistogram()
        .observe(
          {
            value: duration,
            labels: { method: method, status: status, uri: uri, outcome: outcome, exception: exception, error: error },
            exemplarLabels: {
              trace_id: traceId,
              span_id: spanId,
            },
          }
        );
    });

    next();
  }

  /**
   * Check if path should be excluded from metrics
   */
  private shouldExcludePath(path: string): boolean {
    return this.excludedPaths.some(
      (excluded) => path === excluded || path.startsWith(excluded + '/'),
    );
  }

  /**
   * Convert dynamic route paths to parameterized format
   * Example: /users/123 -> /users/{id}
   */
  private parameterizeRoute(req: Request): string {
    // Get the base URL (route pattern) from Express
    const baseUrl = req.baseUrl || '';
    const route = req.route?.path || '';

    // If we have a route pattern from Express, use it
    if (route) {
      const fullPattern = baseUrl + route;
      // Express uses :param format, convert to {param}
      return fullPattern.replace(/:(\w+)/g, '{$1}');
    }

    // Fallback: Apply heuristic parameterization to the actual path
    return this.heuristicParameterization(req.path);
  }

  /**
   * Heuristic-based route parameterization for cases where route pattern is unavailable
   * Converts segments that look like IDs (UUIDs, numeric IDs, etc.) to {id}
   */
  private heuristicParameterization(path: string): string {
    return path
      .split('/')
      .map((segment) => {
        // Skip empty segments
        if (!segment) return segment;

        // Check if segment looks like a UUID
        if (
          /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
            segment,
          )
        ) {
          return '{id}';
        }

        // Check if segment is numeric (likely an ID)
        if (/^\d+$/.test(segment)) {
          return '{id}';
        }

        // Check if segment looks like a MongoDB ObjectId
        if (/^[0-9a-f]{24}$/i.test(segment)) {
          return '{id}';
        }

        // Keep the segment as-is (it's likely a static path component)
        return segment;
      })
      .join('/');
  }

  /**
   * Determine outcome based on HTTP status code
   */
  private determineOutcome(statusCode: number): string {
    if (statusCode >= 100 && statusCode < 200) {
      return 'INFORMATIONAL';
    } else if (statusCode >= 200 && statusCode < 300) {
      return 'SUCCESS';
    } else if (statusCode >= 300 && statusCode < 400) {
      return 'REDIRECTION';
    } else if (statusCode >= 400 && statusCode < 500) {
      return 'CLIENT_ERROR';
    } else if (statusCode >= 500) {
      return 'SERVER_ERROR';
    }
    return 'UNKNOWN';
  }

  /**
   * Extract exception class name from response
   * NestJS stores exception info in res.locals or through custom exception filters
   */
  private extractException(res: Response): string {
    // Check if exception info was stored by an exception filter
    const exception = (res as any).locals?.exception;

    if (exception) {
      // Get constructor name for the exception class
      return exception.constructor?.name || 'Error';
    }

    // If no exception but status indicates error, use generic names
    if (res.statusCode >= 400 && res.statusCode < 500) {
      return 'HttpException';
    } else if (res.statusCode >= 500) {
      return 'InternalServerErrorException';
    }

    return 'none';
  }

  /**
   * Extract error message/type from response
   * Note: This should only capture metrics collection errors, not application errors
   */
  private extractError(res: Response): string {
    // For application errors, we use 'none' to avoid cardinality explosion
    // The error label is reserved for metrics collection/instrumentation errors
    return 'none';
  }

  /**
   * Extract trace ID and span ID from the active OpenTelemetry span context.
   * Falls back to none if no active span is available.
   */
  private extractTraceContext(req: Request): { traceId: string; spanId: string } {
    // Try to get the active span from OpenTelemetry context
    const activeSpan = trace.getActiveSpan();

    if (activeSpan) {
      const spanContext = activeSpan.spanContext();

      // Validate that we have a valid span context
      if (spanContext && spanContext.traceId && spanContext.spanId) {
        return {
          traceId: spanContext.traceId,
          spanId: spanContext.spanId,
        };
      }
    }

    // Fallback to none if no active span is available
    const traceId = 'none';
    const spanId = 'none';

    return { traceId, spanId };
  }
}
