/**
 * Authentication service for BionicPRO
 */

const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000';

export interface User {
  sub: string;
  name: string;
  username: string;
  email?: string;
  roles: string[];
}

export interface LoginResponse {
  auth_url: string;
  state: string;
}

export interface CallbackResponse {
  success: boolean;
  user: User;
}

class AuthService {
  private baseUrl: string;

  constructor() {
    this.baseUrl = API_BASE_URL;
  }

  /**
   * Initiate login flow with PKCE
   */
  async initiateLogin(codeChallenge: string): Promise<LoginResponse> {
    const response = await fetch(`${this.baseUrl}/api/auth/login`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      credentials: 'include',
      body: JSON.stringify({
        redirect_uri: `${window.location.origin}/callback`,
        code_challenge: codeChallenge,
      }),
    });

    if (!response.ok) {
      throw new Error('Failed to initiate login');
    }

    return response.json();
  }

  /**
   * Handle OAuth callback
   */
  async handleCallback(code: string, state: string, codeVerifier: string): Promise<CallbackResponse> {
    const response = await fetch(`${this.baseUrl}/api/auth/callback`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      credentials: 'include',
      body: JSON.stringify({
        code,
        state,
        redirect_uri: `${window.location.origin}/callback`,
        code_verifier: codeVerifier,
      }),
    });

    if (!response.ok) {
      throw new Error('Failed to handle callback');
    }

    return response.json();
  }

  /**
   * Get current user info
   */
  async getUserInfo(): Promise<User> {
    const response = await fetch(`${this.baseUrl}/api/auth/userinfo`, {
      method: 'GET',
      credentials: 'include',
    });

    if (!response.ok) {
      throw new Error('Not authenticated');
    }

    return response.json();
  }

  /**
   * Check if user is authenticated
   */
  async checkAuth(): Promise<{ authenticated: boolean; user: string | null }> {
    const response = await fetch(`${this.baseUrl}/api/auth/check`, {
      method: 'GET',
      credentials: 'include',
    });

    if (!response.ok) {
      return { authenticated: false, user: null };
    }

    return response.json();
  }

  /**
   * Logout user
   */
  async logout(): Promise<void> {
    await fetch(`${this.baseUrl}/api/auth/logout`, {
      method: 'POST',
      credentials: 'include',
    });
  }

  /**
   * Make authenticated request
   */
  async authenticatedRequest(url: string, options: RequestInit = {}): Promise<Response> {
    return fetch(`${this.baseUrl}${url}`, {
      ...options,
      credentials: 'include',
      headers: {
        'Content-Type': 'application/json',
        ...options.headers,
      },
    });
  }
}

const authService = new AuthService();
export default authService;
