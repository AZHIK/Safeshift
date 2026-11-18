/**
 * A small in-memory stand-in for the Supabase client.
 *
 * The configuration console talks to the database through the query builder
 * of @supabase/supabase-js. The tests drive the same builder surface the
 * engine uses, with the answers programmed per table and per operation, so
 * the engine is exercised without a database.
 */

export type MockFilter = {
  column: string;
  operator: 'eq' | 'neq' | 'is' | 'or';
  value: unknown;
};

export type MockRequest = {
  table: string;
  operation: 'select' | 'insert' | 'update' | 'delete';
  filters: MockFilter[];
  payload?: Record<string, unknown>;
  order?: { column: string; ascending: boolean };
  range?: { from: number; to: number };
  limit?: number;
  single: boolean;
};

export type MockResult = {
  data?: unknown;
  error?: { message: string } | null;
  count?: number;
};

export type MockHandler = (request: MockRequest) => MockResult | Promise<MockResult>;

export type MockRpcHandler = (
  name: string,
  args: Record<string, unknown>,
) => MockResult | Promise<MockResult>;

export type MockClient = {
  from: (table: string) => MockBuilder;
  rpc: (name: string, args: Record<string, unknown>) => Promise<MockResult>;
  auth: { getUser: () => Promise<{ data: { user: { id: string } | null }; error: null }> };
  requests: MockRequest[];
  rpcCalls: { name: string; args: Record<string, unknown> }[];
};

class MockBuilder implements PromiseLike<MockResult> {
  private request: MockRequest;

  constructor(
    table: string,
    operation: MockRequest['operation'],
    payload: Record<string, unknown> | undefined,
    requests: MockRequest[],
  ) {
    this.request = {
      table,
      operation,
      filters: [],
      payload,
      single: false,
    };
    requests.push(this.request);
  }

  select(): MockBuilder {
    return this;
  }

  insert(payload: Record<string, unknown>): MockBuilder {
    this.request.operation = 'insert';
    this.request.payload = payload;
    return this;
  }

  update(payload: Record<string, unknown>): MockBuilder {
    this.request.operation = 'update';
    this.request.payload = payload;
    return this;
  }

  delete(): MockBuilder {
    this.request.operation = 'delete';
    return this;
  }

  eq(column: string, value: unknown): MockBuilder {
    this.request.filters.push({ column, operator: 'eq', value });
    return this;
  }

  neq(column: string, value: unknown): MockBuilder {
    this.request.filters.push({ column, operator: 'neq', value });
    return this;
  }

  is(column: string, value: unknown): MockBuilder {
    this.request.filters.push({ column, operator: 'is', value });
    return this;
  }

  or(clause: string): MockBuilder {
    this.request.filters.push({ column: '__or', operator: 'or', value: clause });
    return this;
  }

  order(column: string, options?: { ascending?: boolean }): MockBuilder {
    this.request.order = { column, ascending: options?.ascending ?? true };
    return this;
  }

  range(from: number, to: number): MockBuilder {
    this.request.range = { from, to };
    return this;
  }

  limit(count: number): MockBuilder {
    this.request.limit = count;
    return this;
  }

  single(): MockBuilder {
    this.request.single = true;
    return this;
  }

  maybeSingle(): MockBuilder {
    this.request.single = true;
    return this;
  }

  then<TResult1 = MockResult, TResult2 = never>(
    onfulfilled?: ((value: MockResult) => TResult1 | PromiseLike<TResult1>) | null,
    onrejected?: ((reason: unknown) => TResult2 | PromiseLike<TResult2>) | null,
  ): PromiseLike<TResult1 | TResult2> {
    return this.resolve().then(onfulfilled, onrejected);
  }

  private async resolve(): Promise<MockResult> {
    const handler = (this as unknown as { handler: MockHandler }).handler;
    return handler(this.request);
  }
}

/** Builds a mock client that answers with the given handlers. */
export function createMockClient(handler: MockHandler, rpcHandler?: MockRpcHandler): MockClient {
  const requests: MockRequest[] = [];
  const rpcCalls: { name: string; args: Record<string, unknown> }[] = [];

  const client: MockClient = {
    from(table: string) {
      const builder = new MockBuilder(table, 'select', undefined, requests);
      (builder as unknown as { handler: MockHandler }).handler = handler;
      return builder;
    },
    async rpc(name: string, args: Record<string, unknown>) {
      rpcCalls.push({ name, args });
      if (!rpcHandler) return { data: null, error: null };
      return rpcHandler(name, args);
    },
    auth: {
      async getUser() {
        return { data: { user: { id: '11111111-1111-4111-8111-111111111111' } }, error: null };
      },
    },
    requests,
    rpcCalls,
  };

  return client;
}

/** The requests the client received for one table. */
export function requestsFor(client: MockClient, table: string): MockRequest[] {
  return client.requests.filter((request) => request.table === table);
}

/** The single request the client received for one table and operation. */
export function requestFor(
  client: MockClient,
  table: string,
  operation: MockRequest['operation'],
): MockRequest | undefined {
  return requestsFor(client, table).find((request) => request.operation === operation);
}
