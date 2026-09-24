import React, { useState, useEffect } from 'react';
import { 
  Navigation, 
  MapPin, 
  Layers, 
  RefreshCw, 
  Crosshair, 
  Radio, 
  User, 
  Phone, 
  Zap, 
  CheckCircle, 
  AlertCircle,
  Eye,
  Sliders,
  Filter
} from 'lucide-react';

const MYSURU_ZONES = [
  { id: 'z1', name: 'Gokulam 3rd Stage', x: 260, y: 140, demand: 'High', workers: 14, surge: '1.4x' },
  { id: 'z2', name: 'Kuvempunagar', x: 280, y: 380, demand: 'Very High', workers: 22, surge: '1.5x' },
  { id: 'z3', name: 'Hebbal Industrial Area', x: 180, y: 110, demand: 'Moderate', workers: 8, surge: '1.0x' },
  { id: 'z4', name: 'Jayalakshmipuram', x: 330, y: 220, demand: 'High', workers: 16, surge: '1.3x' },
  { id: 'z5', name: 'Saraswathipuram', x: 340, y: 310, demand: 'Moderate', workers: 11, surge: '1.1x' },
  { id: 'z6', name: 'Vidyaranyapuram', x: 380, y: 440, demand: 'High', workers: 15, surge: '1.3x' },
  { id: 'z7', name: 'Vijayanagar 2nd Stage', x: 190, y: 260, demand: 'Low', workers: 6, surge: '1.0x' },
];

const INITIAL_WORKERS = [
  { id: 'w1', name: 'Suresh Kumar', trade: 'Electrician', status: 'en_route', lat: 12.3312, lng: 76.6212, x: 275, y: 160, battery: '88%', phone: '+91 98450 12345', job: '#JUG-8821', speed: '28 km/h' },
  { id: 'w2', name: 'Ramesh Gowda', trade: 'Plumber', status: 'online', lat: 12.2981, lng: 76.6341, x: 295, y: 360, battery: '94%', phone: '+91 97412 67890', job: null, speed: '0 km/h' },
  { id: 'w3', name: 'Manjunath B.', trade: 'Carpenter', status: 'in_progress', lat: 12.3150, lng: 76.6450, x: 325, y: 235, battery: '62%', phone: '+91 99001 44556', job: '#JUG-8819', speed: '0 km/h' },
  { id: 'w4', name: 'Arun Prakash', trade: 'AC Tech', status: 'en_route', lat: 12.3550, lng: 76.6120, x: 195, y: 125, battery: '79%', phone: '+91 94481 99887', job: '#JUG-8825', speed: '34 km/h' },
  { id: 'w5', name: 'Praveen Naik', trade: 'Plumber', status: 'online', lat: 12.2850, lng: 76.6500, x: 370, y: 420, battery: '91%', phone: '+91 98860 33221', job: null, speed: '0 km/h' },
  { id: 'w6', name: 'Kiran Swamy', trade: 'Electrician', status: 'online', lat: 12.3080, lng: 76.6280, x: 210, y: 275, battery: '83%', phone: '+91 94800 77112', job: null, speed: '0 km/h' },
];

const ACTIVE_DISPATCH_ROUTES = [
  { id: 'r1', fromX: 275, fromY: 160, toX: 310, toY: 190, customer: 'Ananya Rao', worker: 'Suresh Kumar', eta: '6 mins' },
  { id: 'r2', fromX: 195, fromY: 125, toX: 220, toY: 145, customer: 'Vikram Joshi', worker: 'Arun Prakash', eta: '9 mins' },
];

