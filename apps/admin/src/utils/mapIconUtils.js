import L from 'leaflet';

/**
 * Creates custom high-tech SVG DivIcons for Leaflet map markers.
 */

export function createWorkerVehicleIcon(worker, isSelected = false) {
  const statusColor = 
    worker.status === 'en_route' ? '#10b981' : 
    worker.status === 'in_progress' ? '#f59e0b' : '#3b82f6';

  const isEnRoute = worker.status === 'en_route';
  const heading = worker.heading || 0;
  const initial = (worker.trade && worker.trade[0]) ? worker.trade[0].toUpperCase() : 'W';

  const html = `
    <div class="relative flex items-center justify-center cursor-pointer select-none" style="width: 44px; height: 44px;">
      ${isEnRoute ? `
        <!-- Animated Radar Aura Ring for moving vehicle -->
        <div class="absolute inset-0 rounded-full vehicle-aura-pulse" style="background: ${statusColor}; opacity: 0.25;"></div>
      ` : ''}

      ${isSelected ? `
        <!-- High-visibility selection halo -->
        <div class="absolute -inset-1 rounded-full border-2 border-cyan-400 animate-ping opacity-60"></div>
      ` : ''}

      <!-- Main Marker Badge -->
      <div 
        class="relative w-8 h-8 rounded-full flex items-center justify-center shadow-lg transition-transform hover:scale-110"
        style="
          background: linear-gradient(135deg, #18181b 0%, #09090b 100%);
          border: 2.5px solid ${statusColor};
          box-shadow: 0 0 14px ${statusColor}66, 0 4px 6px rgba(0,0,0,0.4);
        "
      >
        <span class="text-xs font-black text-white tracking-wider">${initial}</span>

        ${isEnRoute ? `
          <!-- Vehicle Direction Heading Indicator -->
          <div 
            class="absolute -top-2 w-3 h-3 flex items-center justify-center transition-transform duration-300" 
            style="transform: rotate(${heading}deg);"
          >
            <svg viewBox="0 0 10 10" class="w-2.5 h-2.5" fill="${statusColor}">
              <polygon points="5,0 10,10 5,7 0,10" />
            </svg>
          </div>
        ` : ''}
      </div>

      <!-- Live Speed / Battery Tiny Tag -->
      <div 
        class="absolute -bottom-2 bg-zinc-950/90 text-[8px] font-mono text-zinc-300 px-1 py-0.2 rounded border border-zinc-800 whitespace-nowrap shadow-xs"
      >
        ${worker.status === 'en_route' ? `${worker.speed || 28}km/h` : `${worker.battery || 85}%`}
      </div>
    </div>
  `;

  return L.divIcon({
    html,
    className: 'custom-worker-div-icon',
    iconSize: [44, 44],
    iconAnchor: [22, 22],
    popupAnchor: [0, -22],
  });
}

/**
 * Creates pulsing destination pin for dispatched customers.
 */
export function createCustomerDestinationIcon(customerName, etaMins) {
  const html = `
    <div class="relative flex items-center justify-center select-none" style="width: 50px; height: 50px;">
      <!-- Expanding Radar Wave -->
      <div class="absolute inset-0 rounded-full radar-beacon-ring bg-indigo-500/40 border border-indigo-400"></div>

      <!-- Core Customer Marker -->
      <div 
        class="relative w-7 h-7 rounded-full bg-indigo-600 border-2 border-white flex items-center justify-center shadow-xl"
        style="box-shadow: 0 0 18px rgba(99, 102, 241, 0.8);"
      >
        <svg class="w-3.5 h-3.5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
        </svg>
      </div>

      <!-- ETA Pill Label -->
      <div 
        class="absolute -bottom-3 left-1/2 -translate-x-1/2 bg-indigo-950/95 text-indigo-200 text-[9px] font-bold px-2 py-0.5 rounded-full border border-indigo-500/50 whitespace-nowrap shadow-md flex items-center space-x-1"
      >
        <span>${customerName.split(' ')[0]}</span>
        <span class="text-emerald-400">• ${etaMins}m</span>
      </div>
    </div>
  `;

  return L.divIcon({
    html,
    className: 'custom-customer-div-icon',
    iconSize: [50, 50],
    iconAnchor: [25, 25],
    popupAnchor: [0, -25],
  });
}

/**
 * Creates high-contrast demand surge badge for municipal wards.
 */
export function createZoneDemandIcon(zone) {
  const isHigh = zone.demand === 'Very High' || zone.demand === 'High';
  const html = `
    <div 
      class="cursor-pointer transition-transform hover:scale-110 flex items-center space-x-1.5 px-2.5 py-1 rounded-xl shadow-lg backdrop-blur-md"
      style="
        background: rgba(15, 23, 42, 0.85);
        border: 1px solid ${zone.color}66;
        box-shadow: 0 4px 12px ${zone.color}33;
      "
    >
      <span class="w-2 h-2 rounded-full inline-block animate-pulse" style="background: ${zone.color};"></span>
      <span class="text-[11px] font-bold text-white whitespace-nowrap">${zone.name}</span>
      ${isHigh ? `
        <span 
          class="text-[9px] font-extrabold px-1.5 py-0.5 rounded-md whitespace-nowrap"
          style="background: ${zone.color}22; color: ${zone.color}; border: 1px solid ${zone.color}44;"
        >
          ${zone.surge}
        </span>
      ` : ''}
    </div>
  `;

  return L.divIcon({
    html,
    className: 'custom-zone-div-icon',
    iconSize: [120, 28],
    iconAnchor: [60, 14],
  });
}
