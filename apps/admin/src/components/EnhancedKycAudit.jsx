import React, { useState } from 'react';
import { 
  ShieldCheck, 
  ZoomIn, 
  ZoomOut, 
  RotateCw, 
  Sun, 
  CheckCircle2, 
  XCircle, 
  AlertTriangle, 
  UserCheck, 
  Send, 
  Phone, 
  FileCheck,
  Eye,
  SlidersHorizontal,
  ChevronRight
} from 'lucide-react';

const PENDING_APPLICATIONS = [
  {
    id: 'KYC-9021',
    name: 'Basavaraj S. Patil',
    phone: '+91 98450 77889',
    trade: 'Electrician',
    experienceYears: 6,
    aadhaarNumber: 'XXXX-XXXX-4912',
    aadhaarImageUrl: 'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?auto=format&fit=crop&q=80&w=600',
    selfieUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&q=80&w=300',
    submittedAt: 'Today, 04:10 PM',
    heuristics: {
      nameMatchScore: 96,
      faceMatchScore: 91,
      formatChecksumValid: true,
      blacklistClear: true,
    }
  },
  {
    id: 'KYC-9019',
    name: 'Mohammad Farooq',
    phone: '+91 97412 33441',
    trade: 'AC Technician',
    experienceYears: 4,
    aadhaarNumber: 'XXXX-XXXX-8104',
    aadhaarImageUrl: 'https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&q=80&w=600',
    selfieUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&q=80&w=300',
    submittedAt: 'Today, 01:25 PM',
    heuristics: {
      nameMatchScore: 84,
      faceMatchScore: 78,
      formatChecksumValid: true,
      blacklistClear: true,
    }
  }
];

