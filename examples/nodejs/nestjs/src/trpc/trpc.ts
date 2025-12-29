import { initTRPC } from '@trpc/server';
import { trace, context as otelContext, SpanStatusCode } from '@opentelemetry/api';
import type { TrpcContext } from './trpc.context';
import type { TrpcMetricsService } from './trpc.metrics';
import type { UsersService } from '../users/services/users.service';

export function createTrpcFactory(deps: { metrics: TrpcMetricsService; usersService: UsersService }) {
  const t = initTRPC.context<TrpcContext>().create();
  const tracer = trace.getTracer('trpc');

  const metricsMiddleware = t.middleware(async (opts) => {
    const startHr = process.hrtime.bigint();

    const span = tracer.startSpan(`trpc.${opts.path}`, {
      attributes: {
        'rpc.system': 'trpc',
        'rpc.service': 'nestjs',
        'rpc.method': opts.path,
        'trpc.procedure': opts.path,
        'trpc.type': opts.type,
      },
    });

    try {
      const result = await otelContext.with(trace.setSpan(otelContext.active(), span), async () => {
        return opts.next();
      });

      const durationSeconds = Number(process.hrtime.bigint() - startHr) / 1e9;

      const ok = result.ok;
      deps.metrics.observe({
        durationSeconds,
        procedure: opts.path,
        type: opts.type,
        outcome: ok ? 'SUCCESS' : 'ERROR',
        error: ok ? 'none' : 'TrpcError',
      });

      if (!ok) {
        span.setStatus({ code: SpanStatusCode.ERROR });
      }

      return result;
    } catch (error) {
      const durationSeconds = Number(process.hrtime.bigint() - startHr) / 1e9;

      deps.metrics.observe({
        durationSeconds,
        procedure: opts.path,
        type: opts.type,
        outcome: 'ERROR',
        error: 'UnhandledError',
      });

      span.recordException(error as Error);
      span.setStatus({ code: SpanStatusCode.ERROR });
      throw error;
    } finally {
      span.end();
    }
  });

  const publicProcedure = t.procedure.use(metricsMiddleware);

  const appRouter = t.router({
    hello: publicProcedure
      .input((value) => {
        if (value != null && typeof value !== 'object') {
          throw new Error('Invalid input');
        }
        return value as { name?: string } | undefined;
      })
      .query(({ input }) => {
        return { greeting: `hello ${input?.name ?? 'world'}` };
      }),

    boom: publicProcedure.mutation(() => {
      throw new Error('boom');
    }),

    users: {
      list: publicProcedure.query(() => deps.usersService.findAll()),

      get: publicProcedure
        .input((value) => {
          if (!value || typeof value !== 'object') {
            throw new Error('Invalid input');
          }
          const v = value as Record<string, unknown>;
          const id = String(v.id ?? '');
          if (!id) {
            throw new Error('Invalid input');
          }
          return { id };
        })
        .query(({ input }) => deps.usersService.findOne(input.id)),
    },
  });

  return { t, appRouter };
}

export type AppRouter = ReturnType<typeof createTrpcFactory>['appRouter'];
