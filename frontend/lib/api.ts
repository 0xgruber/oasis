import axios, { AxiosInstance, AxiosError } from 'axios';
import Cookies from 'js-cookie';

// For browser clients, never default to `localhost` (that points to *their* machine).
// Default to same-origin proxy at `/api` (see `frontend/next.config.mjs` rewrites).
const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || '/api';

// Create axios instance with base configuration
const apiClient: AxiosInstance = axios.create({
  baseURL: API_BASE_URL,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor to add JWT token
apiClient.interceptors.request.use(
  (config) => {
    const token = Cookies.get('oasis_token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response interceptor for error handling
apiClient.interceptors.response.use(
  (response) => response,
  (error: AxiosError) => {
    if (error.response?.status === 401) {
      // Unauthorized - clear token and redirect to login
      // BUT: Don't redirect if we're already on the login page or if this is a login request
      const isLoginRequest = error.config?.url?.includes('/auth/login');
      const isLoginPage = typeof window !== 'undefined' && window.location.pathname === '/login';
      
      if (!isLoginRequest && !isLoginPage) {
        Cookies.remove('oasis_token');
        if (typeof window !== 'undefined') {
          window.location.href = '/login';
        }
      }
    }
    return Promise.reject(error);
  }
);

// Types
export interface LoginRequest {
  username: string;
  password: string;
}

export interface LoginResponse {
  access_token: string;
  token_type: string;
}

export interface User {
  user_id: string;
  tenant_id: string;
  username: string;
  role: string;
}

export interface LogEntry {
  uuid: string;
  tenant_id: string;
  timestamp: number;
  severity_id: number;
  category_uid: number;
  class_uid: number;
  message?: string;
  raw_log: string;
  ocsf: Record<string, unknown>;
  ingested_at: number;
}

export interface LogsResponse {
  logs: LogEntry[];
  total: number;
  offset: number;
  limit: number;
}

// API Functions
export const authApi = {
  login: async (credentials: LoginRequest): Promise<LoginResponse> => {
    const response = await apiClient.post<LoginResponse>('/auth/login', credentials);
    return response.data;
  },

  logout: () => {
    Cookies.remove('oasis_token');
    if (typeof window !== 'undefined') {
      window.location.href = '/login';
    }
  },
};

export const logsApi = {
  getLogs: async (params?: {
    limit?: number;
    offset?: number;
    start_time?: number;
    end_time?: number;
  }): Promise<LogsResponse> => {
    const response = await apiClient.get<LogsResponse>('/logs', { params });
    return response.data;
  },
};

export const healthApi = {
  check: async (): Promise<{ status: string }> => {
    const response = await apiClient.get('/health');
    return response.data;
  },
};

export default apiClient;
