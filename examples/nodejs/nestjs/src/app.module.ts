import { Module, NestModule, MiddlewareConsumer } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { LoggerModule } from 'nestjs-pino';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { CommonModule } from './common/common.module';
import { UsersModule } from './users/users.module';
import { HttpMetricsMiddleware } from './common/middleware/http-metrics.middleware';

const isProduction = process.env.NODE_ENV === 'production';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    LoggerModule.forRoot({
      pinoHttp: {
        transport: isProduction
          ? {
            targets: [
              {
                target: 'pino-opentelemetry-transport',
                level: process.env.LOG_LEVEL || 'info',
                options: {},
              },
              {
                target: 'pino/file',
                level: process.env.LOG_LEVEL || 'info',
                options: { destination: 1 }, // stdout
              },
            ],
          }
          : { target: 'pino-pretty', options: { colorize: true } },
        level: process.env.LOG_LEVEL || 'info',
        // Add trace context to logs for correlation
        customProps: () => ({
          context: 'HTTP',
        }),
        // Redact sensitive fields
        redact: ['req.headers.authorization', 'req.headers.cookie'],
        // Auto-log request/response
        autoLogging: true,
      },
    }),
    CommonModule,
    UsersModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(HttpMetricsMiddleware).forRoutes('*');
  }
}