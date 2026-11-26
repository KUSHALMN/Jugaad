import React, { useState, useEffect, useMemo, useCallback } from 'react';
import { createPortal } from 'react-dom';
import { supabase } from '../supabaseClient';
import { API_ENDPOINTS } from '../apiConfig';
import AdminActionModal from './AdminActionModal';
import {
  Users,
  Search,
  Filter,
  ShieldAlert,
  ShieldCheck,
  Ban,
  CheckCircle2,
  Clock,
  Phone,
  Mail,
  Calendar,
  DollarSign,
  TrendingUp,
  RotateCcw,
  ChevronRight,
  UserCheck,
  UserX,
  X,
  Download,
  Activity,
  BatteryLow,
  Wifi,
  MapPin,
  Sparkles,
  Wallet,
  Flag
} from 'lucide-react';
import { exportCustomersToCsv } from '../utils/csvExport';

const DEFAULT_DEMO_CUSTOMERS = [
  {
    id: 'usr_mys_8921',
    name: 'Ramesh Gowda',
    phone: '+91 98450 12890',
    email: 'ramesh.gowda@gmail.com',
    role: 'employer',
    city: 'Mysuru',
    last_location: 'Vijayanagar 2nd Stage, Mysuru',
    behavior_pattern: 'Night Emergency • Low-Battery Express',
    created_at: '2026-09-15T10:30:00Z',
    battery_level: 11,
    is_low_battery: true,
    battery_state: 'discharging',
    network_mode: 'mobile',
    device_platform: 'android',
    recent_searches: ['electrician', 'mcb tripping'],
    last_booked_skill: 'electrician',
    has_trusted_contact: true,
    activity_log: [
      { type: 'booking', detail: 'Booked electrician (Express Mode)', network: 'mobile', timestamp: '2026-11-25T17:10:00Z' },
      { type: 'search', detail: 'Searched "mcb tripping"', network: 'mobile', timestamp: '2026-11-25T17:08:00Z' },
      { type: 'app_open', detail: 'Opened Jugaad (android • mobile)', network: 'mobile', timestamp: '2026-11-25T17:05:00Z' },
    ],
    recent_jobs: [
      { id: 'job_101', skill_required: 'electrician', status: 'in_progress', amount: 349, created_at: '2026-11-25T17:10:00Z' },
      { id: 'job_098', skill_required: 'ac_service', status: 'completed', amount: 599, created_at: '2026-11-18T11:20:00Z' },
    ],
    total_bookings: 8,
    completed_bookings: 7,
    cancelled_bookings: 1,
    cancellation_rate: 12.5,
    total_spent: 3450,
    is_suspended: false,
    status: 'active',
  },
  {
    id: 'usr_mys_7742',
    name: 'Ananya Rao',
    phone: '+91 99002 44321',
    email: 'ananya.rao@outlook.com',
    role: 'employer',
    city: 'Bengaluru',
    last_location: 'Indiranagar 100ft Rd, Bengaluru',
    behavior_pattern: 'Weekend AC & Appliance Regular',
    created_at: '2026-09-20T14:15:00Z',
    battery_level: 78,
    is_low_battery: false,
    battery_state: 'charging',
    network_mode: 'wifi',
    device_platform: 'iOS',
    recent_searches: ['ac cleaning', 'geyser not heating'],
    last_booked_skill: 'ac_service',
    has_trusted_contact: true,
    activity_log: [
      { type: 'category_tap', detail: 'Selected AC Service', network: 'wifi', timestamp: '2026-11-25T16:45:00Z' },
      { type: 'search', detail: 'Searched "ac cleaning"', network: 'wifi', timestamp: '2026-11-25T16:42:00Z' },
    ],
    recent_jobs: [
      { id: 'job_204', skill_required: 'ac_service', status: 'completed', amount: 649, created_at: '2026-11-24T15:30:00Z' },
    ],
    total_bookings: 12,
    completed_bookings: 12,
    cancelled_bookings: 0,
    cancellation_rate: 0.0,
    total_spent: 6800,
    is_suspended: false,
    status: 'active',
  },
  {
    id: 'usr_mys_6109',
    name: 'Karthik Nayak',
    phone: '+91 97411 99800',
    email: 'karthik.nayak@yahoo.com',
    role: 'worker',
    city: 'Mysuru',
    last_location: 'Gokulam 3rd Stage, Mysuru',
    behavior_pattern: 'High-Frequency Field Pro • Mobile Data',
    created_at: '2026-09-28T09:45:00Z',
    battery_level: 64,
    is_low_battery: false,
    battery_state: 'discharging',
    network_mode: 'mobile',
    device_platform: 'android',
    recent_searches: ['vijayanagar surge'],
    last_booked_skill: 'plumber',
    has_trusted_contact: false,
    activity_log: [
      { type: 'network_change', detail: 'Switched to mobile', network: 'mobile', timestamp: '2026-11-25T16:20:00Z' },
      { type: 'app_open', detail: 'Opened Jugaad (android • mobile)', network: 'mobile', timestamp: '2026-11-25T16:00:00Z' },
    ],
    recent_jobs: [
      { id: 'job_305', skill_required: 'plumber', status: 'completed', amount: 450, created_at: '2026-11-25T14:10:00Z' },
    ],
    total_bookings: 14,
    completed_bookings: 13,
    cancelled_bookings: 1,
    cancellation_rate: 7.1,
    total_spent: 5250,
    is_suspended: false,
    status: 'active',
  },
  {
    id: 'usr_mys_5210',
    name: 'Divya Shenoy',
    phone: '+91 99011 88990',
    email: 'divya.s@gmail.com',
    role: 'employer',
    city: 'Mysuru',
    last_location: 'Kuvempunagar, Mysuru',
    behavior_pattern: 'High Cancellation Risk • Price Comparator',
    created_at: '2026-10-02T16:20:00Z',
    battery_level: 42,
    is_low_battery: false,
    battery_state: 'discharging',
    network_mode: 'wifi',
    device_platform: 'Web',
    recent_searches: ['carpenter', 'stove repair'],
    last_booked_skill: 'carpenter',
    has_trusted_contact: false,
    activity_log: [
      { type: 'search', detail: 'Searched "stove repair"', network: 'wifi', timestamp: '2026-11-23T12:15:00Z' },
    ],
    recent_jobs: [
      { id: 'job_410', skill_required: 'carpenter', status: 'cancelled', amount: 300, created_at: '2026-11-20T10:00:00Z' },
    ],
    total_bookings: 5,
    completed_bookings: 2,
    cancelled_bookings: 3,
    cancellation_rate: 60.0,
    total_spent: 900,
    is_suspended: true,
    status: 'suspended',
  },
];

