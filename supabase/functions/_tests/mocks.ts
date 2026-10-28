// deno-lint-ignore-file require-await
import type { SupabaseClient } from '../_shared/db.ts';

export interface QueryContext {
  table: string;
  op: 'select' | 'insert' | 'update' | 'upsert';
  columns?: string;
  options?: unknown;
  payload?: unknown;
  filters: Array<[string, unknown]>;
}

export interface QueryResult<T = unknown> {
  data?: T;
  error?: { code?: string; message?: string } | null;
  count?: number;
}

export interface TableMock {
  select?: (context: QueryContext) => QueryResult | Promise<QueryResult>;
  insert?: (context: QueryContext) => QueryResult | Promise<QueryResult>;
  update?: (context: QueryContext) => QueryResult | Promise<QueryResult>;
  upsert?: (context: QueryContext) => QueryResult | Promise<QueryResult>;
}

export interface SupabaseMockOptions {
  tables?: Record<string, TableMock>;
  rpc?: (name: string, args: Record<string, unknown>) => QueryResult | Promise<QueryResult>;
  storage?: {
    upload?: (bucket: string, path: string, body: unknown, options: unknown) => QueryResult;
    createSignedUrl?: (bucket: string, path: string, expiresIn: number) => QueryResult;
    list?: (bucket: string, prefix: string, options: unknown) => QueryResult;
    remove?: (bucket: string, paths: string[]) => QueryResult;
  };
}

class QueryBuilder {
  private op: QueryContext['op'] = 'select';
  private columns: string | undefined;
  private options: unknown;
  private payload: unknown;
  private readonly filters: Array<[string, unknown]> = [];

  constructor(
    private readonly table: string,
    private readonly optionsMap: SupabaseMockOptions,
  ) {}

  select(columns?: string, options?: unknown): this {
    if (this.op === 'select') this.columns = columns;
    this.options = options;
    return this;
  }

  insert(payload: unknown): this {
    this.op = 'insert';
    this.payload = payload;
    return this;
  }

  update(payload: unknown): this {
    this.op = 'update';
    this.payload = payload;
    return this;
  }

  upsert(payload: unknown, options?: unknown): this {
    this.op = 'upsert';
    this.payload = payload;
    this.options = options;
    return this;
  }

  eq(column: string, value: unknown): this {
    this.filters.push([column, value]);
    return this;
  }

  gt(column: string, value: unknown): this {
    this.filters.push([`>${column}`, value]);
    return this;
  }

  or(expression: string): this {
    this.filters.push(['or', expression]);
    return this;
  }

  limit(_count: number): this {
    return this;
  }

  order(_column: string, _options?: unknown): this {
    return this;
  }

  private resolve(): QueryResult | Promise<QueryResult> {
    const table = this.optionsMap.tables?.[this.table];
    if (!table) return { data: null, error: null };
    const context: QueryContext = {
      table: this.table,
      op: this.op,
      columns: this.columns,
      options: this.options,
      payload: this.payload,
      filters: this.filters,
    };
    const handler = table[this.op];
    return handler ? handler(context) : { data: null, error: null };
  }

  maybeSingle(): Promise<QueryResult> {
    return Promise.resolve(this.resolve());
  }

  single(): Promise<QueryResult> {
    return Promise.resolve(this.resolve());
  }

  then<TResult1 = QueryResult, TResult2 = never>(
    onfulfilled?: ((value: QueryResult) => TResult1 | PromiseLike<TResult1>) | null,
    onrejected?: ((reason: unknown) => TResult2 | PromiseLike<TResult2>) | null,
  ): Promise<TResult1 | TResult2> {
    return Promise.resolve(this.resolve()).then(onfulfilled, onrejected);
  }
}

export function createSupabaseMock(options: SupabaseMockOptions = {}): SupabaseClient {
  return {
    from(table: string) {
      return new QueryBuilder(table, options);
    },
    rpc(name: string, args: Record<string, unknown> = {}) {
      return Promise.resolve(options.rpc ? options.rpc(name, args) : { data: null, error: null });
    },
    storage: {
      from(bucket: string) {
        return {
          upload(path: string, body: unknown, uploadOptions: unknown) {
            return Promise.resolve(
              options.storage?.upload?.(bucket, path, body, uploadOptions) ?? {
                data: { path },
                error: null,
              },
            );
          },
          createSignedUrl(path: string, expiresIn: number) {
            return Promise.resolve(
              options.storage?.createSignedUrl?.(bucket, path, expiresIn) ?? {
                data: { signedUrl: `https://example.test/${bucket}/${path}` },
                error: null,
              },
            );
          },
          list(prefix: string, listOptions: unknown) {
            return Promise.resolve(
              options.storage?.list?.(bucket, prefix, listOptions) ?? {
                data: [],
                error: null,
              },
            );
          },
          remove(paths: string[]) {
            return Promise.resolve(
              options.storage?.remove?.(bucket, paths) ?? {
                data: paths.map((name) => ({ name })),
                error: null,
              },
            );
          },
        };
      },
    },
    auth: {
      getUser: async (token: string) => ({
        data: { user: token ? { id: '00000000-0000-4000-8000-000000000001' } : null },
        error: null,
      }),
    },
  } as unknown as SupabaseClient;
}