export default function RadarMapModal({ liveWorkers = [], liveJobs = [] }) {
  const [workers, setWorkers] = useState(INITIAL_WORKERS);
  const [selectedWorker, setSelectedWorker] = useState(null);
  const [filterTrade, setFilterTrade] = useState('all');
  const [filterStatus, setFilterStatus] = useState('all');
  const [showHeatmap, setShowHeatmap] = useState(true);
  const [showRoutes, setShowRoutes] = useState(true);
  const [isLivePinging, setIsLivePinging] = useState(true);
  const [lastRefreshed, setLastRefreshed] = useState(new Date().toLocaleTimeString());

  // Ingest real Supabase workers when available
  useEffect(() => {
    if (liveWorkers && liveWorkers.length > 0) {
      const mapped = liveWorkers.map((lw, index) => {
        const lat = parseFloat(lw.lat) || (12.3051 + Math.sin(index * 1.5) * 0.03);
        const lng = parseFloat(lw.lng) || (76.6551 + Math.cos(index * 1.5) * 0.03);
        const normX = Math.max(80, Math.min(520, ((lng - 76.58) / 0.12) * 600));
        const normY = Math.max(60, Math.min(460, (1 - ((lat - 12.26) / 0.12)) * 520));

        const tradeStr = lw.category || lw.work_category || 'General';
        const formattedTrade = tradeStr.charAt(0).toUpperCase() + tradeStr.slice(1).replace('_', ' ');

        return {
          id: lw.id || `w-${index}`,
          name: lw.name || 'Worker',
          trade: formattedTrade,
          status: lw.is_online || lw.isOnline ? 'online' : (lw.status || 'online'),
          lat: lat.toFixed(4),
          lng: lng.toFixed(4),
          x: normX,
          y: normY,
          battery: `${75 + (index * 7) % 23}%`,
          phone: lw.phone || '+91 98450 00000',
          job: lw.current_job_id || null,
          speed: lw.is_online ? '0 km/h' : '22 km/h'
        };
      });
      setWorkers(mapped);
    }
  }, [liveWorkers]);

  // Simulate subtle real-time GPS jitter for moving en-route workers
  useEffect(() => {
    if (!isLivePinging) return;
    const interval = setInterval(() => {
      setWorkers(prev => prev.map(w => {
        if (w.status === 'en_route') {
          const dx = (Math.random() - 0.5) * 4;
          const dy = (Math.random() - 0.5) * 4;
          return { ...w, x: Math.max(100, Math.min(500, w.x + dx)), y: Math.max(80, Math.min(500, w.y + dy)) };
        }
        return w;
      }));
      setLastRefreshed(new Date().toLocaleTimeString());
    }, 3000);
    return () => clearInterval(interval);
  }, [isLivePinging]);

  const filteredWorkers = workers.filter(w => {
    if (filterTrade !== 'all' && w.trade !== filterTrade) return false;
    if (filterStatus !== 'all' && w.status !== filterStatus) return false;
    return true;
  });

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Top Banner Control bar */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-white p-5 rounded-2xl border border-zinc-200/80 shadow-xs">
        <div>
          <div className="flex items-center space-x-2">
            <span className="relative flex h-2.5 w-2.5">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
              <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-emerald-500"></span>
            </span>
            <h2 className="text-base font-bold text-zinc-900 tracking-tight">
              Mysuru City Geolocation Telemetry Radar
            </h2>
            <span className="px-2 py-0.5 text-[10px] font-semibold tracking-wider uppercase bg-emerald-50 text-emerald-700 rounded-md border border-emerald-200">
              Live PostGIS Feed
            </span>
          </div>
          <p className="text-xs text-zinc-500 mt-1">
            Tracking active worker heartbeat pings across 7 municipal wards. Auto-synced at {lastRefreshed}.
          </p>
        </div>

        {/* View toggles */}
        <div className="flex items-center space-x-3">
          <button
            onClick={() => setShowHeatmap(!showHeatmap)}
            className={`px-3 py-1.5 text-xs font-medium rounded-lg border flex items-center space-x-1.5 transition-colors cursor-pointer ${
              showHeatmap 
                ? 'bg-indigo-50 border-indigo-200 text-indigo-700 font-semibold' 
                : 'bg-white border-zinc-200 text-zinc-600 hover:bg-zinc-50'
            }`}
          >
            <Layers className="w-3.5 h-3.5" />
            <span>Demand Heatmap</span>
          </button>

          <button
            onClick={() => setShowRoutes(!showRoutes)}
            className={`px-3 py-1.5 text-xs font-medium rounded-lg border flex items-center space-x-1.5 transition-colors cursor-pointer ${
              showRoutes 
                ? 'bg-indigo-50 border-indigo-200 text-indigo-700 font-semibold' 
                : 'bg-white border-zinc-200 text-zinc-600 hover:bg-zinc-50'
            }`}
          >
            <Navigation className="w-3.5 h-3.5" />
            <span>Dispatch Routes</span>
          </button>

          <button
            onClick={() => setIsLivePinging(!isLivePinging)}
            className={`px-3 py-1.5 text-xs font-medium rounded-lg border flex items-center space-x-1.5 transition-colors cursor-pointer ${
              isLivePinging 
                ? 'bg-emerald-50 border-emerald-200 text-emerald-700 font-semibold' 
                : 'bg-zinc-100 border-zinc-200 text-zinc-400'
            }`}
          >
            <Radio className="w-3.5 h-3.5 animate-pulse" />
            <span>{isLivePinging ? 'Live Pings (3s)' : 'Paused'}</span>
          </button>
        </div>
      </div>

      {/* Main Map + Inspection Layout */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        
        {/* Vector Map Canvas (8 Columns) */}
        <div className="lg:col-span-8 bg-zinc-950 rounded-2xl border border-zinc-800 p-4 relative overflow-hidden shadow-xl min-h-[560px] flex flex-col justify-between">
          
          {/* Map Top Overlays & Filters */}
          <div className="flex flex-wrap items-center justify-between gap-2 z-10">
            <div className="flex items-center space-x-2 bg-zinc-900/80 backdrop-blur-md px-3 py-1.5 rounded-xl border border-zinc-800 text-white text-xs">
              <Filter className="w-3.5 h-3.5 text-zinc-400" />
              <select 
                value={filterTrade} 
                onChange={(e) => setFilterTrade(e.target.value)}
                className="bg-transparent text-xs text-white focus:outline-none cursor-pointer"
              >
                <option value="all" className="bg-zinc-900 text-white">All Skills</option>
                <option value="Electrician" className="bg-zinc-900 text-white">Electrician</option>
                <option value="Plumber" className="bg-zinc-900 text-white">Plumber</option>
                <option value="Carpenter" className="bg-zinc-900 text-white">Carpenter</option>
                <option value="AC Tech" className="bg-zinc-900 text-white">AC Tech</option>
              </select>
            </div>

            <div className="flex items-center space-x-2 bg-zinc-900/80 backdrop-blur-md px-3 py-1.5 rounded-xl border border-zinc-800 text-white text-xs">
              <select 
                value={filterStatus} 
                onChange={(e) => setFilterStatus(e.target.value)}
                className="bg-transparent text-xs text-white focus:outline-none cursor-pointer"
              >
                <option value="all" className="bg-zinc-900 text-white">All Statuses</option>
                <option value="online" className="bg-zinc-900 text-white">Online & Ready</option>
                <option value="en_route" className="bg-zinc-900 text-white">En Route</option>
                <option value="in_progress" className="bg-zinc-900 text-white">In Progress</option>
              </select>
            </div>
          </div>

          {/* Interactive SVG Radar Map Canvas */}
          <div className="relative w-full h-[460px] my-2">
            <svg className="w-full h-full" viewBox="0 0 600 520">
              <defs>
                <radialGradient id="radarScan" cx="50%" cy="50%" r="50%">
                  <stop offset="0%" stopColor="#6366F1" stopOpacity="0.1" />
                  <stop offset="100%" stopColor="#6366F1" stopOpacity="0" />
                </radialGradient>
                <linearGradient id="routeGradient" x1="0%" y1="0%" x2="100%" y2="100%">
                  <stop offset="0%" stopColor="#10B981" />
                  <stop offset="100%" stopColor="#6366F1" />
                </linearGradient>
                <radialGradient id="heatGlowHigh" cx="50%" cy="50%" r="50%">
                  <stop offset="0%" stopColor="#EF4444" stopOpacity="0.4" />
                  <stop offset="80%" stopColor="#F59E0B" stopOpacity="0.1" />
                  <stop offset="100%" stopColor="#EF4444" stopOpacity="0" />
                </radialGradient>
              </defs>

              {/* Grid Lines */}
              <g stroke="#27272A" strokeWidth="0.5" strokeDasharray="3 3">
                {[100, 200, 300, 400, 500].map(x => (
                  <line key={`x-${x}`} x1={x} y1="40" x2={x} y2="480" />
                ))}
                {[80, 160, 240, 320, 400, 480].map(y => (
                  <line key={`y-${y}`} x1="50" y1={y} x2="550" y2={y} />
                ))}
              </g>

              {/* Municipal Road Corridors */}
              <g stroke="#3F3F46" strokeWidth="2.5" fill="none" opacity="0.6">
                <path d="M 120 100 Q 250 200 350 450" />
                <path d="M 450 120 Q 300 240 180 380" />
                <path d="M 80 260 L 520 260" strokeDasharray="6 3" strokeWidth="1.5" />
                <path d="M 300 60 L 300 460" strokeDasharray="6 3" strokeWidth="1.5" />
              </g>

              {/* Demand Density Heatmap Layer */}
              {showHeatmap && (
                <g>
                  {MYSURU_ZONES.map(z => (
                    <circle
                      key={`heat-${z.id}`}
                      cx={z.x}
                      cy={z.y}
                      r={z.demand === 'Very High' ? 70 : z.demand === 'High' ? 55 : 35}
                      fill="url(#heatGlowHigh)"
                    />
                  ))}
                </g>
              )}

              {/* Municipal Zone Label Badges */}
              {MYSURU_ZONES.map(z => (
                <g key={z.id}>
                  <circle cx={z.x} cy={z.y} r="3" fill="#A1A1AA" />
                  <text 
                    x={z.x + 8} 
                    y={z.y + 4} 
                    fill="#71717A" 
                    fontSize="10" 
                    fontFamily="sans-serif"
                    fontWeight="500"
                  >
                    {z.name}
                  </text>
                </g>
              ))}

              {/* Active Dispatch Routes (Animated dashed vector lines) */}
              {showRoutes && ACTIVE_DISPATCH_ROUTES.map(r => (
                <g key={r.id}>
                  <line
                    x1={r.fromX}
                    y1={r.fromY}
                    x2={r.toX}
                    y2={r.toY}
                    stroke="url(#routeGradient)"
                    strokeWidth="2.5"
                    strokeDasharray="6 4"
                    strokeLinecap="round"
                    className="animate-pulse"
                  />
                  {/* Destination Customer Pin */}
                  <circle cx={r.toX} cy={r.toY} r="7" fill="#6366F1" stroke="#FFFFFF" strokeWidth="2" />
                  <text x={r.toX + 10} y={r.toY + 4} fill="#C7D2FE" fontSize="10" fontWeight="600">
                    {r.customer} ({r.eta})
                  </text>
                </g>
              ))}

              {/* Worker Marker Pins */}
              {filteredWorkers.map(w => {
                const isSelected = selectedWorker?.id === w.id;
                const statusColor = w.status === 'en_route' ? '#10B981' : w.status === 'in_progress' ? '#F59E0B' : '#3B82F6';

                return (
                  <g 
                    key={w.id} 
                    className="cursor-pointer transition-transform hover:scale-125"
                    onClick={() => setSelectedWorker(w)}
                  >
                    {/* Pulsing ring for en-route and working */}
                    {w.status !== 'online' && (
                      <circle cx={w.x} cy={w.y} r="18" fill={statusColor} opacity="0.2">
                        <animate attributeName="r" values="10;24;10" dur="2.5s" repeatCount="indefinite" />
                        <animate attributeName="opacity" values="0.3;0;0.3" dur="2.5s" repeatCount="indefinite" />
                      </circle>
                    )}

                    {/* Worker Pin Circle */}
                    <circle
                      cx={w.x}
                      cy={w.y}
                      r={isSelected ? "11" : "8"}
                      fill={statusColor}
                      stroke="#FFFFFF"
                      strokeWidth={isSelected ? "3" : "2"}
                    />

                    {/* Trade initials tag */}
                    <text
                      x={w.x}
                      y={w.y + 3}
                      fill="#FFFFFF"
                      fontSize="8"
                      fontWeight="bold"
                      textAnchor="middle"
                    >
                      {w.trade[0]}
                    </text>
                  </g>
                );
              })}
            </svg>
          </div>

          {/* Bottom Map Legend */}
          <div className="flex flex-wrap items-center justify-between text-[11px] text-zinc-400 bg-zinc-900/90 backdrop-blur-md px-4 py-2.5 rounded-xl border border-zinc-800">
            <div className="flex items-center space-x-4">
              <span className="flex items-center space-x-1.5">
                <span className="w-2.5 h-2.5 rounded-full bg-blue-500 inline-block"></span>
                <span>Online & Idle ({workers.filter(w => w.status === 'online').length})</span>
              </span>
              <span className="flex items-center space-x-1.5">
                <span className="w-2.5 h-2.5 rounded-full bg-emerald-500 inline-block"></span>
                <span>En Route to Job ({workers.filter(w => w.status === 'en_route').length})</span>
              </span>
              <span className="flex items-center space-x-1.5">
                <span className="w-2.5 h-2.5 rounded-full bg-amber-500 inline-block"></span>
                <span>On Site Working ({workers.filter(w => w.status === 'in_progress').length})</span>
              </span>
            </div>
            <span className="text-zinc-500">Tap any pin to inspect worker telemetry</span>
          </div>
        </div>

        {/* Right Inspection & Telemetry Drawer (4 Columns) */}
        <div className="lg:col-span-4 space-y-4">
          {selectedWorker ? (
            <div className="bg-white rounded-2xl border border-zinc-200/80 p-5 shadow-xs animate-fade-in space-y-4">
              <div className="flex items-center justify-between pb-3 border-b border-zinc-100">
                <div className="flex items-center space-x-3">
                  <div className="w-10 h-10 rounded-full bg-indigo-50 border border-indigo-100 flex items-center justify-center text-indigo-700 font-bold">
                    {selectedWorker.name.split(' ').map(n => n[0]).join('')}
                  </div>
                  <div>
                    <h3 className="text-sm font-bold text-zinc-900">{selectedWorker.name}</h3>
                    <span className="text-xs text-zinc-500">{selectedWorker.trade} • {selectedWorker.phone}</span>
                  </div>
                </div>
                <button 
                  onClick={() => setSelectedWorker(null)}
                  className="text-zinc-400 hover:text-zinc-600 text-xs cursor-pointer"
                >
                  ✕
                </button>
              </div>

              {/* Status pill */}
              <div className="grid grid-cols-2 gap-2 text-xs">
                <div className="bg-zinc-50 p-2.5 rounded-xl border border-zinc-100">
                  <span className="text-zinc-400 block text-[10px] uppercase font-bold">Status</span>
                  <span className="font-semibold text-zinc-800 capitalize mt-0.5 inline-block">
                    {selectedWorker.status.replace('_', ' ')}
                  </span>
                </div>
                <div className="bg-zinc-50 p-2.5 rounded-xl border border-zinc-100">
                  <span className="text-zinc-400 block text-[10px] uppercase font-bold">Speed / Battery</span>
                  <span className="font-semibold text-zinc-800 mt-0.5 inline-block">
                    {selectedWorker.speed} • {selectedWorker.battery}
                  </span>
                </div>
              </div>

              {/* Coordinates */}
              <div className="bg-zinc-50 p-3 rounded-xl border border-zinc-100 text-xs space-y-1">
                <div className="flex justify-between text-zinc-500">
                  <span>GPS Lat / Lng</span>
                  <span className="font-mono text-zinc-700">{selectedWorker.lat}, {selectedWorker.lng}</span>
                </div>
                {selectedWorker.job && (
                  <div className="flex justify-between text-zinc-500 pt-1 border-t border-zinc-200/50">
                    <span>Assigned Dispatch</span>
                    <span className="font-semibold text-indigo-600">{selectedWorker.job}</span>
                  </div>
                )}
              </div>

              {/* Quick Actions */}
              <div className="pt-2 space-y-2">
                <a
                  href={`tel:${selectedWorker.phone}`}
                  className="w-full py-2 px-3 bg-zinc-900 hover:bg-zinc-800 text-white text-xs font-semibold rounded-xl flex items-center justify-center space-x-2 transition-colors cursor-pointer"
                >
                  <Phone className="w-3.5 h-3.5" />
                  <span>Call Provider Directly</span>
                </a>
                <button
                  onClick={() => alert(`Ping sent to ${selectedWorker.name}'s device. High-priority GPS heartbeat requested.`)}
                  className="w-full py-2 px-3 bg-indigo-50 hover:bg-indigo-100 text-indigo-700 text-xs font-semibold rounded-xl flex items-center justify-center space-x-2 transition-colors border border-indigo-200 cursor-pointer"
                >
                  <Crosshair className="w-3.5 h-3.5" />
                  <span>Force GPS Recalibration</span>
                </button>
              </div>
            </div>
          ) : (
            <div className="bg-white rounded-2xl border border-zinc-200/80 p-6 text-center text-zinc-500 shadow-xs">
              <Crosshair className="w-8 h-8 text-zinc-300 mx-auto mb-2" />
              <h4 className="text-sm font-semibold text-zinc-700">No Worker Selected</h4>
              <p className="text-xs text-zinc-400 mt-1">
                Click any worker marker on the Mysuru radar map to inspect live speed, battery status, and telemetry.
              </p>
            </div>
          )}

          {/* Municipal Wards Demand Summary */}
          <div className="bg-white rounded-2xl border border-zinc-200/80 p-5 shadow-xs space-y-3">
            <h4 className="text-xs font-bold text-zinc-900 uppercase tracking-wider flex items-center space-x-1.5">
              <Zap className="w-3.5 h-3.5 text-amber-500" />
              <span>Ward Demand Surges</span>
            </h4>
            <div className="space-y-2 text-xs">
              {MYSURU_ZONES.slice(0, 4).map(z => (
                <div key={z.id} className="flex items-center justify-between p-2 rounded-lg bg-zinc-50 border border-zinc-100">
                  <div>
                    <span className="font-semibold text-zinc-800">{z.name}</span>
                    <span className="text-[10px] text-zinc-400 block">{z.workers} active providers</span>
                  </div>
                  <span className={`px-2 py-0.5 rounded font-bold text-[10px] ${
                    z.surge !== '1.0x' ? 'bg-amber-100 text-amber-800' : 'bg-zinc-100 text-zinc-600'
                  }`}>
                    {z.surge} Surge
                  </span>
                </div>
              ))}
            </div>
          </div>
        </div>

      </div>
    </div>
  );
}
