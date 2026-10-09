// apps/admin/src/apiConfig.js
// Centralized configuration for Jugaad Admin Dashboard API connectivity

export const BACKEND_API_URL = 
  import.meta.env.VITE_BACKEND_API_URL || 
  import.meta.env.VITE_API_URL || 
  'http://localhost:8000';

export const API_ENDPOINTS = {
  HEALTH: `${BACKEND_API_URL}/health`,
  PLATFORM_CONFIG: `${BACKEND_API_URL}/v1/platform/config`,
  DASHBOARD_STATS: `${BACKEND_API_URL}/v1/admin/dashboard/stats`,
  APPROVE_WORKER: (id) => `${BACKEND_API_URL}/v1/admin/workers/${id}/approve`,
  REJECT_WORKER: (id) => `${BACKEND_API_URL}/v1/admin/workers/${id}/reject`,
  CANCEL_JOB: (id) => `${BACKEND_API_URL}/v1/admin/jobs/${id}/cancel`,
  BROADCAST: `${BACKEND_API_URL}/v1/admin/broadcast`,
  SERVICES: `${BACKEND_API_URL}/v1/services`,
  USERS: (role = 'all', search = '') => `${BACKEND_API_URL}/v1/admin/users?role=${role}&search=${encodeURIComponent(search)}`,
  USER_STATUS: (id) => `${BACKEND_API_URL}/v1/admin/users/${id}/status`,
  ANALYTICS_SUMMARY: (days = 7) => `${BACKEND_API_URL}/v1/admin/analytics/summary?days=${days}`,
};

