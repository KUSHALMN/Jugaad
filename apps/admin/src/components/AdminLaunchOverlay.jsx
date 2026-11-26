import React, { useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import {
  Shield,
  Radio,
  Users,
  CheckCircle2,
  Zap,
  Video,
  ArrowRight,
  MapPin,
  Activity,
  Lock,
} from 'lucide-react';

const DURATION_MS = 10000;

const PHASES = [
  {
    badge: 'PHASE 01 • ZERO-TRUST AUTH',
    title: 'Authorizing Core Admin Session',
    subtitle: 'Verifying role-based access & encrypted session keys...',
  },
  {
    badge: 'PHASE 02 • GEO-FENCE MESH',
    title: 'Mapping Hyperlocal Dispatch Mesh',
    subtitle: 'Locking Mysuru & Bengaluru live technician radar zones...',
  },
  {
    badge: 'PHASE 03 • REALTIME TELEMETRY',
    title: 'Syncing Users, Cookies & Escrow',
    subtitle: 'Streaming device context, 30s video diagnostics & payouts...',
  },
  {
    badge: 'PHASE 04 • ALL SYSTEMS NOMINAL',
    title: 'Jugaad Command Console Ready',
    subtitle: 'Launching live operations dashboard...',
  },
];

const CITY_NODES = [
  { name: 'Vijayanagar', x: 34, y: 42, color: '#f97316', unlockAt: 15 },
  { name: 'Gokulam', x: 162, y: 46, color: '#10b981', unlockAt: 28 },
  { name: 'Kuvempunagar', x: 28, y: 146, color: '#10b981', unlockAt: 42 },
  { name: 'Indiranagar', x: 168, y: 144, color: '#f97316', unlockAt: 56 },
  { name: 'Hebbal Zone', x: 100, y: 20, color: '#f97316', unlockAt: 70 },
  { name: 'Koramangala', x: 100, y: 178, color: '#10b981', unlockAt: 82 },
];

const BOOT_LOGS = [
  { at: 5, text: 'Admin RBAC signature & session key verified' },
  { at: 20, text: 'Supabase Realtime WebSocket channel subscribed' },
  { at: 36, text: 'Mysuru & Bengaluru 15-min dispatch mesh locked' },
  { at: 52, text: '46 user activity, network & cookie profiles synced' },
  { at: 68, text: '30s Video Diagnosis & Escrow Vault 100% online' },
  { at: 85, text: 'Command Console UI ready — entering workspace' },
];

const SYSTEM_CHECKS = [
  { label: 'Supabase Realtime', icon: Radio, unlockAt: 18 },
  { label: 'Users & Cookies', icon: Users, unlockAt: 42 },
  { label: 'Escrow Vault 100%', icon: Lock, unlockAt: 64 },
  { label: '30s Video Pipeline', icon: Video, unlockAt: 82 },
];

export default function AdminLaunchOverlay({ onComplete }) {
  const [progress, setProgress] = useState(0);
  const onCompleteRef = useRef(onComplete);
  onCompleteRef.current = onComplete;

  useEffect(() => {
    const start = performance.now();
    let rafId;

    const tick = (now) => {
      const elapsed = Math.max(0, now - start);
      const pct = Math.max(0, Math.min(100, (elapsed / DURATION_MS) * 100));
      setProgress(pct);
      if (elapsed < DURATION_MS) {
        rafId = requestAnimationFrame(tick);
      } else {
        onCompleteRef.current?.();
      }
    };

    rafId = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(rafId);
  }, []);

  const phaseIndex = Math.max(0, Math.min(3, Math.floor(progress / 25)));
  const currentPhase = PHASES[phaseIndex] || PHASES[0];
  const secondsLeft = Math.max(0, Math.ceil(((100 - progress) / 100) * 10));

  const liveWorkers = Math.round((progress / 100) * 42);
  const liveUsers = Math.round((progress / 100) * 46);

  return createPortal(
    <div className="fixed inset-0 z-[200] flex items-center justify-center overflow-y-auto p-4 bg-gradient-to-br from-orange-50 via-white to-emerald-50">
      {/* Ambient pulsing orange & emerald orbs */}
      <div className="absolute -top-28 -left-28 w-[520px] h-[520px] rounded-full bg-orange-400/25 blur-[120px] animate-pulse pointer-events-none" />
      <div className="absolute -bottom-28 -right-28 w-[520px] h-[520px] rounded-full bg-emerald-400/25 blur-[120px] animate-pulse pointer-events-none" />

      {/* Subtle animated grid backdrop */}
      <div
        className="absolute inset-0 opacity-25 pointer-events-none"
        style={{
          backgroundImage:
            'linear-gradient(to right, rgba(249,115,22,0.12) 1px, transparent 1px), linear-gradient(to bottom, rgba(16,185,129,0.12) 1px, transparent 1px)',
          backgroundSize: '42px 42px',
        }}
      />

      {/* Top-right Skip pill */}
      <button
        onClick={() => onCompleteRef.current?.()}
        className="fixed top-5 right-5 z-20 inline-flex items-center gap-1.5 px-4 py-2 rounded-full bg-white/85 backdrop-blur-md border border-orange-200 text-xs font-bold text-zinc-700 hover:text-orange-600 hover:bg-white shadow-sm transition-all cursor-pointer"
      >
        <span>Skip Intro ({secondsLeft}s)</span>
        <ArrowRight className="w-3.5 h-3.5" />
      </button>

      {/* Main Holographic Glass Console */}
      <div className="relative z-10 w-full max-w-4xl mx-auto rounded-[30px] bg-white/75 backdrop-blur-2xl border border-white/95 shadow-[0_24px_80px_rgba(234,88,12,0.14),0_8px_32px_rgba(16,185,129,0.12)] p-6 sm:p-9 space-y-6">
        {/* Top Status Header */}
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 border-b border-orange-100/80 pb-5">
          <div className="flex items-center gap-3.5">
            <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-orange-500 to-emerald-600 flex items-center justify-center text-white shadow-lg shadow-orange-500/25">
              {progress >= 92 ? (
                <CheckCircle2 className="w-6 h-6 animate-bounce" />
              ) : (
                <Shield className="w-6 h-6" />
              )}
            </div>
            <div>
              <div className="inline-flex items-center gap-1.5 text-[10px] font-extrabold uppercase tracking-widest text-orange-600">
                <Zap className="w-3 h-3 text-emerald-600" />
                <span>{currentPhase.badge}</span>
              </div>
              <h2 className="text-xl sm:text-2xl font-bold text-zinc-950 tracking-tight">
                {currentPhase.title}
              </h2>
              <p className="text-xs sm:text-sm text-zinc-500">{currentPhase.subtitle}</p>
            </div>
          </div>

          <div className="inline-flex items-center gap-2 self-start sm:self-center px-3.5 py-1.5 rounded-full bg-emerald-50 border border-emerald-200 text-emerald-700 text-xs font-bold font-mono">
            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-ping" />
            <span>{Math.round(progress)}% SYNCED</span>
          </div>
        </div>

        {/* Center 2-Column Visualization: Radar Mesh + Live Telemetry Feed */}
        <div className="grid grid-cols-1 md:grid-cols-12 gap-6 items-center">
          {/* Left: Sweeping Conic Radar & City Nodes */}
          <div className="md:col-span-6 flex flex-col items-center justify-center">
            <div className="relative w-64 h-64 flex items-center justify-center">
              {/* Rotating Conic Radar Sweep */}
              <div
                className="absolute inset-2 rounded-full animate-[spin_3.2s_linear_infinite] opacity-70"
                style={{
                  background:
                    'conic-gradient(from 0deg, rgba(16,185,129,0.28) 0deg, rgba(249,115,22,0.16) 55deg, transparent 110deg, transparent 360deg)',
                }}
              />

              {/* Concentric Sonar Rings */}
              <div className="absolute inset-0 rounded-full border-2 border-dashed border-orange-300/70 animate-[spin_18s_linear_infinite]" />
              <div className="absolute inset-6 rounded-full border border-emerald-300/80" />
              <div className="absolute inset-12 rounded-full border border-orange-200/80" />
              <div className="absolute inset-16 rounded-full bg-gradient-to-tr from-orange-100/70 to-emerald-100/70 animate-pulse" />

              {/* SVG Node Links */}
              <svg viewBox="0 0 200 200" className="absolute inset-0 w-full h-full">
                {CITY_NODES.map((node) => {
                  const active = progress >= node.unlockAt;
                  return (
                    <g key={node.name}>
                      <line
                        x1="100"
                        y1="100"
                        x2={node.x}
                        y2={node.y}
                        stroke={node.color}
                        strokeWidth={active ? '1.8' : '1'}
                        strokeDasharray="4 4"
                        className={active ? 'leaflet-route-flow opacity-90' : 'opacity-25'}
                      />
                      <circle
                        cx={node.x}
                        cy={node.y}
                        r={active ? '5.5' : '3.5'}
                        fill={node.color}
                        className={active ? 'opacity-100' : 'opacity-30'}
                      />
                    </g>
                  );
                })}
              </svg>

              {/* Floating City Labels */}
              {CITY_NODES.map((node) => {
                const active = progress >= node.unlockAt;
                return (
                  <div
                    key={node.name}
                    style={{
                      left: `${(node.x / 200) * 100}%`,
                      top: `${(node.y / 200) * 100}%`,
                    }}
                    className={`absolute -translate-x-1/2 -translate-y-5 px-1.5 py-0.5 rounded-md text-[9px] font-bold whitespace-nowrap transition-all duration-300 ${
                      active
                        ? 'bg-white/95 text-zinc-800 border border-orange-200/80 shadow-xs scale-100 opacity-100'
                        : 'opacity-0 scale-75'
                    }`}
                  >
                    {node.name}
                  </div>
                );
              })}

              {/* Center Core */}
              <div className="relative z-10 w-16 h-16 rounded-2xl bg-gradient-to-br from-orange-500 to-emerald-600 flex items-center justify-center text-white shadow-xl shadow-orange-500/30">
                <MapPin className="w-7 h-7" />
              </div>
            </div>
          </div>

          {/* Right: Live Counters + Streaming Telemetry Console */}
          <div className="md:col-span-6 space-y-4">
            {/* Live KPI Counter Pair */}
            <div className="grid grid-cols-2 gap-3">
              <div className="rounded-2xl bg-orange-50/80 border border-orange-200/70 p-3.5">
                <span className="text-[10px] font-bold text-orange-600 uppercase tracking-wider block">
                  Active Partners
                </span>
                <span className="text-2xl font-extrabold text-zinc-950 font-mono">
                  {liveWorkers}
                </span>
                <span className="text-[11px] text-zinc-500 block">Online across zones</span>
              </div>
              <div className="rounded-2xl bg-emerald-50/80 border border-emerald-200/70 p-3.5">
                <span className="text-[10px] font-bold text-emerald-700 uppercase tracking-wider block">
                  Synced Users
                </span>
                <span className="text-2xl font-extrabold text-emerald-700 font-mono">
                  {liveUsers}
                </span>
                <span className="text-[11px] text-zinc-500 block">Activity &amp; cookies</span>
              </div>
            </div>

            {/* Live Boot Log Stream */}
            <div className="rounded-2xl bg-white/80 border border-zinc-200/80 p-3.5 space-y-2">
              <div className="flex items-center justify-between text-[10px] font-bold uppercase tracking-wider text-zinc-400">
                <span className="inline-flex items-center gap-1 text-zinc-600">
                  <Activity className="w-3 h-3 text-orange-500" />
                  Live Telemetry Stream
                </span>
                <span className="text-emerald-600">IST • REALTIME</span>
              </div>
              <div className="space-y-1.5">
                {BOOT_LOGS.map((log) => {
                  const visible = progress >= log.at;
                  return (
                    <div
                      key={log.text}
                      className={`flex items-center gap-2 text-xs transition-all duration-300 ${
                        visible ? 'opacity-100 translate-x-0' : 'opacity-25 translate-x-1'
                      }`}
                    >
                      <CheckCircle2
                        className={`w-3.5 h-3.5 shrink-0 ${
                          visible ? 'text-emerald-600' : 'text-zinc-300'
                        }`}
                      />
                      <span className={visible ? 'text-zinc-800 font-medium' : 'text-zinc-400'}>
                        {log.text}
                      </span>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>
        </div>

        {/* Bottom Progress Bar + System Check Chips */}
        <div className="space-y-3 pt-1">
          <div className="h-2.5 w-full rounded-full bg-zinc-100 overflow-hidden border border-zinc-200/70">
            <div
              style={{ width: `${progress}%` }}
              className="h-full rounded-full bg-gradient-to-r from-orange-500 via-amber-500 to-emerald-600 transition-[width] duration-75"
            />
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5">
            {SYSTEM_CHECKS.map((item) => {
              const Icon = item.icon;
              const ready = progress >= item.unlockAt;
              return (
                <div
                  key={item.label}
                  className={`px-3 py-2 rounded-xl border text-xs font-semibold flex items-center justify-center gap-1.5 transition-all duration-300 ${
                    ready
                      ? 'bg-emerald-50/95 border-emerald-200 text-emerald-700 shadow-xs'
                      : 'bg-white/60 border-zinc-200/70 text-zinc-400'
                  }`}
                >
                  {ready ? (
                    <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600 shrink-0" />
                  ) : (
                    <Icon className="w-3.5 h-3.5 shrink-0" />
                  )}
                  <span className="truncate">{item.label}</span>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </div>,
    document.body
  );
}
