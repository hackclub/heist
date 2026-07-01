export let userName = '';
export let isAuthed = false;

export async function checkAuth() {
  try {
    const r = await fetch('/auth/me');
    if (r.ok) {
      const data = await r.json();
      userName = data.name || '';
      isAuthed = true;
      return true;
    }
  } catch (e) { /* */ }
  isAuthed = false;
  return false;
}

export async function api<T>(url: string): Promise<T> {
  const r = await fetch(url);
  if (!r.ok) throw new Error(`API error: ${r.status}`);
  return r.json();
}

export function esc(s: string) {
  const d = document.createElement('div');
  d.textContent = s;
  return d.innerHTML;
}

export function fmt(s: string) {
  return new Date(s).toLocaleString();
}
