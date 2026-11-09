// Google Calendar's reminders call alert(): they become cards in the page
// (calendar.css), one per reminder, counted in the service's badge, each with
// "In 5 min" (shown again 5 minutes later) and "OK". × or Escape closes them
// all; Escape elsewhere in Calendar (closing an event…) leaves the count alone.
// Built with DOM calls, not markup: calendar.google.com sends
// `require-trusted-types-for 'script'`, so assigning innerHTML throws.
(() => {
  if (window.__vigieReminders) return;
  window.__vigieReminders = true;

  const fr = (document.documentElement.lang || navigator.language).startsWith('fr');
  const label = {
    one: fr ? 'Rappel' : 'Reminder',
    many: n => (fr ? `${n} rappels` : `${n} reminders`),
    snooze: fr ? 'Dans 5 min' : 'In 5 min',
    closeAll: fr ? 'Tout fermer' : 'Close all',
  };
  const SNOOZE_MS = 5 * 60 * 1000;

  const el = (tag, className, text) => {
    const e = document.createElement(tag);
    if (className) e.className = className;
    if (text) e.textContent = text;
    return e;
  };

  const modal = el('div');
  modal.id = 'franz-modal';
  const title = el('span', 'vigie-title');
  const closeAll = el('button', 'vigie-close', '×');
  closeAll.title = label.closeAll;
  const header = el('div', 'vigie-header');
  header.append(el('span', 'vigie-bell', '🔔'), title, closeAll);
  const list = el('div', 'vigie-list');
  const card = el('div', 'vigie-card');
  card.append(header, list);
  modal.append(card);

  const update = () => {
    const n = list.children.length;
    title.textContent = n > 1 ? label.many(n) : label.one;
    modal.classList.toggle('open', n > 0);
    window.vigie.setBadge(n);
  };

  const show = text => {
    const item = el('div', 'vigie-reminder');
    const snooze = el('button', 'vigie-snooze', label.snooze);
    const ok = el('button', 'vigie-ok', 'OK');
    snooze.addEventListener('click', () => {
      item.remove();
      update();
      setTimeout(() => show(text), SNOOZE_MS);
    });
    ok.addEventListener('click', () => {
      item.remove();
      update();
    });
    const actions = el('div', 'vigie-actions');
    actions.append(snooze, ok);
    item.append(el('p', 'vigie-text', String(text ?? '')), actions);
    list.append(item);
    update();
  };

  const hideAll = () => {
    if (!list.children.length) return;
    list.replaceChildren();
    update();
  };
  closeAll.addEventListener('click', hideAll);
  document.addEventListener('keydown', e => e.key === 'Escape' && modal.classList.contains('open') && hideAll());

  window.alert = show;
  const attach = () => (document.body ? document.body.append(modal) : setTimeout(attach, 100));
  attach();
})();
