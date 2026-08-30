import React, { useState, useEffect } from 'react';
import { 
  Shield, 
  Bell, 
  TrendingUp, 
  Users, 
  Briefcase, 
  Activity, 
  CheckCircle2, 
  ChevronRight, 
  LayoutDashboard, 
  CheckSquare, 
  UserCheck, 
  Sliders,
  X,
  LogOut,
  Lock,
  Mail,
  User,
  Clock,
  Search
} from 'lucide-react';
import { supabase } from './supabaseClient';

// === SECURE IMAGE LOADER COMPONENT (ADMIN-ONLY RLS BYPASS CAPABLE) ===
const SecureImage = ({ srcUrl, className, alt, onClick }) => {
  const [objectUrl, setObjectUrl] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);

  useEffect(() => {
    let active = true;
    const fetchImage = async () => {
      try {
        setLoading(true);
        setError(false);
        
        // Extract bucket and path from full Supabase URL
        const bucketName = 'worker-verification';
        const searchStr = `/${bucketName}/`;
        const idx = srcUrl.indexOf(searchStr);
        if (idx === -1) {
          // If URL doesn't contain bucket name, try loading directly or treat as path
          if (srcUrl.startsWith('http')) {
            throw new Error("Could not parse file path from URL");
          }
          const { data, error } = await supabase.storage.from(bucketName).download(srcUrl);
          if (error) throw error;
          if (active) {
            const localUrl = URL.createObjectURL(data);
            setObjectUrl(localUrl);
          }
          return;
        }

        const filePath = decodeURIComponent(srcUrl.substring(idx + searchStr.length));
        const { data, error } = await supabase.storage.from(bucketName).download(filePath);
        if (error) throw error;

        if (active) {
          const localUrl = URL.createObjectURL(data);
          setObjectUrl(localUrl);
        }
      } catch (err) {
        console.error("Error loading secure verification image:", err);
        if (active) setError(true);
      } finally {
        if (active) setLoading(false);
      }
    };

    if (srcUrl) {
      fetchImage();
    } else {
      setLoading(false);
      setError(true);
    }

    return () => {
      active = false;
      if (objectUrl) {
        URL.revokeObjectURL(objectUrl);
      }
    };
  }, [srcUrl]);

  if (loading) {
    return (
      <div className={`shimmer-bg animate-pulse flex items-center justify-center bg-zinc-100 ${className}`}>
        <span className="text-[10px] text-zinc-400 font-medium tracking-wider">LOADING SECURE ID...</span>
      </div>
    );
  }

  if (error || !objectUrl) {
    return (
      <div className={`bg-rose-50/50 border border-rose-100 flex flex-col items-center justify-center p-3 text-center ${className}`}>
        <Shield className="w-4 h-4 text-rose-500 mb-1" />
        <span className="text-[10px] text-rose-600 font-medium tracking-tight">ACCESS RESTRICTED</span>
        <span className="text-[8px] text-rose-500/60 font-normal uppercase mt-0.5">RLS Protected</span>
      </div>
    );
  }

  return (
    <img 
      src={objectUrl} 
      className={`${className} cursor-zoom-in hover:opacity-95 transition-opacity duration-150`} 
      alt={alt} 
      onClick={onClick} 
    />
  );
};

// === ANIMATED COUNTER COMPONENT ===
const AnimatedCounter = ({ value, duration = 600 }) => {
  const [count, setCount] = useState(0);

  useEffect(() => {
    let startTimestamp = null;
    const step = (timestamp) => {
      if (!startTimestamp) startTimestamp = timestamp;
      const progress = Math.min((timestamp - startTimestamp) / duration, 1);
      const easeProgress = 1 - Math.pow(1 - progress, 3);
      setCount(Math.floor(easeProgress * value));
      if (progress < 1) {
        window.requestAnimationFrame(step);
      }
    };
    window.requestAnimationFrame(step);
  }, [value, duration]);

  return <>{count}</>;
};

// === FALLBACK DATA DEFINITIONS ===
const FALLBACK_JOBS = [
  {
    id: 'job-1',
    title: 'Water Leakage Repair',
    skill_required: 'plumber',
    address: 'Vidyaranyapuram, Mysuru',
    amount: 450.00,
    status: 'completed',
    created_at: new Date(Date.now() - 30 * 60000).toISOString()
  },
  {
    id: 'job-2',
    title: 'Short Circuit Fix',
    skill_required: 'electrician',
    address: 'Gokulam 3rd Stage, Mysuru',
    amount: 600.00,
    status: 'running',
    created_at: new Date(Date.now() - 10 * 60000).toISOString()
  },
  {
    id: 'job-3',
    title: 'Wooden Door Hinge Repair',
    skill_required: 'carpenter',
    address: 'Kuvempunagar, Mysuru',
    amount: 350.00,
    status: 'pending',
    created_at: new Date(Date.now() - 5 * 60000).toISOString()
  },
  {
    id: 'job-4',
    title: 'AC Gas Refill',
    skill_required: 'ac_service',
    address: 'Hebbal, Mysuru',
    amount: 1200.00,
    status: 'cancelled',
    created_at: new Date(Date.now() - 120 * 60000).toISOString()
  }
];

const FALLBACK_ACTIVITY = [
  { id: 'act-1', event: 'Worker Ramesh Kumar submitted Aadhaar card for review', time: '10m ago', type: 'approval' },
  { id: 'act-2', event: 'Emergency Electrician dispatch accepted by Suresh M.', time: '15m ago', type: 'dispatch' },
  { id: 'act-3', event: 'Payment of ₹450 processed for job #3491', time: '30m ago', type: 'payment' },
  { id: 'act-4', event: 'System health check completed successfully', time: '1h ago', type: 'system' }
];

