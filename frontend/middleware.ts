import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

/**
 * O.A.S.I.S. Route-Based Access Control Middleware
 * 
 * Enforces role-based access control for the three-portal architecture:
 * - /admin/* → platform_admin ONLY
 * - /dashboard/* → soc_analyst + platform_admin (S.O.C.A.P.)
 * - /login → Public (unauthenticated only)
 */

const TOKEN_KEY = 'oasis_token';

interface JWTPayload {
  user_id: string;
  tenant_id: string;
  username: string;
  role: string;
  exp?: number;
  iat?: number;
}

/**
 * Decode JWT token (client-side decoding, not verification)
 * Note: This is safe for routing decisions since the API verifies tokens server-side
 */
function decodeToken(token: string): JWTPayload | null {
  try {
    const base64Url = token.split('.')[1];
    const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
    const jsonPayload = decodeURIComponent(
      atob(base64)
        .split('')
        .map((c) => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
        .join('')
    );
    return JSON.parse(jsonPayload);
  } catch (error) {
    console.error('[Middleware] Failed to decode token:', error);
    return null;
  }
}

/**
 * Check if token is expired
 */
function isTokenExpired(payload: JWTPayload): boolean {
  if (!payload.exp) return true;
  const expirationTime = payload.exp * 1000; // Convert to milliseconds
  return Date.now() >= expirationTime;
}

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  
  // ===================================================================
  // PUBLIC ROUTES - No authentication required
  // ===================================================================
  
  const publicPaths = ['/login', '/api/auth'];
  const isPublicPath = publicPaths.some(path => pathname.startsWith(path));
  
  if (isPublicPath) {
    // If already authenticated and trying to access /login, redirect to dashboard
    const token = request.cookies.get(TOKEN_KEY)?.value;
    if (token && pathname === '/login') {
      const payload = decodeToken(token);
      if (payload && !isTokenExpired(payload)) {
        return NextResponse.redirect(new URL('/dashboard', request.url));
      }
    }
    return NextResponse.next();
  }
  
  // ===================================================================
  // PROTECTED ROUTES - Authentication required
  // ===================================================================
  
  const token = request.cookies.get(TOKEN_KEY)?.value;
  
  // No token → redirect to login
  if (!token) {
    const loginUrl = new URL('/login', request.url);
    loginUrl.searchParams.set('redirect', pathname);
    return NextResponse.redirect(loginUrl);
  }
  
  // Decode token
  const payload = decodeToken(token);
  if (!payload) {
    // Invalid token → redirect to login
    const loginUrl = new URL('/login', request.url);
    return NextResponse.redirect(loginUrl);
  }
  
  // Expired token → redirect to login
  if (isTokenExpired(payload)) {
    const loginUrl = new URL('/login', request.url);
    loginUrl.searchParams.set('expired', 'true');
    return NextResponse.redirect(loginUrl);
  }
  
  // ===================================================================
  // ROLE-BASED ACCESS CONTROL
  // ===================================================================
  
  const userRole = payload.role;
  
  // Admin Portal - platform_admin ONLY
  if (pathname.startsWith('/admin')) {
    if (userRole !== 'platform_admin') {
      // Unauthorized → redirect to dashboard with error message
      const dashboardUrl = new URL('/dashboard', request.url);
      dashboardUrl.searchParams.set('error', 'access_denied');
      return NextResponse.redirect(dashboardUrl);
    }
  }
  
  // S.O.C.A.P. (SOC Analyst Portal) - soc_analyst + platform_admin
  // Currently: /dashboard, /users, /system-settings
  // After refactor: /(socap)/*
  if (pathname.startsWith('/dashboard') || 
      pathname.startsWith('/users') || 
      pathname.startsWith('/system-settings')) {
    // SOC analysts and platform admins can access
    if (userRole !== 'soc_analyst' && userRole !== 'platform_admin') {
      // Customer users should not access SOC portal
      // For now, redirect to dashboard (will be customer portal in Phase 2D)
      const loginUrl = new URL('/login', request.url);
      loginUrl.searchParams.set('error', 'wrong_portal');
      return NextResponse.redirect(loginUrl);
    }
  }
  
  // Root redirect - send to appropriate portal based on role
  if (pathname === '/') {
    if (userRole === 'platform_admin' || userRole === 'soc_analyst') {
      return NextResponse.redirect(new URL('/dashboard', request.url));
    } else if (userRole === 'customer_user') {
      // For now, redirect to dashboard (will be customer portal in Phase 2D)
      return NextResponse.redirect(new URL('/dashboard', request.url));
    }
  }
  
  // Allow request to proceed
  return NextResponse.next();
}

/**
 * Middleware matcher configuration
 * Runs on all routes except static files and API routes
 */
export const config = {
  matcher: [
    /*
     * Match all request paths except:
     * - _next/static (static files)
     * - _next/image (image optimization files)
     * - favicon.ico (favicon file)
     * - public files (images, fonts, etc.)
     */
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)',
  ],
};
