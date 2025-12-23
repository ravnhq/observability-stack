import {
  ApolloServerPlugin,
  GraphQLRequestContext,
  GraphQLRequestListener,
} from '@apollo/server';
import { Plugin } from '@nestjs/apollo';
import { MetricsService } from '../services/metrics.service';
import { trace } from '@opentelemetry/api';
import { GraphQLError } from 'graphql';

@Plugin()
export class GraphQLMetricsPlugin implements ApolloServerPlugin {
  constructor(private readonly metricsService: MetricsService) {}

  async requestDidStart(
    requestContext: GraphQLRequestContext<any>,
  ): Promise<GraphQLRequestListener<any>> {
    const startTime = Date.now();
    let errorPhase: string | null = null;
    let errors: readonly GraphQLError[] | null = null;

    // Store reference to plugin instance to avoid 'this' binding issues
    const plugin = this;

    return {
      async didEncounterErrors(ctx) {
        errors = ctx.errors;
        errorPhase = plugin.determineErrorPhase(ctx, errors);
      },

      async willSendResponse(ctx) {
        const duration = (Date.now() - startTime) / 1000;

        // Extract metadata
        const operationName = plugin.extractOperationName(ctx);
        const operationType = plugin.extractOperationType(ctx);
        const phase = errorPhase || 'SUCCESS';
        const { status, outcome } = plugin.determineStatusAndOutcome(
          errors,
          errorPhase,
        );
        const exception = plugin.extractException(errors);

        // Extract trace context
        const { traceId, spanId } = plugin.extractTraceContext();

        // Observe metric
        plugin.metricsService.getGraphqlOperationHistogram().observe({
          value: duration,
          labels: {
            operation_name: operationName,
            operation_type: operationType,
            status: status,
            outcome: outcome,
            exception: exception,
            phase: phase,
          },
          exemplarLabels: {
            trace_id: traceId,
            span_id: spanId,
          },
        });
      },
    };
  }

  /**
   * Extract operation name from request context
   * Returns named operation or 'anonymous' as fallback
   */
  private extractOperationName(ctx: GraphQLRequestContext<any>): string {
    return ctx.operationName || 'anonymous';
  }

  /**
   * Extract operation type (query, mutation, subscription)
   */
  private extractOperationType(ctx: GraphQLRequestContext<any>): string {
    if (!ctx.operation) {
      return 'unknown';
    }
    return ctx.operation.operation;
  }

  /**
   * Determine the phase where error occurred
   * Returns: PARSE, VALIDATE, or EXECUTE
   */
  private determineErrorPhase(
    ctx: GraphQLRequestContext<any>,
    errors: readonly GraphQLError[] | null,
  ): string | null {
    if (!errors || errors.length === 0) {
      return null;
    }

    const error = errors[0];

    // Parse errors: no operation available
    if (!ctx.operation) {
      return 'PARSE';
    }

    // Validation errors: check error extensions
    if (error.extensions?.code === 'GRAPHQL_VALIDATION_FAILED') {
      return 'VALIDATE';
    }

    // Check if error has path (execution error)
    if (error.path && error.path.length > 0) {
      return 'EXECUTE';
    }

    // Other errors without path are likely validation
    return 'VALIDATE';
  }

  /**
   * Determine HTTP-like status code and outcome based on error phase
   */
  private determineStatusAndOutcome(
    errors: readonly GraphQLError[] | null,
    errorPhase: string | null,
  ): { status: string; outcome: string } {
    if (!errorPhase) {
      return { status: '200', outcome: 'SUCCESS' };
    }

    if (errorPhase === 'PARSE' || errorPhase === 'VALIDATE') {
      return { status: '400', outcome: 'CLIENT_ERROR' };
    }

    return { status: '500', outcome: 'SERVER_ERROR' };
  }

  /**
   * Extract exception name from errors
   */
  private extractException(errors: readonly GraphQLError[] | null): string {
    if (!errors || errors.length === 0) {
      return 'none';
    }

    const error = errors[0];

    // Use extension code if available
    if (error.extensions?.code) {
      return error.extensions.code as string;
    }

    // Use error class name
    if (error.constructor?.name) {
      return error.constructor.name;
    }

    return 'GraphQLError';
  }

  /**
   * Extract trace ID and span ID from the active OpenTelemetry span context.
   * Falls back to 'none' if no active span is available.
   */
  private extractTraceContext(): { traceId: string; spanId: string } {
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

    // Fallback to 'none' if no active span is available
    return { traceId: 'none', spanId: 'none' };
  }
}
