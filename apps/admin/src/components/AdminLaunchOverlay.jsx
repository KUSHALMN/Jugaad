import React, { useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { Shield, Radio, Users, CheckCircle2, Zap, Video, ArrowRight } from 'lucide-react';

const DURATION_MS = 10000;

const PHASES = [
  {
    title: 'Authorizing Core Admin Session',
    subtitle: 'Verifying role-based access & encrypted session keys...',
  },
  {
    title: 'Mapping Hyperlocal Dispatch Mesh',
    subtitle: 'Connecting Mysuru & Bengaluru technician radar zones...',
  },
  {
    title: 'Syncing Live Telemetry & Escrow',
    subtitle: 'Streaming user activity, 30s video diagnostics & payouts...',
  },
  {
    title: 'Jugaad Command Console Ready',
    subtitle: 'All systems nominal. Launching live operations view...',
  },
];

const SYSTEM_CHECKS = [
  { label: 'Supabase Realtime', icon: Radio, unlockAt: 18 },
  { label: 'Users & Activity', icon: Users, unlockAt: 42 },
  { label: 'Escrow Vault 100%', icon: Shield, unlockAt: 65 },
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
      const elapsed = now - start;
      const pct = Math.min(100, (elapsed / DURATION_MS) * 100);
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

  const phaseIndex = Math.min(3, Math.floor(progress / 25));
  const currentPhase = PHASES[phaseIndex];
  const secondsLeft = Math.max(0, Math.ceil(((100 - progress) / 100) * 10));

  return createPortal(
    <div className="fixed inset-0 z-[200] flex items-center justify-center overflow-y-auto p-4 bg-gradient-to-br from-orange-50 via-white to-emerald-50">
      {/* Ambient pulsing orange & emerald orbs */}
      <div className="absolute -top-32 -left-32 w-[460px] h-[460px] rounded-full bg-orange-400/20 blur-[110px] animate-pulse" />
      <div className="absolute -bottom-32 -right-32 w-[460px] h-[460px] rounded-full bg-emerald-400/20 blur-[110px] animate-pulse" />

      {/* Top-right Skip button */}
      <button
        onClick={onComplete}
        className="absolute top-6 right-6 z-20 inline-flex items-center gap-1.5 px-4 py-2 rounded-full bg-white/80 backdrop-blur-md border border-orange-200/80 text-xs font-semibold text-zinc-700 hover:text-orange-600 hover:bg-white shadow-sm transition-all cursor-pointer"
      >
        <span>Skip Intro ({secondsLeft}s)</span>
        <ArrowRight className="w-3.5 h-3.5" />
      </button>

      {/* Main Frosted Glass Visualization Card */}
      <div className="relative z-10 w-full max-w-2xl mx-4 rounded-[28px] bg-white/75 backdrop-blur-2xl border border-white/90 shadow-[0_20px_70px_rgba(234,88,12,0.12),0_8px_30px_rgba(16,185,129,0.10)] p-8 sm:p-10 text-center space-y-7">
        {/* Animated Radar + Dispatch Node Mesh */}
        <div className="relative mx-auto w-56 h-56 flex items-center justify-center">
          {/* Concentric rotating/pulsing rings */}
          <div className="absolute inset-0 rounded-full border-2 border-dashed border-orange-300/70 animate-[spin_14s_linear_infinite]" />
          <div className="absolute inset-4 rounded-full border border-emerald-400/60 animate-[spin_10s_linear_infinite_reverse]" />
          <div className="absolute inset-8 rounded-full bg-gradient-to-tr from-orange-100/70 to-emerald-100/70 animate-pulse" />

          {/* SVG Hyperlocal Node Links */}
          <svg viewBox="0 0 200 200" className="absolute inset-0 w-full h-full">
            <line x1="100" y1="100" x2="36" y2="54" stroke="#f97316" strokeWidth="1.5" strokeDasharray="4 4" className="leaflet-route-flow" />
            <line x1="100" y1="100" x2="164" y2="54" stroke="#10b981" strokeWidth="1.5" strokeDasharray="4 4" className="leaflet-route-flow" />
            <line x1="100" y1="100" x2="42" y2="152" stroke="#10b981" strokeWidth="1.5" strokeDasharray="4 4" className="leaflet-route-flow" />
            <line x1="100" y1="100" x2="158" y2="152" stroke="#f97316" strokeWidth="1.5" strokeDasharray="4 4" className="leaflet-route-flow" />

            <circle cx="36" cy="54" r="5" fill="#f97316" className={progress > 20 ? 'opacity-100' : 'opacity-30'} />
            <circle cx="164" cy="54" r="5" fill="#10b981" className={progress > 40 ? 'opacity-100' : 'opacity-30'} />
            <circle cx="42" cy="152" r="5" fill="#10b981" className={progress > 60 ? 'opacity-100' : 'opacity-30'} />
            <circle cx="158" cy="152" r="5" fill="#f97316" className={progress > 80 ? 'opacity-100' : 'opacity-30'} />
          </svg>

          {/* Center Emblem */}
          <div className="relative z-10 w-20 h-20 rounded-2xl bg-gradient-to-br from-orange-500 to-emerald-600 flex items-center justify-center text-white shadow-xl shadow-orange-500/30">
            {progress >= 92 ? (
              <CheckCircle2 className="w-10 h-10 animate-bounce" />
            ) : (
              <Shield className="w-10 h-10" />
            )}
          </div>
        </div>

        {/* Phase Headline */}
        <div className="space-y-1.5">
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-orange-50 border border-orange-200 text-orange-700 text-[11px] font-bold uppercase tracking-widest">
            <Zap className="w-3 h-3 text-emerald-600" />
            <span>Jugaad Ops Command Console</span>
          </div>
          <h2 className="text-2xl sm:text-3xl font-bold text-zinc-950 tracking-tight pt-1">
            {currentPhase.title}
          </h2>
          <p className="text-sm text-zinc-500">{currentPhase.subtitle}</p>
        </div>

        {/* Progress Bar */}
        <div className="space-y-2">
          <div className="h-2.5 w-full rounded-full bg-zinc-100 overflow-hidden border border-zinc-200/70">
            <div
              style={{ width: `${progress}%` }}
              className="h-full rounded-full bg-gradient-to-r from-orange-500 via-amber-500 to-emerald-600 transition-[width] duration-75"
            />
          </div>
          <div className="flex justify-between text-xs font-mono text-zinc-500">
            <span>INITIALIZING TELEMETRY</span>
            <span className="font-bold text-emerald-700">{Math.round(progress)}%</span>
          </div>
        </div>

        {/* Sequential System Status Chips */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5 pt-1">
          {SYSTEM_CHECKS.map((item) => {
            const Icon = item.icon;
            const ready = progress >= item.unlockAt;
            return (
              <div
                key={item.label}
                className={`px-3 py-2.5 rounded-xl border text-xs font-semibold flex items-center justify-center gap-1.5 transition-all duration-300 ${
                  ready
                    ? 'bg-emerald-50/90 border-emerald-200 text-emerald-700 shadow-xs'
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
    </div>,
    document.body
  );
}
