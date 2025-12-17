import client from 'prom-client';

const register = new client.Registry();
client.collectDefaultMetrics({ register });

const processUptimeGauge = new client.Gauge({
  name: 'process_uptime_seconds',
  help: 'Number of seconds the process has been running',
  registers: [register],
});

setInterval(() => {
  processUptimeGauge.set(process.uptime());
}, 1000).unref();

const HISTOGRAM_BUCKETS = [0.001, 0.005, 0.015, 0.05, 0.1, 0.2, 0.3, 0.4, 0.5, 1, 2, 5, 10];
const metricsErrorLabel = 'none';

const httpRequestDuration = new client.Histogram({
  name: 'http_server_requests_seconds',
  help: 'HTTP server request duration in seconds',
  labelNames: ['method', 'status', 'uri', 'outcome', 'exception', 'error'],
  buckets: HISTOGRAM_BUCKETS,
  registers: [register],
});

type Outcome =
  | 'SERVER_ERROR'
  | 'CLIENT_ERROR'
  | 'REDIRECTION'
  | 'SUCCESS'
  | 'INFORMATIONAL'
  | 'UNKNOWN';

const determineOutcome = (status: number): Outcome => {
  if (status >= 500) return 'SERVER_ERROR';
  if (status >= 400) return 'CLIENT_ERROR';
  if (status >= 300) return 'REDIRECTION';
  if (status >= 200) return 'SUCCESS';
  if (status >= 100) return 'INFORMATIONAL';
  return 'UNKNOWN';
};

const defaultExceptionLabel = (status: number): string => {
  if (status >= 500) return 'InternalServerErrorException';
  if (status >= 400) return 'HttpException';
  return 'none';
};

type StopTimer = (status: number, exceptionLabel?: string) => void;

export const startHttpRequestTimer = (method: string, uri: string): StopTimer => {
  const start = process.hrtime.bigint();

  return (status: number, exceptionLabel?: string) => {
    const durationSeconds = Number(process.hrtime.bigint() - start) / 1e9;
    httpRequestDuration
      .labels(
        method,
        status.toString(),
        uri,
        determineOutcome(status),
        exceptionLabel ?? defaultExceptionLabel(status),
        metricsErrorLabel,
      )
      .observe(durationSeconds);
  };
};

export const getMetrics = async () => register.metrics();
export const metricsContentType = register.contentType;
