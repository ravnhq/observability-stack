import { Request, Response, NextFunction } from 'express';
import { trace } from '@opentelemetry/api';
import client, { type ObserveDataWithExemplar, type OpenMetricsContentType } from 'prom-client';

const register = new client.Registry<OpenMetricsContentType>();
register.setContentType(client.Registry.OPENMETRICS_CONTENT_TYPE);

client.collectDefaultMetrics({
  register,
});

const processUptimeGauge = new client.Gauge({
  name: 'process_uptime_seconds',
  help: 'Number of seconds the process has been running',
  registers: [register],
});

setInterval(() => {
  processUptimeGauge.set(process.uptime());
}, 1000).unref();

const histogramBuckets = [0.001, 0.005, 0.015, 0.05, 0.1, 0.2, 0.3, 0.4, 0.5, 1, 2, 5, 10];

const httpRequestDuration = new client.Histogram({
  name: 'http_server_requests_seconds',
  help: 'HTTP server request duration in seconds',
  labelNames: ['method', 'status', 'uri', 'outcome', 'exception', 'error'],
  buckets: histogramBuckets,
  registers: [register],
  enableExemplars: true,
});

const EXCLUDED_PATHS = ['/metrics', '/health'];
const metricsErrorLabel = 'none';

type TraceContext = { traceId: string; spanId: string };

const getTraceContext = (): TraceContext => {
  const activeSpan = trace.getActiveSpan();
  const spanContext = activeSpan?.spanContext();
  if (spanContext?.traceId && spanContext?.spanId) {
    return { traceId: spanContext.traceId, spanId: spanContext.spanId };
  }
  return { traceId: 'none', spanId: 'none' };
};

const shouldExcludePath = (path: string): boolean =>
  EXCLUDED_PATHS.some((excluded) => path === excluded || path.startsWith(`${excluded}/`));

const determineOutcome = (statusCode: number): string => {
  if (statusCode >= 500) return 'SERVER_ERROR';
  if (statusCode >= 400) return 'CLIENT_ERROR';
  if (statusCode >= 300) return 'REDIRECTION';
  if (statusCode >= 200) return 'SUCCESS';
  if (statusCode >= 100) return 'INFORMATIONAL';
  return 'UNKNOWN';
};

const parameterizeRoute = (req: Request): string => {
  const base = req.baseUrl || '';
  const routePath = req.route?.path;
  if (routePath) {
    return `${base}${routePath}`.replace(/:(\w+)/g, '{$1}');
  }
  return heuristicParameterization(req.path);
};

const heuristicParameterization = (path: string): string =>
  path
    .split('/')
    .map((segment) => {
      if (!segment) return segment;
      if (/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(segment)) {
        return '{id}';
      }
      if (/^\d+$/.test(segment)) {
        return '{id}';
      }
      if (/^[0-9a-f]{24}$/i.test(segment)) {
        return '{id}';
      }
      return segment;
    })
    .join('/');

const extractException = (res: Response): string => {
  const locals = res.locals as { exception?: Error };
  const exception = locals?.exception;
  if (exception) {
    return exception.constructor?.name || 'Error';
  }
  if (res.statusCode >= 500) return 'InternalServerErrorException';
  if (res.statusCode >= 400) return 'HttpException';
  return 'none';
};

export const metricsMiddleware = (req: Request, res: Response, next: NextFunction) => {
  if (shouldExcludePath(req.path)) {
    return next();
  }

  const start = process.hrtime.bigint();

  res.on('finish', () => {
    const durationSeconds = Number(process.hrtime.bigint() - start) / 1e9;
    const labels = {
      method: req.method,
      status: res.statusCode.toString(),
      uri: parameterizeRoute(req),
      outcome: determineOutcome(res.statusCode),
      exception: extractException(res),
      error: metricsErrorLabel,
    } as const;
    const { traceId, spanId } = getTraceContext();

    const observation: ObserveDataWithExemplar<string> = {
      value: durationSeconds,
      labels,
      exemplarLabels: {
        trace_id: traceId,
        span_id: spanId,
      },
    };

    httpRequestDuration.observe(observation);
  });

  next();
};

export const metricsHandler = async (_req: Request, res: Response) => {
  res.setHeader('Content-Type', register.contentType);
  res.send(await register.metrics());
};