export default function EnhancedKycAudit() {
  const [applications, setApplications] = useState(PENDING_APPLICATIONS);
  const [selectedApp, setSelectedApp] = useState(PENDING_APPLICATIONS[0]);
  const [zoomLevel, setZoomLevel] = useState(100);
  const [rotation, setRotation] = useState(0);
  const [highContrast, setHighContrast] = useState(false);
  const [actionNotice, setActionNotice] = useState(null);

  const handleApprove = () => {
    if (!selectedApp) return;
    setApplications(prev => prev.filter(a => a.id !== selectedApp.id));
    setActionNotice(`Application ${selectedApp.id} for ${selectedApp.name} approved! Onboarding SMS dispatched.`);
    setSelectedApp(applications.find(a => a.id !== selectedApp.id) || null);
    setTimeout(() => setActionNotice(null), 4000);
  };

  const handleWhatsAppRequest = () => {
    if (!selectedApp) return;
    setActionNotice(`WhatsApp notification sent to ${selectedApp.phone}: "Please upload a clearer, uncropped photo of your Aadhaar card."`);
    setTimeout(() => setActionNotice(null), 4000);
  };

  const handleReject = () => {
    if (!selectedApp) return;
    setApplications(prev => prev.filter(a => a.id !== selectedApp.id));
    setActionNotice(`Application ${selectedApp.id} rejected. Worker informed via SMS.`);
    setSelectedApp(applications.find(a => a.id !== selectedApp.id) || null);
    setTimeout(() => setActionNotice(null), 4000);
  };

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Top Banner */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-white p-5 rounded-2xl border border-zinc-200/80 shadow-xs">
        <div>
          <div className="flex items-center space-x-2">
            <span className="p-1.5 bg-emerald-50 text-emerald-600 rounded-lg border border-emerald-200">
              <ShieldCheck className="w-4 h-4" />
            </span>
            <h2 className="text-base font-bold text-zinc-900 tracking-tight">
              Automated KYC & Aadhaar Verification Audit Suite
            </h2>
            <span className="px-2 py-0.5 text-[10px] font-semibold tracking-wider uppercase bg-emerald-50 text-emerald-700 rounded-md border border-emerald-200">
              {applications.length} Pending Audit
            </span>
          </div>
          <p className="text-xs text-zinc-500 mt-1">
            High-precision document inspection lightbox, automated Verhoeff format checksum, facial match confidence, and one-click WhatsApp remediation.
          </p>
        </div>
      </div>

      {actionNotice && (
        <div className="p-3 bg-emerald-50 border border-emerald-200 rounded-xl text-xs font-semibold text-emerald-800 flex items-center space-x-2 animate-fade-in">
          <CheckCircle2 className="w-4 h-4 text-emerald-600" />
          <span>{actionNotice}</span>
        </div>
      )}

      {/* Main Grid: Queue (4 cols) + Inspection Lightbox (8 cols) */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        
        {/* Queue List (4 cols) */}
        <div className="lg:col-span-4 space-y-3">
          <div className="text-xs font-bold text-zinc-400 uppercase tracking-wider px-1">
            Pending Candidates ({applications.length})
          </div>

          {applications.map(app => {
            const isSelected = selectedApp?.id === app.id;
            return (
              <div
                key={app.id}
                onClick={() => {
                  setSelectedApp(app);
                  setZoomLevel(100);
                  setRotation(0);
                  setHighContrast(false);
                }}
                className={`p-4 rounded-2xl border transition-all cursor-pointer ${
                  isSelected 
                    ? 'bg-white border-indigo-500 shadow-md ring-2 ring-indigo-500/10' 
                    : 'bg-white border-zinc-200/80 hover:bg-zinc-50/60'
                }`}
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center space-x-3">
                    <img 
                      src={app.selfieUrl} 
                      alt={app.name} 
                      className="w-10 h-10 rounded-full object-cover border border-zinc-200" 
                    />
                    <div>
                      <h4 className="text-xs font-bold text-zinc-900">{app.name}</h4>
                      <span className="text-[11px] text-zinc-500">{app.trade} • {app.experienceYears} yrs exp</span>
                    </div>
                  </div>
                  <ChevronRight className="w-4 h-4 text-zinc-400" />
                </div>

                <div className="mt-3 pt-2.5 border-t border-zinc-100 flex items-center justify-between text-[11px]">
                  <span className="text-zinc-400">{app.aadhaarNumber}</span>
                  <span className="text-emerald-600 font-bold">
                    {app.heuristics.nameMatchScore}% Match
                  </span>
                </div>
              </div>
            );
          })}

          {applications.length === 0 && (
            <div className="p-8 bg-white rounded-2xl border border-zinc-200/80 text-center text-zinc-400 text-xs">
              All pending worker applications have been audited!
            </div>
          )}
        </div>

        {/* Inspection Lightbox (8 cols) */}
        <div className="lg:col-span-8">
          {selectedApp ? (
            <div className="bg-white rounded-2xl border border-zinc-200/80 p-5 shadow-xs space-y-5 animate-fade-in">
              
              {/* Top Details & Controls Bar */}
              <div className="flex flex-wrap items-center justify-between gap-3 pb-3 border-b border-zinc-100">
                <div>
                  <h3 className="text-sm font-bold text-zinc-900">{selectedApp.name}</h3>
                  <span className="text-xs text-zinc-500">{selectedApp.id} • {selectedApp.phone}</span>
                </div>

                {/* Lightbox Image Controls */}
                <div className="flex items-center space-x-2 bg-zinc-100 p-1 rounded-xl">
                  <button
                    onClick={() => setZoomLevel(prev => Math.min(200, prev + 25))}
                    className="p-1.5 hover:bg-white rounded-lg text-zinc-600 transition-colors cursor-pointer"
                    title="Zoom In"
                  >
                    <ZoomIn className="w-4 h-4" />
                  </button>
                  <button
                    onClick={() => setZoomLevel(prev => Math.max(75, prev - 25))}
                    className="p-1.5 hover:bg-white rounded-lg text-zinc-600 transition-colors cursor-pointer"
                    title="Zoom Out"
                  >
                    <ZoomOut className="w-4 h-4" />
                  </button>
                  <button
                    onClick={() => setRotation(prev => (prev + 90) % 360)}
                    className="p-1.5 hover:bg-white rounded-lg text-zinc-600 transition-colors cursor-pointer"
                    title="Rotate 90°"
                  >
                    <RotateCw className="w-4 h-4" />
                  </button>
                  <button
                    onClick={() => setHighContrast(prev => !prev)}
                    className={`p-1.5 rounded-lg transition-colors cursor-pointer ${
                      highContrast ? 'bg-zinc-900 text-white' : 'hover:bg-white text-zinc-600'
                    }`}
                    title="Invert / High Contrast"
                  >
                    <Sun className="w-4 h-4" />
                  </button>
                </div>
              </div>

              {/* Side-by-Side Image Canvas */}
              <div className="grid grid-cols-1 md:grid-cols-12 gap-4">
                {/* Government ID Preview (8 cols) */}
                <div className="md:col-span-8 bg-zinc-950 rounded-xl p-3 flex flex-col items-center justify-center relative overflow-hidden min-h-[260px]">
                  <img
                    src={selectedApp.aadhaarImageUrl}
                    alt="Aadhaar Document"
                    style={{
                      transform: `scale(${zoomLevel / 100}) rotate(${rotation}deg)`,
                      filter: highContrast ? 'contrast(200%) grayscale(100%)' : 'none',
                      transition: 'transform 200ms ease-out',
                    }}
                    className="max-h-56 object-contain rounded-lg shadow-lg"
                  />
                  <span className="absolute bottom-2 left-2 text-[10px] text-zinc-400 bg-zinc-900/80 px-2 py-0.5 rounded">
                    Zoom: {zoomLevel}% • Rotation: {rotation}°
                  </span>
                </div>

                {/* Profile Live Selfie (4 cols) */}
                <div className="md:col-span-4 bg-zinc-50 border border-zinc-200/80 rounded-xl p-3 flex flex-col items-center justify-center text-center">
                  <img
                    src={selectedApp.selfieUrl}
                    alt="Candidate Selfie"
                    className="w-28 h-28 rounded-full object-cover border-2 border-white shadow-sm mb-2"
                  />
                  <span className="text-xs font-bold text-zinc-900">Live Profile Photo</span>
                  <span className="text-[10px] text-zinc-400 mt-0.5">Captured at onboarding</span>
                </div>
              </div>

              {/* Automated AI & Format Heuristics Bar */}
              <div className="grid grid-cols-2 md:grid-cols-4 gap-2 pt-1 text-xs">
                <div className="p-2.5 rounded-xl bg-emerald-50/70 border border-emerald-200 flex items-center space-x-2">
                  <CheckCircle2 className="w-4 h-4 text-emerald-600" />
                  <div>
                    <span className="text-[10px] font-bold text-emerald-800 uppercase block">Name Match</span>
                    <span className="font-extrabold text-emerald-900">{selectedApp.heuristics.nameMatchScore}% Match</span>
                  </div>
                </div>

                <div className="p-2.5 rounded-xl bg-emerald-50/70 border border-emerald-200 flex items-center space-x-2">
                  <CheckCircle2 className="w-4 h-4 text-emerald-600" />
                  <div>
                    <span className="text-[10px] font-bold text-emerald-800 uppercase block">Face Match</span>
                    <span className="font-extrabold text-emerald-900">{selectedApp.heuristics.faceMatchScore}% Match</span>
                  </div>
                </div>

                <div className="p-2.5 rounded-xl bg-blue-50/70 border border-blue-200 flex items-center space-x-2">
                  <FileCheck className="w-4 h-4 text-blue-600" />
                  <div>
                    <span className="text-[10px] font-bold text-blue-800 uppercase block">Verhoeff Checksum</span>
                    <span className="font-extrabold text-blue-900">Valid Aadhaar</span>
                  </div>
                </div>

                <div className="p-2.5 rounded-xl bg-indigo-50/70 border border-indigo-200 flex items-center space-x-2">
                  <ShieldCheck className="w-4 h-4 text-indigo-600" />
                  <div>
                    <span className="text-[10px] font-bold text-indigo-800 uppercase block">Police Clearance</span>
                    <span className="font-extrabold text-indigo-900">Clear / Verified</span>
                  </div>
                </div>
              </div>

              {/* Action Buttons */}
              <div className="pt-3 border-t border-zinc-100 flex flex-wrap items-center justify-between gap-3">
                <button
                  onClick={handleWhatsAppRequest}
                  className="px-3.5 py-2.5 bg-zinc-100 hover:bg-zinc-200 text-zinc-700 text-xs font-semibold rounded-xl flex items-center space-x-1.5 transition-colors cursor-pointer"
                >
                  <Send className="w-3.5 h-3.5 text-emerald-600" />
                  <span>Request Re-upload via WhatsApp</span>
                </button>

                <div className="flex items-center space-x-2">
                  <button
                    onClick={handleReject}
                    className="px-4 py-2.5 bg-rose-50 hover:bg-rose-100 text-rose-700 border border-rose-200 text-xs font-semibold rounded-xl flex items-center space-x-1.5 transition-colors cursor-pointer"
                  >
                    <XCircle className="w-3.5 h-3.5" />
                    <span>Reject Application</span>
                  </button>

                  <button
                    onClick={handleApprove}
                    className="px-5 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold rounded-xl flex items-center space-x-1.5 shadow-xs transition-colors cursor-pointer"
                  >
                    <CheckCircle2 className="w-4 h-4" />
                    <span>Approve & Activate Fleet ID</span>
                  </button>
                </div>
              </div>

            </div>
          ) : (
            <div className="bg-white rounded-2xl border border-zinc-200/80 p-8 text-center text-zinc-400 text-xs">
              Select an applicant from the left to launch the inspection suite.
            </div>
          )}
        </div>

      </div>
    </div>
  );
}
