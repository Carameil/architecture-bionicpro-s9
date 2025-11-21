/**
 * PKCE (Proof Key for Code Exchange) utilities
 */

// Generate a cryptographically random string
export function generateRandomString(length: number): string {
  const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
  const array = new Uint8Array(length);
  crypto.getRandomValues(array);
  return Array.from(array)
    .map(byte => charset[byte % charset.length])
    .join('');
}

// Generate code verifier (43-128 characters)
export function generateCodeVerifier(): string {
  return generateRandomString(128);
}

// Generate code challenge from verifier using SHA-256
export async function generateCodeChallenge(verifier: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(verifier);
  const digest = await crypto.subtle.digest('SHA-256', data);
  
  // Convert ArrayBuffer to base64url encoding
  const uint8Array = new Uint8Array(digest);
  const numberArray = Array.from(uint8Array);
  const base64 = btoa(String.fromCharCode(...numberArray));
  
  return base64
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
}

// Store PKCE values in session storage
export function storePKCEValues(state: string, codeVerifier: string): void {
  sessionStorage.setItem('pkce_state', state);
  sessionStorage.setItem('pkce_code_verifier', codeVerifier);
}

// Retrieve PKCE values from session storage
export function getPKCEValues(): { state: string | null; codeVerifier: string | null } {
  return {
    state: sessionStorage.getItem('pkce_state'),
    codeVerifier: sessionStorage.getItem('pkce_code_verifier')
  };
}

// Clear PKCE values from session storage
export function clearPKCEValues(): void {
  sessionStorage.removeItem('pkce_state');
  sessionStorage.removeItem('pkce_code_verifier');
}
