import React, { useState } from 'react';
import { 
  Zap, 
  CloudRain, 
  Moon, 
  Sparkles, 
  RotateCcw, 
  BellRing, 
  CheckCircle2, 
  Sliders, 
  DollarSign, 
  MapPin, 
  TrendingUp,
  AlertCircle
} from 'lucide-react';

const INITIAL_MYSURU_ZONES = [
  { id: 'z1', name: 'Gokulam 1st - 3rd Stage', multiplier: 1.4, baseEmergencyFee: 75, activeWorkers: 14, unfulfilledSearches: 28 },
  { id: 'z2', name: 'Kuvempunagar & TK Layout', multiplier: 1.5, baseEmergencyFee: 100, activeWorkers: 22, unfulfilledSearches: 45 },
  { id: 'z3', name: 'Hebbal Industrial Suburb', multiplier: 1.0, baseEmergencyFee: 50, activeWorkers: 8, unfulfilledSearches: 10 },
  { id: 'z4', name: 'Jayalakshmipuram & Vontikoppal', multiplier: 1.3, baseEmergencyFee: 75, activeWorkers: 16, unfulfilledSearches: 21 },
  { id: 'z5', name: 'Saraswathipuram & Tonachikoppal', multiplier: 1.1, baseEmergencyFee: 50, activeWorkers: 11, unfulfilledSearches: 14 },
  { id: 'z6', name: 'Vidyaranyapuram & JP Nagar', multiplier: 1.3, baseEmergencyFee: 75, activeWorkers: 15, unfulfilledSearches: 32 },
  { id: 'z7', name: 'Vijayanagar 1st - 4th Stage', multiplier: 1.0, baseEmergencyFee: 50, activeWorkers: 6, unfulfilledSearches: 8 },
];

