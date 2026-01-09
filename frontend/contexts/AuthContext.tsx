'use client';

import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { useRouter } from 'next/navigation';
import { authApi, LoginRequest, User } from '@/lib/api';
import { tokenUtils } from '@/lib/auth';

interface AuthContextType {
  user: User | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  login: (credentials: LoginRequest) => Promise<void>;
  logout: () => void;
  error: string | null;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();

  useEffect(() => {
    // Check for existing token on mount
    const token = tokenUtils.getToken();
    if (token && !tokenUtils.isTokenExpired(token)) {
      const decoded = tokenUtils.decodeToken(token);
      setUser(decoded);
    }
    setIsLoading(false);
  }, []);

  const login = async (credentials: LoginRequest) => {
    setError(null);
    setIsLoading(true);

    try {
      const response = await authApi.login(credentials);
      const { access_token } = response;

      // Store token
      tokenUtils.setToken(access_token);

      // Decode and set user
      const decoded = tokenUtils.decodeToken(access_token);
      setUser(decoded);

      // Redirect to dashboard
      router.push('/dashboard');
    } catch (err: any) {
      const errorMessage = err.response?.data?.detail || 'Login failed. Please check your credentials.';
      setError(errorMessage);
      throw err;
    } finally {
      setIsLoading(false);
    }
  };

  const logout = () => {
    tokenUtils.removeToken();
    setUser(null);
    router.push('/login');
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        isLoading,
        isAuthenticated: !!user,
        login,
        logout,
        error,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
