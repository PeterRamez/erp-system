'use client';
import { useMemo, useState } from 'react';

type Props={value?:string;onChange:(value:string)=>void;placeholder?:string;required?:boolean;label?:string;includeTime?:boolean};
const monthNames=['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
const week=['ح','ن','ث','ر','خ','ج','س'];
const pad=(n:number)=>String(n).padStart(2,'0');
const parse=(v:string)=>{if(!v)return new Date();const [date,time='00:00']=v.split('T');const [y,m,d]=date.split('-').map(Number);const [hh,mm]=time.split(':').map(Number);return new Date(y,m-1,d,hh||0,mm||0);};
const localValue=(d:Date)=>`${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
export default function DateTimePicker({value='',onChange,placeholder='اختار التاريخ',required=false,label,includeTime=true}:Props){
 const selected=parse(value);const [open,setOpen]=useState(false);const [view,setView]=useState(()=>new Date(selected.getFullYear(),selected.getMonth(),1));
 const cells=useMemo(()=>{const first=new Date(view.getFullYear(),view.getMonth(),1).getDay();const count=new Date(view.getFullYear(),view.getMonth()+1,0).getDate();return [...Array(first).fill(null),...Array.from({length:count},(_,i)=>i+1)];},[view]);
 const dateText=value?selected.toLocaleDateString('ar-EG',{weekday:'long',year:'numeric',month:'long',day:'numeric'}):'';
 const timeText=value?`${pad(selected.getHours())}:${pad(selected.getMinutes())}`:'09:00';
 const commit=(date:Date,time=timeText)=>{const [h,m]=time.split(':').map(Number);date.setHours(h||0,m||0,0,0);onChange(localValue(date));};
 return <div className="date-picker-wrap">
  <button type="button" className={`date-picker-trigger ${required&&!value?'date-picker-required':''}`} onClick={()=>{if(!open)setView(new Date(selected.getFullYear(),selected.getMonth(),1));setOpen(v=>!v)}} aria-haspopup="dialog" aria-expanded={open}>
   <span className="date-picker-icon">▦</span><span className={value?'':'date-picker-placeholder'}>{value?dateText+(includeTime?` · ${timeText}`:''):placeholder}</span><span className="date-picker-caret">⌄</span>
  </button>
  {open&&<div className="date-picker-popover" role="dialog" aria-label={label||'اختيار التاريخ'}>
   <div className="date-picker-month"><button type="button" aria-label="الشهر التالي" onClick={()=>setView(new Date(view.getFullYear(),view.getMonth()+1,1))}>‹</button><strong>{monthNames[view.getMonth()]} {view.getFullYear()}</strong><button type="button" aria-label="الشهر السابق" onClick={()=>setView(new Date(view.getFullYear(),view.getMonth()-1,1))}>›</button></div>
   <div className="date-picker-grid">{week.map((d,i)=><span className="date-picker-weekday" key={i}>{d}</span>)}{cells.map((day,i)=>day===null?<span key={`blank-${i}`}/>:<button type="button" key={day} className={`date-picker-day ${selected.getFullYear()===view.getFullYear()&&selected.getMonth()===view.getMonth()&&selected.getDate()===day&&value?'active':''} ${new Date().getFullYear()===view.getFullYear()&&new Date().getMonth()===view.getMonth()&&new Date().getDate()===day?'today':''}`} onClick={()=>{const d=new Date(view.getFullYear(),view.getMonth(),day);commit(d);if(!includeTime)setOpen(false);}}>{day}</button>)}</div>
   {includeTime&&<div className="date-picker-time"><label>الوقت</label><input type="time" value={timeText} onChange={e=>commit(new Date(selected.getFullYear(),selected.getMonth(),selected.getDate()),e.target.value)}/><button type="button" onClick={()=>setOpen(false)}>تم</button></div>}
   <div className="date-picker-footer"><button type="button" onClick={()=>{const now=new Date();commit(now);setView(new Date(now.getFullYear(),now.getMonth(),1));}}>اليوم</button><button type="button" onClick={()=>{onChange('');setOpen(false);}}>مسح</button></div>
  </div>}
 </div>;
}
