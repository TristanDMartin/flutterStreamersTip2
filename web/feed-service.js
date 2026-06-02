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
