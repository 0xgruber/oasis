import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

/**
 * O.A.S.I.S. Route-Based Access Control Middleware
 * 
 * Enforces credential-based exclusive access control for the three-portal architecture:
 * - /admin/* → platform_admin credentials ONLY
 * - /dashboard/* → soc_analyst credentials ONLY
 * - /login → Public (unauthenticated only)
 * 
 * Each credential grants access to ONE portal only (exclusive access model).
 */

const TOKEN_KEY = 'oasis_token';

interface JWTPayload {
  sub: string;  // user_id
  credential_id: string;
  credential_type: string;
  username: string;
  email: string;
  tenant_id: string;
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
    // If already authenticated and trying to access /login, redirect to appropriate portal
    const token = request.cookies.get(TOKEN_KEY)?.value;
    if (token && pathname === '/login') {
      const payload = decodeToken(token);
      if (payload && !isTokenExpired(payload)) {
        // Redirect based on credential type
        if (payload.credential_type === 'soc_analyst') {
          return NextResponse.redirect(new URL('/dashboard', request.url));
        } else if (payload.credential_type === 'platform_admin') {
          return NextResponse.redirect(new URL('/admin', request.url));
        }
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
  // CREDENTIAL-BASED EXCLUSIVE ACCESS CONTROL
  // ===================================================================
  
  const credentialType = payload.credential_type;
  
  // Admin Portal - platform_admin credentials ONLY
  if (pathname.startsWith('/admin')) {
    if (credentialType !== 'platform_admin') {
      // Wrong credentials → redirect to login with error
      const loginUrl = new URL('/login', request.url);
      loginUrl.searchParams.set('error', 'wrong_portal');
      loginUrl.searchParams.set('message', 'Please log in with admin credentials to access the admin portal');
      return NextResponse.redirect(loginUrl);
    }
  }
  
  // SOC Portal - soc_analyst credentials ONLY
  if (pathname.startsWith('/dashboard') || pathname.startsWith('/settings')) {
    if (credentialType !== 'soc_analyst') {
      // Wrong credentials → redirect to login with error
      const loginUrl = new URL('/login', request.url);
      loginUrl.searchParams.set('error', 'wrong_portal');
      loginUrl.searchParams.set('message', 'Please log in with SOC analyst credentials to access the SOC portal');
      return NextResponse.redirect(loginUrl);
    }
  }
  
  // Root redirect - send to appropriate portal based on credential type
  if (pathname === '/') {
    if (credentialType === 'soc_analyst') {
      return NextResponse.redirect(new URL('/dashboard', request.url));
    } else if (credentialType === 'platform_admin') {
      return NextResponse.redirect(new URL('/admin', request.url));
    } else if (credentialType === 'customer_user') {
      // For now, redirect to login (will be customer portal in Phase 2D)
      return NextResponse.redirect(new URL('/login', request.url));
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
