export interface ApiError {
  code: string;
  message: string;
  details?: unknown;
}

export type ApiResult<T> = { data: T; error: null } | { data: null; error: ApiError };

export interface Pagination {
  page: number;
  pageSize: number;
  total: number;
}

export interface Paginated<T> {
  items: T[];
  pagination: Pagination;
}

export type SortDirection = 'asc' | 'desc';

export interface Money {
  amount: number;
  currencyCode: string;
}
