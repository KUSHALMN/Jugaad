import React, { useState, useEffect, useMemo, useCallback } from 'react';
import { supabase } from '../supabaseClient';
import { API_ENDPOINTS } from '../apiConfig';
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
  AlertTriangle,
  RotateCcw,
  ExternalLink,
  ChevronRight,
  UserCheck,
  UserX,
  X
} from 'lucide-react';

export default function CustomersManager({ session }) {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [sortBy, setSortBy] = useState('recent');
  const [selectedUser, setSelectedUser] = useState(null);
  const [isUpdating, setIsUpdating] = useState(false);
  const [actionFeedback, setActionFeedback] = useState(null);

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
        setUsers(data.users || []);
      } else {
        // Fallback: direct Supabase query
        const { data, error } = await supabase
          .from('users')
          .select('*')
          .eq('role', 'employer')
          .order('created_at', { ascending: false })
          .limit(100);

        if (!error && data) {
          setUsers(data.map(u => ({
            ...u,
            total_bookings: 0,
            completed_bookings: 0,
            cancelled_bookings: 0,
            cancellation_rate: 0,
            total_spent: 0,
            status: u.is_suspended ? 'suspended' : 'active',
          })));
        }
      }
    } catch (err) {
      console.warn('Error fetching customers directory:', err);
    } finally {
      setLoading(false);
    }
  }, [session, searchQuery]);

  useEffect(() => {
    fetchUsers();

    // Live subscription for instant customer status sync
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

  const handleToggleStatus = async (user, suspend) => {
    const actionName = suspend ? 'suspend' : 'reactivate';
    let reason = '';
    if (suspend) {
      reason = prompt(`Enter reason for suspending customer "${user.name || user.id}":`) || 'Policy violation or excessive fraudulent cancellations.';
      if (!reason) return;
    } else {
      if (!confirm(`Are you sure you want to reactivate customer "${user.name || user.id}"?`)) return;
    }

    setIsUpdating(true);
    try {
      const token = session?.access_token || '';
      const adminId = session?.user?.id || 'admin-local';

      // 1. Direct Supabase update for instantaneous UX
      await supabase
        .from('users')
        .update({
          is_suspended: suspend,
          is_banned: suspend,
          status: suspend ? 'suspended' : 'active',
        })
        .eq('id', user.id);

      // 2. Call backend moderation endpoint for audit log
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
      fetchUsers();
      if (selectedUser && selectedUser.id === user.id) {
        setSelectedUser(prev => prev ? { ...prev, is_suspended: suspend, status: suspend ? 'suspended' : 'active' } : null);
      }
    } catch (err) {
      console.error('Failed to update customer status:', err);
      alert('Action failed: ' + err.message);
    } finally {
      setIsUpdating(false);
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
    <div className="space-y-6 animate-in fade-in duration-300">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-zinc-900/60 p-6 rounded-2xl border border-zinc-800 backdrop-blur-xl">
        <div>
          <div className="flex items-center gap-3">
            <div className="p-2.5 bg-blue-500/10 text-blue-400 rounded-xl border border-blue-500/20">
              <Users className="w-6 h-6" />
            </div>
            <div>
              <h2 className="text-xl font-bold text-white tracking-tight">Customer Directory & Intelligence</h2>
              <p className="text-sm text-zinc-400">Monitor booking health, manage fraudulent behavior, and audit customer spend.</p>
            </div>
          </div>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={fetchUsers}
            disabled={loading}
            className="flex items-center gap-2 px-4 py-2 bg-zinc-800 hover:bg-zinc-700 text-zinc-300 hover:text-white rounded-xl text-sm font-medium border border-zinc-700/60 transition shadow-sm"
          >
            <RotateCcw className={`w-4 h-4 ${loading ? 'animate-spin text-blue-400' : ''}`} />
            Refresh Directory
          </button>
        </div>
      </div>

      {actionFeedback && (
        <div className="flex items-center gap-3 p-4 bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 rounded-xl text-sm font-medium">
          <CheckCircle2 className="w-5 h-5 flex-shrink-0" />
          <span>{actionFeedback.message}</span>
        </div>
      )}

      {/* KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="p-5 bg-zinc-900/40 rounded-2xl border border-zinc-800/80">
          <div className="flex items-center justify-between text-zinc-400 text-xs font-semibold uppercase tracking-wider mb-2">
            <span>Total Customers</span>
            <Users className="w-4 h-4 text-blue-400" />
          </div>
          <div className="text-2xl font-black text-white">{metrics.total}</div>
          <div className="text-xs text-zinc-500 mt-1">Registered employer profiles</div>
        </div>

        <div className="p-5 bg-zinc-900/40 rounded-2xl border border-zinc-800/80">
          <div className="flex items-center justify-between text-zinc-400 text-xs font-semibold uppercase tracking-wider mb-2">
            <span>Gross Platform Spend</span>
            <DollarSign className="w-4 h-4 text-emerald-400" />
          </div>
          <div className="text-2xl font-black text-emerald-400">₹{metrics.totalSpent.toLocaleString()}</div>
          <div className="text-xs text-zinc-500 mt-1">Aggregated booking value</div>
        </div>

        <div className="p-5 bg-zinc-900/40 rounded-2xl border border-zinc-800/80">
          <div className="flex items-center justify-between text-zinc-400 text-xs font-semibold uppercase tracking-wider mb-2">
            <span>Frequent Bookers</span>
            <TrendingUp className="w-4 h-4 text-purple-400" />
          </div>
          <div className="text-2xl font-black text-purple-400">{metrics.frequent}</div>
          <div className="text-xs text-zinc-500 mt-1">Completed 3+ service jobs</div>
        </div>

        <div className="p-5 bg-zinc-900/40 rounded-2xl border border-zinc-800/80">
          <div className="flex items-center justify-between text-zinc-400 text-xs font-semibold uppercase tracking-wider mb-2">
            <span>Suspended / Flagged</span>
            <ShieldAlert className="w-4 h-4 text-red-400" />
          </div>
          <div className="text-2xl font-black text-red-400">{metrics.suspended}</div>
          <div className="text-xs text-zinc-500 mt-1">Restricted customer accounts</div>
        </div>
      </div>

      {/* Filter and Search Bar */}
      <div className="flex flex-col md:flex-row items-stretch md:items-center justify-between gap-4 bg-zinc-900/40 p-4 rounded-2xl border border-zinc-800/80">
        <div className="relative flex-1">
          <Search className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-zinc-500" />
          <input
            type="text"
            placeholder="Search by customer name, phone, email, or user ID..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-10 pr-4 py-2.5 bg-zinc-800/60 border border-zinc-700/60 rounded-xl text-sm text-white placeholder-zinc-500 focus:outline-none focus:border-blue-500/80 transition"
          />
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <div className="flex items-center gap-2">
            <Filter className="w-4 h-4 text-zinc-500" />
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
              className="bg-zinc-800/80 border border-zinc-700/60 rounded-xl px-3 py-2 text-sm text-zinc-300 focus:outline-none focus:border-blue-500/80"
            >
              <option value="all">All Statuses</option>
              <option value="active">Active Only</option>
              <option value="suspended">Suspended Only</option>
              <option value="frequent">Frequent Bookers (3+)</option>
              <option value="high_cancel">High Cancellation (&gt;25%)</option>
            </select>
          </div>

          <select
            value={sortBy}
            onChange={(e) => setSortBy(e.target.value)}
            className="bg-zinc-800/80 border border-zinc-700/60 rounded-xl px-3 py-2 text-sm text-zinc-300 focus:outline-none focus:border-blue-500/80"
          >
            <option value="recent">Sort by Newest</option>
            <option value="spend">Sort by Highest Spend</option>
            <option value="bookings">Sort by Most Bookings</option>
            <option value="cancel">Sort by Cancellation Rate</option>
          </select>
        </div>
      </div>

      {/* Customer Directory Table */}
      <div className="bg-zinc-900/40 rounded-2xl border border-zinc-800/80 overflow-hidden shadow-xl">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-zinc-800/50 text-zinc-400 text-xs font-semibold uppercase tracking-wider border-b border-zinc-800">
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
            <tbody className="divide-y divide-zinc-800/60">
              {loading && users.length === 0 ? (
                <tr>
                  <td colSpan={7} className="py-12 text-center text-zinc-500">
                    <RotateCcw className="w-6 h-6 animate-spin mx-auto mb-2 text-blue-500" />
                    Loading customer directory...
                  </td>
                </tr>
              ) : filteredUsers.length === 0 ? (
                <tr>
                  <td colSpan={7} className="py-12 text-center text-zinc-500">
                    No customers found matching the search and filter criteria.
                  </td>
                </tr>
              ) : (
                filteredUsers.map((user) => {
                  const isSusp = user.is_suspended || user.status === 'suspended';
                  const cancelRate = user.cancellation_rate || 0;
                  return (
                    <tr key={user.id} className="hover:bg-zinc-800/30 transition group">
                      <td className="py-3.5 px-4">
                        <div className="flex items-center gap-3">
                          <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-blue-600 to-indigo-700 flex items-center justify-center text-white font-bold text-xs uppercase shadow-sm">
                            {(user.name || 'U').slice(0, 2)}
                          </div>
                          <div>
                            <div className="font-semibold text-white group-hover:text-blue-400 transition flex items-center gap-2">
                              {user.name || 'Anonymous User'}
                              {isSusp && (
                                <span className="px-1.5 py-0.5 bg-red-500/10 border border-red-500/20 text-red-400 text-[10px] font-bold rounded">
                                  BANNED
                                </span>
                              )}
                            </div>
                            <div className="text-xs text-zinc-500 font-mono">
                              #{user.id.slice(0, 8)}
                            </div>
                          </div>
                        </div>
                      </td>

                      <td className="py-3.5 px-4">
                        <div className="space-y-0.5">
                          {user.phone ? (
                            <div className="flex items-center gap-1.5 text-zinc-300 text-xs font-mono">
                              <Phone className="w-3 h-3 text-zinc-500" />
                              {user.phone}
                            </div>
                          ) : (
                            <div className="text-xs text-zinc-600">No phone provided</div>
                          )}
                          {user.email && (
                            <div className="flex items-center gap-1.5 text-zinc-400 text-xs truncate max-w-[180px]">
                              <Mail className="w-3 h-3 text-zinc-500" />
                              {user.email}
                            </div>
                          )}
                        </div>
                      </td>

                      <td className="py-3.5 px-4 text-center">
                        <div className="inline-flex items-center gap-1.5 px-2.5 py-1 bg-zinc-800/80 rounded-lg text-xs font-medium">
                          <span className="text-white font-bold">{user.total_bookings || 0}</span>
                          <span className="text-zinc-500">jobs</span>
                          <span className="text-emerald-400 font-semibold">({user.completed_bookings || 0} done)</span>
                        </div>
                      </td>

                      <td className="py-3.5 px-4 text-center">
                        <span
                          className={`inline-block px-2.5 py-0.5 rounded-full text-xs font-bold ${
                            cancelRate > 25
                              ? 'bg-red-500/10 text-red-400 border border-red-500/20'
                              : cancelRate > 10
                              ? 'bg-amber-500/10 text-amber-400 border border-amber-500/20'
                              : 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20'
                          }`}
                        >
                          {cancelRate}%
                        </span>
                      </td>

                      <td className="py-3.5 px-4 text-right font-mono font-bold text-white">
                        ₹{(user.total_spent || 0).toLocaleString()}
                      </td>

                      <td className="py-3.5 px-4 text-center">
                        <span
                          className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-semibold ${
                            isSusp
                              ? 'bg-red-500/10 text-red-400 border border-red-500/20'
                              : 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20'
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
                            className="p-1.5 bg-zinc-800 hover:bg-zinc-700 text-zinc-300 hover:text-white rounded-lg transition"
                            title="Inspect Customer"
                          >
                            <ChevronRight className="w-4 h-4" />
                          </button>

                          {isSusp ? (
                            <button
                              onClick={() => handleToggleStatus(user, false)}
                              disabled={isUpdating}
                              className="px-2.5 py-1 bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 rounded-lg text-xs font-semibold transition"
                            >
                              Reactivate
                            </button>
                          ) : (
                            <button
                              onClick={() => handleToggleStatus(user, true)}
                              disabled={isUpdating}
                              className="px-2.5 py-1 bg-red-500/10 hover:bg-red-500/20 text-red-400 border border-red-500/30 rounded-lg text-xs font-semibold transition"
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

      {/* Customer Detail Drawer / Modal */}
      {selectedUser && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm animate-in fade-in">
          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl w-full max-w-lg p-6 shadow-2xl relative space-y-5">
            <button
              onClick={() => setSelectedUser(null)}
              className="absolute top-4 right-4 p-1.5 bg-zinc-800 hover:bg-zinc-700 text-zinc-400 hover:text-white rounded-lg transition"
            >
              <X className="w-5 h-5" />
            </button>

            <div className="flex items-center gap-4">
              <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-blue-600 to-indigo-700 flex items-center justify-center text-white font-bold text-xl uppercase shadow-md">
                {(selectedUser.name || 'U').slice(0, 2)}
              </div>
              <div>
                <h3 className="text-lg font-bold text-white">{selectedUser.name || 'Anonymous Customer'}</h3>
                <p className="text-xs text-zinc-400 font-mono">User ID: {selectedUser.id}</p>
                <div className="flex items-center gap-2 mt-1">
                  <span
                    className={`inline-block px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider ${
                      selectedUser.is_suspended || selectedUser.status === 'suspended'
                        ? 'bg-red-500/10 text-red-400 border border-red-500/20'
                        : 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20'
                    }`}
                  >
                    {selectedUser.is_suspended || selectedUser.status === 'suspended' ? 'Suspended Account' : 'Active Account'}
                  </span>
                </div>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3 py-2 border-y border-zinc-800">
              <div className="p-3 bg-zinc-800/40 rounded-xl">
                <span className="text-xs text-zinc-500 block">Total Spent</span>
                <span className="text-lg font-bold text-emerald-400 font-mono">
                  ₹{(selectedUser.total_spent || 0).toLocaleString()}
                </span>
              </div>
              <div className="p-3 bg-zinc-800/40 rounded-xl">
                <span className="text-xs text-zinc-500 block">Total Bookings</span>
                <span className="text-lg font-bold text-white font-mono">
                  {selectedUser.total_bookings || 0}
                </span>
              </div>
              <div className="p-3 bg-zinc-800/40 rounded-xl">
                <span className="text-xs text-zinc-500 block">Completed Jobs</span>
                <span className="text-lg font-bold text-blue-400 font-mono">
                  {selectedUser.completed_bookings || 0}
                </span>
              </div>
              <div className="p-3 bg-zinc-800/40 rounded-xl">
                <span className="text-xs text-zinc-500 block">Cancellation Rate</span>
                <span
                  className={`text-lg font-bold font-mono ${
                    (selectedUser.cancellation_rate || 0) > 25 ? 'text-red-400' : 'text-zinc-200'
                  }`}
                >
                  {selectedUser.cancellation_rate || 0}%
                </span>
              </div>
            </div>

            <div className="space-y-2 text-xs text-zinc-300">
              <div className="flex justify-between py-1.5 border-b border-zinc-800/60">
                <span className="text-zinc-500">Phone Number:</span>
                <span className="font-mono">{selectedUser.phone || 'Not provided'}</span>
              </div>
              <div className="flex justify-between py-1.5 border-b border-zinc-800/60">
                <span className="text-zinc-500">Email Address:</span>
                <span>{selectedUser.email || 'Not provided'}</span>
              </div>
              <div className="flex justify-between py-1.5 border-b border-zinc-800/60">
                <span className="text-zinc-500">Member Since:</span>
                <span>{selectedUser.created_at ? new Date(selectedUser.created_at).toLocaleDateString() : 'Unknown'}</span>
              </div>
            </div>

            <div className="pt-2 flex gap-3">
              {selectedUser.is_suspended || selectedUser.status === 'suspended' ? (
                <button
                  onClick={() => handleToggleStatus(selectedUser, false)}
                  disabled={isUpdating}
                  className="flex-1 py-2.5 bg-emerald-600 hover:bg-emerald-500 text-white rounded-xl text-sm font-semibold transition flex items-center justify-center gap-2"
                >
                  <UserCheck className="w-4 h-4" />
                  Reactivate Customer Account
                </button>
              ) : (
                <button
                  onClick={() => handleToggleStatus(selectedUser, true)}
                  disabled={isUpdating}
                  className="flex-1 py-2.5 bg-red-600 hover:bg-red-500 text-white rounded-xl text-sm font-semibold transition flex items-center justify-center gap-2"
                >
                  <UserX className="w-4 h-4" />
                  Suspend / Ban Account
                </button>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
