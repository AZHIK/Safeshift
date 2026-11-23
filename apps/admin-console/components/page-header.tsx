import Link from 'next/link';
import type { ReactNode } from 'react';

export function PageHeader({
  title,
  description,
  actions,
  records,
}: {
  title: string;
  description?: string;
  actions?: ReactNode;
  records?: string[];
}) {
  return (
    <div className="page-head">
      <div>
        <h1 className="page-title">{title}</h1>
        {description ? <p className="page-desc">{description}</p> : null}
      </div>
      {(actions || records) && <div className="page-actions">{actions}{records?.map(key=><Link className="btn" key={key} href={'/records/'+key}>Browse & export {key.replaceAll('-',' ')}</Link>)}</div>}
    </div>
  );
}
