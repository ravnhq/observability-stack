import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { Response } from 'express';

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();

    // Store exception in response locals for metrics middleware
    response.locals.exception = exception;

    // Determine status code
    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;

    // Get error response
    const errorResponse =
      exception instanceof HttpException
        ? exception.getResponse()
        : { message: 'Internal server error' };

    // Send response
    response.status(status).json({
      statusCode: status,
      timestamp: new Date().toISOString(),
      error:
        typeof errorResponse === 'string'
          ? errorResponse
          : (errorResponse as any).message || errorResponse,
    });
  }
}
