/**
 * Website feed client.
 *
 * Keep website feed ranking server-owned: the website consumes the same
 * backend-ranked For You payload as mobile instead of duplicating Firestore
 * ranking logic in React.
 */
export async function fetchForYouFeed({baseUrl = '', limit = 30, token} = {}) {
  const url = new URL('/apiFeedForYou', baseUrl || window.location.origin);
  url.searchParams.set('limit', String(limit));

  const response = await fetch(url.toString(), {
    method: 'GET',
    headers: {
      Accept: 'application/json',
      ...(token ? {Authorization: `Bearer ${token}`} : {}),
    },
  });
  if (!response.ok) {
    throw new Error(`For You feed failed: ${response.status}`);
  }
  const data = await response.json();
  return Array.isArray(data.items) ? data.items : [];
}

export async function fetchProfileVideos({
  baseUrl = '',
  profileUserId,
  token,
} = {}) {
  if (!profileUserId) {
    throw new Error('profileUserId is required');
  }
  const url = new URL('/api/profile-videos', baseUrl || window.location.origin);
  url.searchParams.set('userId', profileUserId);

  const response = await fetch(url.toString(), {
    method: 'GET',
    headers: {
      Accept: 'application/json',
      ...(token ? {Authorization: `Bearer ${token}`} : {}),
    },
  });
  if (!response.ok) {
    throw new Error(`Profile videos failed: ${response.status}`);
  }
  const data = await response.json();
  const videos = Array.isArray(data.items) ? data.items : [];
  console.log('WEB_PROFILE_VIDEO_IDS', videos.map((video) => video.id));
  return videos;
}

export async function createMuxDirectUpload({
  baseUrl = '',
  token,
  videoId,
  userId,
  isDraft = false,
  metadata = {},
} = {}) {
  if (!token) {
    throw new Error('token is required');
  }
  const url = new URL('/mux/direct-upload', baseUrl || window.location.origin);
  const response = await fetch(url.toString(), {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      ...metadata,
      ...(videoId ? {videoId} : {}),
      ...(userId ? {userId} : {}),
      isDraft,
    }),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(data.error || `Mux direct upload failed: ${response.status}`);
  }
  const canonicalVideoId = data.canonicalVideoId || data.videoId;
  if (!canonicalVideoId) {
    throw new Error('Mux direct upload did not return a canonical videoId');
  }
  return {
    ...data,
    videoId: canonicalVideoId,
    canonicalVideoId,
  };
}
