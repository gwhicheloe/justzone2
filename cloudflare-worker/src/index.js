const STRAVA_TOKEN_URL = 'https://www.strava.com/oauth/token';

export default {
  async fetch(request, env) {
    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: corsHeaders(),
      });
    }

    const url = new URL(request.url);

    try {
      if (request.method === 'POST' && url.pathname === '/token') {
        return await handleTokenExchange(request, env);
      }

      if (request.method === 'POST' && url.pathname === '/refresh') {
        return await handleTokenRefresh(request, env);
      }

      return jsonResponse({ error: 'Not found' }, 404);
    } catch (error) {
      return jsonResponse({ error: error.message }, 500);
    }
  },
};

async function handleTokenExchange(request, env) {
  const { code } = await request.json();

  if (!code) {
    return jsonResponse({ error: 'Missing authorization code' }, 400);
  }

  const response = await fetch(STRAVA_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: env.STRAVA_CLIENT_ID,
      client_secret: env.STRAVA_CLIENT_SECRET,
      code: code,
      grant_type: 'authorization_code',
    }),
  });

  const data = await response.json();

  if (!response.ok) {
    return jsonResponse({ error: data.message || 'Token exchange failed' }, response.status);
  }

  // Return only what the app needs (strip out athlete details if desired)
  return jsonResponse({
    access_token: data.access_token,
    refresh_token: data.refresh_token,
    expires_at: data.expires_at,
  });
}

async function handleTokenRefresh(request, env) {
  const { refresh_token } = await request.json();

  if (!refresh_token) {
    return jsonResponse({ error: 'Missing refresh token' }, 400);
  }

  const response = await fetch(STRAVA_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: env.STRAVA_CLIENT_ID,
      client_secret: env.STRAVA_CLIENT_SECRET,
      refresh_token: refresh_token,
      grant_type: 'refresh_token',
    }),
  });

  const data = await response.json();

  if (!response.ok) {
    return jsonResponse({ error: data.message || 'Token refresh failed' }, response.status);
  }

  return jsonResponse({
    access_token: data.access_token,
    refresh_token: data.refresh_token,
    expires_at: data.expires_at,
  });
}

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
}

function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...corsHeaders(),
    },
  });
}
