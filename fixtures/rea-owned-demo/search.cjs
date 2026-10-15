'use strict';
function normalize(text) {
  return String(text ?? '').normalize('NFKC').trim().toLowerCase();
}
function rankMatches(notes, query) {
  const term = normalize(query);
  if (!term) return [];
  return notes
    .filter((note) => normalize(note.title).includes(term))
    .sort((left, right) => normalize(left.title).localeCompare(normalize(right.title)));
}
module.exports = { normalize, rankMatches };
