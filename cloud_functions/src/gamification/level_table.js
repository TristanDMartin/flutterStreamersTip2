/**
 * Canonical level / rank table for all gamification backends.
 * Mobile, website, desktop, admin, and Tippy must not define their own curves.
 */

const LEVELS = [
  {level: 1, title: 'New Creator', xpRequired: 0},
  {level: 2, title: 'Getting Started', xpRequired: 100},
  {level: 3, title: 'Clip Builder', xpRequired: 250},
  {level: 4, title: 'Consistent Creator', xpRequired: 500},
  {level: 5, title: 'Rising Creator', xpRequired: 900},
  {level: 10, title: 'Growth Creator', xpRequired: 2500},
  {level: 20, title: 'Partner-Level Creator', xpRequired: 8000},
  {level: 30, title: 'Elite Creator', xpRequired: 18000},
  {level: 40, title: 'Platform Leader', xpRequired: 35000},
  {level: 50, title: 'StreamersTip Legend', xpRequired: 60000},
];

const LEVELS_BY_XP = [...LEVELS].sort((a, b) => a.xpRequired - b.xpRequired);

function levelFromTotalXp(totalXp) {
  const xp = Math.max(0, Math.trunc(totalXp));
  let row = LEVELS_BY_XP[0];
  for (const candidate of LEVELS_BY_XP) {
    if (xp >= candidate.xpRequired) {
      row = candidate;
    }
  }
  return row.level;
}

function rankTitleForLevel(level) {
  const lv = Math.max(1, Math.trunc(level));
  let row = LEVELS_BY_XP[0];
  for (const candidate of LEVELS_BY_XP) {
    if (candidate.level <= lv) {
      row = candidate;
    }
  }
  return row.title;
}

/** Row shape for progression_callable compatibility. */
function levelRowForTotalXp(totalXp) {
  const level = levelFromTotalXp(totalXp);
  return {
    level,
    rankName: rankTitleForLevel(level),
    title: rankTitleForLevel(level),
    xp: xpFloorForLevel(level),
  };
}

function xpFloorForLevel(level) {
  const lv = Math.max(1, Math.trunc(level));
  let floor = 0;
  for (const row of LEVELS_BY_XP) {
    if (row.level <= lv) {
      floor = row.xpRequired;
    }
  }
  return floor;
}

function xpCeilingForLevel(level) {
  const lv = Math.max(1, Math.trunc(level));
  for (const row of LEVELS_BY_XP) {
    if (row.level > lv) {
      return row.xpRequired;
    }
  }
  const max = LEVELS_BY_XP[LEVELS_BY_XP.length - 1];
  return max.xpRequired + 1000;
}

function xpProgressForLevel(level, totalXp) {
  const floor = xpFloorForLevel(level);
  const ceiling = xpCeilingForLevel(level);
  const span = Math.max(1, ceiling - floor);
  const into = Math.max(0, Math.trunc(totalXp) - floor);
  const percent = Math.min(100, Math.round((into / span) * 100));
  return {
    currentLevelXp: floor,
    nextLevelXp: ceiling,
    progressPercent: percent,
  };
}

module.exports = {
  LEVELS,
  levelFromTotalXp,
  rankTitleForLevel,
  levelRowForTotalXp,
  xpFloorForLevel,
  xpCeilingForLevel,
  xpProgressForLevel,
};
