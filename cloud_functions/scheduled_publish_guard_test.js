'use strict';

const assert = require('assert');
const {evaluateScheduledPublish} = require('./src/videos/scheduled_publish_guard');

function test(name, fn) {
  try {
    fn();
    console.log(`ok ${name}`);
  } catch (err) {
    console.error(`FAIL ${name}`);
    throw err;
  }
}

const readyVideo = {
  ownerId: 'alice',
  status: 'ready',
  muxPlaybackId: 'pb123',
};
const post = {videoId: 'v1', authorId: 'alice'};
const activeOwner = {accountStatus: 'active'};

test('owner publishes own ready video', () => {
  const actual = evaluateScheduledPublish({postData: post, videoData: readyVideo, ownerData: activeOwner});
  assert.deepStrictEqual(actual, {ok: true, ownerId: 'alice'});
});

test('legacy owner without accountStatus is renderable', () => {
  const actual = evaluateScheduledPublish({postData: post, videoData: readyVideo, ownerData: {}});
  assert.strictEqual(actual.ok, true);
});

test('rejects another user\'s video', () => {
  const actual = evaluateScheduledPublish({
    postData: {videoId: 'v1', authorId: 'mallory'},
    videoData: readyVideo,
    ownerData: activeOwner,
  });
  assert.deepStrictEqual(actual, {ok: false, reason: 'author_not_owner'});
});

test('rejects missing video', () => {
  const actual = evaluateScheduledPublish({postData: post, videoData: null, ownerData: activeOwner});
  assert.strictEqual(actual.reason, 'video_not_found');
});

test('rejects deleted and moderated videos', () => {
  for (const patch of [{isDeleted: true}, {status: 'deleted'}, {moderationStatus: 'removed'}, {ownerActive: false}]) {
    const actual = evaluateScheduledPublish({
      postData: post,
      videoData: {...readyVideo, ...patch},
      ownerData: activeOwner,
    });
    assert.strictEqual(actual.reason, 'video_tombstoned', JSON.stringify(patch));
  }
});

test('rejects unprocessed video', () => {
  const actual = evaluateScheduledPublish({
    postData: post,
    videoData: {...readyVideo, status: 'processing'},
    ownerData: activeOwner,
  });
  assert.strictEqual(actual.reason, 'video_not_processed');
});

test('rejects video without playback', () => {
  const actual = evaluateScheduledPublish({
    postData: post,
    videoData: {ownerId: 'alice', status: 'ready'},
    ownerData: activeOwner,
  });
  assert.strictEqual(actual.reason, 'playback_missing');
});

test('rejects banned, deactivated, or missing owner', () => {
  for (const ownerData of [{accountStatus: 'banned'}, {accountStatus: 'deactivated'}, null]) {
    const actual = evaluateScheduledPublish({postData: post, videoData: readyVideo, ownerData});
    assert.strictEqual(actual.reason, 'owner_not_renderable');
  }
});

console.log('scheduled_publish_guard_test: all passed');
