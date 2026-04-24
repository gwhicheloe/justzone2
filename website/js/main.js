// Nav scroll
const nav = document.getElementById('nav');
window.addEventListener('scroll', () => nav.classList.toggle('scrolled', window.scrollY > 32), {passive:true});

// Mobile menu toggle
const navToggle = document.getElementById('nav-toggle');
const navLinks = document.getElementById('nav-links');
if (navToggle && navLinks) {
  const close = () => {
    navToggle.classList.remove('open');
    navLinks.classList.remove('open');
    navToggle.setAttribute('aria-expanded', 'false');
  };
  navToggle.addEventListener('click', () => {
    const isOpen = navToggle.classList.toggle('open');
    navLinks.classList.toggle('open', isOpen);
    navToggle.setAttribute('aria-expanded', String(isOpen));
  });
  navLinks.querySelectorAll('a').forEach(a => a.addEventListener('click', close));
}

// Reveal
const ro = new IntersectionObserver(entries => {
  entries.forEach(e => { if (e.isIntersecting) { e.target.classList.add('in'); ro.unobserve(e.target); }});
}, {threshold:.06, rootMargin:'0px 0px -30px 0px'});
document.querySelectorAll('.rv').forEach(el => ro.observe(el));

// Smooth anchor scroll
document.querySelectorAll('a[href^="#"]').forEach(a => {
  a.addEventListener('click', e => {
    const t = document.querySelector(a.getAttribute('href'));
    if (t) { e.preventDefault(); t.scrollIntoView({behavior:'smooth', block:'start'}); }
  });
});

// Live phone
let elapsed = 1700, total = 3600, chunk = 900;
let hr = 142, pw = 168;
const fmt = s => `${String(Math.floor(s/60)).padStart(2,'0')}:${String(s%60).padStart(2,'0')}`;
const els = {
  timer: document.getElementById('hp-timer'),
  elapsed: document.getElementById('hp-elapsed'),
  remain: document.getElementById('hp-remain'),
  pb: document.getElementById('prog-bar'),
  hr: document.getElementById('hp-hr'),
  pw: document.getElementById('hp-pw')
};
setInterval(() => {
  elapsed = Math.min(total, elapsed + 1);
  const inChunk = elapsed % chunk;
  const remaining = chunk - inChunk;
  els.timer && (els.timer.textContent = fmt(remaining));
  els.elapsed && (els.elapsed.textContent = fmt(elapsed));
  els.remain && (els.remain.textContent = fmt(total - elapsed));
  els.pb && els.pb.setAttribute('width', String(Math.round((elapsed / total) * 270)));
  if (Math.random() > .68) { hr += Math.random() > .5 ? 1 : -1; hr = Math.max(139, Math.min(147, hr)); els.hr && (els.hr.textContent = hr); }
  if (Math.random() > .76) { pw += Math.random() > .5 ? 1 : -1; pw = Math.max(163, Math.min(173, pw)); els.pw && (els.pw.textContent = pw); }
}, 1000);
