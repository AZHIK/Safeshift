'use client';
import { useState } from 'react';
export function ReplyText({ choices }: { choices:{id:string;name:string;body:string}[] }) {
  const [message,setMessage]=useState('');
  return <>{choices.length > 0 && <label className="field">Insert saved reply
    <select className="input" value="" onChange={e=>{const choice=choices.find(c=>c.id===e.target.value); if(choice) setMessage(text=>text ? text+'\n'+choice.body : choice.body);}}>
      <option value="">Choose a reply</option>{choices.map(c=><option key={c.id} value={c.id}>{c.name}</option>)}
    </select></label>}
    <label className="field">Message<textarea required className="input" name="message" value={message} onChange={e=>setMessage(e.target.value)}/></label></>;
}
