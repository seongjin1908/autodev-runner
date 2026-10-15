'use strict';
const { rankMatches } = require('./search.cjs');
function getMatchingNotes(notes, query) {
  return rankMatches(notes, query).slice(0, 5);
}
module.exports = { getMatchingNotes };
