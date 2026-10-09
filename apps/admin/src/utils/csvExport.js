// apps/admin/src/utils/csvExport.js
// Production-grade CSV Export Utility for Jugaad Admin Operations Panel

/**
 * Safely format a cell for CSV export, handling quotes, commas, and newlines.
 */
function escapeCsvCell(value) {
  if (value === null || value === undefined) return '""';
  const str = String(value).replace(/"/g, '""');
  return `"${str}"`;
}

/**
 * Triggers a browser download of a CSV file.
 */
export function downloadCsv(filename, headers, rows) {
  const headerLine = headers.map(escapeCsvCell).join(',');
  const rowLines = rows.map(row => row.map(escapeCsvCell).join(','));
  const csvContent = '\uFEFF' + [headerLine, ...rowLines].join('\r\n'); // UTF-8 BOM for Excel compatibility

  const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.setAttribute('href', url);
  link.setAttribute('download', `${filename}_${new Date().toISOString().slice(0, 10)}.csv`);
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
}

/**
 * Export Platform Jobs to CSV.
 */
export function exportJobsToCsv(jobs = []) {
  const headers = [
    'Job ID',
    'Customer Name',
    'Customer Phone',
    'Worker Name',
    'Worker Phone',
    'Work Category',
    'Job Type',
    'Status',
    'Payment Status',
    'Base Amount (₹)',
    'Surcharge Fee (₹)',
    'Total Amount (₹)',
    'Created At',
    'Completed At',
    'Notes / Reason',
  ];

  const rows = jobs.map(j => {
    const amount = parseFloat(j.amount || 0);
    const surcharge = parseFloat(j.surcharge_amount || 0);
    const total = amount + surcharge;

    return [
      j.id || '',
      j.customer_name || j.customerName || 'Customer',
      j.customer_phone || j.customerPhone || '',
      j.worker_name || j.workerName || 'Unassigned',
      j.worker_phone || j.workerPhone || '',
      j.category || j.work_category || 'General',
      j.job_type || 'standard',
      j.status || 'unknown',
      j.payment_status || 'unpaid',
      amount.toFixed(2),
      surcharge.toFixed(2),
      total.toFixed(2),
      j.created_at ? new Date(j.created_at).toLocaleString() : '',
      j.completed_at ? new Date(j.completed_at).toLocaleString() : '',
      j.notes || j.reason || '',
    ];
  });

  downloadCsv('jugaad_jobs_report', headers, rows);
}

import { parseWorkerCategory, parseWorkerSkills } from './workerUtils';

/**
 * Export Worker Roster & KYC Audit to CSV.
 */
export function exportWorkersToCsv(workers = []) {
  const headers = [
    'Worker ID',
    'Full Name',
    'Phone',
    'Email',
    'Primary Category',
    'All Skills',
    'Rating (★)',
    'Jobs Completed',
    'Hourly Rate (₹)',
    'Approval Status',
    'ID Document Attached',
    'Area',
    'Registered Date',
  ];

  const rows = workers.map(w => {
    const skills = parseWorkerSkills(w);
    const category = parseWorkerCategory(w);
    const isApproved = w.status === 'approved' || w.approval_status === 'approved' || w.id_verified || w.isVerified;
    const approvalStatus = w.is_banned || w.status === 'suspended' ? 'Suspended' : isApproved ? 'Approved (Verified)' : (w.status || 'Pending Review');

    return [
      w.id || '',
      w.displayName || w.name || 'Worker',
      w.displayPhone || w.phone || '',
      w.email || '',
      category,
      skills.join('; '),
      (w.rating || 0).toString(),
      (w.total_jobs || w.totalJobsCompleted || 0).toString(),
      (w.hourly_rate || w.rate_per_hour || 200).toString(),
      approvalStatus,
      w.id_document_url || w.aadhaarUrl ? 'Yes' : 'No',
      w.area || w.address || 'Mysuru',
      w.created_at ? new Date(w.created_at).toLocaleDateString() : '',
    ];
  });

  downloadCsv('jugaad_workers_kyc_report', headers, rows);
}

/**
 * Export Customer Intelligence Directory to CSV.
 */
export function exportCustomersToCsv(customers = []) {
  const headers = [
    'User ID',
    'Full Name',
    'Phone',
    'Email',
    'Total Bookings',
    'Completed Bookings',
    'Cancelled Bookings',
    'Cancellation Rate (%)',
    'Total Gross Spend (₹)',
    'Account Status',
    'Member Since',
  ];

  const rows = customers.map(u => {
    return [
      u.id || '',
      u.name || 'Customer',
      u.phone || '',
      u.email || '',
      (u.total_bookings || 0).toString(),
      (u.completed_bookings || 0).toString(),
      (u.cancelled_bookings || 0).toString(),
      `${u.cancellation_rate || 0}%`,
      (u.total_spent || 0).toFixed(2),
      u.is_suspended || u.status === 'suspended' ? 'Suspended' : 'Active',
      u.created_at ? new Date(u.created_at).toLocaleDateString() : '',
    ];
  });

  downloadCsv('jugaad_customers_directory', headers, rows);
}
