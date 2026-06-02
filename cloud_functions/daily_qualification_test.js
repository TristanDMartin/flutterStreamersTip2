const assert = require('assert');

const {
  buildDailyQualificationUpdates,
  streakFromStoredFields,
  todayKey,
  yesterdayKey,
} = require('./src/gamification/daily_qualification');

function testStreakIncrement() {
  const yesterday = yesterdayKey();
  const first = buildDailyQualificationUpdates({
    gamification: {lastActiveDate: yesterday, streakCount: 2},
  });
  assert.strictEqual(first.skipped, false);
  assert.strictEqual(first.updates.streakCount, 3);
  assert.strictEqual(first.streakExtended, true);
}

function testStreakResetAfterGap() {
  const result = buildDailyQualificationUpdates({
    gamification: {lastActiveDate: '2020-01-01', streakCount: 9},
  });
  assert.strictEqual(result.skipped, false);
  assert.strictEqual(result.updates.streakCount, 1);
}

function testStreakSkipSameDay() {
  const today = todayKey();
  const result = buildDailyQualificationUpdates({
    gamification: {lastActiveDate: today, streakCount: 4},
  });
  assert.strictEqual(result.skipped, true);
}

function testStreakFromStoredFields() {
  const today = todayKey();
  const streak = streakFromStoredFields({
    gamification: {lastActiveDate: today, streakCount: 5},
  });
  assert.strictEqual(streak.streakCount, 5);
  assert.strictEqual(streak.streakStatus, 'Active today');
}

function main() {
  testStreakIncrement();
  testStreakResetAfterGap();
  testStreakSkipSameDay();
  testStreakFromStoredFields();
  console.log('daily_qualification_test: ok');
}

main();
