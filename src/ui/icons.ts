const paths: Record<string, string> = {
  wheat:
    '<path d="M7 22 17 2M12 12C4 12 4 5 4 5s8 0 8 7Zm2-4c-2-7 5-7 5-7s1 6-5 7Zm-5 9c-7 0-7-6-7-6s7 0 7 6Zm3-2c1-7 8-6 8-6s-1 7-8 6Z"/>',
  coin: '<circle cx="12" cy="12" r="9"/><path d="M15 7h-4a3 3 0 0 0 0 6h2a2 2 0 0 1 0 4H9m3-12v14"/>',
  house: '<path d="m3 11 9-8 9 8M5 10v11h14V10M10 21v-7h4v7"/>',
  sun: '<circle cx="12" cy="12" r="4"/><path d="M12 1v2m0 18v2M1 12h2m18 0h2M4 4l2 2m12 12 2 2M4 20l2-2M18 6l2-2"/>',
  leaf: '<path d="M19 3C3 2 1 13 8 17s14-2 11-14ZM5 21 16 8"/>',
  snow: '<path d="M12 2v20M3 7l18 10M3 17 21 7M8 4l4 3 4-3M8 20l4-3 4 3"/>',
  heart:
    '<path d="M20 5c-3-3-6-1-8 1-2-2-5-4-8-1-5 5 4 12 8 15 4-3 13-10 8-15Z"/>',
  basket: '<path d="M3 10h18l-3 11H6ZM7 10 12 3l5 7M9 14v3m6-3v3"/>',
  book: '<path d="M3 4q5-2 9 1 5-3 9-1v16q-4-2-9 0-5-2-9 0ZM12 5v15M6 8h3m6 0h3M6 12h3m6 0h3"/>',
  arrow: '<path d="M4 12h16m-6-6 6 6-6 6"/>',
  check: '<path d="m5 12 4 4L19 6"/>',
  chevron: '<path d="m8 5 7 7-7 7"/>',
  close: '<path d="m6 6 12 12M6 18 18 6"/>',
  sound: '<path d="M3 9h4l5-5v16l-5-5H3ZM16 8q5 4 0 8m3-11q8 7 0 14"/>',
  mute: '<path d="M3 9h4l5-5v16l-5-5H3Zm13 0 6 6m-6 0 6-6"/>',
  motion: '<path d="M3 6h12M3 12h8M3 18h12m2-13 5 7-5 7"/>',
  people:
    '<circle cx="9" cy="7" r="3"/><path d="M3 21v-4a6 6 0 0 1 12 0v4M16 4a3 3 0 0 1 0 6m2 3a5 5 0 0 1 3 5v3"/>',
  lock: '<rect x="5" y="10" width="14" height="11" rx="2"/><path d="M8 10V6a4 4 0 0 1 8 0v4m-4 4v3"/>',
  flag: '<path d="M5 22V3q5-3 9 0t6 0v10q-3 3-7 0t-8 0"/>',
  warning: '<path d="m12 3 10 18H2ZM12 9v5m0 3v1"/>',
};
export function icon(name: string, cls = '') {
  return `<svg class="icon ${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths[name] ?? paths.leaf}</svg>`;
}
