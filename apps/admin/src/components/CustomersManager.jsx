import React, { useState, useEffect, useMemo, useCallback } from 'react';
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
  Download
} from 'lucide-react';
import { exportCustomersToCsv } from '../utils/csvExport';

const DEFAULT_DEMO_CUSTOMERS = [
  {
    id: 'usr_mys_8921',
    name: 'Ramesh Gowda',
    phone: '+91 98450 12890',
    email: 'ramesh.gowda@gmail.com',
    role: 'employer',
    created_at: '2026-09-15T10:30:00Z',
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
    created_at: '2026-09-20T14:15:00Z',
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
    role: 'employer',
    created_at: '2026-09-28T09:45:00Z',
    total_bookings: 4,
    completed_bookings: 3,
    cancelled_bookings: 1,
    cancellation_rate: 25.0,
    total_spent: 1850,
    is_suspended: false,
    status: 'active',
  },
  {
    id: 'usr_mys_5210',
    name: 'Divya Shenoy',
    phone: '+91 99011 88990',
    email: 'divya.s@gmail.com',
    role: 'employer',
    created_at: '2026-10-02T16:20:00Z',
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
  const [statusFilter, setStatusFilter] = useState('all');
  const [sortBy, setSortBy] = useState('recent');
  const [selectedUser, setSelectedUser] = useState(null);
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

      // Primary: backend API with enriched stats
      const res = await fetch(API_ENDPOINTS.USERS('employer', searchQuery), {
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
        // Fallback: direct Supabase query
        const { data, error } = await supabase
          .from('users')
          .select('*')
          .eq('role', 'employer')
          .order('created_at', { ascending: false })
          .limit(100);

        if (!error && data && data.length > 0) {
          setUsers(data.map(u => ({
            ...u,
            total_bookings: 0,
            completed_bookings: 0,
            cancelled_bookings: 0,
            cancellation_rate: 0,
            total_spent: 0,
            status: u.is_suspended ? 'suspended' : 'active',
          })));
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
  }, [session, searchQuery]);

  useEffect(() => {
    fetchUsers();

    const channel = supabase
      .channel('public:admin_users_sync')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'users' }, () => {
        fetchUsers();
      })
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [fetchUsers]);

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
      {/* Header Block matching Website Theme */}
      <div className="flex flex-col md:flex-row md:items-center md:justify-between border-b border-zinc-200/80 pb-6 mb-2">
        <div>
          <h2 className="text-[28px] font-semibold text-zinc-950 tracking-tight">Customer Directory & Intelligence</h2>
          <p className="text-sm text-zinc-500 font-normal mt-1.5">Monitor booking health, manage fraudulent behavior, and inspect customer lifetime spend.</p>
        </div>
        <div className="flex items-center space-x-3 mt-4 md:mt-0">
          <button
            onClick={() => exportCustomersToCsv(filteredUsers)}
            className="bg-white hover:bg-zinc-50 border border-zinc-200 text-zinc-800 font-medium active:scale-98 transition-all rounded-[10px] py-2 px-4 text-sm flex items-center space-x-1.5 shadow-sm"
          >
            <Download className="w-4 h-4 text-zinc-500" />
            <span>Export Customers CSV</span>
          </button>
          <button
            onClick={fetchUsers}
            disabled={loading}
            className="bg-zinc-950 hover:bg-zinc-800 text-white font-medium active:scale-98 transition-all rounded-[10px] py-2 px-4 text-sm flex items-center space-x-1.5 shadow-sm"
          >
            <RotateCcw className={`w-4 h-4 ${loading ? 'animate-spin text-zinc-400' : ''}`} />
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

      {/* KPI Headline Cards matching Website Theme */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="bg-white border border-zinc-200/80 rounded-[20px] p-5 shadow-[0_4px_20px_rgba(0,0,0,0.03)] hover:scale-[1.01] transition-all">
          <span className="text-xs font-medium text-zinc-400 uppercase tracking-wider block">Total Customers</span>
          <h3 className="text-[28px] font-semibold text-zinc-900 mt-2 leading-none font-mono">
            {metrics.total}
          </h3>
          <span className="text-xs text-zinc-500 mt-2 block font-normal">Registered employer accounts</span>
        </div>

        <div className="bg-white border border-zinc-200/80 rounded-[20px] p-5 shadow-[0_4px_20px_rgba(0,0,0,0.03)] hover:scale-[1.01] transition-all">
          <span className="text-xs font-medium text-zinc-400 uppercase tracking-wider block">Gross Customer Spend</span>
          <h3 className="text-[28px] font-semibold text-emerald-600 mt-2 leading-none font-mono">
            ₹{metrics.totalSpent.toLocaleString()}
          </h3>
          <span className="text-xs text-zinc-500 mt-2 block font-normal">Cumulative booking value</span>
        </div>

        <div className="bg-white border border-zinc-200/80 rounded-[20px] p-5 shadow-[0_4px_20px_rgba(0,0,0,0.03)] hover:scale-[1.01] transition-all">
          <span className="text-xs font-medium text-zinc-400 uppercase tracking-wider block">Frequent Bookers</span>
          <h3 className="text-[28px] font-semibold text-indigo-600 mt-2 leading-none font-mono">
            {metrics.frequent}
          </h3>
          <span className="text-xs text-zinc-500 mt-2 block font-normal">Completed 3+ service jobs</span>
        </div>

        <div className="bg-white border border-zinc-200/80 rounded-[20px] p-5 shadow-[0_4px_20px_rgba(0,0,0,0.03)] hover:scale-[1.01] transition-all">
          <span className="text-xs font-medium text-zinc-400 uppercase tracking-wider block">Suspended / Flagged</span>
          <h3 className="text-[28px] font-semibold text-red-600 mt-2 leading-none font-mono">
            {metrics.suspended}
          </h3>
          <span className="text-xs text-zinc-500 mt-2 block font-normal">Restricted customer profiles</span>
        </div>
      </div>

      {/* Filter and Search Panel matching Website Theme */}
      <div className="bg-white border border-zinc-200/80 rounded-[20px] p-5 shadow-[0_4px_20px_rgba(0,0,0,0.03)] flex flex-col md:flex-row gap-4 items-center justify-between">
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
      <div className="bg-white border border-zinc-200/80 rounded-[20px] shadow-[0_4px_20px_rgba(0,0,0,0.03)] overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-zinc-50/80 text-zinc-500 text-xs font-medium uppercase tracking-wider border-b border-zinc-200/80">
              <tr>
                <th className="py-3.5 px-4">Customer</th>
                <th className="py-3.5 px-4">Contact</th>
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
                  <td colSpan={7} className="py-12 text-center text-zinc-400">
                    <RotateCcw className="w-6 h-6 animate-spin mx-auto mb-2 text-zinc-400" />
                    Loading customer directory...
                  </td>
                </tr>
              ) : filteredUsers.length === 0 ? (
                <tr>
                  <td colSpan={7} className="py-12 text-center text-zinc-400">
                    No customers found matching the search and filter criteria.
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
                          <div className="w-9 h-9 rounded-full bg-zinc-100 border border-zinc-200 flex items-center justify-center text-zinc-700 font-bold text-xs uppercase shadow-sm">
                            {(user.name || 'U').slice(0, 2)}
                          </div>
                          <div>
                            <div className="font-semibold text-zinc-900 group-hover:text-indigo-600 transition flex items-center gap-2">
                              {user.name || 'Anonymous User'}
                              {isSusp && (
                                <span className="px-1.5 py-0.5 bg-red-50 border border-red-200 text-red-700 text-[10px] font-bold rounded-md">
                                  SUSPENDED
                                </span>
                              )}
                            </div>
                            <div className="text-xs text-zinc-400 font-mono">
                              #{user.id.slice(0, 8)}
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

      {/* Customer Detail Drawer / Modal matching Website Theme */}
      {selectedUser && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-zinc-950/60 backdrop-blur-sm animate-in fade-in">
          <div className="bg-white border border-zinc-200 rounded-[24px] w-full max-w-lg p-6 shadow-2xl relative space-y-5">
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
            </div>

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
        </div>
      )}

      {/* In-app Confirmation Modal (Zero native browser popups!) */}
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
      />
    </div>
  );
}