export default function SurgeGeofencingHub() {
  const [zones, setZones] = useState(INITIAL_MYSURU_ZONES);
  const [activePreset, setActivePreset] = useState('custom');
  const [broadcastSent, setBroadcastSent] = useState(false);
  const [saveFeedback, setSaveFeedback] = useState(null);

  const handleMultiplierChange = (zoneId, newMultiplier) => {
    setActivePreset('custom');
    setZones(prev => prev.map(z => z.id === zoneId ? { ...z, multiplier: parseFloat(newMultiplier) } : z));
  };

  const handleFeeChange = (zoneId, newFee) => {
    setActivePreset('custom');
    setZones(prev => prev.map(z => z.id === zoneId ? { ...z, baseEmergencyFee: parseInt(newFee) } : z));
  };

  const applyPreset = (presetKey) => {
    setActivePreset(presetKey);
    if (presetKey === 'monsoon') {
      setZones(prev => prev.map(z => ({ ...z, multiplier: 1.6, baseEmergencyFee: 150 })));
      setSaveFeedback('Monsoon Downpour Mode activated (+60% surge + ₹150 hazard bonus for workers)');
    } else if (presetKey === 'night') {
      setZones(prev => prev.map(z => ({ ...z, multiplier: 1.5, baseEmergencyFee: 200 })));
      setSaveFeedback('Night Emergency Shift activated (₹200 night-shift allowance active)');
    } else if (presetKey === 'festival') {
      setZones(prev => prev.map(z => ({ ...z, multiplier: 1.8, baseEmergencyFee: 150 })));
      setSaveFeedback('Dasara / Festival Surge active (+80% peak demand surge across all wards)');
    } else if (presetKey === 'reset') {
      setZones(INITIAL_MYSURU_ZONES);
      setActivePreset('custom');
      setSaveFeedback('Surge pricing reset to standard baseline rates (1.0x).');
    }
    setTimeout(() => setSaveFeedback(null), 4000);
  };

  const handleBroadcast = () => {
    setBroadcastSent(true);
    setTimeout(() => setBroadcastSent(false), 4000);
  };

  const avgMultiplier = (zones.reduce((sum, z) => sum + z.multiplier, 0) / zones.length).toFixed(2);

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Top Banner */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-white p-5 rounded-2xl border border-zinc-200/80 shadow-xs">
        <div>
          <div className="flex items-center space-x-2">
            <span className="p-1.5 bg-amber-50 text-amber-600 rounded-lg border border-amber-200">
              <Zap className="w-4 h-4" />
            </span>
            <h2 className="text-base font-bold text-zinc-900 tracking-tight">
              Dynamic Surge Pricing & Geofencing Hub
            </h2>
            <span className="px-2 py-0.5 text-[10px] font-semibold tracking-wider uppercase bg-indigo-50 text-indigo-700 rounded-md border border-indigo-200">
              Avg Surge: {avgMultiplier}x
            </span>
          </div>
          <p className="text-xs text-zinc-500 mt-1">
            Configure municipal neighborhood multiplier matrices, activate weather hazard incentives, and broadcast surge alerts to fleet.
          </p>
        </div>

        {/* Global Broadcast Trigger */}
        <button
          onClick={handleBroadcast}
          disabled={broadcastSent}
          className="px-4 py-2 bg-gradient-to-r from-amber-500 to-orange-500 hover:from-amber-600 hover:to-orange-600 text-white text-xs font-bold rounded-xl flex items-center space-x-2 shadow-xs transition-all active:scale-98 cursor-pointer disabled:opacity-50"
        >
          <BellRing className="w-3.5 h-3.5" />
          <span>{broadcastSent ? 'Surge Push Dispatched!' : 'Broadcast Surge to Fleet'}</span>
        </button>
      </div>

      {saveFeedback && (
        <div className="p-3 bg-amber-50 border border-amber-200 rounded-xl text-xs font-semibold text-amber-900 flex items-center space-x-2 animate-fade-in">
          <CheckCircle2 className="w-4 h-4 text-amber-600" />
          <span>{saveFeedback}</span>
        </div>
      )}

      {/* Quick Seasonal / Weather Presets */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <button
          onClick={() => applyPreset('monsoon')}
          className={`p-4 rounded-2xl border text-left transition-all cursor-pointer ${
            activePreset === 'monsoon' 
              ? 'bg-blue-50/80 border-blue-300 shadow-xs' 
              : 'bg-white border-zinc-200/80 hover:bg-zinc-50'
          }`}
        >
          <CloudRain className="w-5 h-5 text-blue-600 mb-2" />
          <h4 className="text-xs font-bold text-zinc-900">Monsoon Downpour</h4>
          <span className="text-[11px] text-zinc-500 block mt-0.5">1.6x surge + ₹150 hazard pay</span>
        </button>

        <button
          onClick={() => applyPreset('night')}
          className={`p-4 rounded-2xl border text-left transition-all cursor-pointer ${
            activePreset === 'night' 
              ? 'bg-indigo-50/80 border-indigo-300 shadow-xs' 
              : 'bg-white border-zinc-200/80 hover:bg-zinc-50'
          }`}
        >
          <Moon className="w-5 h-5 text-indigo-600 mb-2" />
          <h4 className="text-xs font-bold text-zinc-900">Late Night Emergency</h4>
          <span className="text-[11px] text-zinc-500 block mt-0.5">1.5x surge + ₹200 night fee</span>
        </button>

        <button
          onClick={() => applyPreset('festival')}
          className={`p-4 rounded-2xl border text-left transition-all cursor-pointer ${
            activePreset === 'festival' 
              ? 'bg-amber-50/80 border-amber-300 shadow-xs' 
              : 'bg-white border-zinc-200/80 hover:bg-zinc-50'
          }`}
        >
          <Sparkles className="w-5 h-5 text-amber-600 mb-2" />
          <h4 className="text-xs font-bold text-zinc-900">Dasara Festival Rush</h4>
          <span className="text-[11px] text-zinc-500 block mt-0.5">1.8x maximum peak volume</span>
        </button>

        <button
          onClick={() => applyPreset('reset')}
          className="p-4 rounded-2xl border bg-white border-zinc-200/80 hover:bg-zinc-50 text-left transition-all cursor-pointer"
        >
          <RotateCcw className="w-5 h-5 text-zinc-500 mb-2" />
          <h4 className="text-xs font-bold text-zinc-900">Reset Standard Rates</h4>
          <span className="text-[11px] text-zinc-500 block mt-0.5">Revert all to 1.0x base</span>
        </button>
      </div>

      {/* Ward Multipliers Table */}
      <div className="bg-white rounded-2xl border border-zinc-200/80 overflow-hidden shadow-xs">
        <div className="p-4 border-b border-zinc-100 flex items-center justify-between text-xs font-bold text-zinc-400 uppercase tracking-wider">
          <span>Municipal Ward / Geofence Zone</span>
          <span>Demand vs. Supply</span>
          <span>Surge Multiplier</span>
          <span>Emergency Base Fee</span>
        </div>

        <div className="divide-y divide-zinc-100">
          {zones.map(z => (
            <div key={z.id} className="p-4 flex flex-col md:flex-row md:items-center justify-between gap-4 hover:bg-zinc-50/60 transition-colors">
              {/* Zone Name */}
              <div className="md:w-1/3">
                <div className="flex items-center space-x-2">
                  <MapPin className="w-3.5 h-3.5 text-zinc-400" />
                  <span className="font-semibold text-xs text-zinc-900">{z.name}</span>
                </div>
                <span className="text-[10px] text-zinc-400 block ml-5 mt-0.5">PostGIS Polygon #GEOFENCE_{z.id.toUpperCase()}</span>
              </div>

              {/* Demand status */}
              <div className="md:w-1/4">
                <div className="flex items-center space-x-2 text-xs">
                  <span className="text-zinc-600 font-medium">{z.unfulfilledSearches} requests</span>
                  <span className="text-zinc-400">/</span>
                  <span className="text-emerald-700 font-medium">{z.activeWorkers} workers</span>
                </div>
                <div className="w-32 h-1.5 bg-zinc-100 rounded-full mt-1.5 overflow-hidden">
                  <div 
                    className="h-full bg-amber-500 rounded-full" 
                    style={{ width: `${Math.min(100, (z.unfulfilledSearches / (z.activeWorkers * 2)) * 100)}%` }} 
                  />
                </div>
              </div>

              {/* Slider Multiplier */}
              <div className="md:w-1/4 flex items-center space-x-3">
                <input
                  type="range"
                  min="1.0"
                  max="2.5"
                  step="0.1"
                  value={z.multiplier}
                  onChange={(e) => handleMultiplierChange(z.id, e.target.value)}
                  className="w-28 accent-amber-500 cursor-pointer"
                />
                <span className={`px-2 py-1 rounded-md text-xs font-extrabold ${
                  z.multiplier > 1.2 ? 'bg-amber-100 text-amber-900' : 'bg-zinc-100 text-zinc-700'
                }`}>
                  {z.multiplier.toFixed(1)}x
                </span>
              </div>

              {/* Emergency Base Fee input */}
              <div className="flex items-center space-x-2">
                <span className="text-xs text-zinc-400">₹</span>
                <select
                  value={z.baseEmergencyFee}
                  onChange={(e) => handleFeeChange(z.id, e.target.value)}
                  className="px-2.5 py-1 text-xs font-semibold rounded-lg border border-zinc-200 bg-white text-zinc-800 focus:outline-none cursor-pointer"
                >
                  <option value={50}>₹50 Base</option>
                  <option value={75}>₹75 Base</option>
                  <option value={100}>₹100 Base</option>
                  <option value={150}>₹150 Base</option>
                  <option value={200}>₹200 Base</option>
                </select>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
