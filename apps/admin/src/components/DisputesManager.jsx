import React, { useState } from 'react';
import { 
  AlertTriangle, 
  CheckCircle2, 
  Clock, 
  RotateCcw, 
  ShieldAlert, 
  Search, 
  Filter, 
  User, 
  FileText, 
  ExternalLink,
  MessageSquare,
  DollarSign,
  ChevronRight,
  ShieldCheck,
  Ban
} from 'lucide-react';

const INITIAL_DISPUTES = [
  {
    id: 'DISP-1042',
    jobId: '#JUG-8812',
    customer: 'Naveen Deshmukh',
    customerPhone: '+91 98440 22334',
    worker: 'Harish R.',
    workerPhone: '+91 97422 55667',
    trade: 'Plumber',
    reason: 'Water pipe joint burst 2 hours after repair',
    category: 'Work Quality Issue',
    amount: 550,
    status: 'under_review',
    createdAt: 'Today, 02:15 PM',
    workerStrikes: 1,
    workerNotes: 'Used high-pressure PVC cement as standard. The main tank gate valve was faulty and pressurized above rated capacity.',
    customerNotes: 'Floor was completely flooded. I had to call another emergency plumber to shut off the main valve.',
    hasPhotoProof: true,
  },
  {
    id: 'DISP-1041',
    jobId: '#JUG-8798',
    customer: 'Divya Shenoy',
    customerPhone: '+91 99011 88990',
    worker: 'Santosh Kumar',
    workerPhone: '+91 98860 11223',
    trade: 'Electrician',
    reason: 'Demanded ₹300 extra in cash outside app billing',
    category: 'Overcharging / Policy Breach',
    amount: 450,
    status: 'escalated',
    createdAt: 'Yesterday, 06:40 PM',
    workerStrikes: 2,
    workerNotes: 'Had to replace 15 meters of burnt internal wiring which was not included in initial booking estimate.',
    customerNotes: 'Worker refused to complete job unless I handed over ₹300 in physical cash without receipt.',
    hasPhotoProof: false,
  },
  {
    id: 'DISP-1039',
    jobId: '#JUG-8760',
    customer: 'Girish Murthy',
    customerPhone: '+91 94490 33445',
    worker: 'Chandrashekar M.',
    workerPhone: '+91 94801 66778',
    trade: 'AC Technician',
    reason: 'Technician arrived 1 hour 15 minutes late without calling',
    category: 'No-Show / Extreme Delay',
    amount: 800,
    status: 'resolved',
    createdAt: '22 Sep, 11:30 AM',
    workerStrikes: 0,
    workerNotes: 'Flat tire near Hebbal outer ring road in heavy rain. Phone battery died.',
    customerNotes: 'Missed my office shift waiting for the technician.',
    hasPhotoProof: false,
  }
];

