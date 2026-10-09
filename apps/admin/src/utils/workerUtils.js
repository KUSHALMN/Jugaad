// apps/admin/src/utils/workerUtils.js
// Robust normalizer and parser for Jugaad Worker records across Supabase, Backend API, and local state

/**
 * Parses skills or specialities into a clean string array.
 * Handles:
 * - Real JS Arrays: ['electrician', 'plumber']
 * - Python-stringified lists: "['Electrician', 'Electrician']"
 * - JSON stringified arrays: "[\"plumber\"]"
 * - Comma-delimited strings: "electrician, plumber"
 * - Single strings: "electrician"
 */
export function parseWorkerSkills(workerOrSkills) {
  let raw = workerOrSkills;
  if (workerOrSkills && typeof workerOrSkills === 'object' && !Array.isArray(workerOrSkills)) {
    raw = workerOrSkills.skills || workerOrSkills.specialities || workerOrSkills.category || workerOrSkills.work_category;
  }

  if (!raw) return [];

  if (Array.isArray(raw)) {
    return raw.map(s => String(s).trim()).filter(Boolean);
  }

  if (typeof raw === 'string') {
    const trimmed = raw.trim();
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      try {
        // Try standard JSON parse first
        const parsed = JSON.parse(trimmed);
        if (Array.isArray(parsed)) return parsed.map(s => String(s).trim()).filter(Boolean);
      } catch (_) {
        // Handle Python string representation e.g. "['Electrician', 'Electrician']"
        try {
          const jsonified = trimmed.replace(/'/g, '"');
          const parsed = JSON.parse(jsonified);
          if (Array.isArray(parsed)) return parsed.map(s => String(s).trim()).filter(Boolean);
        } catch (_) {
          // Fallback: strip brackets and quotes
          return trimmed
            .replace(/[\[\]'"]/g, '')
            .split(',')
            .map(s => s.trim())
            .filter(Boolean);
        }
      }
    }

    if (trimmed.includes(',')) {
      return trimmed.split(',').map(s => s.trim()).filter(Boolean);
    }

    if (trimmed !== 'None' && trimmed.length > 0) {
      return [trimmed];
    }
  }

  return [];
}

/**
 * Returns a clean, human-readable primary trade category for a worker.
 */
export function parseWorkerCategory(worker) {
  if (!worker) return 'General';

  // Direct category string
  if (worker.work_category && typeof worker.work_category === 'string' && worker.work_category !== 'None') {
    return formatCategoryTitle(worker.work_category);
  }
  if (worker.category && typeof worker.category === 'string' && worker.category !== 'None') {
    return formatCategoryTitle(worker.category);
  }

  // Check skills array
  const skills = parseWorkerSkills(worker);
  if (skills.length > 0 && skills[0]) {
    return formatCategoryTitle(skills[0]);
  }

  // Check trade property
  if (worker.trade && typeof worker.trade === 'string' && worker.trade !== 'None') {
    return formatCategoryTitle(worker.trade);
  }

  return 'General';
}

/**
 * Clean and format trade category string (e.g. "ac_service" -> "AC Service")
 */
export function formatCategoryTitle(str) {
  if (!str) return 'General';
  const clean = String(str).replace(/[\[\]'"]/g, '').trim();
  const lower = clean.toLowerCase();

  if (lower.includes('electrician')) return 'Electrician';
  if (lower.includes('plumber')) return 'Plumber';
  if (lower.includes('carpenter')) return 'Carpenter';
  if (lower.includes('ac')) return 'AC Service';
  if (lower.includes('phone')) return 'Phone Repair';
  if (lower.includes('laptop')) return 'Laptop Repair';
  if (lower.includes('stove') || lower.includes('gas')) return 'Stove Repair';
  if (lower.includes('clean')) return 'Home Cleaning';
  if (lower.includes('purifier') || lower.includes('water')) return 'Water Purifier';

  return clean.charAt(0).toUpperCase() + clean.slice(1).replace('_', ' ');
}

/**
 * Safely extracts Aadhaar document image/PDF URL.
 */
export function getAadhaarUrl(worker) {
  if (!worker) return null;
  if (worker.aadhaar_card_url) return worker.aadhaar_card_url;
  if (worker.aadhaar_url) return worker.aadhaar_url;

  let docs = worker.documents;
  if (typeof docs === 'string') {
    try {
      docs = JSON.parse(docs);
    } catch (_) {
      docs = [];
    }
  }

  if (Array.isArray(docs)) {
    const doc = docs.find(d => d && (
      d.name === 'aadhaar_card' || 
      d.name === 'aadhaar' || 
      d.name === 'id_card' ||
      d.type === 'aadhaar'
    ));
    if (doc?.url) return doc.url;
  }

  // If id_document_url is present and isn't specifically named profile
  if (worker.id_document_url && !worker.id_document_url.includes('profile_photo')) {
    return worker.id_document_url;
  }

  return null;
}

/**
 * Safely extracts worker portrait profile photo URL.
 */
export function getProfilePhoto(worker) {
  if (!worker) return null;
  if (worker.avatar_url) return worker.avatar_url;
  if (worker.profile_photo) return worker.profile_photo;
  if (worker.photo_url) return worker.photo_url;

  let docs = worker.documents;
  if (typeof docs === 'string') {
    try {
      docs = JSON.parse(docs);
    } catch (_) {
      docs = [];
    }
  }

  if (Array.isArray(docs)) {
    const doc = docs.find(d => d && (
      d.name === 'profile_photo' || 
      d.name === 'photo' || 
      d.type === 'profile'
    ));
    if (doc?.url) return doc.url;
  }

  if (worker.id_document_url && worker.id_document_url.includes('profile')) {
    return worker.id_document_url;
  }

  return null;
}

/**
 * Determines comprehensive verification and operational status for a worker.
 */
export function getWorkerVerificationStatus(worker) {
  if (!worker) {
    return {
      isApproved: false,
      isSuspended: false,
      isPending: true,
      isRejected: false,
      label: 'Unverified',
      badgeClass: 'bg-amber-50 text-amber-700 border-amber-200/80',
    };
  }

  const isSuspended = 
    worker.is_banned === true || 
    worker.suspended === true || 
    worker.suspended === 'True' || 
    worker.status === 'suspended';

  if (isSuspended) {
    return {
      isApproved: false,
      isSuspended: true,
      isPending: false,
      isRejected: false,
      label: 'Suspended',
      badgeClass: 'bg-rose-50 text-rose-700 border-rose-200/80',
    };
  }

  const isApproved = 
    worker.status === 'approved' || 
    worker.approval_status === 'approved' || 
    worker.id_verified === true || 
    worker.id_verified === 'True' || 
    worker.isVerified === true || 
    worker.isVerified === 'True' ||
    worker.is_seed_verified === true ||
    worker.is_seed_verified === 'True';

  const isRejected = 
    worker.status === 'rejected' || 
    worker.approval_status === 'rejected';

  if (isApproved) {
    return {
      isApproved: true,
      isSuspended: false,
      isPending: false,
      isRejected: false,
      label: 'Verified',
      badgeClass: 'bg-emerald-50 text-emerald-700 border-emerald-200/80',
    };
  }

  if (isRejected) {
    return {
      isApproved: false,
      isSuspended: false,
      isPending: false,
      isRejected: true,
      label: 'Rejected',
      badgeClass: 'bg-rose-50 text-rose-700 border-rose-200/80',
    };
  }

  return {
    isApproved: false,
    isSuspended: false,
    isPending: true,
    isRejected: false,
    label: 'Pending Review',
    badgeClass: 'bg-amber-50 text-amber-700 border-amber-200/80',
  };
}

/**
 * Normalizes a raw worker row into a predictable, clean data structure.
 */
export function normalizeWorker(rawWorker, userMap = {}) {
  if (!rawWorker) return null;

  const user = userMap[rawWorker.id] || userMap[rawWorker.worker_id] || {};
  const rawName = rawWorker.name && rawWorker.name !== 'None' ? rawWorker.name : user.name;
  const name = rawName || 'Service Partner';

  const rawPhone = rawWorker.phone && rawWorker.phone !== 'None' ? rawWorker.phone : user.phone;
  const phone = rawPhone || 'N/A';

  const email = rawWorker.email || user.email || '';
  const category = parseWorkerCategory(rawWorker);
  const allSkills = parseWorkerSkills(rawWorker);
  const statusInfo = getWorkerVerificationStatus(rawWorker);

  const rawRating = parseFloat(rawWorker.rating || 0.0);
  const rating = isNaN(rawRating) ? 4.8 : rawRating;

  const rawTotal = parseInt(rawWorker.total_jobs || rawWorker.totalJobsCompleted || rawWorker.review_count || 0, 10);
  const totalJobs = isNaN(rawTotal) ? 0 : rawTotal;

  const profilePhoto = getProfilePhoto(rawWorker) || user.avatar_url || null;
  const aadhaarUrl = getAadhaarUrl(rawWorker);

  const isOnline = 
    rawWorker.is_online === true || 
    rawWorker.is_online === 'True' || 
    rawWorker.isOnline === true || 
    rawWorker.isOnline === 'True' || 
    rawWorker.is_available === true;

  const hourlyRate = parseFloat(rawWorker.hourly_rate || rawWorker.rate_per_hour || 200.0);

  return {
    ...rawWorker,
    id: rawWorker.id || rawWorker.worker_id,
    name,
    displayName: name,
    phone,
    displayPhone: phone,
    email,
    category,
    displayCategory: category,
    skills: allSkills.length > 0 ? allSkills : [category],
    statusInfo,
    status: statusInfo.isApproved ? 'approved' : statusInfo.isSuspended ? 'suspended' : statusInfo.isRejected ? 'rejected' : 'pending',
    approval_status: statusInfo.isApproved ? 'approved' : statusInfo.isSuspended ? 'suspended' : statusInfo.isRejected ? 'rejected' : 'pending',
    id_verified: statusInfo.isApproved,
    isVerified: statusInfo.isApproved,
    rating: Number(rating.toFixed(1)),
    total_jobs: totalJobs,
    totalJobsCompleted: totalJobs,
    profilePhoto,
    avatarUrl: profilePhoto,
    id_document_url: aadhaarUrl || rawWorker.id_document_url,
    aadhaarUrl,
    is_online: isOnline,
    isOnline,
    hourlyRate: isNaN(hourlyRate) ? 200.0 : hourlyRate,
    area: rawWorker.area || rawWorker.address || 'Mysuru, Karnataka',
  };
}

/**
 * High-fidelity fallback pending worker applicants for when DB pending queue is empty.
 * Allows the admin to preview, audit, and test approvals anytime.
 */
export const FALLBACK_PENDING_WORKERS = [
  {
    id: 'pw-seed-101',
    name: 'Basavaraj S. Patil',
    phone: '+91 98450 77889',
    category: 'Electrician',
    work_category: 'Electrician',
    skills: ['Electrician', 'Inverter Repair', 'Wiring'],
    area: 'Gokulam 3rd Stage, Mysuru',
    rating: 4.8,
    total_jobs: 14,
    experience: '6 Years',
    status: 'pending',
    approval_status: 'pending',
    id_verified: false,
    profilePhoto: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&q=80&w=250',
    id_document_url: 'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?auto=format&fit=crop&q=80&w=600',
    aadhaarUrl: 'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?auto=format&fit=crop&q=80&w=600',
    created_at: new Date(Date.now() - 45 * 60000).toISOString(),
  },
  {
    id: 'pw-seed-102',
    name: 'Mohammad Farooq',
    phone: '+91 97412 33441',
    category: 'AC Service',
    work_category: 'ac_service',
    skills: ['AC Service', 'Compressor Refill', 'HVAC'],
    area: 'Kuvempunagar, Mysuru',
    rating: 4.9,
    total_jobs: 22,
    experience: '4 Years',
    status: 'pending',
    approval_status: 'pending',
    id_verified: false,
    profilePhoto: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&q=80&w=250',
    id_document_url: 'https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&q=80&w=600',
    aadhaarUrl: 'https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&q=80&w=600',
    created_at: new Date(Date.now() - 95 * 60000).toISOString(),
  }
];
