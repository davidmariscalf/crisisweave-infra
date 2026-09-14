const WORKSITES=[
{id:'cw-work-001',title:'Remove flood debris from community centre',area:'Synthetic River District',type:'Debris removal',state:'assigned',priority:'urgent',people:6,skills:['General cleanup'],hazards:['Sharp debris','Unstable material'],team:'Demo Response Team',instructions:'Meet the coordinator at the staging point before entering the site.'},
{id:'cw-work-002',title:'Tarp damaged roof after storm',area:'Synthetic West Ward',type:'Tarping',state:'ready',priority:'high',people:4,skills:['Roof safety'],hazards:['Fall risk','Wet surface'],team:null,instructions:'Roof work requires an approved crew lead and fall protection.'},
{id:'cw-work-003',title:'Deliver cleanup supplies to staging point',area:'Synthetic River District',type:'Delivery',state:'ready',priority:'normal',people:2,skills:['Driving'],hazards:['Traffic'],team:null,instructions:'Check in at staging before loading supplies.'},
{id:'cw-work-004',title:'Muck out ground floor after flood assessment',area:'Synthetic South Bank',type:'Muck out',state:'in_progress',priority:'high',people:5,skills:['General cleanup'],hazards:['Contaminated water','Heavy lifting'],team:'Demo Cleanup Crew B',instructions:'Use assigned PPE. Stop work if utilities or structure appear unsafe.'},
{id:'cw-work-005',title:'Assess fallen tree blocking community access',area:'Synthetic Hill District',type:'Assessment',state:'ready',priority:'normal',people:2,skills:['Damage assessment'],hazards:['Unstable tree'],team:null,instructions:'Assessment only. Do not cut or move the tree without a qualified team.'}
];
let active='open';
const grid=document.getElementById('grid'),empty=document.getElementById('empty'),search=document.getElementById('search');
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
function visible(w){
  if(active==='open'&&!['ready','assigned','in_progress'].includes(w.state))return false;
  if(active==='ready'&&w.state!=='ready')return false;
  if(active==='priority'&&!['urgent','high'].includes(w.priority))return false;
  if(active==='in_progress'&&w.state!=='in_progress')return false;
  const q=search.value.trim().toLowerCase();
  return !q||[w.title,w.area,w.type,...w.skills,...w.hazards].join(' ').toLowerCase().includes(q);
}
function stateLabel(s){return({ready:'Ready',assigned:'Assigned',in_progress:'In progress'}[s]||s)}
function card(w){return `<article class="card"><div class="row"><span class="state ${esc(w.state)}">${esc(stateLabel(w.state))}</span><span class="priority ${esc(w.priority)}">${esc(w.priority)}</span></div><h2>${esc(w.title)}</h2><div class="area">${esc(w.area)} · ${esc(w.type)}</div><div class="facts"><div class="fact"><span>People needed</span><strong>${w.people}</strong></div><div class="fact"><span>Assignment</span><strong>${esc(w.team||'Unassigned')}</strong></div></div><div class="label">Skills</div><div class="chips">${w.skills.map(x=>`<span class="chip">${esc(x)}</span>`).join('')}</div><div class="label">Hazards</div><div class="chips">${w.hazards.map(x=>`<span class="chip hazard">${esc(x)}</span>`).join('')}</div><div class="instructions">${esc(w.instructions)}</div>${w.team?`<div class="team">Assigned team: <strong>${esc(w.team)}</strong></div>`:''}<div class="source">Source: synthetic requested/assessed worksite · No hazard-to-job inference</div></article>`}
function render(){const rows=WORKSITES.filter(visible);grid.innerHTML=rows.map(card).join('');empty.style.display=rows.length?'none':'block';document.getElementById('count').textContent=`${rows.length} worksite${rows.length===1?'':'s'}`}
document.querySelectorAll('.filter').forEach(b=>b.onclick=()=>{document.querySelectorAll('.filter').forEach(x=>x.classList.remove('active'));b.classList.add('active');active=b.dataset.filter;render()});
search.oninput=render;
render();