export default function CustomersManager({ session }) {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [roleFilter, setRoleFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const [sortBy, setSortBy] = useState('recent');
  const [selectedUser, setSelectedUser] = useState(null);
  const [selectedUserJobs, setSelectedUserJobs] = useState([]);
  const [actionFeedback, setActionFeedback] = useState(null);

  // In-app modal state (replacing native browser alerts)
  const [modalState, setModalState] = useState({
    isOpen: false,
    type: 'confirm',
    title: '',
    message: '',
    inputLabel: '',
    inputPlaceholder: '',
    initialInputValue: '',
    confirmText: 'Confirm',
    onConfirm: () => {},
  });

  const fetchUsers = useCallback(async () => {
    setLoading(true);
    try {
      const token = session?.access_token || '';
      const adminId = session?.user?.id || 'admin-local';

      // Primary: backend API with enriched stats + activity
      const res = await fetch(API_ENDPOINTS.USERS(roleFilter, searchQuery), {
        headers: {
          'Authorization': `Bearer ${token}`,
          'X-Admin-Id': adminId,
        },
      });

      if (res.ok) {
        const data = await res.json();
        const fetched = data.users || [];
        setUsers(fetched.length > 0 ? fetched : DEFAULT_DEMO_CUSTOMERS);
      } else {
        // Fallback: direct Supabase query for ALL users + their recent jobs
        let query = supabase
          .from('users')
          .select('*')
          .order('created_at', { ascending: false })
          .limit(200);
        if (roleFilter !== 'all') {
          query = query.eq('role', roleFilter);
        }
        const { data, error } = await query;

        if (!error && data && data.length > 0) {
          const { data: jobsData } = await supabase
            .from('jobs')
            .select('id, employer_id, worker_id, skill_required, status, amount, surcharge_amount, created_at, address, diagnosis_video_url')
            .order('created_at', { ascending: false })
            .limit(300);
          const jobsByUser = {};
          (jobsData || []).forEach((j) => {
            [j.employer_id, j.worker_id].filter(Boolean).forEach((uid) => {
              if (!jobsByUser[uid]) jobsByUser[uid] = [];
              jobsByUser[uid].push(j);
            });
          });
          setUsers(data.map((u) => {
            const uJobs = jobsByUser[u.id] || [];
            const completed = uJobs.filter((j) => (j.status || '').toLowerCase() === 'completed');
            const cancelled = uJobs.filter((j) => (j.status || '').toLowerCase() === 'cancelled');
            const spent = completed.reduce((acc, j) => acc + Number(j.amount || 0) + Number(j.surcharge_amount || 0), 0);
            const totalB = uJobs.length;
            const cancelRate = totalB > 0 ? Math.round((cancelled.length / totalB) * 1000) / 10 : 0;
            const derivedPattern = u.behavior_pattern || (
              cancelRate > 25
                ? 'High Cancel Risk • Review Needed'
                : totalB >= 3
                ? 'Frequent Repeat Booker'
                : u.is_low_battery
                ? 'Battery-Saver Express User'
                : 'Steady Local User'
            );
            return {
              ...u,
              last_location: u.last_location || u.city || (uJobs[0]?.address || 'Mysuru'),
              behavior_pattern: derivedPattern,
              total_bookings: totalB,
              completed_bookings: completed.length,
              cancelled_bookings: cancelled.length,
              cancellation_rate: cancelRate,
              total_spent: spent,
              recent_jobs: uJobs.slice(0, 5),
              status: u.is_suspended ? 'suspended' : 'active',
            };
          }));
        } else {
          setUsers(DEFAULT_DEMO_CUSTOMERS);
        }
      }
    } catch (err) {
      console.warn('Error fetching customers directory:', err);
      setUsers(DEFAULT_DEMO_CUSTOMERS);
    } finally {
      setLoading(false);
    }
  }, [session, searchQuery, roleFilter]);

  useEffect(() => {
    fetchUsers();

    const channel = supabase
      .channel('public:admin_users_sync')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'users' }, () => {
        fetchUsers();
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'jobs' }, () => {
        fetchUsers();
      })
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [fetchUsers]);

  useEffect(() => {
    if (!selectedUser) {
      setSelectedUserJobs([]);
      return;
    }
    if (Array.isArray(selectedUser.recent_jobs) && selectedUser.recent_jobs.length > 0) {
      setSelectedUserJobs(selectedUser.recent_jobs);
      return;
    }
    let active = true;
    supabase
      .from('jobs')
      .select('id, skill_required, status, amount, created_at, address, diagnosis_video_url')
      .or(`employer_id.eq.${selectedUser.id},worker_id.eq.${selectedUser.id}`)
      .order('created_at', { ascending: false })
      .limit(8)
      .then(({ data }) => {
        if (active && Array.isArray(data)) setSelectedUserJobs(data);
      });
    return () => {
      active = false;
    };
  }, [selectedUser]);

  const requestToggleStatus = (user, suspend) => {
    if (suspend) {
      setModalState({
        isOpen: true,
        type: 'prompt',
        title: `Suspend Customer Account`,
        message: `Please provide a reason for restricting access for ${user.name || user.id}. The customer will be prohibited from creating new service bookings.`,
        inputLabel: 'Suspension Reason',
        inputPlaceholder: 'e.g. Repeated fraudulent cancellations, policy breach, payment chargebacks...',
        initialInputValue: 'Excessive cancellations or policy breach.',
        confirmText: 'Suspend Account',
        onConfirm: (reason) => executeToggleStatus(user, true, reason),
      });
    } else {
      setModalState({
        isOpen: true,
        type: 'confirm',
        title: `Reactivate Customer Account`,
        message: `Are you sure you want to lift all restrictions for ${user.name || user.id}? They will regain full access to request services.`,
        confirmText: 'Reactivate Account',
        onConfirm: () => executeToggleStatus(user, false, ''),
      });
    }
  };

  const executeToggleStatus = async (user, suspend, reason) => {
    try {
      const token = session?.access_token || '';
      const adminId = session?.user?.id || 'admin-local';

      // 1. Direct Supabase update
      await supabase
        .from('users')
        .update({
          is_suspended: suspend,
          is_banned: suspend,
          status: suspend ? 'suspended' : 'active',
        })
        .eq('id', user.id);

      // 2. Call backend moderation endpoint
      try {
        await fetch(API_ENDPOINTS.USER_STATUS(user.id), {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${token}`,
            'X-Admin-Id': adminId,
          },
          body: JSON.stringify({
            is_suspended: suspend,
            reason: reason,
          }),
        });
      } catch (backendErr) {
        console.warn('Backend user status audit note:', backendErr);
      }

      setActionFeedback({
        type: 'success',
        message: `Customer ${user.name || 'Account'} has been ${suspend ? 'suspended' : 'reactivated'}.`,
      });
      setTimeout(() => setActionFeedback(null), 4000);

      // Local optimistic update
      setUsers(prev => prev.map(u => u.id === user.id ? { ...u, is_suspended: suspend, status: suspend ? 'suspended' : 'active' } : u));
      if (selectedUser && selectedUser.id === user.id) {
        setSelectedUser(prev => prev ? { ...prev, is_suspended: suspend, status: suspend ? 'suspended' : 'active' } : null);
      }
    } catch (err) {
      console.error('Failed to update customer status:', err);
      setModalState({
        isOpen: true,
        type: 'info',
        title: 'Action Error',
        message: 'Could not update customer status: ' + err.message,
        confirmText: 'Dismiss',
        onConfirm: () => {},
      });
    }
  };

  // Metrics
  const metrics = useMemo(() => {
    const total = users.length;
    const suspended = users.filter(u => u.is_suspended || u.status === 'suspended').length;
    const frequent = users.filter(u => (u.total_bookings || 0) >= 3).length;
    const totalSpent = users.reduce((sum, u) => sum + (u.total_spent || 0), 0);
    return { total, suspended, frequent, totalSpent };
  }, [users]);

  // Filtered and Sorted Users
  const filteredUsers = useMemo(() => {
    return users.filter(u => {
      const matchesSearch =
        !searchQuery ||
        (u.name || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
        (u.phone || '').includes(searchQuery) ||
        (u.email || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
        (u.id || '').toLowerCase().includes(searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      if (statusFilter === 'active') return !u.is_suspended && u.status !== 'suspended';
      if (statusFilter === 'suspended') return u.is_suspended || u.status === 'suspended';
      if (statusFilter === 'frequent') return (u.total_bookings || 0) >= 3;
      if (statusFilter === 'high_cancel') return (u.cancellation_rate || 0) > 25;

      return true;
    }).sort((a, b) => {
      if (sortBy === 'spend') return (b.total_spent || 0) - (a.total_spent || 0);
      if (sortBy === 'bookings') return (b.total_bookings || 0) - (a.total_bookings || 0);
      if (sortBy === 'cancel') return (b.cancellation_rate || 0) - (a.cancellation_rate || 0);
      return new Date(b.created_at || 0) - new Date(a.created_at || 0);
    });
  }, [users, searchQuery, statusFilter, sortBy]);

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header Block matching Glass & Orange/Green Theme */}
      <div className="flex flex-col md:flex-row md:items-center md:justify-between pb-2">
        <div className="flex items-start gap-3.5">
          <div className="w-1 h-12 rounded-full bg-orange-500 mt-1 shrink-0" />
          <div>
            <h2 className="text-[26px] font-bold text-zinc-950 tracking-tight leading-tight">
              Customer Directory &amp; Intelligence
            </h2>
            <p className="text-sm text-zinc-500 font-normal mt-1">
              Monitor booking health, manage fraudulent behavior, and inspect customer lifetime spend.
            </p>
          </div>
        </div>
        <div className="flex items-center space-x-3 mt-4 md:mt-0">
          <button
            onClick={() => exportCustomersToCsv(filteredUsers)}
            className="jugaad-glass hover:bg-white/90 text-zinc-800 font-semibold active:scale-98 transition-all rounded-xl py-2 px-4 text-sm flex items-center space-x-1.5"
          >
            <Download className="w-4 h-4 text-zinc-600" />
            <span>Export Customers CSV</span>
          </button>
          <button
            onClick={fetchUsers}
            disabled={loading}
            className="bg-emerald-800 hover:bg-emerald-900 text-white font-semibold active:scale-98 transition-all rounded-xl py-2 px-4 text-sm flex items-center space-x-1.5 shadow-sm shadow-emerald-900/20"
          >
            <RotateCcw className={`w-4 h-4 ${loading ? 'animate-spin text-emerald-200' : ''}`} />
            <span>Refresh</span>
          </button>
        </div>
      </div>

      {actionFeedback && (
        <div className="flex items-center gap-3 p-4 bg-emerald-50 border border-emerald-200 text-emerald-800 rounded-[14px] text-sm font-medium shadow-sm animate-fade-in">
          <CheckCircle2 className="w-5 h-5 flex-shrink-0 text-emerald-600" />
          <span>{actionFeedback.message}</span>
        </div>
      )}

      {/* KPI Headline Cards matching Mockup Glass Design */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
        <div className="jugaad-glass rounded-[20px] p-5 flex items-center gap-4 hover:scale-[1.01] transition-all">
          <div className="w-11 h-11 rounded-full bg-orange-100/90 border border-orange-200/70 flex items-center justify-center text-orange-600 shrink-0">
            <Users className="w-5 h-5" />
          </div>
          <div className="min-w-0">
            <span className="text-[11px] font-bold text-orange-600 uppercase tracking-wider block">Total Users</span>
            <h3 className="text-[26px] font-bold text-zinc-950 mt-0.5 leading-none font-mono">
              {metrics.total}
            </h3>
            <span className="text-[11px] text-zinc-500 mt-1 block truncate">Registered platform accounts</span>
          </div>
        </div>

        <div className="jugaad-glass rounded-[20px] p-5 flex items-center gap-4 hover:scale-[1.01] transition-all">
          <div className="w-11 h-11 rounded-full bg-emerald-100/90 border border-emerald-200/70 flex items-center justify-center text-emerald-600 shrink-0">
            <Wallet className="w-5 h-5" />
          </div>
          <div className="min-w-0">
            <span className="text-[11px] font-bold text-emerald-700 uppercase tracking-wider block">Gross Customer Spend</span>
            <h3 className="text-[26px] font-bold text-emerald-600 mt-0.5 leading-none font-mono">
              ₹{metrics.totalSpent.toLocaleString()}
            </h3>
            <span className="text-[11px] text-zinc-500 mt-1 block truncate">Cumulative booking value</span>
          </div>
        </div>

        <div className="jugaad-glass rounded-[20px] p-5 flex items-center gap-4 hover:scale-[1.01] transition-all">
          <div className="w-11 h-11 rounded-full bg-blue-100/90 border border-blue-200/70 flex items-center justify-center text-blue-600 shrink-0">
            <Calendar className="w-5 h-5" />
          </div>
          <div className="min-w-0">
            <span className="text-[11px] font-bold text-blue-700 uppercase tracking-wider block">Frequent Bookers</span>
            <h3 className="text-[26px] font-bold text-zinc-950 mt-0.5 leading-none font-mono">
              {metrics.frequent}
            </h3>
            <span className="text-[11px] text-zinc-500 mt-1 block truncate">Completed 3+ service jobs</span>
          </div>
        </div>

        <div className="jugaad-glass rounded-[20px] p-5 flex items-center gap-4 hover:scale-[1.01] transition-all">
          <div className="w-11 h-11 rounded-full bg-rose-100/90 border border-rose-200/70 flex items-center justify-center text-rose-600 shrink-0">
            <Flag className="w-5 h-5" />
          </div>
          <div className="min-w-0">
            <span className="text-[11px] font-bold text-rose-600 uppercase tracking-wider block">Suspended / Flagged</span>
            <h3 className="text-[26px] font-bold text-rose-600 mt-0.5 leading-none font-mono">
              {metrics.suspended}
            </h3>
            <span className="text-[11px] text-zinc-500 mt-1 block truncate">Restricted user profiles</span>
          </div>
        </div>
      </div>

      {/* Filter and Search Panel matching Glass Theme */}
      <div className="jugaad-glass rounded-[22px] p-5 flex flex-col md:flex-row gap-4 items-center justify-between">
        <div className="relative w-full md:w-80">
          <Search className="absolute left-3 top-3 h-4 w-4 text-zinc-400" />
          <input
            type="text"
            placeholder="Search by customer name, phone, email, or user ID..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-9 pr-4 py-2 bg-white border border-zinc-200 rounded-[10px] text-zinc-800 text-sm focus:outline-none focus:border-zinc-400 transition"
          />
        </div>

        <div className="flex flex-wrap items-center gap-3 w-full md:w-auto">
          <select
            value={roleFilter}
            onChange={(e) => setRoleFilter(e.target.value)}
            className="bg-white border border-zinc-200 rounded-[10px] py-2 px-3 text-sm text-zinc-700 focus:outline-none"
          >
            <option value="all">All Roles</option>
            <option value="employer">Customers</option>
            <option value="worker">Workers</option>
          </select>

          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="bg-white border border-zinc-200 rounded-[10px] py-2 px-3 text-sm text-zinc-700 focus:outline-none"
          >
            <option value="all">All Statuses</option>
            <option value="active">Active Only</option>
            <option value="suspended">Suspended Only</option>
            <option value="frequent">Frequent Bookers (3+)</option>
            <option value="high_cancel">High Cancellation (&gt;25%)</option>
          </select>

          <select
            value={sortBy}
            onChange={(e) => setSortBy(e.target.value)}
            className="bg-white border border-zinc-200 rounded-[10px] py-2 px-3 text-sm text-zinc-700 focus:outline-none"
          >
            <option value="recent">Sort by Newest</option>
            <option value="spend">Sort by Highest Spend</option>
            <option value="bookings">Sort by Most Bookings</option>
            <option value="cancel">Sort by Cancellation Rate</option>
          </select>
        </div>
      </div>

      {/* Customer Directory Table */}
      <div className="jugaad-glass rounded-[22px] overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-zinc-50/80 text-zinc-500 text-xs font-medium uppercase tracking-wider border-b border-zinc-200/80">
              <tr>
                <th className="py-3.5 px-4">User & Role</th>
                <th className="py-3.5 px-4">Contact</th>
                <th className="py-3.5 px-4">Live Activity</th>
                <th className="py-3.5 px-4 text-center">Bookings</th>
                <th className="py-3.5 px-4 text-center">Cancel Rate</th>
                <th className="py-3.5 px-4 text-right">Total Spent</th>
                <th className="py-3.5 px-4 text-center">Status</th>
                <th className="py-3.5 px-4 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-100">
              {loading && users.length === 0 ? (
                <tr>
                  <td colSpan={8} className="py-12 text-center text-zinc-400">
                    <RotateCcw className="w-6 h-6 animate-spin mx-auto mb-2 text-zinc-400" />
                    Loading users & live activity...
                  </td>
                </tr>
              ) : filteredUsers.length === 0 ? (
                <tr>
                  <td colSpan={8} className="py-12 text-center text-zinc-400">
                    No users found matching the search and filter criteria.
                  </td>
                </tr>
              ) : (
                filteredUsers.map((user) => {
                  const isSusp = user.is_suspended || user.status === 'suspended';
                  const cancelRate = user.cancellation_rate || 0;
                  return (
                    <tr key={user.id} className="hover:bg-zinc-50/80 transition-colors group">
                      <td className="py-3.5 px-4">
                        <div className="flex items-center gap-3">
                          <div className={`w-9 h-9 rounded-full flex items-center justify-center font-bold text-xs uppercase shadow-xs ${
                            user.role === 'worker'
                              ? 'bg-emerald-100 text-emerald-700 border border-emerald-200/80'
                              : 'bg-purple-100 text-purple-700 border border-purple-200/80'
                          }`}>
                            {(user.name || 'U').slice(0, 2)}
                          </div>
                          <div>
                            <div className="font-semibold text-zinc-900 group-hover:text-orange-600 transition flex items-center gap-2">
                              {user.name || 'Anonymous User'}
                              {isSusp && (
                                <span className="px-1.5 py-0.5 bg-red-50 border border-red-200 text-red-700 text-[10px] font-bold rounded-md">
                                  SUSPENDED
                                </span>
                              )}
                            </div>
                            <div className="text-xs text-zinc-400 font-mono flex items-center gap-1.5">
                              <span>#{user.id.slice(0, 8)}</span>
                              <span className={`px-1.5 py-0.5 rounded-md font-sans text-[10px] font-bold uppercase ${
                                user.role === 'worker'
                                  ? 'bg-blue-50 text-blue-700 border border-blue-200/60'
                                  : 'bg-sky-50 text-sky-700 border border-sky-200/60'
                              }`}>
                                {user.role === 'worker' ? 'Worker' : 'Customer'}
                              </span>
                            </div>
                          </div>
                        </div>
                      </td>

                      <td className="py-3.5 px-4">
                        <div className="space-y-0.5">
                          {user.phone ? (
                            <div className="flex items-center gap-1.5 text-zinc-800 text-xs font-mono font-medium">
                              <Phone className="w-3 h-3 text-zinc-400" />
                              {user.phone}
                            </div>
                          ) : (
                            <div className="text-xs text-zinc-400">No phone provided</div>
                          )}
                          {user.email && (
                            <div className="flex items-center gap-1.5 text-zinc-500 text-xs truncate max-w-[180px]">
                              <Mail className="w-3 h-3 text-zinc-400" />
                              {user.email}
                            </div>
                          )}
                        </div>
                      </td>

                      <td className="py-3.5 px-4">
                        <div className="space-y-1 text-xs">
                          <div className="flex items-center gap-1 text-zinc-700 font-medium">
                            <MapPin className="w-3 h-3 text-emerald-600 flex-shrink-0" />
                            <span className="truncate max-w-[190px]">
                              {user.last_location || user.city || 'Mysuru'}
                            </span>
                          </div>
                          {user.behavior_pattern && (
                            <div className="text-[11px] font-medium text-orange-700 truncate max-w-[200px]">
                              {user.behavior_pattern}
                            </div>
                          )}
                          <div className="flex flex-wrap items-center gap-1">
                            {user.last_booked_skill && (
                              <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-emerald-50 text-emerald-700 border border-emerald-200 font-medium capitalize">
                                <Activity className="w-3 h-3" />
                                {user.last_booked_skill.replace('_', ' ')}
                              </span>
                            )}
                            {user.is_low_battery && (
                              <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-amber-50 text-amber-700 border border-amber-200 font-medium">
                                <BatteryLow className="w-3 h-3" />
                                {user.battery_level ?? '<15'}%
                              </span>
                            )}
                            {user.network_mode && (
                              <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-sky-50 text-sky-700 border border-sky-200 font-medium uppercase text-[10px]">
                                <Wifi className="w-3 h-3" />
                                {user.network_mode}
                              </span>
                            )}
                            {user.device_platform && (
                              <span className="px-1.5 py-0.5 rounded bg-zinc-100 text-zinc-600 text-[10px] font-medium">
                                {user.device_platform}
                              </span>
                            )}
                          </div>
                          {Array.isArray(user.activity_log) && user.activity_log.length > 0 ? (
                            <div className="text-[11px] text-zinc-600 truncate max-w-[220px]">
                              {user.activity_log[0].detail}
                            </div>
                          ) : Array.isArray(user.recent_searches) && user.recent_searches.length > 0 ? (
                            <div className="text-[11px] text-zinc-500 truncate max-w-[200px]">
                              Searched: {user.recent_searches.slice(0, 2).join(', ')}
                            </div>
                          ) : (
                            <div className="text-[11px] text-zinc-400">
                              {user.recent_jobs?.length > 0
                                ? `Last job: ${(user.recent_jobs[0].skill_required || '').replace('_', ' ')}`
                                : 'No recent searches'}
                            </div>
                          )}
                        </div>
                      </td>

                      <td className="py-3.5 px-4 text-center">
                        <div className="inline-flex items-center gap-1.5 px-2.5 py-1 bg-zinc-100 rounded-lg text-xs font-medium">
                          <span className="text-zinc-900 font-bold">{user.total_bookings || 0}</span>
                          <span className="text-zinc-500">jobs</span>
                          <span className="text-emerald-700 font-semibold">({user.completed_bookings || 0} done)</span>
                        </div>
                      </td>

                      <td className="py-3.5 px-4 text-center">
                        <span
                          className={`inline-block px-2.5 py-0.5 rounded-full text-xs font-semibold ${
                            cancelRate > 25
                              ? 'bg-red-50 text-red-700 border border-red-200'
                              : cancelRate > 10
                              ? 'bg-amber-50 text-amber-700 border border-amber-200'
                              : 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                          }`}
                        >
                          {cancelRate}%
                        </span>
                      </td>

                      <td className="py-3.5 px-4 text-right font-mono font-bold text-zinc-900">
                        ₹{(user.total_spent || 0).toLocaleString()}
                      </td>

                      <td className="py-3.5 px-4 text-center">
                        <span
                          className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-semibold ${
                            isSusp
                              ? 'bg-red-50 text-red-700 border border-red-200'
                              : 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                          }`}
                        >
                          {isSusp ? (
                            <>
                              <Ban className="w-3 h-3" /> Suspended
                            </>
                          ) : (
                            <>
                              <CheckCircle2 className="w-3 h-3" /> Active
                            </>
                          )}
                        </span>
                      </td>

                      <td className="py-3.5 px-4 text-right">
                        <div className="flex items-center justify-end gap-2">
                          <button
                            onClick={() => setSelectedUser(user)}
                            className="p-1.5 bg-zinc-100 hover:bg-zinc-200 text-zinc-700 rounded-lg transition"
                            title="Inspect Customer"
                          >
                            <ChevronRight className="w-4 h-4" />
                          </button>

                          {isSusp ? (
                            <button
                              onClick={() => requestToggleStatus(user, false)}
                              className="px-2.5 py-1 bg-emerald-50 hover:bg-emerald-100 text-emerald-700 border border-emerald-200 rounded-lg text-xs font-semibold transition"
                            >
                              Reactivate
                            </button>
                          ) : (
                            <button
                              onClick={() => requestToggleStatus(user, true)}
                              className="px-2.5 py-1 bg-red-50 hover:bg-red-100 text-red-700 border border-red-200 rounded-lg text-xs font-semibold transition"
                            >
                              Suspend
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Customer Detail Drawer / Modal rendered in Portal so fixed inset-0 covers full viewport */}
      {selectedUser && createPortal(
        <div
          onClick={() => setSelectedUser(null)}
          className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-zinc-950/60 backdrop-blur-sm"
        >
          <div
            onClick={(e) => e.stopPropagation()}
            className="bg-white/95 backdrop-blur-xl border border-orange-100 rounded-[24px] w-full max-w-lg max-h-[88vh] overflow-y-auto p-6 shadow-2xl relative space-y-5"
          >
            <button
              onClick={() => setSelectedUser(null)}
              className="absolute top-4 right-4 p-1.5 rounded-full text-zinc-400 hover:text-zinc-700 hover:bg-zinc-100 transition"
            >
              <X className="w-5 h-5" />
            </button>

            <div className="flex items-center gap-4">
              <div className="w-14 h-14 rounded-full bg-zinc-100 border border-zinc-200 flex items-center justify-center text-zinc-700 font-bold text-xl uppercase shadow-sm">
                {(selectedUser.name || 'U').slice(0, 2)}
              </div>
              <div>
                <h3 className="text-lg font-bold text-zinc-950">{selectedUser.name || 'Anonymous Customer'}</h3>
                <p className="text-xs text-zinc-400 font-mono">User ID: {selectedUser.id}</p>
                <div className="flex items-center gap-2 mt-1">
                  <span
                    className={`inline-block px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider ${
                      selectedUser.is_suspended || selectedUser.status === 'suspended'
                        ? 'bg-red-50 text-red-700 border border-red-200'
                        : 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                    }`}
                  >
                    {selectedUser.is_suspended || selectedUser.status === 'suspended' ? 'Suspended Account' : 'Active Account'}
                  </span>
                </div>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3 py-2 border-y border-zinc-100">
              <div className="p-3 bg-zinc-50 rounded-xl border border-zinc-100">
                <span className="text-xs text-zinc-400 block">Total Spent</span>
                <span className="text-lg font-bold text-emerald-600 font-mono">
                  ₹{(selectedUser.total_spent || 0).toLocaleString()}
                </span>
              </div>
              <div className="p-3 bg-zinc-50 rounded-xl border border-zinc-100">
                <span className="text-xs text-zinc-400 block">Total Bookings</span>
                <span className="text-lg font-bold text-zinc-900 font-mono">
                  {selectedUser.total_bookings || 0}
                </span>
              </div>
              <div className="p-3 bg-zinc-50 rounded-xl border border-zinc-100">
                <span className="text-xs text-zinc-400 block">Completed Jobs</span>
                <span className="text-lg font-bold text-indigo-600 font-mono">
                  {selectedUser.completed_bookings || 0}
                </span>
              </div>
              <div className="p-3 bg-zinc-50 rounded-xl border border-zinc-100">
                <span className="text-xs text-zinc-400 block">Cancellation Rate</span>
                <span
                  className={`text-lg font-bold font-mono ${
                    (selectedUser.cancellation_rate || 0) > 25 ? 'text-red-600' : 'text-zinc-900'
                  }`}
                >
                  {selectedUser.cancellation_rate || 0}%
                </span>
              </div>
            </div>

            <div className="space-y-2 text-xs text-zinc-700">
              <div className="flex justify-between py-1.5 border-b border-zinc-100">
                <span className="text-zinc-400">Phone Number:</span>
                <span className="font-mono font-medium">{selectedUser.phone || 'Not provided'}</span>
              </div>
              <div className="flex justify-between py-1.5 border-b border-zinc-100">
                <span className="text-zinc-400">Email Address:</span>
                <span className="font-medium">{selectedUser.email || 'Not provided'}</span>
              </div>
              <div className="flex justify-between py-1.5 border-b border-zinc-100">
                <span className="text-zinc-400">Member Since:</span>
                <span className="font-medium">{selectedUser.created_at ? new Date(selectedUser.created_at).toLocaleDateString() : 'Unknown'}</span>
              </div>
              <div className="flex justify-between py-1.5 border-b border-zinc-100">
                <span className="text-zinc-400">Location:</span>
                <span className="font-medium text-zinc-900">
                  {selectedUser.last_location || selectedUser.city || 'Mysuru'}
                </span>
              </div>
              <div className="flex justify-between items-center py-1.5 border-b border-zinc-100">
                <span className="text-zinc-400">Behavior Pattern:</span>
                <span className="font-medium text-orange-700">
                  {selectedUser.behavior_pattern || 'Steady Local User'}
                </span>
              </div>
              <div className="flex justify-between py-1.5 border-b border-zinc-100">
                <span className="text-zinc-400">Device & Network Context:</span>
                <span className="font-medium">
                  {selectedUser.device_platform ? `${selectedUser.device_platform} · ` : ''}
                  {selectedUser.battery_level != null
                    ? `${selectedUser.battery_level}%${selectedUser.battery_state ? ` (${selectedUser.battery_state})` : ''}`
                    : 'Battery N/A'}
                  {selectedUser.network_mode ? ` · ${selectedUser.network_mode.toUpperCase()}` : ''}
                  {selectedUser.has_trusted_contact ? ' · Trusted Contact Set' : ''}
                </span>
              </div>
              {Array.isArray(selectedUser.activity_log) && selectedUser.activity_log.length > 0 && (
                <div className="py-1.5 border-b border-zinc-100">
                  <span className="text-zinc-400 block mb-1">Live Phone & App Activity:</span>
                  <div className="max-h-28 overflow-y-auto space-y-1 pr-1">
                    {selectedUser.activity_log.slice(0, 8).map((ev, idx) => (
                      <div key={idx} className="flex items-center justify-between text-[11px] bg-zinc-50 px-2.5 py-1 rounded-lg">
                        <span className="text-zinc-800 font-medium truncate max-w-[260px]">{ev.detail || ev.type}</span>
                        <span className="text-zinc-400 font-mono text-[10px]">
                          {ev.network ? `${ev.network} · ` : ''}
                          {ev.timestamp ? new Date(ev.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : ''}
                        </span>
                      </div>
                    ))}
                  </div>
                </div>
              )}
              {Array.isArray(selectedUser.recent_searches) && selectedUser.recent_searches.length > 0 && (
                <div className="py-1.5 border-b border-zinc-100">
                  <span className="text-zinc-400 block mb-1">Recent Searches:</span>
                  <div className="flex flex-wrap gap-1.5">
                    {selectedUser.recent_searches.map((q, idx) => (
                      <span key={idx} className="px-2 py-0.5 rounded-full bg-zinc-100 text-zinc-700 text-[11px] font-medium">
                        {q}
                      </span>
                    ))}
                  </div>
                </div>
              )}
            </div>

            {selectedUserJobs.length > 0 && (
              <div className="space-y-2">
                <span className="text-xs font-semibold text-zinc-500 uppercase tracking-wider block">
                  Recent Activity ({selectedUserJobs.length} bookings)
                </span>
                <div className="max-h-36 overflow-y-auto space-y-1.5 pr-1">
                  {selectedUserJobs.map((j) => (
                    <div key={j.id} className="flex items-center justify-between px-3 py-2 rounded-xl bg-zinc-50 border border-zinc-100 text-xs">
                      <div>
                        <span className="font-semibold text-zinc-900 capitalize">
                          {(j.skill_required || 'Service').replace('_', ' ')}
                        </span>
                        <span className="text-zinc-400 ml-2">
                          {j.created_at ? new Date(j.created_at).toLocaleDateString() : ''}
                        </span>
                      </div>
                      <div className="flex items-center gap-2">
                        <span className="font-mono font-semibold text-zinc-800">₹{j.amount || 0}</span>
                        <span className="px-2 py-0.5 rounded-full bg-emerald-50 text-emerald-700 border border-emerald-200 text-[10px] font-semibold uppercase">
                          {j.status || 'requested'}
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            <div className="pt-2 flex gap-3">
              {selectedUser.is_suspended || selectedUser.status === 'suspended' ? (
                <button
                  onClick={() => requestToggleStatus(selectedUser, false)}
                  className="flex-1 py-2.5 bg-emerald-600 hover:bg-emerald-500 text-white rounded-xl text-sm font-semibold transition flex items-center justify-center gap-2 shadow-sm"
                >
                  <UserCheck className="w-4 h-4" />
                  Reactivate Customer Account
                </button>
              ) : (
                <button
                  onClick={() => requestToggleStatus(selectedUser, true)}
                  className="flex-1 py-2.5 bg-red-600 hover:bg-red-500 text-white rounded-xl text-sm font-semibold transition flex items-center justify-center gap-2 shadow-sm"
                >
                  <UserX className="w-4 h-4" />
                  Suspend / Ban Account
                </button>
              )}
            </div>
          </div>
        </div>,
        document.body
      )}

      {/* In-app Confirmation Modal (Zero native browser popups!) */}
      {createPortal(
        <AdminActionModal
          isOpen={modalState.isOpen}
          type={modalState.type}
          title={modalState.title}
          message={modalState.message}
          inputLabel={modalState.inputLabel}
          inputPlaceholder={modalState.inputPlaceholder}
          initialInputValue={modalState.initialInputValue}
          confirmText={modalState.confirmText}
          onConfirm={modalState.onConfirm}
          onClose={() => setModalState(prev => ({ ...prev, isOpen: false }))}
        />,
        document.body
      )}
    </div>
  );
}