export default function DisputesManager() {
  const [disputes, setDisputes] = useState(INITIAL_DISPUTES);
  const [selectedDispute, setSelectedDispute] = useState(INITIAL_DISPUTES[0]);
  const [filterStatus, setFilterStatus] = useState('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [actionFeedback, setActionFeedback] = useState(null);

  const filteredDisputes = disputes.filter(d => {
    if (filterStatus !== 'all' && d.status !== filterStatus) return false;
    if (searchQuery.trim() !== '') {
      const q = searchQuery.toLowerCase();
      return (
        d.id.toLowerCase().includes(q) ||
        d.jobId.toLowerCase().includes(q) ||
        d.customer.toLowerCase().includes(q) ||
        d.worker.toLowerCase().includes(q)
      );
    }
    return true;
  });

  const handleAction = (actionType) => {
    if (!selectedDispute) return;

    if (actionType === 'full_refund') {
      setDisputes(prev => prev.map(d => d.id === selectedDispute.id ? { ...d, status: 'refunded' } : d));
      setSelectedDispute(prev => ({ ...prev, status: 'refunded' }));
      setActionFeedback(`₹${selectedDispute.amount} 100% Razorpay refund initiated back to ${selectedDispute.customer}'s UPI account.`);
    } else if (actionType === 'apply_strike') {
      setDisputes(prev => prev.map(d => d.id === selectedDispute.id ? { ...d, workerStrikes: d.workerStrikes + 1 } : d));
      setSelectedDispute(prev => ({ ...prev, workerStrikes: prev.workerStrikes + 1 }));
      setActionFeedback(`Penalty strike added to ${selectedDispute.worker}. Total strikes: ${selectedDispute.workerStrikes + 1}/3.`);
    } else if (actionType === 'resolve') {
      setDisputes(prev => prev.map(d => d.id === selectedDispute.id ? { ...d, status: 'resolved' } : d));
      setSelectedDispute(prev => ({ ...prev, status: 'resolved' }));
      setActionFeedback(`Dispute ${selectedDispute.id} marked as resolved without penalties.`);
    }

    setTimeout(() => setActionFeedback(null), 4000);
  };

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header Summary */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-white p-5 rounded-2xl border border-zinc-200/80 shadow-xs">
        <div>
          <div className="flex items-center space-x-2">
            <span className="p-1.5 bg-rose-50 text-rose-600 rounded-lg border border-rose-200">
              <ShieldAlert className="w-4 h-4" />
            </span>
            <h2 className="text-base font-bold text-zinc-900 tracking-tight">
              Customer Disputes & Refund Resolution Center
            </h2>
            <span className="px-2 py-0.5 text-[10px] font-semibold tracking-wider uppercase bg-amber-50 text-amber-700 rounded-md border border-amber-200">
              {disputes.filter(d => d.status === 'under_review' || d.status === 'escalated').length} Actionable
            </span>
          </div>
          <p className="text-xs text-zinc-500 mt-1">
            Audit customer complaints, review before/after photo evidence, enforce worker strike policies, and trigger Razorpay refunds.
          </p>
        </div>

        {/* Filter & Search Bar */}
        <div className="flex items-center space-x-3">
          <div className="relative">
            <Search className="w-3.5 h-3.5 text-zinc-400 absolute left-3 top-2.5" />
            <input
              type="text"
              placeholder="Search ticket, customer, worker..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-8 pr-3 py-1.5 bg-zinc-50 border border-zinc-200 rounded-xl text-xs text-zinc-800 placeholder-zinc-400 focus:outline-none focus:border-indigo-500 w-48 md:w-64"
            />
          </div>

          <select
            value={filterStatus}
            onChange={(e) => setFilterStatus(e.target.value)}
            className="px-3 py-1.5 text-xs font-medium rounded-xl border border-zinc-200 bg-white text-zinc-700 focus:outline-none cursor-pointer"
          >
            <option value="all">All Disputes</option>
            <option value="under_review">Under Review</option>
            <option value="escalated">Escalated</option>
            <option value="resolved">Resolved</option>
            <option value="refunded">Refunded</option>
          </select>
        </div>
      </div>

      {actionFeedback && (
        <div className="p-3 bg-emerald-50 border border-emerald-200 rounded-xl text-xs font-semibold text-emerald-800 flex items-center space-x-2 animate-fade-in">
          <CheckCircle2 className="w-4 h-4 text-emerald-600" />
          <span>{actionFeedback}</span>
        </div>
      )}

      {/* Main Grid: Ticket List (7 cols) + Detail Drawer (5 cols) */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        
        {/* Ticket List */}
        <div className="lg:col-span-7 bg-white rounded-2xl border border-zinc-200/80 overflow-hidden shadow-xs">
          <div className="p-4 border-b border-zinc-100 flex items-center justify-between text-xs font-bold text-zinc-400 uppercase tracking-wider">
            <span>Dispute Tickets ({filteredDisputes.length})</span>
            <span>Order Value</span>
          </div>

          <div className="divide-y divide-zinc-100">
            {filteredDisputes.map(d => {
              const isSelected = selectedDispute?.id === d.id;
              const statusBadge = 
                d.status === 'refunded' ? 'bg-purple-50 text-purple-700 border-purple-200' :
                d.status === 'escalated' ? 'bg-rose-50 text-rose-700 border-rose-200' :
                d.status === 'under_review' ? 'bg-amber-50 text-amber-700 border-amber-200' :
                'bg-emerald-50 text-emerald-700 border-emerald-200';

              return (
                <div
                  key={d.id}
                  onClick={() => setSelectedDispute(d)}
                  className={`p-4 transition-all cursor-pointer flex items-center justify-between hover:bg-zinc-50/80 ${
                    isSelected ? 'bg-indigo-50/40 border-l-4 border-indigo-600 pl-3' : ''
                  }`}
                >
                  <div className="space-y-1">
                    <div className="flex items-center space-x-2">
                      <span className="font-mono font-bold text-xs text-zinc-900">{d.id}</span>
                      <span className="text-[10px] text-zinc-400">• {d.jobId}</span>
                      <span className={`px-2 py-0.5 text-[9px] font-bold rounded-md border uppercase ${statusBadge}`}>
                        {d.status.replace('_', ' ')}
                      </span>
                    </div>

                    <h4 className="text-xs font-semibold text-zinc-800 line-clamp-1">{d.reason}</h4>
                    <span className="text-[11px] text-zinc-500 block">
                      Customer: <strong className="text-zinc-700 font-medium">{d.customer}</strong> ➔ Provider: <strong className="text-zinc-700 font-medium">{d.worker}</strong> ({d.trade})
                    </span>
                  </div>

                  <div className="text-right">
                    <span className="text-sm font-extrabold text-zinc-900">₹{d.amount}</span>
                    <span className="text-[10px] text-zinc-400 block mt-0.5">{d.createdAt}</span>
                  </div>
                </div>
              );
            })}

            {filteredDisputes.length === 0 && (
              <div className="p-8 text-center text-zinc-400 text-xs">
                No dispute cases found matching current filters.
              </div>
            )}
          </div>
        </div>

        {/* Detailed Inspection Drawer */}
        <div className="lg:col-span-5 space-y-4">
          {selectedDispute ? (
            <div className="bg-white rounded-2xl border border-zinc-200/80 p-5 shadow-xs space-y-4 animate-fade-in">
              <div className="flex items-center justify-between pb-3 border-b border-zinc-100">
                <div>
                  <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wider block">Case File</span>
                  <h3 className="text-sm font-bold text-zinc-900">{selectedDispute.id} ({selectedDispute.category})</h3>
                </div>
                <span className="text-base font-extrabold text-indigo-600">₹{selectedDispute.amount}</span>
              </div>

              {/* Stakeholders Card */}
              <div className="grid grid-cols-2 gap-3 text-xs">
                <div className="p-3 bg-zinc-50 rounded-xl border border-zinc-100">
                  <span className="text-[10px] font-bold text-zinc-400 uppercase">Customer Claim</span>
                  <span className="font-semibold text-zinc-900 block mt-0.5">{selectedDispute.customer}</span>
                  <span className="text-[11px] text-zinc-500">{selectedDispute.customerPhone}</span>
                </div>

                <div className="p-3 bg-zinc-50 rounded-xl border border-zinc-100">
                  <span className="text-[10px] font-bold text-zinc-400 uppercase">Service Provider</span>
                  <span className="font-semibold text-zinc-900 block mt-0.5">{selectedDispute.worker} ({selectedDispute.trade})</span>
                  <span className="text-[11px] text-zinc-500">Strikes: {selectedDispute.workerStrikes}/3</span>
                </div>
              </div>

              {/* Statements & Logs */}
              <div className="space-y-2 text-xs">
                <div className="p-3 bg-rose-50/50 border border-rose-100 rounded-xl">
                  <span className="font-bold text-rose-800 text-[10px] uppercase block mb-1">Customer Statement</span>
                  <p className="text-zinc-700 italic">"{selectedDispute.customerNotes}"</p>
                </div>

                <div className="p-3 bg-zinc-50 border border-zinc-200/60 rounded-xl">
                  <span className="font-bold text-zinc-700 text-[10px] uppercase block mb-1">Worker Counter-Log</span>
                  <p className="text-zinc-600 italic">"{selectedDispute.workerNotes}"</p>
                </div>
              </div>

              {/* Worker Strike Status Pill */}
              <div className="p-3 bg-amber-50/60 border border-amber-200 rounded-xl flex items-center justify-between text-xs">
                <div className="flex items-center space-x-2 text-amber-800">
                  <AlertTriangle className="w-4 h-4 text-amber-600" />
                  <span className="font-semibold">Worker Strike Level:</span>
                </div>
                <div className="flex space-x-1">
                  {[1, 2, 3].map(st => (
                    <span 
                      key={st} 
                      className={`w-4 h-4 rounded-full flex items-center justify-center text-[9px] font-bold ${
                        st <= selectedDispute.workerStrikes ? 'bg-rose-500 text-white' : 'bg-zinc-200 text-zinc-500'
                      }`}
                    >
                      {st}
                    </span>
                  ))}
                </div>
              </div>

              {/* Decision Actions */}
              <div className="pt-2 border-t border-zinc-100 space-y-2">
                <div className="grid grid-cols-2 gap-2">
                  <button
                    onClick={() => handleAction('full_refund')}
                    className="py-2.5 px-3 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl text-xs font-semibold flex items-center justify-center space-x-1.5 transition-colors cursor-pointer"
                  >
                    <RotateCcw className="w-3.5 h-3.5" />
                    <span>Issue 100% Refund</span>
                  </button>

                  <button
                    onClick={() => handleAction('resolve')}
                    className="py-2.5 px-3 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-xs font-semibold flex items-center justify-center space-x-1.5 transition-colors cursor-pointer"
                  >
                    <ShieldCheck className="w-3.5 h-3.5" />
                    <span>Dismiss Dispute</span>
                  </button>
                </div>

                <button
                  onClick={() => handleAction('apply_strike')}
                  className="w-full py-2 px-3 bg-rose-50 hover:bg-rose-100 text-rose-700 border border-rose-200 rounded-xl text-xs font-semibold flex items-center justify-center space-x-1.5 transition-colors cursor-pointer"
                >
                  <Ban className="w-3.5 h-3.5" />
                  <span>Enforce Penalty Strike on {selectedDispute.worker}</span>
                </button>
              </div>
            </div>
          ) : (
            <div className="bg-white rounded-2xl border border-zinc-200/80 p-8 text-center text-zinc-400 text-xs">
              Select a dispute ticket to inspect case details.
            </div>
          )}
        </div>

      </div>
    </div>
  );
}
