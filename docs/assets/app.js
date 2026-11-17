// TnP Student website. Change CONFIG if the repository moves.
const CONFIG = {
  repo: 'urraf/tnp-student', // GitHub "owner/name"
  apk: 'TnP-Student.apk', // asset name attached to every release
};

const releaseApi = `https://api.github.com/repos/${CONFIG.repo}/releases/latest`;
// The APK is published next to this page (see .github/workflows/pages.yml), so the
// download never touches github.com — on phones with the GitHub app installed, Android
// opens github.com links in that app, which shows a sign-in screen instead of downloading.
const siteApk = new URL(CONFIG.apk, window.location.href).href;
// Fallback until the site has its own copy: newest release on GitHub.
const githubApk = `https://github.com/${CONFIG.repo}/releases/latest/download/${CONFIG.apk}`;
let downloadUrl = siteApk;
const repoUrl = `https://github.com/${CONFIG.repo}`;

const ua = navigator.userAgent;
const isAndroid = /Android/i.test(ua);
const isIOS = /iPhone|iPad|iPod/i.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
const isMobile = isAndroid || isIOS || /Mobi/i.test(ua);

// ---------------------------------------------------------------- Links ----
// Every Download button (navbar included) downloads the APK directly.
const setDownloadLinks = (url) => {
  downloadUrl = url;
  document.querySelectorAll('.js-download').forEach((a) => {
    a.href = url;
    a.setAttribute('download', CONFIG.apk);
  });
};
document.querySelectorAll('.js-download').forEach((a) => {
  a.addEventListener('click', () => {
    if (!isIOS) return;
    document.getElementById('ios-note')?.removeAttribute('hidden');
  });
});
setDownloadLinks(siteApk);
// If this copy of the site has no APK next to it (local preview, first deploy), use GitHub.
const apkCheck = window.location.protocol.startsWith('http')
  ? fetch(siteApk, { method: 'HEAD', cache: 'no-store' })
      .then((r) => { if (!r.ok) setDownloadLinks(githubApk); })
      .catch(() => setDownloadLinks(githubApk))
  : Promise.resolve(setDownloadLinks(githubApk));
document.querySelectorAll('.js-github').forEach((a) => (a.href = repoUrl));
document.querySelectorAll('.js-releases').forEach((a) => (a.href = `${repoUrl}/releases`));
if (isIOS) document.getElementById('ios-note')?.removeAttribute('hidden');

// ----------------------------------------------------- Latest release info --
fetch(releaseApi, { headers: { Accept: 'application/vnd.github+json' } })
  .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
  .then((rel) => {
    const version = String(rel.tag_name || '').replace(/^v/i, '');
    const asset = (rel.assets || []).find((x) => x.name === CONFIG.apk) || (rel.assets || []).find((x) => /\.apk$/i.test(x.name));
    const size = asset ? `${(asset.size / 1048576).toFixed(0)} MB` : '';
    const date = rel.published_at ? new Date(rel.published_at).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }) : '';
    const short = [version && `v${version}`, size, 'free'].filter(Boolean).join(' · ');
    const long = [version && `Version ${version}`, date && `updated ${date}`, 'Android 7.0+', size].filter(Boolean).join(' · ');
    document.querySelectorAll('.js-release-meta').forEach((el) => (el.textContent = short));
    document.querySelectorAll('.js-release-meta-long').forEach((el) => (el.textContent = long));
    document.querySelectorAll('.js-release-size').forEach((el) => (el.textContent = size ? `${size} · direct download` : 'Direct download'));
  })
  .catch(() => { /* keep the static text */ });

// -------------------------------------------------------------------- QR ----
window.addEventListener('load', async () => {
  const card = document.getElementById('qr-card');
  if (isMobile || !card || typeof QRCode === 'undefined') return;
  await apkCheck;
  card.hidden = false;
  // eslint-disable-next-line no-new
  new QRCode(document.getElementById('qr'), {
    text: downloadUrl,
    width: 176,
    height: 176,
    colorDark: '#0e1120',
    colorLight: '#ffffff',
    correctLevel: QRCode.CorrectLevel.M,
  });
});

// ------------------------------------------------------------- Nav state ----
const nav = document.querySelector('.nav');
const onScroll = () => nav.classList.toggle('is-scrolled', window.scrollY > 24);
onScroll();
window.addEventListener('scroll', onScroll, { passive: true });

// ---------------------------------------------------------- Scroll reveal ---
const io = 'IntersectionObserver' in window
  ? new IntersectionObserver((entries) => {
      entries.forEach((e) => {
        if (!e.isIntersecting) return;
        e.target.classList.add('is-visible');
        io.unobserve(e.target);
      });
    }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' })
  : null;
document.querySelectorAll('.reveal').forEach((el, i) => {
  el.style.transitionDelay = `${Math.min(i % 6, 5) * 70}ms`;
  if (io) io.observe(el); else el.classList.add('is-visible');
});

// ------------------------------------------------------------ Chime demo ---
const chime = document.getElementById('chime');
document.querySelector('.js-play')?.addEventListener('click', () => {
  chime.currentTime = 0;
  chime.play().catch(() => {});
});
