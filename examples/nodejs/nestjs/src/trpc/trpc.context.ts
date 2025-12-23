import type { Request, Response } from 'express';

export type TrpcContext = {
  req: Request;
  res: Response;
};

export function createTrpcContext(opts: { req: Request; res: Response }): TrpcContext {
  return { req: opts.req, res: opts.res };
}