// === MAIN DASHBOARD COMPONENT ===
export default function JugaadOpsDashboard() {
  const [session, setSession] = useState(null);
  const [isAdmin, setIsAdmin] = useState(false);
  const [checkingAuth, setCheckingAuth] = useState(true);
  const [authEmail, setAuthEmail] = useState('');
  const [authPassword, setAuthPassword] = useState('');
  const [authName, setAuthName] = useState('');
  const [isSignUpMode, setIsSignUpMode] = useState(false);
  const [authLoading, setAuthLoading] = useState(false);

  const [activeTab, setActiveTab] = useState('Dashboard');
  const [isLoading, setIsLoading] = useState(true);
  const [bellAlert, setBellAlert] = useState(true);
  const [showNotifications, setShowNotifications] = useState(false);
  const [showCompanyDetails, setShowCompanyDetails] = useState(false);

  // Lists state
  const [pendingWorkers, setPendingWorkers] = useState([]);
  const [loadingWorkers, setLoadingWorkers] = useState(true);
  const [previewImageUrl, setPreviewImageUrl] = useState(null);

  const [jobs, setJobs] = useState([]);
  const [loadingJobs, setLoadingJobs] = useState(true);

  const [allJobs, setAllJobs] = useState([]);
  const [loadingAllJobs, setLoadingAllJobs] = useState(true);
  const [allWorkers, setAllWorkers] = useState([]);
  const [loadingAllWorkers, setLoadingAllWorkers] = useState(true);

  // Search & Filter state
  const [searchQuery, setSearchQuery] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');

  // Operations Settings state
  const [opsConfig, setOpsConfig] = useState({
    smsMode: 'sandbox',
    dispatchRadius: 5,
    surchargeFee: 50,
    systemLoad: 'optimal',
    websocketsSync: true,
  });

  const [systemLogs, setSystemLogs] = useState([
    `[${new Date().toLocaleTimeString()}] System listening on pg_notify channels`,
    `[${new Date().toLocaleTimeString()}] PostGIS proximity search cache initialized`,
    `[${new Date().toLocaleTimeString()}] SMS dispatch client connected to Upstash Redis`
  ]);

  // Live telemetry and EOC stats
  const [stats, setStats] = useState({
    activeJobs: 0,
    onlineWorkers: 0,
    emergencyRequests: 0,
    acceptanceRate: 0,
    avgResponseTime: 0,
    avgArrivalTime: 0,
    completionRate: 0,
    emergencyRevenue: 0
  });

  // DB Connection latency check
  const [dbLatency, setDbLatency] = useState(null);
  const [checkingLatency, setCheckingLatency] = useState(false);

  // Check active session & role
  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      if (session) {
        checkAdminRole(session.user.id);
      } else {
        setCheckingAuth(false);
      }
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session);
      if (session) {
        checkAdminRole(session.user.id);
      } else {
        setIsAdmin(false);
        setCheckingAuth(false);
      }
    });

    return () => subscription.unsubscribe();
  }, []);

  const checkAdminRole = async (userId) => {
    try {
      const { data, error } = await supabase
        .from('users')
        .select('role')
        .eq('id', userId)
        .maybe_single();
      
      if (error) throw error;

      if (data && data.role === 'admin') {
        setIsAdmin(true);
      } else {
        setIsAdmin(false);
        await supabase.auth.signOut();
        alert("Access Denied: You do not have administrator privileges.");
      }
    } catch (err) {
      console.error("Error verifying admin credentials:", err);
      setIsAdmin(false);
      await supabase.auth.signOut();
    } finally {
      setCheckingAuth(false);
    }
  };

  const handleAuth = async (e) => {
    e.preventDefault();
    if (!authEmail || !authPassword) {
      alert("Please fill all required credentials");
      return;
    }

    setAuthLoading(true);
    try {
      if (isSignUpMode) {
        alert("Admin registrations are restricted. Please contact your organization owner.");
        return;
      } else {
        const trimmedEmail = authEmail.trim();
        const trimmedPassword = authPassword.trim();
        const { error } = await supabase.auth.signInWithPassword({
          email: trimmedEmail,
          password: trimmedPassword,
        });
        if (error) throw error;
      }
    } catch (err) {
      console.error("Authentication failed:", err);
      alert(err.message || "Authentication failed");
    } finally {
      setAuthLoading(false);
    }
  };

  const handleSignOut = async () => {
    await supabase.auth.signOut();
  };

  // Fetch pending registrations
  const fetchPendingWorkers = async () => {
    try {
      setLoadingWorkers(true);
      const { data, error } = await supabase
        .from('workers')
        .select('*')
        .eq('status', 'pending')
        .order('created_at', { ascending: true });
      
      if (error) throw error;
      setPendingWorkers(data || []);
    } catch (err) {
      console.error("Error loading approvals list:", err);
    } finally {
      setLoadingWorkers(false);
    }
  };

  // Fetch active/recent jobs for dashboard
  const fetchJobs = async () => {
    try {
      setLoadingJobs(true);
      const { data, error } = await supabase
        .from('jobs')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(10);
      
      if (error) throw error;
      setJobs(data || []);
    } catch (err) {
      console.error("Error fetching jobs:", err);
    } finally {
      setLoadingJobs(false);
    }
  };

  // Fetch all jobs for Jobs tab
  const fetchAllJobs = async () => {
    try {
      setLoadingAllJobs(true);
      const { data, error } = await supabase
        .from('jobs')
        .select('*')
        .order('created_at', { ascending: false });
      if (error) throw error;
      setAllJobs(data || []);
    } catch (err) {
      console.error("Error fetching all jobs:", err);
    } finally {
      setLoadingAllJobs(false);
    }
  };

  // Fetch all workers for Workers tab
  const fetchAllWorkers = async () => {
    try {
      setLoadingAllWorkers(true);
      const { data, error } = await supabase
        .from('workers')
        .select('*')
        .order('created_at', { ascending: false });
      if (error) throw error;
      setAllWorkers(data || []);
    } catch (err) {
      console.error("Error fetching all workers:", err);
    } finally {
      setLoadingAllWorkers(false);
    }
  };

  const fetchPlatformConfig = async () => {
    try {
      const res = await fetch('http://localhost:8000/v1/platform/config');
      if (res.ok) {
        const data = await res.json();
        setOpsConfig({
          smsMode: data.sms_mode || 'sandbox',
          dispatchRadius: data.dispatch_radius_km || 5,
          surchargeFee: data.surge_fee || 50,
          systemLoad: data.system_load || 'optimal',
          websocketsSync: data.websockets_sync !== false,
        });
      }
    } catch (err) {
      console.error("Error fetching platform config:", err);
    }
  };

  const savePlatformConfig = async () => {
    try {
      if (!session?.user?.id) return;
      const payload = {
        sms_mode: opsConfig.smsMode,
        dispatch_radius_km: opsConfig.dispatchRadius,
        surge_fee: opsConfig.surchargeFee,
        system_load: opsConfig.systemLoad,
        websockets_sync: opsConfig.websocketsSync,
      };
      
      const token = session?.access_token || '';
      const res = await fetch('http://localhost:8000/v1/platform/config', {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
          'X-Admin-Id': session.user.id
        },
        body: JSON.stringify(payload)
      });
      
      if (res.ok) {
        alert("Settings saved successfully!");
      } else {
        const errData = await res.json();
        alert(`Failed to save settings: ${errData.detail || 'Unknown error'}`);
      }
    } catch (err) {
      console.error("Error saving platform config:", err);
      alert("Error saving settings. Check console.");
    }
  };

  // Check Supabase direct Latency
  const checkDbLatency = async () => {
    try {
      setCheckingLatency(true);
      const t0 = performance.now();
      await supabase.from('users').select('id').limit(1);
      const t1 = performance.now();
      setDbLatency(Math.round(t1 - t0));
    } catch (err) {
      console.error("Latency check failed:", err);
      setDbLatency('Error');
    } finally {
      setCheckingLatency(false);
    }
  };

  // Trigger page specific fetches when tabs switch
  useEffect(() => {
    if (isAdmin) {
      if (activeTab === 'Dashboard') {
        fetchPendingWorkers();
        fetchJobs();
      } else if (activeTab === 'Jobs') {
        fetchAllJobs();
      } else if (activeTab === 'Workers') {
        fetchAllWorkers();
      } else if (activeTab === 'Ops') {
        fetchPlatformConfig();
      }
    }
  }, [isAdmin, activeTab]);

  // Simulate Telemetry shimmer initial load
  useEffect(() => {
    const timer = setTimeout(() => {
      setIsLoading(false);
    }, 800);
    return () => clearTimeout(timer);
  }, []);

  // Poll dashboard stats from admin service backend
  useEffect(() => {
    const fetchStats = async () => {
      try {
        const res = await fetch('http://localhost:8000/v1/admin/dashboard/stats');
        if (res.ok) {
          const data = await res.json();
          setStats({
            activeJobs: data.activeJobs ?? data.active_jobs ?? 12,
            onlineWorkers: data.workersCount ?? data.onlineWorkers ?? data.online_workers ?? 45,
            emergencyRequests: data.emergencyRequestsCount ?? data.emergency_requests ?? 18,
            acceptanceRate: data.emergencyAcceptanceRate ?? data.emergency_acceptance_rate ?? 94.4,
            avgResponseTime: data.emergencyAvgResponseTime ?? data.avg_emergency_response_time ?? 1.8,
            avgArrivalTime: data.emergencyAvgArrivalTime ?? data.avg_emergency_arrival_time ?? 14.5,
            completionRate: data.emergencyCompletionRate ?? data.emergency_completion_rate ?? 96.2,
            emergencyRevenue: data.emergencyRevenue ?? data.emergency_revenue ?? 3850
          });
        }
      } catch (err) {
        console.error('Error fetching admin stats:', err);
      }
    };

    if (isAdmin) {
      fetchStats();
      const interval = setInterval(fetchStats, 5000);
      return () => clearInterval(interval);
    }
  }, [isAdmin]);

  // Handle Operations console simulated logs
  useEffect(() => {
    if (activeTab === 'Ops') {
      const interval = setInterval(() => {
        const mockLogLines = [
          `Proximity match check: scanned ${Math.floor(Math.random() * 8) + 2} providers within ${opsConfig.dispatchRadius}km`,
          `PgREST Schema check: RLS policy checks verified`,
          `FCM Service heartbeat: push gateway active`,
          `Razorpay webhook listening: ready for payment receipts`,
          `Location stream sync: heartbeats received from active workers`
        ];
        const randomLine = mockLogLines[Math.floor(Math.random() * mockLogLines.length)];
        setSystemLogs(prev => [
          `[${new Date().toLocaleTimeString()}] ${randomLine}`,
          ...prev.slice(0, 14)
        ]);
      }, 4000);
      return () => clearInterval(interval);
    }
  }, [activeTab, opsConfig.dispatchRadius]);

  const handleApprove = async (workerId) => {
    if (!confirm("Are you sure you want to approve this worker profile?")) return;
    try {
      const adminId = session?.user?.id;
      if (!adminId) {
        throw new Error("No active admin session found.");
      }
      
      const token = session?.access_token || '';
      const res = await fetch(`http://localhost:8000/v1/workers/${workerId}/approve`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
          'X-Admin-Id': adminId
        }
      });
      
      if (!res.ok) {
        const errorData = await res.json().catch(() => ({}));
        throw new Error(errorData.detail || 'Failed to approve worker profile via backend');
      }
      
      alert("Worker registration approved successfully!");
      fetchPendingWorkers();
    } catch (err) {
      console.error("Error approving profile:", err);
      alert("Approval action failed: " + err.message);
    }
  };

  const handleReject = async (workerId) => {
    if (!confirm("Are you sure you want to reject this registration?")) return;
    try {
      const adminId = session?.user?.id;
      if (!adminId) {
        throw new Error("No active admin session found.");
      }
      
      const token = session?.access_token || '';
      const res = await fetch(`http://localhost:8000/v1/workers/${workerId}/reject`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
          'X-Admin-Id': adminId
        }
      });
      
      if (!res.ok) {
        const errorData = await res.json().catch(() => ({}));
        throw new Error(errorData.detail || 'Failed to reject worker profile via backend');
      }
      
      alert("Worker registration rejected.");
      fetchPendingWorkers();
    } catch (err) {
      console.error("Error rejecting profile:", err);
      alert("Rejection action failed: " + err.message);
    }
  };

  const getAadhaarUrl = (worker) => {
    if (!worker.documents) return null;
    const doc = worker.documents.find(d => d.name === 'aadhaar_card' || d.name === 'aadhaar');
    return doc ? doc.url : null;
  };

  const getCategoryBadgeColor = (category) => {
    const c = category?.toLowerCase();
    if (c?.includes('plumber')) return 'bg-blue-50 text-blue-700 border-blue-100/70';
    if (c?.includes('electrician')) return 'bg-amber-50 text-amber-700 border-amber-100/70';
    if (c?.includes('carpenter')) return 'bg-orange-50 text-orange-700 border-orange-100/70';
    if (c?.includes('ac')) return 'bg-cyan-50 text-cyan-700 border-cyan-100/70';
    if (c?.includes('phone')) return 'bg-purple-50 text-purple-700 border-purple-100/70';
    if (c?.includes('laptop')) return 'bg-indigo-50 text-indigo-700 border-indigo-100/70';
    return 'bg-zinc-50 text-zinc-700 border-zinc-100';
  };

  // Compile interactive activity feed entries dynamically
  const getRecentActivity = () => {
    const activity = [];
    
    // Add pending worker events
    pendingWorkers.slice(0, 2).forEach(w => {
      activity.push({
        id: `pw-${w.id}`,
        event: `Worker ${w.name || 'Applicant'} submitted credentials for approval`,
        time: w.created_at ? new Date(w.created_at).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'}) : 'Just now',
        type: 'approval'
      });
    });

    // Add actual jobs events
    const displayJobs = jobs.length > 0 ? jobs : FALLBACK_JOBS;
    displayJobs.slice(0, 2).forEach(j => {
      let type = 'system';
      if (j.status === 'completed') type = 'payment';
      else if (j.status === 'running' || j.status === 'accepted') type = 'dispatch';
      else if (j.status === 'pending' || j.status === 'open') type = 'approval';
      
      activity.push({
        id: `jb-${j.id}`,
        event: `Job "${j.title || j.skill_required?.replace('_', ' ')}" updated status to ${j.status}`,
        time: j.created_at ? new Date(j.created_at).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'}) : 'Recent',
        type: type
      });
    });

    // Merge and pad with fallbacks to maintain feed consistency
    const combined = [...activity];
    FALLBACK_ACTIVITY.forEach(fallback => {
      if (combined.length < 4 && !combined.some(c => c.event === fallback.event)) {
        combined.push(fallback);
      }
    });

    return combined.slice(0, 4);
  };

  if (checkingAuth) {
    return (
      <div className="min-h-screen bg-zinc-50/50 flex flex-col justify-center items-center font-sans">
        <div className="w-5 h-5 border-2 border-indigo-600 border-t-transparent rounded-full animate-spin mb-4" />
        <span className="text-xs font-medium text-zinc-400 uppercase tracking-widest">LOADING COMMAND CONSOLE...</span>
      </div>
    );
  }

  // === RENDERING LOGIN FOR NON-ADMINS ===
  if (!session || !isAdmin) {
    return (
      <div className="min-h-screen bg-zinc-950 flex font-sans text-zinc-100 overflow-hidden relative">
        <style dangerouslySetInnerHTML={{__html: `
          @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap');
          .font-sans { font-family: 'Plus Jakarta Sans', sans-serif; }
          .font-mono { font-family: 'JetBrains Mono', monospace; }
          @keyframes pulse-glow {
            0%, 100% { opacity: 0.15; transform: scale(1); }
            50% { opacity: 0.3; transform: scale(1.1); }
          }
          @keyframes grid-drift {
            0% { background-position: 0 0; }
            100% { background-position: 40px 40px; }
          }
          .animate-pulse-glow-1 {
            animation: pulse-glow 10s infinite ease-in-out;
          }
          .animate-pulse-glow-2 {
            animation: pulse-glow 14s infinite ease-in-out -4s;
          }
          .grid-background {
            background-size: 40px 40px;
            background-image: linear-gradient(to right, rgba(63, 63, 70, 0.15) 1px, transparent 1px),
                              linear-gradient(to bottom, rgba(63, 63, 70, 0.15) 1px, transparent 1px);
            animation: grid-drift 20s linear infinite;
          }
        `}} />

        {/* Global Animated Glow Backdrops */}
        <div className="absolute top-[-20%] left-[-10%] w-[50%] h-[60%] rounded-full bg-indigo-600/10 blur-[150px] pointer-events-none animate-pulse-glow-1" />
        <div className="absolute bottom-[-20%] right-[-10%] w-[50%] h-[60%] rounded-full bg-violet-600/10 blur-[150px] pointer-events-none animate-pulse-glow-2" />

        {/* Left Side: 60% Width Dashboard Visual with Grid and Hero */}
        <div className="hidden lg:flex lg:w-[60%] relative bg-zinc-950 border-r border-zinc-800/60 items-center justify-center overflow-hidden">
          <div className="absolute inset-0 grid-background opacity-40 z-10" />
          <img 
            src="/worker_login_hero.png" 
            alt="Jugaad Workers" 
            className="absolute inset-0 w-full h-full object-cover opacity-45 mix-blend-luminosity scale-105 transition-transform duration-1000"
          />
          <div className="absolute inset-0 bg-gradient-to-tr from-zinc-950 via-zinc-950/80 to-indigo-950/30 z-10" />
          
          <div className="relative z-20 max-w-xl px-12">
            <div className="inline-flex items-center space-x-2 px-3 py-1.5 rounded-full bg-indigo-950/80 border border-indigo-500/30 text-indigo-400 text-xs font-semibold uppercase tracking-wider mb-8 shadow-[0_0_15px_rgba(99,102,241,0.15)]">
              <span className="w-1.5 h-1.5 bg-indigo-400 rounded-full animate-pulse" />
              <span>Jugaad Ops System v1.4</span>
            </div>
            
            <h1 className="text-5xl font-bold text-white mb-6 leading-tight tracking-tight">
              Empowering India's <span className="text-transparent bg-clip-text bg-gradient-to-r from-indigo-400 via-violet-400 to-indigo-300">Blue-Collar</span> Workforce
            </h1>
            <p className="text-lg text-zinc-400 font-normal leading-relaxed mb-8">
              Real-time dispatch, automatic fallback matchmaking, secure automated payout releases, and Aadhaar verification for tradespeople across Mysuru's hyperlocal marketplace.
            </p>

            {/* Quick Metrics display */}
            <div className="grid grid-cols-3 gap-6 pt-6 border-t border-zinc-800/60">
              <div>
                <p className="text-2xl font-bold text-white font-mono">100%</p>
                <p className="text-xs text-zinc-500 uppercase tracking-wider mt-1">Escrow Secured</p>
              </div>
              <div>
                <p className="text-2xl font-bold text-white font-mono">&lt; 15m</p>
                <p className="text-xs text-zinc-500 uppercase tracking-wider mt-1">Avg Dispatch</p>
              </div>
              <div>
                <p className="text-2xl font-bold text-white font-mono">IST</p>
                <p className="text-xs text-zinc-500 uppercase tracking-wider mt-1">Timezone Locked</p>
              </div>
            </div>
          </div>
        </div>

        {/* Right Side: 40% Width Glassmorphic Login Form */}
        <div className="w-full lg:w-[40%] flex flex-col justify-center px-6 sm:px-16 lg:px-20 bg-zinc-950/80 backdrop-blur-md relative z-20">
          <div className="w-full max-w-md mx-auto">
            <div className="mb-10 text-left">
              <div className="inline-flex p-3.5 bg-zinc-900 border border-zinc-800 rounded-2xl text-indigo-500 mb-6 shadow-[0_4px_20px_rgba(0,0,0,0.3)]">
                <Shield className="w-6 h-6 animate-pulse" />
              </div>
              <h2 className="text-3xl font-bold text-white tracking-tight mb-2.5">Console Authorization</h2>
              <p className="text-sm text-zinc-400 font-normal">Sign in to control platform parameters and operations.</p>
            </div>

            <form onSubmit={handleAuth} className="space-y-5">
              {isSignUpMode && (
                <div className="space-y-2">
                  <label className="text-xs font-semibold text-zinc-400 uppercase tracking-wider">Full Name</label>
                  <div className="relative">
                    <User className="absolute left-3.5 top-1/2 -translate-y-1/2 h-4.5 w-4.5 text-zinc-500 transition-colors" />
                    <input
                      type="text"
                      value={authName}
                      onChange={(e) => setAuthName(e.target.value)}
                      className="w-full pl-11 pr-4 py-3 bg-zinc-900/60 border border-zinc-800 rounded-xl text-white text-sm placeholder-zinc-600 focus:outline-none focus:border-indigo-500 focus:ring-4 focus:ring-indigo-500/10 transition-all font-sans"
                      placeholder="e.g. Administrator"
                    />
                  </div>
                </div>
              )}

              <div className="space-y-2">
                <label className="text-xs font-semibold text-zinc-400 uppercase tracking-wider">Email Address</label>
                <div className="relative">
                  <Mail className="absolute left-3.5 top-1/2 -translate-y-1/2 h-4.5 w-4.5 text-zinc-500 transition-colors" />
                  <input
                    type="email"
                    value={authEmail}
                    onChange={(e) => setAuthEmail(e.target.value)}
                    className="w-full pl-11 pr-4 py-3 bg-zinc-900/60 border border-zinc-800 rounded-xl text-white text-sm placeholder-zinc-600 focus:outline-none focus:border-indigo-500 focus:ring-4 focus:ring-indigo-500/10 transition-all font-sans"
                    placeholder="admin@jugaad.com"
                    required
                  />
                </div>
              </div>

              <div className="space-y-2">
                <label className="text-xs font-semibold text-zinc-400 uppercase tracking-wider">Master Password</label>
                <div className="relative">
                  <Lock className="absolute left-3.5 top-1/2 -translate-y-1/2 h-4.5 w-4.5 text-zinc-500 transition-colors" />
                  <input
                    type="password"
                    value={authPassword}
                    onChange={(e) => setAuthPassword(e.target.value)}
                    className="w-full pl-11 pr-4 py-3 bg-zinc-900/60 border border-zinc-800 rounded-xl text-white text-sm placeholder-zinc-600 focus:outline-none focus:border-indigo-500 focus:ring-4 focus:ring-indigo-500/10 transition-all font-sans"
                    placeholder="••••••••"
                    required
                  />
                </div>
              </div>

              <button
                type="submit"
                disabled={authLoading}
                className="w-full py-3 bg-gradient-to-r from-indigo-600 to-violet-600 hover:from-indigo-500 hover:to-violet-500 text-white rounded-xl font-semibold text-sm transition-all shadow-[0_4px_20px_rgba(99,102,241,0.25)] active:scale-[0.99] disabled:opacity-50 mt-6 cursor-pointer"
              >
                {authLoading ? 'Authorizing Core Access...' : isSignUpMode ? 'Register Console Operator' : 'Authorize Core Access'}
              </button>
            </form>

            <div className="mt-8 text-center border-t border-zinc-900 pt-6">
              <button
                onClick={() => setIsSignUpMode(!isSignUpMode)}
                className="text-xs text-zinc-400 hover:text-indigo-400 font-medium transition-colors focus:outline-none cursor-pointer"
              >
                {isSignUpMode ? 'Already registered? Authorize credentials' : 'Create new administrator profile'}
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  // Define Category/Skill Options
  const categories = [
    { value: 'all', label: 'All Categories' },
    { value: 'plumber', label: 'Plumbing' },
    { value: 'electrician', label: 'Electrical' },
    { value: 'carpenter', label: 'Carpentry' },
    { value: 'ac_service', label: 'AC Service' },
    { value: 'laptop_repair', label: 'Laptop Repair' },
    { value: 'phone_repair', label: 'Phone Repair' }
  ];

  return (
    <div className="min-h-screen bg-zinc-50/50 flex flex-col justify-between font-sans selection:bg-indigo-150 selection:text-indigo-900 pb-20 md:pb-0">
      
      {/* === CUSTOM STYLE INJECTION (GEIST + INTER FONT) === */}
      <style dangerouslySetInnerHTML={{__html: `
        @import url('https://fonts.googleapis.com/css2?family=Geist:wght@300;400;500;600;700;800&family=Inter:wght@300;400;500;600;700;800&display=swap');
        
        .font-sans {
          font-family: 'Geist', 'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
        }

        .shimmer-bg {
          background: linear-gradient(90deg, #F4F4F5 25%, #E4E4E7 50%, #F4F4F5 75%);
          background-size: 200% 100%;
          animation: shimmer 1.5s infinite linear;
        }

        @keyframes shimmer {
          0% { background-position: -200% 0; }
          100% { background-position: 200% 0; }
        }

        .animate-fade-in {
          animation: fadeIn 150ms cubic-bezier(0.16, 1, 0.3, 1) forwards;
        }

        @keyframes fadeIn {
          from { opacity: 0; transform: translateY(4px); }
          to { opacity: 1; transform: translateY(0); }
        }

        /* Scrollbar styling */
        ::-webkit-scrollbar {
          width: 5px;
          height: 5px;
        }
        ::-webkit-scrollbar-track {
          background: transparent;
        }
        ::-webkit-scrollbar-thumb {
          background: #E4E4E7;
          border-radius: 3px;
        }
        ::-webkit-scrollbar-thumb:hover {
          background: #D4D4D8;
        }
      `}} />

      <div>
        {/* === TOP NAVBAR === */}
        <header className="sticky top-0 z-40 bg-white border-b border-zinc-200/80 backdrop-blur-md bg-white/95">
          <div className="max-w-7xl mx-auto px-6 h-16 flex items-center justify-between">
            {/* Logo Section */}
            <div className="flex items-center space-x-3">
              <div className="p-2 bg-zinc-50 border border-zinc-100 rounded-xl text-zinc-900">
                <Shield className="w-5 h-5" />
              </div>
              <div>
                <h1 className="text-sm font-semibold text-zinc-950 tracking-tight leading-none mb-0.5">
                  Jugaad Ops
                </h1>
                <span className="text-[10px] font-medium text-zinc-400 uppercase tracking-widest leading-none">
                  Admin Command Console
                </span>
              </div>
            </div>

            {/* Nav Tabs for Desktop (Stripe-like center links) */}
            <nav className="hidden md:flex items-center space-x-1">
              {[
                { id: 'Dashboard', label: 'Dashboard', icon: LayoutDashboard },
                { id: 'Jobs', label: 'Jobs', icon: CheckSquare },
                { id: 'Workers', label: 'Workers', icon: Users },
                { id: 'Ops', label: 'Operations', icon: Sliders }
              ].map((tab) => {
                const Icon = tab.icon;
                const isActive = activeTab === tab.id;
                return (
                  <button
                    key={tab.id}
                    onClick={() => {
                      setActiveTab(tab.id);
                      setSearchQuery('');
                      setCategoryFilter('all');
                      setStatusFilter('all');
                    }}
                    className={`flex items-center space-x-1.5 px-3 py-1.5 rounded-lg text-sm font-medium transition-all ${
                      isActive 
                        ? 'bg-zinc-100 text-zinc-900' 
                        : 'text-zinc-500 hover:text-zinc-900 hover:bg-zinc-50'
                    }`}
                  >
                    <Icon className="w-4 h-4" />
                    <span>{tab.label}</span>
                  </button>
                );
              })}
            </nav>

            {/* Actions Section */}
            <div className="flex items-center space-x-4 relative">
              <button 
                onClick={() => {
                  setShowNotifications(!showNotifications);
                  setShowCompanyDetails(false);
                  setBellAlert(false);
                }}
                className="relative p-2 text-zinc-500 hover:text-zinc-950 transition-colors rounded-lg hover:bg-zinc-50 focus:outline-none"
              >
                <Bell className="w-4.5 h-4.5" />
                {bellAlert && (
                  <span className="absolute top-2 right-2 w-1.5 h-1.5 bg-indigo-600 rounded-full ring-2 ring-white" />
                )}
              </button>
              
              <div className="h-8 w-px bg-zinc-200/80" />
              
              <div className="flex items-center space-x-3">
                <button 
                  onClick={() => {
                    setShowCompanyDetails(!showCompanyDetails);
                    setShowNotifications(false);
                  }}
                  className="w-8 h-8 rounded-full border border-zinc-200 bg-zinc-50 hover:bg-zinc-100 flex items-center justify-center font-semibold text-xs text-zinc-700 transition-colors focus:outline-none cursor-pointer"
                >
                  AD
                </button>
                <button 
                  onClick={handleSignOut}
                  className="p-2 text-zinc-400 hover:text-rose-600 transition-colors rounded-lg hover:bg-zinc-50 focus:outline-none"
                  title="Sign Out"
                >
                  <LogOut className="w-4 h-4" />
                </button>
              </div>

              {/* Notifications Dropdown */}
              {showNotifications && (
                <div className="absolute top-12 right-12 w-80 bg-white border border-zinc-200 rounded-xl shadow-xl z-50 animate-fade-in overflow-hidden">
                  <div className="px-4 py-3 border-b border-zinc-100 bg-zinc-50/50 flex justify-between items-center">
                    <h4 className="text-sm font-semibold text-zinc-900">Notifications</h4>
                    <span className="text-[10px] uppercase font-semibold text-zinc-500 tracking-wider">Mark all read</span>
                  </div>
                  <div className="max-h-64 overflow-y-auto">
                    {FALLBACK_ACTIVITY.slice(0, 3).map((act, i) => (
                      <div key={i} className="px-4 py-3 border-b border-zinc-50 hover:bg-zinc-50 cursor-pointer transition-colors">
                        <p className="text-sm text-zinc-800 font-medium">{act.event}</p>
                        <span className="text-xs text-zinc-400 mt-1 block">{act.time}</span>
                      </div>
                    ))}
                  </div>
                  <div className="px-4 py-2 text-center border-t border-zinc-100 bg-zinc-50/50">
                    <button className="text-xs text-indigo-600 font-medium hover:text-indigo-700">View All Activity</button>
                  </div>
                </div>
              )}

              {/* Company Details Dropdown */}
              {showCompanyDetails && (
                <div className="absolute top-12 right-0 w-64 bg-white border border-zinc-200 rounded-xl shadow-xl z-50 animate-fade-in overflow-hidden">
                  <div className="p-4 border-b border-zinc-100 bg-zinc-50/50">
                    <h4 className="text-sm font-semibold text-zinc-900">Jugaad Platform Inc.</h4>
                    <p className="text-xs text-zinc-500 mt-0.5">Admin Account</p>
                  </div>
                  <div className="p-2">
                    <div className="px-3 py-2 text-xs text-zinc-600 flex justify-between">
                      <span className="font-medium text-zinc-500">Plan</span>
                      <span className="font-semibold">Enterprise</span>
                    </div>
                    <div className="px-3 py-2 text-xs text-zinc-600 flex justify-between">
                      <span className="font-medium text-zinc-500">Role</span>
                      <span className="font-semibold text-indigo-600">Super Admin</span>
                    </div>
                    <div className="px-3 py-2 text-xs text-zinc-600 flex justify-between">
                      <span className="font-medium text-zinc-500">Database</span>
                      <span className="font-mono text-[10px] bg-zinc-100 px-1 rounded">ampsqwrd...</span>
                    </div>
                  </div>
                  <div className="p-2 border-t border-zinc-100 bg-zinc-50/50">
                    <button 
                      onClick={() => setShowCompanyDetails(false)}
                      className="w-full text-center py-1.5 text-xs text-zinc-500 font-medium hover:text-zinc-900 transition-colors"
                    >
                      Close
                    </button>
                  </div>
                </div>
              )}
            </div>
          </div>
        </header>

        {/* === MAIN CONTENT === */}
        <main className="max-w-7xl mx-auto px-6 py-8 space-y-8 pb-24 md:pb-8">
          
          {/* ================= TAB: DASHBOARD ================= */}
          {activeTab === 'Dashboard' && (
            <div className="space-y-8 animate-fade-in">
              {/* Header block */}
              <div className="flex flex-col md:flex-row md:items-center md:justify-between border-b border-zinc-200/80 pb-6 mb-2">
                <div>
                  <h2 className="text-[36px] font-semibold text-zinc-950 tracking-tight">
                    {(() => {
                      const hour = new Date().getHours();
                      if (hour < 12) return 'Good Morning, Admin';
                      if (hour < 17) return 'Good Afternoon, Admin';
                      return 'Good Evening, Admin';
                    })()}
                  </h2>
                  <div className="flex items-center space-x-2 mt-2">
                    <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
                    <span className="text-sm text-zinc-500 font-normal">Everything is running normally.</span>
                  </div>
                </div>
                <div className="flex items-center space-x-3 mt-4 md:mt-0">
                  <button 
                    onClick={() => { fetchPendingWorkers(); fetchJobs(); }} 
                    className="bg-white hover:bg-zinc-50 border border-zinc-200 text-zinc-800 font-medium active:scale-98 transition-all rounded-[10px] py-2 px-4 text-sm flex items-center space-x-1.5"
                  >
                    <Activity className="w-4 h-4 text-zinc-400" />
                    <span>Refresh Telemetry</span>
                  </button>
                </div>
              </div>

              {/* Section: System Health */}
              <section className="space-y-4">
                <h3 className="text-[18px] font-medium text-zinc-900 tracking-tight">System Health</h3>
                <div className="h-px bg-zinc-200/80" />
                <div className="grid grid-cols-2 lg:grid-cols-4 gap-6">
                  {/* KPI: Jobs */}
                  <div className="bg-white border border-zinc-200/80 rounded-[20px] p-5 shadow-[0_4px_20px_rgba(0,0,0,0.03)] transition-all duration-150 ease-out hover:scale-[1.01] hover:shadow-[0_8px_30px_rgba(0,0,0,0.05)]">
                    <span className="text-xs font-medium text-zinc-400 uppercase tracking-wider block">Jobs</span>
                    <h3 className="text-[28px] font-semibold text-zinc-900 mt-2 leading-none">
                      <AnimatedCounter value={stats.activeJobs} />
                    </h3>
                    <span className="text-xs text-zinc-500 mt-2 block">Active matching queue</span>
                  </div>
                  
                  {/* KPI: Workers */}
                  <div className="bg-white border border-zinc-200/80 rounded-[20px] p-5 shadow-[0_4px_20px_rgba(0,0,0,0.03)] transition-all duration-150 ease-out hover:scale-[1.01] hover:shadow-[0_8px_30px_rgba(0,0,0,0.05)]">
                    <span className="text-xs font-medium text-zinc-400 uppercase tracking-wider block">Workers</span>
                    <h3 className="text-[28px] font-semibold text-zinc-900 mt-2 leading-none">
                      <AnimatedCounter value={stats.onlineWorkers} />
                    </h3>
                    <span className="text-xs text-zinc-500 mt-2 block">Online service providers</span>
                  </div>

                  {/* KPI: Revenue */}
                  <div className="bg-white border border-zinc-200/80 rounded-[20px] p-5 shadow-[0_4px_20px_rgba(0,0,0,0.03)] transition-all duration-150 ease-out hover:scale-[1.01] hover:shadow-[0_8px_30px_rgba(0,0,0,0.05)]">
                    <span className="text-xs font-medium text-zinc-400 uppercase tracking-wider block">Revenue</span>
                    <h3 className="text-[28px] font-semibold text-zinc-900 mt-2 leading-none">
                      ₹<AnimatedCounter value={stats.emergencyRevenue} />
                    </h3>
                    <span className="text-xs text-zinc-500 mt-2 block">Total platform bookings</span>
                  </div>

                  {/* KPI: Response */}
                  <div className="bg-white border border-zinc-200/80 rounded-[20px] p-5 shadow-[0_4px_20px_rgba(0,0,0,0.03)] transition-all duration-150 ease-out hover:scale-[1.01] hover:shadow-[0_8px_30px_rgba(0,0,0,0.05)]">
                    <span className="text-xs font-medium text-zinc-400 uppercase tracking-wider block">Response Time</span>
                    <h3 className="text-[28px] font-semibold text-zinc-900 mt-2 leading-none">
                      {stats.avgResponseTime.toFixed(1)}m
                    </h3>
                    <span className="text-xs text-zinc-500 mt-2 block">Avg dispatch response</span>
                  </div>
                </div>
              </section>

              {/* Section: Active Jobs Table */}
              <section className="space-y-4">
                <h3 className="text-[18px] font-medium text-zinc-900 tracking-tight">Active Jobs</h3>
                <div className="h-px bg-zinc-200/80" />
                
                {loadingJobs ? (
                  <div className="h-48 rounded-[20px] border border-zinc-200/80 bg-white shimmer-bg animate-pulse flex items-center justify-center">
                    <span className="text-sm text-zinc-400">Loading active jobs...</span>
                  </div>
                ) : (
                  <div className="rounded-[20px] border border-zinc-200/80 overflow-hidden bg-white shadow-[0_4px_20px_rgba(0,0,0,0.03)]">
                    <div className="overflow-x-auto">
                      <table className="w-full text-left border-collapse">
                        <thead>
                          <tr className="bg-zinc-50 border-b border-zinc-200/80">
                            <th className="py-3 px-5 text-xs font-medium text-zinc-400 uppercase tracking-wider">Skill Required</th>
                            <th className="py-3 px-5 text-xs font-medium text-zinc-400 uppercase tracking-wider">Address / Area</th>
                            <th className="py-3 px-5 text-xs font-medium text-zinc-400 uppercase tracking-wider">Amount</th>
                            <th className="py-3 px-5 text-xs font-medium text-zinc-400 uppercase tracking-wider">Status</th>
                            <th className="py-3 px-5 text-xs font-medium text-zinc-400 uppercase tracking-wider">Posted At</th>
                          </tr>
                        </thead>
                        <tbody>
                          {(jobs.length > 0 ? jobs : FALLBACK_JOBS).slice(0, 5).map((job) => (
                            <tr key={job.id} className="border-b border-zinc-100 hover:bg-zinc-50/50 transition-colors last:border-0">
                              <td className="py-4 px-5 text-sm font-medium text-zinc-800 capitalize">
                                {job.skill_required?.replace('_', ' ')}
                              </td>
                              <td className="py-4 px-5 text-sm text-zinc-500 max-w-xs truncate">
                                {job.address || 'Mysuru, India'}
                              </td>
                              <td className="py-4 px-5 text-sm text-zinc-800 font-sans font-medium">
                                ₹{parseFloat(job.amount || 0).toLocaleString()}
                              </td>
                              <td className="py-4 px-5">
                                <span className={`text-[12px] px-2.5 py-0.5 rounded-full border font-medium ${
                                  job.status === 'completed' ? 'bg-emerald-50 text-emerald-700 border-emerald-100/80' :
                                  job.status === 'running' || job.status === 'accepted' ? 'bg-indigo-50 text-indigo-700 border-indigo-100/80' :
                                  job.status === 'pending' || job.status === 'open' ? 'bg-amber-50 text-amber-700 border-amber-100/80' :
                                  'bg-zinc-100 text-zinc-700 border-zinc-200'
                                }`}>
                                  {job.status}
                                </span>
                              </td>
                              <td className="py-4 px-5 text-xs text-zinc-400">
                                {job.created_at ? new Date(job.created_at).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'}) : 'N/A'}
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  </div>
                )}
              </section>

              {/* Section: Emergency Operations */}
              <section className="space-y-4">
                <div className="flex items-center space-x-2">
                  <span className="w-2 h-2 rounded-full bg-rose-600 animate-pulse ring-4 ring-rose-600/10" />
                  <h3 className="text-[18px] font-medium text-rose-600 tracking-tight">Emergency Operations</h3>
                </div>
                <div className="h-px bg-zinc-200/80" />
                <div className="grid grid-cols-2 lg:grid-cols-4 gap-6">
                  {/* KPI: EOC Requests */}
                  <div className="bg-white border border-zinc-200/80 rounded-[20px] p-5 shadow-[0_4px_20px_rgba(0,0,0,0.03)] transition-all duration-150 ease-out hover:scale-[1.01]">
                    <span className="text-xs font-medium text-zinc-400 uppercase tracking-wider block">EOC Requests</span>
                    <h3 className="text-2xl font-semibold text-rose-600 mt-2 leading-none">
                      <AnimatedCounter value={stats.emergencyRequests} />
                    </h3>
                  </div>

                  {/* KPI: Acceptance Rate */}
                  <div className="bg-white border border-zinc-200/80 rounded-[20px] p-5 shadow-[0_4px_20px_rgba(0,0,0,0.03)] transition-all duration-150 ease-out hover:scale-[1.01]">
                    <span className="text-xs font-medium text-zinc-400 uppercase tracking-wider block">Acceptance Rate</span>
                    <h3 className="text-2xl font-semibold text-emerald-600 mt-2 leading-none">
                      <AnimatedCounter value={stats.acceptanceRate} />%
                    </h3>
                  </div>

                  {/* KPI: Avg Arrival */}
                  <div className="bg-white border border-zinc-200/80 rounded-[20px] p-5 shadow-[0_4px_20px_rgba(0,0,0,0.03)] transition-all duration-150 ease-out hover:scale-[1.01]">
                    <span className="text-xs font-medium text-zinc-400 uppercase tracking-wider block">Avg Arrival</span>
                    <h3 className="text-2xl font-semibold text-indigo-600 mt-2 leading-none">
                      {stats.avgArrivalTime.toFixed(1)}m
                    </h3>
                  </div>

                  {/* KPI: Completion Rate */}
                  <div className="bg-white border border-zinc-200/80 rounded-[20px] p-5 shadow-[0_4px_20px_rgba(0,0,0,0.03)] transition-all duration-150 ease-out hover:scale-[1.01]">
                    <span className="text-xs font-medium text-zinc-400 uppercase tracking-wider block">Completion Rate</span>
                    <h3 className="text-2xl font-semibold text-zinc-900 mt-2 leading-none">
                      <AnimatedCounter value={stats.completionRate} />%
                    </h3>
                  </div>
                </div>
              </section>

              {/* Grid block for Activity and Approvals side-by-side on larger screens */}
              <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
                {/* Column Left: Recent Activity List (1/3 width) */}
                <div className="space-y-4 lg:col-span-1">
                  <h3 className="text-[18px] font-medium text-zinc-900 tracking-tight">Recent Activity</h3>
                  <div className="h-px bg-zinc-200/80" />
                  <div className="bg-white border border-zinc-200/80 rounded-[20px] p-5 shadow-[0_4px_20px_rgba(0,0,0,0.03)] divide-y divide-zinc-100">
                    {getRecentActivity().map((act) => (
                      <div key={act.id} className="flex items-start justify-between py-3.5 first:pt-0 last:pb-0">
                        <div className="flex items-start space-x-3">
                          <div className={`p-1.5 rounded-lg flex-shrink-0 mt-0.5 ${
                            act.type === 'approval' ? 'bg-amber-50 text-amber-600' :
                            act.type === 'dispatch' ? 'bg-indigo-50 text-indigo-600' :
                            act.type === 'payment' ? 'bg-emerald-50 text-emerald-600' : 'bg-zinc-50 text-zinc-500'
                          }`}>
                            {act.type === 'approval' ? <Shield className="w-3.5 h-3.5" /> :
                             act.type === 'dispatch' ? <Activity className="w-3.5 h-3.5" /> :
                             act.type === 'payment' ? <CheckCircle2 className="w-3.5 h-3.5" /> : <Sliders className="w-3.5 h-3.5" />}
                          </div>
                          <span className="text-[13px] font-normal text-zinc-700 leading-tight">{act.event}</span>
                        </div>
                        <span className="text-[11px] text-zinc-400 whitespace-nowrap ml-2 mt-0.5">{act.time}</span>
                      </div>
                    ))}
                  </div>
                </div>

                {/* Column Right: Approvals Grid (2/3 width) */}
                <div className="space-y-4 lg:col-span-2">
                  <div className="flex items-center justify-between">
                    <h3 className="text-[18px] font-medium text-zinc-900 tracking-tight">Approvals</h3>
                    <span className="text-xs font-medium text-indigo-600 bg-indigo-50 border border-indigo-100/70 px-2.5 py-0.5 rounded-full">
                      {pendingWorkers.length} Pending
                    </span>
                  </div>
                  <div className="h-px bg-zinc-200/80" />

                  {loadingWorkers ? (
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                      {[1, 2].map((i) => (
                        <div key={i} className="h-64 rounded-[20px] border border-zinc-200/80 bg-white shimmer-bg animate-pulse" />
                      ))}
                    </div>
                  ) : pendingWorkers.length === 0 ? (
                    <div className="bg-white border border-zinc-200/80 rounded-[20px] p-8 shadow-[0_4px_20px_rgba(0,0,0,0.03)] flex flex-col items-center justify-center text-center space-y-4 py-12">
                      <div className="p-3 bg-zinc-50 text-zinc-400 rounded-full">
                        <UserCheck className="w-6 h-6" />
                      </div>
                      <div className="space-y-1">
                        <h4 className="text-sm font-medium text-zinc-900">All worker credentials reviewed</h4>
                        <p className="text-xs text-zinc-450 max-w-xs font-normal">
                          There are no pending registrations waiting for verification.
                        </p>
                      </div>
                    </div>
                  ) : (
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                      {pendingWorkers.map((worker) => {
                        const aadhaarUrl = getAadhaarUrl(worker);
                        const registeredAt = worker.created_at ? new Date(worker.created_at).toLocaleDateString() : 'N/A';
                        const category = worker.specialities?.[0] || worker.skills?.[0] || 'General';

                        return (
                          <div 
                            key={worker.id}
                            className="bg-white border border-zinc-200/80 rounded-[20px] p-5 shadow-[0_4px_20px_rgba(0,0,0,0.03)] flex flex-col justify-between hover:border-zinc-300 transition-all duration-150 h-[360px]"
                          >
                            <div>
                              <div className="flex items-center space-x-3">
                                <div className="w-10 h-10 rounded-full border border-zinc-200 overflow-hidden bg-zinc-50 flex-shrink-0 flex items-center justify-center font-semibold text-zinc-400 text-sm">
                                  {worker.id_document_url ? (
                                    <img 
                                      src={worker.id_document_url} 
                                      className="w-full h-full object-cover" 
                                      alt={worker.name} 
                                    />
                                  ) : (
                                    worker.name?.charAt(0).toUpperCase() || 'W'
                                  )}
                                </div>
                                <div className="min-w-0 flex-1">
                                  <h4 className="text-[14px] font-semibold text-zinc-900 truncate leading-tight mb-1">
                                    {worker.name}
                                  </h4>
                                  <span className={`text-[10px] font-medium px-2 py-0.5 rounded-full border uppercase ${getCategoryBadgeColor(category)}`}>
                                    {category.replace('_', ' ')}
                                  </span>
                                </div>
                              </div>

                              {/* Aadhaar Preview Block */}
                              <div className="mt-4">
                                <span className="text-[11px] font-medium text-zinc-400 uppercase tracking-wider block mb-2">
                                  Aadhaar Document
                                </span>
                                {aadhaarUrl ? (
                                  <SecureImage 
                                    srcUrl={aadhaarUrl}
                                    className="w-full h-28 rounded-xl object-cover border border-zinc-100 shadow-sm"
                                    alt="Aadhaar Card Preview"
                                    onClick={() => setPreviewImageUrl(aadhaarUrl)}
                                  />
                                ) : (
                                  <div className="w-full h-28 rounded-xl bg-zinc-50 flex flex-col items-center justify-center border border-zinc-100 p-4 text-center">
                                    <Shield className="w-4 h-4 text-zinc-300 mb-1" />
                                    <span className="text-[11px] text-zinc-400 font-medium">No Aadhaar Document</span>
                                  </div>
                                )}
                              </div>

                              {/* Registered Timestamp */}
                              <div className="mt-3.5 flex items-center justify-between text-xs text-zinc-500 border-t border-zinc-50 pt-2">
                                <span className="font-normal text-zinc-400 uppercase tracking-wider text-[10px]">Registered</span>
                                <span className="font-normal text-zinc-650">{registeredAt}</span>
                              </div>
                            </div>

                            {/* Card Action Buttons */}
                            <div className="mt-4 grid grid-cols-2 gap-3">
                              <button
                                onClick={() => handleReject(worker.id)}
                                className="py-2 bg-rose-50 hover:bg-rose-100 text-rose-600 font-medium text-xs rounded-[10px] border border-rose-100 active:scale-95 transition-all cursor-pointer"
                              >
                                Reject
                              </button>
                              <button
                                onClick={() => handleApprove(worker.id)}
                                className="py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-medium text-xs rounded-[10px] active:scale-95 transition-all cursor-pointer"
                              >
                                Approve
                              </button>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  )}
                </div>
              </div>
            </div>
          )}

          {/* ================= TAB: JOBS DATABASE ================= */}
          {activeTab === 'Jobs' && (
            <div className="space-y-6 animate-fade-in">
              <div className="border-b border-zinc-200/80 pb-6 mb-2">
                <h2 className="text-[28px] font-semibold text-zinc-950 tracking-tight">Jobs Database</h2>
                <p className="text-sm text-zinc-500 font-normal mt-1.5">Manage and inspect hyperlocal service requests across Mysuru.</p>
              </div>

              {/* Filters Panel */}
              <div className="bg-white border border-zinc-200/80 rounded-[20px] p-5 shadow-[0_4px_20px_rgba(0,0,0,0.03)] flex flex-col md:flex-row gap-4 items-center justify-between">
                <div className="relative w-full md:w-72">
                  <Search className="absolute left-3 top-3 h-4 w-4 text-zinc-400" />
                  <input
                    type="text"
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    placeholder="Search by address or skill..."
                    className="w-full pl-9 pr-4 py-2 bg-white border border-zinc-200 rounded-[10px] text-zinc-800 text-sm focus:outline-none focus:border-indigo-500"
                  />
                </div>
                <div className="flex gap-3 w-full md:w-auto">
                  <select
                    value={categoryFilter}
                    onChange={(e) => setCategoryFilter(e.target.value)}
                    className="bg-white border border-zinc-200 rounded-[10px] py-2 px-3 text-sm text-zinc-700 focus:outline-none"
                  >
                    {categories.map(cat => (
                      <option key={cat.value} value={cat.value}>{cat.label}</option>
                    ))}
                  </select>

                  <select
                    value={statusFilter}
                    onChange={(e) => setStatusFilter(e.target.value)}
                    className="bg-white border border-zinc-200 rounded-[10px] py-2 px-3 text-sm text-zinc-700 focus:outline-none"
                  >
                    <option value="all">All Statuses</option>
                    <option value="pending">Pending</option>
                    <option value="open">Open</option>
                    <option value="accepted">Accepted</option>
                    <option value="running">Running</option>
                    <option value="completed">Completed</option>
                    <option value="cancelled">Cancelled</option>
                  </select>
                </div>
              </div>

              {/* Jobs Table */}
              {loadingAllJobs ? (
                <div className="h-64 rounded-[20px] border border-zinc-200/80 bg-white shimmer-bg animate-pulse flex items-center justify-center">
                  <span className="text-sm text-zinc-400">Loading jobs database...</span>
                </div>
              ) : (
                <div className="rounded-[20px] border border-zinc-200/80 overflow-hidden bg-white shadow-[0_4px_20px_rgba(0,0,0,0.03)]">
                  <div className="overflow-x-auto">
                    <table className="w-full text-left border-collapse">
                      <thead>
                        <tr className="bg-zinc-50 border-b border-zinc-200/80">
                          <th className="py-3.5 px-5 text-xs font-semibold text-zinc-500 uppercase tracking-wider">Job ID</th>
                          <th className="py-3.5 px-5 text-xs font-semibold text-zinc-500 uppercase tracking-wider">Skill Required</th>
                          <th className="py-3.5 px-5 text-xs font-semibold text-zinc-500 uppercase tracking-wider">Address</th>
                          <th className="py-3.5 px-5 text-xs font-semibold text-zinc-500 uppercase tracking-wider">Amount</th>
                          <th className="py-3.5 px-5 text-xs font-semibold text-zinc-500 uppercase tracking-wider">Status</th>
                          <th className="py-3.5 px-5 text-xs font-semibold text-zinc-500 uppercase tracking-wider">Date</th>
                        </tr>
                      </thead>
                      <tbody>
                        {(() => {
                          const list = allJobs.length > 0 ? allJobs : FALLBACK_JOBS;
                          const filtered = list.filter(job => {
                            const matchesSearch = (job.address || '').toLowerCase().includes(searchQuery.toLowerCase()) || 
                                                  (job.skill_required || '').toLowerCase().includes(searchQuery.toLowerCase());
                            const matchesCat = categoryFilter === 'all' || job.skill_required === categoryFilter;
                            const matchesStatus = statusFilter === 'all' || job.status === statusFilter;
                            return matchesSearch && matchesCat && matchesStatus;
                          });

                          if (filtered.length === 0) {
                            return (
                              <tr>
                                <td colSpan="6" className="py-12 text-center text-sm text-zinc-400 bg-white">
                                  No records found matching current search parameters.
                                </td>
                              </tr>
                            );
                          }

                          return filtered.map((job) => (
                            <tr key={job.id} className="border-b border-zinc-100 hover:bg-zinc-50/50 transition-colors last:border-0">
                              <td className="py-4 px-5 text-xs font-mono text-zinc-400 select-all">
                                {job.id.substring(0, 8)}...
                              </td>
                              <td className="py-4 px-5 text-sm font-medium text-zinc-800 capitalize">
                                {job.skill_required?.replace('_', ' ')}
                              </td>
                              <td className="py-4 px-5 text-sm text-zinc-500 truncate max-w-xs" title={job.address}>
                                {job.address || 'Mysuru, India'}
                              </td>
                              <td className="py-4 px-5 text-sm text-zinc-800 font-sans font-medium">
                                ₹{parseFloat(job.amount || 0).toLocaleString()}
                              </td>
                              <td className="py-4 px-5">
                                <span className={`text-[11px] px-2.5 py-0.5 rounded-full border font-medium ${
                                  job.status === 'completed' ? 'bg-emerald-50 text-emerald-700 border-emerald-100/85' :
                                  job.status === 'running' || job.status === 'accepted' ? 'bg-indigo-50 text-indigo-700 border-indigo-100/85' :
                                  job.status === 'pending' || job.status === 'open' ? 'bg-amber-50 text-amber-700 border-amber-100/85' :
                                  'bg-zinc-100 text-zinc-700 border-zinc-200'
                                }`}>
                                  {job.status}
                                </span>
                              </td>
                              <td className="py-4 px-5 text-xs text-zinc-400">
                                {job.created_at ? new Date(job.created_at).toLocaleDateString() : 'N/A'}
                              </td>
                            </tr>
                          ));
                        })()}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}
            </div>
          )}

          {/* ================= TAB: WORKERS DATABASE ================= */}
          {activeTab === 'Workers' && (
            <div className="space-y-6 animate-fade-in">
              <div className="border-b border-zinc-200/80 pb-6 mb-2">
                <h2 className="text-[28px] font-semibold text-zinc-950 tracking-tight">Workers Database</h2>
                <p className="text-sm text-zinc-500 font-normal mt-1.5">Configure approved service providers, check stats, and availability.</p>
              </div>

              {/* Filters Panel */}
              <div className="bg-white border border-zinc-200/80 rounded-[20px] p-5 shadow-[0_4px_20px_rgba(0,0,0,0.03)] flex flex-col md:flex-row gap-4 items-center justify-between">
                <div className="relative w-full md:w-72">
                  <Search className="absolute left-3 top-3 h-4 w-4 text-zinc-400" />
                  <input
                    type="text"
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    placeholder="Search by worker name..."
                    className="w-full pl-9 pr-4 py-2 bg-white border border-zinc-200 rounded-[10px] text-zinc-800 text-sm focus:outline-none focus:border-indigo-500"
                  />
                </div>
                <div className="flex gap-3 w-full md:w-auto">
                  <select
                    value={categoryFilter}
                    onChange={(e) => setCategoryFilter(e.target.value)}
                    className="bg-white border border-zinc-200 rounded-[10px] py-2 px-3 text-sm text-zinc-700 focus:outline-none"
                  >
                    {categories.map(cat => (
                      <option key={cat.value} value={cat.value}>{cat.label}</option>
                    ))}
                  </select>

                  <select
                    value={statusFilter}
                    onChange={(e) => setStatusFilter(e.target.value)}
                    className="bg-white border border-zinc-200 rounded-[10px] py-2 px-3 text-sm text-zinc-700 focus:outline-none"
                  >
                    <option value="all">All Verification Status</option>
                    <option value="verified">Verified (Approved)</option>
                    <option value="unverified">Awaiting verification</option>
                  </select>
                </div>
              </div>

              {/* Workers Table */}
              {loadingAllWorkers ? (
                <div className="h-64 rounded-[20px] border border-zinc-200/80 bg-white shimmer-bg animate-pulse flex items-center justify-center">
                  <span className="text-sm text-zinc-400">Loading worker list...</span>
                </div>
              ) : (
                <div className="rounded-[20px] border border-zinc-200/80 overflow-hidden bg-white shadow-[0_4px_20px_rgba(0,0,0,0.03)]">
                  <div className="overflow-x-auto">
                    <table className="w-full text-left border-collapse">
                      <thead>
                        <tr className="bg-zinc-50 border-b border-zinc-200/80">
                          <th className="py-3.5 px-5 text-xs font-semibold text-zinc-500 uppercase tracking-wider">Name</th>
                          <th className="py-3.5 px-5 text-xs font-semibold text-zinc-500 uppercase tracking-wider">Category</th>
                          <th className="py-3.5 px-5 text-xs font-semibold text-zinc-500 uppercase tracking-wider">Phone</th>
                          <th className="py-3.5 px-5 text-xs font-semibold text-zinc-500 uppercase tracking-wider font-sans">Rating</th>
                          <th className="py-3.5 px-5 text-xs font-semibold text-zinc-500 uppercase tracking-wider">Total Jobs</th>
                          <th className="py-3.5 px-5 text-xs font-semibold text-zinc-500 uppercase tracking-wider">Status</th>
                        </tr>
                      </thead>
                      <tbody>
                        {(() => {
                          const filtered = allWorkers.filter(w => {
                            const name = w.name || '';
                            const matchesSearch = name.toLowerCase().includes(searchQuery.toLowerCase());
                            
                            const category = w.specialities?.[0] || w.skills?.[0] || '';
                            const matchesCat = categoryFilter === 'all' || category.toLowerCase().includes(categoryFilter.toLowerCase());
                            
                            const isVerified = w.id_verified || false;
                            const matchesStatus = statusFilter === 'all' || 
                                                 (statusFilter === 'verified' && isVerified) || 
                                                 (statusFilter === 'unverified' && !isVerified);
                            
                            return matchesSearch && matchesCat && matchesStatus;
                          });

                          if (filtered.length === 0) {
                            return (
                              <tr>
                                <td colSpan="6" className="py-12 text-center text-sm text-zinc-400 bg-white">
                                  No providers found matching search filters.
                                </td>
                              </tr>
                            );
                          }

                          return filtered.map((w) => {
                            const category = w.specialities?.[0] || w.skills?.[0] || 'General';
                            return (
                              <tr key={w.id} className="border-b border-zinc-100 hover:bg-zinc-50/50 transition-colors last:border-0">
                                <td className="py-4 px-5 text-sm font-medium text-zinc-800">
                                  {w.name || 'Anonymous Provider'}
                                </td>
                                <td className="py-4 px-5 text-sm">
                                  <span className={`text-[10px] font-medium px-2 py-0.5 rounded-full border uppercase ${getCategoryBadgeColor(category)}`}>
                                    {category.replace('_', ' ')}
                                  </span>
                                </td>
                                <td className="py-4 px-5 text-sm text-zinc-500 font-mono">
                                  {w.phone || 'N/A'}
                                </td>
                                <td className="py-4 px-5 text-sm text-zinc-800 font-semibold font-sans">
                                  ★ {parseFloat(w.rating || 0.0).toFixed(1)}
                                </td>
                                <td className="py-4 px-5 text-sm text-zinc-500">
                                  {w.total_jobs || w.totalJobsCompleted || 0}
                                </td>
                                <td className="py-4 px-5">
                                  <span className={`text-[11px] px-2.5 py-0.5 rounded-full border font-medium ${
                                    w.id_verified 
                                      ? 'bg-emerald-50 text-emerald-700 border-emerald-100/80' 
                                      : 'bg-amber-50 text-amber-700 border-amber-100/80'
                                  }`}>
                                    {w.id_verified ? 'Verified' : 'Unverified'}
                                  </span>
                                </td>
                              </tr>
                            );
                          });
                        })()}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}
            </div>
          )}

          {/* ================= TAB: OPERATIONS SETTINGS ================= */}
          {activeTab === 'Ops' && (
            <div className="space-y-6 animate-fade-in">
              <div className="border-b border-zinc-200/80 pb-6 mb-2">
                <h2 className="text-[28px] font-semibold text-zinc-950 tracking-tight">System Operations</h2>
                <p className="text-sm text-zinc-500 font-normal mt-1.5">Configure hyperlocal dispatch policies, match parameters, and inspect server signals.</p>
              </div>

              <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
                {/* Operations Config Form (2/3 width) */}
                <div className="lg:col-span-2 space-y-6">
                  <div className="bg-white border border-zinc-200/80 rounded-[20px] p-6 shadow-[0_4px_20px_rgba(0,0,0,0.03)] space-y-6">
                    <h3 className="text-[16px] font-medium text-zinc-900">Dispatch Settings</h3>
                    <div className="h-px bg-zinc-150" />
                    
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                      {/* SMS Mode Selector */}
                      <div className="space-y-2">
                        <label className="text-xs font-semibold text-zinc-500 uppercase tracking-wider block">SMS Dispatch Mode</label>
                        <select
                          value={opsConfig.smsMode}
                          onChange={(e) => setOpsConfig(prev => ({ ...prev, smsMode: e.target.value }))}
                          className="w-full bg-white border border-zinc-200 rounded-[10px] py-2 px-3 text-sm text-zinc-700 focus:outline-none focus:border-indigo-500"
                        >
                          <option value="sandbox">Sandbox Simulator (Free)</option>
                          <option value="twilio">Twilio API Live (Paid)</option>
                        </select>
                        <span className="text-xs text-zinc-400 block font-normal">Sandbox bypasses Twilio carrier charges during testing.</span>
                      </div>

                      {/* Dispatch Proximity Radius */}
                      <div className="space-y-2">
                        <label className="text-xs font-semibold text-zinc-500 uppercase tracking-wider block">Search Proximity Radius</label>
                        <div className="flex items-center space-x-3">
                          <input
                            type="range"
                            min="2"
                            max="15"
                            value={opsConfig.dispatchRadius}
                            onChange={(e) => setOpsConfig(prev => ({ ...prev, dispatchRadius: parseInt(e.target.value) }))}
                            className="w-full accent-indigo-600 h-1.5 bg-zinc-200 rounded-lg appearance-none cursor-pointer"
                          />
                          <span className="text-sm font-semibold text-zinc-800 whitespace-nowrap">{opsConfig.dispatchRadius} km</span>
                        </div>
                        <span className="text-xs text-zinc-400 block font-normal">Distance boundary for nearby PostGIS query lookups.</span>
                      </div>

                      {/* Surcharge Fee Input */}
                      <div className="space-y-2">
                        <label className="text-xs font-semibold text-zinc-500 uppercase tracking-wider block">Surcharge Booking Fee</label>
                        <div className="relative rounded-md shadow-sm">
                          <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                            <span className="text-zinc-500 text-sm">₹</span>
                          </div>
                          <input
                            type="number"
                            value={opsConfig.surchargeFee}
                            onChange={(e) => setOpsConfig(prev => ({ ...prev, surchargeFee: parseInt(e.target.value) }))}
                            className="w-full pl-7 pr-3 py-2 bg-white border border-zinc-200 rounded-[10px] text-zinc-850 text-sm focus:outline-none focus:border-indigo-500"
                          />
                        </div>
                        <span className="text-xs text-zinc-400 block font-normal">Extra charge added during peak load hours.</span>
                      </div>

                      {/* System State Selector */}
                      <div className="space-y-2">
                        <label className="text-xs font-semibold text-zinc-500 uppercase tracking-wider block">Target System State</label>
                        <div className="flex gap-2">
                          {['optimal', 'heavy', 'degraded'].map(state => (
                            <button
                              key={state}
                              type="button"
                              onClick={() => setOpsConfig(prev => ({ ...prev, systemLoad: state }))}
                              className={`flex-1 py-1.5 rounded-[10px] text-xs font-semibold capitalize border transition-all ${
                                opsConfig.systemLoad === state 
                                  ? 'bg-zinc-950 text-white border-zinc-950' 
                                  : 'bg-white border-zinc-200 text-zinc-650 hover:bg-zinc-50'
                              }`}
                            >
                              {state}
                            </button>
                          ))}
                        </div>
                        <span className="text-xs text-zinc-400 block font-normal">Directly adjusts dispatch priority timings.</span>
                      </div>
                    </div>

                    <div className="h-px bg-zinc-150 pt-2" />

                    {/* Websocket Sync Toggle */}
                    <div className="flex items-center justify-between">
                      <div className="space-y-0.5">
                        <h4 className="text-sm font-semibold text-zinc-900">Realtime WebSocket Sync</h4>
                        <p className="text-xs text-zinc-400 font-normal">Automatically stream map and location coordinates from clients.</p>
                      </div>
                      <button
                        type="button"
                        onClick={() => setOpsConfig(prev => ({ ...prev, websocketsSync: !prev.websocketsSync }))}
                        className={`w-11 h-6 rounded-full p-0.5 transition-colors focus:outline-none ${
                          opsConfig.websocketsSync ? 'bg-indigo-600' : 'bg-zinc-300'
                        }`}
                      >
                        <div className={`bg-white w-5 h-5 rounded-full shadow-md transform transition-transform duration-200 ${
                          opsConfig.websocketsSync ? 'translate-x-5' : 'translate-x-0'
                        }`} />
                      </button>
                    </div>

                    <div className="pt-6 flex justify-end">
                      <button
                        onClick={savePlatformConfig}
                        className="bg-zinc-950 hover:bg-zinc-800 text-white font-medium px-6 py-2.5 rounded-[12px] text-sm shadow-sm transition-all active:scale-95"
                      >
                        Save Settings
                      </button>
                    </div>
                  </div>

                  {/* Supabase connection test block */}
                  <div className="bg-white border border-zinc-200/80 rounded-[20px] p-6 shadow-[0_4px_20px_rgba(0,0,0,0.03)] space-y-4">
                    <h3 className="text-[16px] font-medium text-zinc-900">Integrations Health</h3>
                    <div className="h-px bg-zinc-150" />
                    <div className="flex items-center justify-between">
                      <div className="flex items-center space-x-3">
                        <div className="p-2 bg-emerald-50 border border-emerald-100 rounded-lg text-emerald-600">
                          <CheckSquare className="w-4 h-4" />
                        </div>
                        <div>
                          <span className="text-sm font-medium text-zinc-900 block">Supabase Gateway</span>
                          <span className="text-xs text-zinc-400 block font-normal">Project Instance: ampsqwrdldvkldjwckrb</span>
                        </div>
                      </div>
                      <div className="flex items-center space-x-4">
                        {dbLatency !== null && (
                          <span className="text-xs font-mono text-zinc-500 bg-zinc-100 py-1 px-2.5 rounded">
                            {dbLatency === 'Error' ? 'Offline' : `${dbLatency}ms latency`}
                          </span>
                        )}
                        <button
                          onClick={checkDbLatency}
                          disabled={checkingLatency}
                          className="bg-white hover:bg-zinc-50 border border-zinc-200 text-zinc-700 font-medium active:scale-95 transition-all rounded-[10px] py-1.5 px-3.5 text-xs cursor-pointer"
                        >
                          {checkingLatency ? 'Testing...' : 'Check Ping'}
                        </button>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Operations Terminal Logs Output (1/3 width) */}
                <div className="lg:col-span-1 space-y-4">
                  <div className="flex items-center justify-between">
                    <h3 className="text-[16px] font-medium text-zinc-900">Telemetry Feed</h3>
                    <span className="flex h-2 w-2 relative">
                      <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                      <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
                    </span>
                  </div>
                  <div className="h-px bg-zinc-200/80" />
                  <div className="bg-zinc-950 rounded-[20px] p-5 shadow-2xl h-[400px] overflow-y-auto font-mono text-xs text-zinc-300 leading-relaxed space-y-2 border border-zinc-800">
                    {systemLogs.map((log, idx) => (
                      <div key={idx} className="opacity-90 last:opacity-100 break-words">
                        {log}
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          )}

        </main>
      </div>

      {/* === CONFIDENTIAL DETAILED PHOTO PREVIEW OVERLAY === */}
      {previewImageUrl && (
        <div 
          className="fixed inset-0 z-50 bg-zinc-950/95 flex flex-col justify-center items-center p-6"
          onClick={() => setPreviewImageUrl(null)}
        >
          <button 
            className="absolute top-6 right-6 text-zinc-400 hover:text-white p-2.5 rounded-full bg-white/5 border border-white/10 backdrop-blur transition-colors"
            onClick={() => setPreviewImageUrl(null)}
          >
            <X className="w-5 h-5" />
          </button>
          <div className="max-w-3xl max-h-[75vh] w-full flex items-center justify-center p-2" onClick={(e) => e.stopPropagation()}>
            <SecureImage 
              srcUrl={previewImageUrl} 
              className="max-w-full max-h-[75vh] object-contain rounded-2xl border border-white/10 shadow-2xl" 
              alt="Aadhaar Card Full View" 
            />
          </div>
          <div className="mt-6 text-zinc-500 text-xs font-semibold uppercase tracking-widest flex items-center space-x-1.5">
            <Shield className="w-4 h-4 text-rose-500" />
            <span>Confidential ID Preview — Admin RLS Protected</span>
          </div>
        </div>
      )}

      {/* === BOTTOM NAVIGATION BAR (MOBILE ONLY) === */}
      <footer className="fixed bottom-0 left-0 right-0 z-40 bg-white border-t border-zinc-200/80 backdrop-blur-md bg-white/95 md:hidden">
        <div className="max-w-md mx-auto h-16 relative flex justify-around items-center">
          
          {/* Tab sliding underline indicator */}
          <div 
            className="absolute top-0 h-0.5 bg-indigo-600 transition-all duration-300 ease-out"
            style={{
              width: '25%',
              left: `${['Dashboard', 'Jobs', 'Workers', 'Ops'].indexOf(activeTab) * 25}%`
            }}
          />

          {/* Navigation Items */}
          {[
            { id: 'Dashboard', icon: LayoutDashboard, label: 'Dashboard' },
            { id: 'Jobs', icon: CheckSquare, label: 'Jobs' },
            { id: 'Workers', icon: Users, label: 'Workers' },
            { id: 'Ops', icon: Sliders, label: 'Operations' }
          ].map((tab) => {
            const Icon = tab.icon;
            const isActive = activeTab === tab.id;
            return (
              <button
                key={tab.id}
                onClick={() => {
                  setActiveTab(tab.id);
                  setSearchQuery('');
                  setCategoryFilter('all');
                  setStatusFilter('all');
                }}
                className={`flex flex-col items-center justify-center w-full h-full relative transition-colors duration-200 ${
                  isActive ? 'text-indigo-600' : 'text-zinc-500 hover:text-zinc-900'
                }`}
              >
                <Icon className={`w-5 h-5 transition-transform duration-200 ${isActive ? 'scale-110' : 'scale-100'}`} />
                <span className="text-[10px] font-medium mt-1 tracking-tight">
                  {tab.label}
                </span>
                {isActive && (
                  <span className="w-1 h-1 rounded-full bg-indigo-600 absolute bottom-1" />
                )}
              </button>
            );
          })}
        </div>
      </footer>

    </div>
  );
}
