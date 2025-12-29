import { Module, OnModuleInit } from '@nestjs/common';
import type { INestApplication } from '@nestjs/common';
import { createExpressMiddleware } from '@trpc/server/adapters/express';
import { TrpcMetricsService } from './trpc.metrics';
import { createTrpcContext } from './trpc.context';
import { createTrpcFactory } from './trpc';
import { MetricsService } from '../common/services/metrics.service';
import { UsersModule } from '../users/users.module';
import { UsersService } from '../users/services/users.service';

@Module({
  imports: [UsersModule],
  providers: [TrpcMetricsService],
  exports: [TrpcMetricsService],
})
export class TrpcModule implements OnModuleInit {
  constructor(
    private readonly trpcMetrics: TrpcMetricsService,
    private readonly usersService: UsersService,
  ) {}

  // no-op: wiring happens from bootstrap via app.get(TrpcModule) pattern
  onModuleInit() {}

  mount(app: INestApplication) {
    const expressApp = app.getHttpAdapter().getInstance();

    const { appRouter } = createTrpcFactory({ metrics: this.trpcMetrics, usersService: this.usersService });

    expressApp.use(
      '/trpc',
      createExpressMiddleware({
        router: appRouter,
        createContext: ({ req, res }) => createTrpcContext({ req, res }),
      }),
    );
  }
}
