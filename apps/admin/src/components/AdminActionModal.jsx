import React, { useState, useEffect } from 'react';
import { AlertTriangle, CheckCircle2, Info, X } from 'lucide-react';

export default function AdminActionModal({
  isOpen,
  type = 'confirm', // 'confirm' | 'danger' | 'prompt' | 'info'
  title = 'Confirmation',
  message = '',
  inputLabel = '',
  inputPlaceholder = 'Enter details...',
  initialInputValue = '',
  confirmText = 'Confirm',
  cancelText = 'Cancel',
  onConfirm,
  onClose,
}) {
  const [inputValue, setInputValue] = useState(initialInputValue);

  useEffect(() => {
    setInputValue(initialInputValue);
  }, [initialInputValue, isOpen]);

  if (!isOpen) return null;

  const isPrompt = type === 'prompt';
  const isDanger = type === 'danger';

  const handleConfirm = () => {
    if (onConfirm) {
      onConfirm(inputValue);
    }
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-zinc-950/60 backdrop-blur-sm animate-in fade-in duration-200">
      <div 
        className="bg-white border border-zinc-200 rounded-[24px] max-w-md w-full p-6 shadow-[0_20px_60px_rgba(0,0,0,0.15)] relative space-y-5 animate-in zoom-in-95 duration-200"
        onClick={(e) => e.stopPropagation()}
      >
        <button
          onClick={onClose}
          className="absolute top-5 right-5 p-1.5 rounded-full text-zinc-400 hover:text-zinc-700 hover:bg-zinc-100 transition-colors"
        >
          <X className="w-5 h-5" />
        </button>

        <div className="flex items-start gap-4">
          <div className={`p-3 rounded-2xl flex-shrink-0 ${
            isDanger 
              ? 'bg-red-50 text-red-600 border border-red-100' 
              : type === 'info' 
              ? 'bg-blue-50 text-blue-600 border border-blue-100' 
              : 'bg-amber-50 text-amber-600 border border-amber-100'
          }`}>
            {isDanger ? (
              <AlertTriangle className="w-6 h-6" />
            ) : type === 'info' ? (
              <Info className="w-6 h-6" />
            ) : (
              <AlertTriangle className="w-6 h-6" />
            )}
          </div>

          <div className="space-y-1 pr-6">
            <h3 className="text-lg font-semibold text-zinc-950 tracking-tight">{title}</h3>
            <p className="text-sm text-zinc-500 leading-relaxed">{message}</p>
          </div>
        </div>

        {isPrompt && (
          <div className="space-y-2 pt-1">
            {inputLabel && (
              <label className="text-xs font-semibold text-zinc-700 uppercase tracking-wider block">
                {inputLabel}
              </label>
            )}
            <textarea
              autoFocus
              value={inputValue}
              onChange={(e) => setInputValue(e.target.value)}
              placeholder={inputPlaceholder}
              rows={3}
              className="w-full p-3 bg-zinc-50 border border-zinc-200 rounded-xl text-sm text-zinc-900 placeholder-zinc-400 focus:outline-none focus:border-zinc-400 focus:bg-white transition"
            />
          </div>
        )}

        <div className="flex items-center justify-end gap-3 pt-2">
          {type !== 'info' && (
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2.5 rounded-xl text-sm font-medium text-zinc-700 hover:text-zinc-900 hover:bg-zinc-100 transition active:scale-98"
            >
              {cancelText}
            </button>
          )}

          <button
            type="button"
            onClick={handleConfirm}
            className={`px-5 py-2.5 rounded-xl text-sm font-medium transition active:scale-98 shadow-sm ${
              isDanger
                ? 'bg-red-600 hover:bg-red-500 text-white'
                : 'bg-zinc-950 hover:bg-zinc-800 text-white'
            }`}
          >
            {confirmText}
          </button>
        </div>
      </div>
    </div>
  );
}
