import Cookies from 'js-cookie';
import { User } from './api';

const TOKEN_KEY = 'oasis_token';

export const tokenUtils = {
  setToken: (token: string) => {
    // Set cookie with secure flags for production
    Cookies.set(TOKEN_KEY, token, {
      expires: 1, // 1 day
      sameSite: 'strict',
      secure: process.env.NODE_ENV === 'production',
    });
  },

  getToken: (): string | undefined => {
    return Cookies.get(TOKEN_KEY);
  },

  removeToken: () => {
    Cookies.remove(TOKEN_KEY);
  },

  decodeToken: (token: string): User | null => {
    try {
      const base64Url = token.split('.')[1];
      const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
      const jsonPayload = decodeURIComponent(
        atob(base64)
          .split('')
          .map((c) => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
          .join('')
      );
      const payload = JSON.parse(jsonPayload);
      
      // Map JWT payload fields to User interface
      return {
        user_id: payload.sub,
        credential_id: payload.credential_id,
        credential_type: payload.credential_type,
        username: payload.username,
        email: payload.email,
        tenant_id: payload.tenant_id,
        exp: payload.exp,
        iat: payload.iat,
      };
    } catch (error) {
      console.error('Failed to decode token:', error);
      return null;
    }
  },

  isTokenExpired: (token: string): boolean => {
    const decoded = tokenUtils.decodeToken(token);
    if (!decoded || !decoded.exp) return true;
    
    const expirationTime = decoded.exp * 1000; // Convert to milliseconds
    return Date.now() >= expirationTime;
  },
};

declare module './api' {
  interface User {
    exp?: number;
    iat?: number;
  }
}
