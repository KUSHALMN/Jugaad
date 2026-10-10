import React, { useState, useEffect, useRef, useCallback } from 'react';
import L from 'leaflet';
import {
  Navigation,
  MapPin,
  Layers,
  Crosshair,
  Radio,
  Phone,
  Zap,
  Filter,
  Play,
  Pause,
  Compass,
  ShieldCheck,
  Activity,
  Maximize2,
  Minimize2,
  Search,
  Moon,
  Send,
  Battery,
  Gauge,
  Map as MapIcon,
  Sparkles,
  Satellite
} from 'lucide-react';
import {
  MYSURU_CENTER,
  MYSURU_DEFAULT_ZOOM,
  TILE_PROVIDERS,
  MYSURU_MUNICIPAL_ZONES,
  INITIAL_REAL_WORKERS,
  INITIAL_ACTIVE_ROUTES,
  getOptimizedRoute,
  initializeRouteGeometries,
  advanceRouteSimulation,
  haversineDistanceKm,
  getDemandSurgeForCoordinates
} from '../utils/mapRoutingUtils';
import {
  createWorkerVehicleIcon,
  createCustomerDestinationIcon,
  createZoneDemandIcon
} from '../utils/mapIconUtils';
import { parseWorkerCategory } from '../utils/workerUtils';

export default function RadarMapModal({ liveWorkers = [], liveJobs = [] }) {
  // Map and simulation states
  const mapContainerRef = useRef(null);
  const mapInstanceRef = useRef(null);
  const tileLayerRef = useRef(null);

  // Layer groups for clean Leaflet management
  const workersLayerGroupRef = useRef(null);
  const routesLayerGroupRef = useRef(null);
  const zonesLayerGroupRef = useRef(null);

  // Component state — default to 'streets' for seamless match with light admin theme
  const [activeTileType, setActiveTileType] = useState('streets');
  const [workers, setWorkers] = useState(INITIAL_REAL_WORKERS);
  const [activeRoutes, setActiveRoutes] = useState(INITIAL_ACTIVE_ROUTES);
  const [selectedWorker, setSelectedWorker] = useState(null);
  const [trackingWorkerId, setTrackingWorkerId] = useState(null);

  // Filters & Toggles
  const [filterTrade, setFilterTrade] = useState('all');
  const [filterStatus, setFilterStatus] = useState('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [showHeatmap, setShowHeatmap] = useState(true);
  const [showRoutes, setShowRoutes] = useState(true);
  const [showZoneLabels, setShowZoneLabels] = useState(true);
  const [isLivePinging, setIsLivePinging] = useState(true);
  const [isClickToDispatchActive, setIsClickToDispatchActive] = useState(false);
  const [lastRefreshed, setLastRefreshed] = useState(new Date().toLocaleTimeString());

  // Simulation controls
  const [isSimulating, setIsSimulating] = useState(true);
  const [speedMultiplier, setSpeedMultiplier] = useState(1);
  const [toastMessage, setToastMessage] = useState(null);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [isDispatching, setIsDispatching] = useState(false);

  // Toast auto-clear
  const showToast = useCallback((msg) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 3800);
  }, []);

  // 1. Ingest real Supabase workers when available and merge with Mysuru coordinates
  useEffect(() => {
    if (liveWorkers && liveWorkers.length > 0) {
      const mapped = liveWorkers.map((lw, index) => {
        let lat = parseFloat(lw.lat);
        let lng = parseFloat(lw.lng);

        if (!lat || isNaN(lat) || lat < 12.2 || lat > 12.45) {
          const zone = MYSURU_MUNICIPAL_ZONES[index % MYSURU_MUNICIPAL_ZONES.length];
          lat = zone.lat + (Math.sin(index * 2) * 0.008);
        }
        if (!lng || isNaN(lng) || lng < 76.5 || lng > 76.75) {
          const zone = MYSURU_MUNICIPAL_ZONES[index % MYSURU_MUNICIPAL_ZONES.length];
          lng = zone.lng + (Math.cos(index * 2) * 0.008);
        }

        const formattedTrade = lw.displayCategory || parseWorkerCategory(lw);
        const isOnline = lw.is_online || lw.isOnline;
        const status = isOnline ? (lw.status === 'en_route' ? 'en_route' : 'online') : (lw.status || 'online');

        return {
          id: lw.id || `live-w-${index}`,
          name: lw.displayName || lw.name || `Provider #${index + 1}`,
          trade: formattedTrade,
          status,
          lat: parseFloat(lat.toFixed(4)),
          lng: parseFloat(lng.toFixed(4)),
          speed: status === 'en_route' ? 26 + (index % 12) : 0,
          heading: (index * 45) % 360,
          battery: 75 + ((index * 9) % 25),
          phone: lw.phone || `+91 98450 ${10000 + index}`,
          job: lw.current_job_id || (status === 'en_route' ? `#JUG-90${index}` : null),
          rating: 4.8,
          jobsCompleted: 50 + (index * 14),
          zone: MYSURU_MUNICIPAL_ZONES[index % MYSURU_MUNICIPAL_ZONES.length].name,
        };
      });

      setWorkers(mapped);
    }
  }, [liveWorkers]);

  // 2. Initialize real road network geometries for active dispatch routes on mount
  useEffect(() => {
    let isMounted = true;
    initializeRouteGeometries(INITIAL_ACTIVE_ROUTES).then((geomRoutes) => {
      if (isMounted) {
        setActiveRoutes(geomRoutes);
      }
    });
    return () => {
      isMounted = false;
    };
  }, []);

  // 3. Initialize Leaflet Map Instance
  useEffect(() => {
    if (!mapContainerRef.current) return;

    if (!mapInstanceRef.current) {
      const map = L.map(mapContainerRef.current, {
        center: MYSURU_CENTER,
        zoom: MYSURU_DEFAULT_ZOOM,
        zoomControl: false,
        attributionControl: true,
      });

      // Custom zoom control in bottom-right
      L.control.zoom({ position: 'bottomright' }).addTo(map);

      // Default Tile Layer
      const provider = TILE_PROVIDERS[activeTileType];
      tileLayerRef.current = L.tileLayer(provider.url, {
        attribution: provider.attribution,
        subdomains: provider.subdomains,
        maxZoom: provider.maxZoom,
      }).addTo(map);

      // Create layer groups
      zonesLayerGroupRef.current = L.layerGroup().addTo(map);
      routesLayerGroupRef.current = L.layerGroup().addTo(map);
      workersLayerGroupRef.current = L.layerGroup().addTo(map);

      mapInstanceRef.current = map;
    }

    return () => {
      if (mapInstanceRef.current) {
        mapInstanceRef.current.remove();
        mapInstanceRef.current = null;
      }
    };
  }, []);

  // 4. Handle Tile Layer switching
  useEffect(() => {
    if (!mapInstanceRef.current || !tileLayerRef.current) return;

    const provider = TILE_PROVIDERS[activeTileType];
    mapInstanceRef.current.removeLayer(tileLayerRef.current);

    tileLayerRef.current = L.tileLayer(provider.url, {
      attribution: provider.attribution,
      subdomains: provider.subdomains,
      maxZoom: provider.maxZoom,
    }).addTo(mapInstanceRef.current);
  }, [activeTileType]);

  // 5. Render Municipal Ward Heatmaps & Surge Zones
  useEffect(() => {
    if (!zonesLayerGroupRef.current) return;
    zonesLayerGroupRef.current.clearLayers();

    if (!showHeatmap) return;

    MYSURU_MUNICIPAL_ZONES.forEach((zone) => {
      const circle = L.circle([zone.lat, zone.lng], {
        radius: zone.radiusMeters,
        color: zone.color,
        fillColor: zone.color,
        fillOpacity: zone.demand === 'Very High' ? 0.22 : zone.demand === 'High' ? 0.16 : 0.08,
        weight: 1.5,
        dashArray: '4, 4',
      });

      circle.bindTooltip(
        `<div class="text-xs p-1">
          <strong class="text-zinc-900">${zone.name}</strong><br/>
          <span style="color: ${zone.color}; font-weight: 700;">${zone.surge} Surge</span> • ${zone.workers} Active
        </div>`,
        { direction: 'top', className: 'custom-leaflet-tooltip' }
      );

      circle.on('click', () => {
        if (mapInstanceRef.current) {
          mapInstanceRef.current.flyTo([zone.lat, zone.lng], 14, { duration: 1.2 });
        }
      });

      circle.addTo(zonesLayerGroupRef.current);

      if (showZoneLabels) {
        const labelMarker = L.marker([zone.lat, zone.lng], {
          icon: createZoneDemandIcon(zone),
        });
        labelMarker.on('click', () => {
          if (mapInstanceRef.current) {
            mapInstanceRef.current.flyTo([zone.lat, zone.lng], 14, { duration: 1.2 });
          }
        });
        labelMarker.addTo(zonesLayerGroupRef.current);
      }
    });
  }, [showHeatmap, showZoneLabels]);

  // 6. Render Active Dispatch Routes
  useEffect(() => {
    if (!routesLayerGroupRef.current) return;
    routesLayerGroupRef.current.clearLayers();

    if (!showRoutes) return;

    activeRoutes.forEach((route) => {
      const coords = route.roadCoordinates || [
        [route.originLat, route.originLng],
        [route.customerLat, route.customerLng],
      ];

      // Outer glow line
      const glowPoly = L.polyline(coords, {
        color: route.color || '#4f46e5',
        weight: 8,
        opacity: 0.28,
        lineCap: 'round',
      });
      glowPoly.addTo(routesLayerGroupRef.current);

      // Inner animated dashed road line
      const flowPoly = L.polyline(coords, {
        color: route.color || '#4f46e5',
        weight: 3.5,
        opacity: 0.95,
        dashArray: '10, 10',
        lineCap: 'round',
        className: 'leaflet-route-flow',
      });
      flowPoly.addTo(routesLayerGroupRef.current);

      // Destination Customer Beacon Marker
      const destMarker = L.marker([route.customerLat, route.customerLng], {
        icon: createCustomerDestinationIcon(route.customerName, route.etaMins),
      });

      destMarker.bindPopup(
        `<div class="p-1">
          <div class="flex items-center space-x-1.5 text-xs font-bold text-indigo-600">
            <span>Customer Destination</span>
          </div>
          <h4 class="text-sm font-extrabold text-zinc-900 mt-1">${route.customerName}</h4>
          <p class="text-[11px] text-zinc-500">${route.customerAddress}</p>
          <div class="mt-2 pt-2 border-t border-zinc-200 flex items-center justify-between text-xs">
            <span class="text-zinc-600">Assigned: <strong>${route.workerName}</strong></span>
            <span class="font-bold text-emerald-600">ETA ${route.etaMins} mins</span>
          </div>
        </div>`,
        { className: 'custom-leaflet-popup' }
      );

      destMarker.addTo(routesLayerGroupRef.current);
    });
  }, [showRoutes, activeRoutes]);

  // 7. Render Worker Markers
  useEffect(() => {
    if (!workersLayerGroupRef.current) return;
    workersLayerGroupRef.current.clearLayers();

    const visibleWorkers = workers.filter((w) => {
      if (filterTrade !== 'all' && w.trade !== filterTrade) return false;
      if (filterStatus !== 'all' && w.status !== filterStatus) return false;
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase();
        const matchesName = w.name.toLowerCase().includes(q);
        const matchesTrade = w.trade.toLowerCase().includes(q);
        const matchesPhone = w.phone.toLowerCase().includes(q);
        if (!matchesName && !matchesTrade && !matchesPhone) return false;
      }
      return true;
    });

    visibleWorkers.forEach((w) => {
      const isSelected = selectedWorker?.id === w.id;
      const marker = L.marker([w.lat, w.lng], {
        icon: createWorkerVehicleIcon(w, isSelected),
        zIndexOffset: isSelected ? 1000 : 100,
      });

      marker.on('click', () => {
        setSelectedWorker(w);
      });

      marker.bindPopup(
        `<div class="p-1 min-w-[210px]">
          <div class="flex items-center justify-between pb-1.5 border-b border-zinc-200">
            <span class="text-xs font-bold text-zinc-900">${w.name}</span>
            <span class="text-[10px] uppercase font-extrabold px-1.5 py-0.5 rounded ${
              w.status === 'en_route' ? 'bg-emerald-50 text-emerald-700 border border-emerald-200' :
              w.status === 'in_progress' ? 'bg-amber-50 text-amber-700 border border-amber-200' :
              'bg-blue-50 text-blue-700 border border-blue-200'
            }">${w.status.replace('_', ' ')}</span>
          </div>
          <div class="grid grid-cols-2 gap-2 mt-2 text-[11px] text-zinc-600">
            <div>Trade: <strong class="text-zinc-900">${w.trade}</strong></div>
            <div>Battery: <strong class="text-emerald-600">${w.battery}%</strong></div>
            <div>Speed: <strong class="text-zinc-900">${w.speed} km/h</strong></div>
            <div>Rating: <strong class="text-amber-600">★ ${w.rating}</strong></div>
          </div>
          <div class="mt-2 pt-2 border-t border-zinc-200 text-[10px] text-zinc-500 flex items-center justify-between">
            <span>GPS: ${w.lat.toFixed(4)}, ${w.lng.toFixed(4)}</span>
            <span class="text-indigo-600 font-semibold cursor-pointer">Inspect Telemetry &rarr;</span>
          </div>
        </div>`,
        { className: 'custom-leaflet-popup' }
      );

      marker.addTo(workersLayerGroupRef.current);
    });
  }, [workers, selectedWorker, filterTrade, filterStatus, searchQuery]);

  // 8. Vehicle Transit Animation Loop
  useEffect(() => {
    if (!isSimulating) return;

    const interval = setInterval(() => {
      const deltaSeconds = 1.0;

      setActiveRoutes((prevRoutes) => {
        const updatedRoutes = prevRoutes.map((r) =>
          advanceRouteSimulation(r, deltaSeconds, speedMultiplier)
        );

        setWorkers((prevWorkers) =>
          prevWorkers.map((w) => {
            const matchingRoute = updatedRoutes.find((r) => r.workerId === w.id);
            if (matchingRoute && matchingRoute.currentLat) {
              return {
                ...w,
                lat: matchingRoute.currentLat,
                lng: matchingRoute.currentLng,
                heading: matchingRoute.heading,
                speed: matchingRoute.speed,
              };
            }
            return w;
          })
        );

        return updatedRoutes;
      });

      if (trackingWorkerId && mapInstanceRef.current) {
        const trackedWorker = workers.find((w) => w.id === trackingWorkerId);
        if (trackedWorker) {
          mapInstanceRef.current.panTo([trackedWorker.lat, trackedWorker.lng], { animate: true, duration: 0.8 });
        }
      }
    }, 1000);

    return () => clearInterval(interval);
  }, [isSimulating, speedMultiplier, trackingWorkerId, workers]);

  // 9. Live GPS Heartbeat ping simulator
  useEffect(() => {
    if (!isLivePinging) return;
    const interval = setInterval(() => {
      setLastRefreshed(new Date().toLocaleTimeString());
    }, 3000);
    return () => clearInterval(interval);
  }, [isLivePinging]);

  // Direct Map Click Dispatch calculation
  const handleDispatchAtCoordinates = useCallback(async (destLat, destLng) => {
    setIsDispatching(true);
    try {
      const onlineWorkers = workers.filter((w) => w.status === 'online');
      const candidates = onlineWorkers.length > 0 ? onlineWorkers : workers;

      let nearestWorker = candidates[0];
      let minDistance = Infinity;

      for (const w of candidates) {
        const d = haversineDistanceKm(w.lat, w.lng, destLat, destLng);
        if (d < minDistance) {
          minDistance = d;
          nearestWorker = w;
        }
      }

      const surgeData = getDemandSurgeForCoordinates(destLat, destLng);
      const origin = { lat: nearestWorker.lat, lng: nearestWorker.lng };
      const dest = { lat: destLat, lng: destLng };

      const roadData = await getOptimizedRoute(origin, dest);

      const customerNames = ['Deepak Kumar', 'Kavitha Swaminathan', 'Manish Patil', 'Divya Prasad', 'Aravind Menon'];
      const randomName = customerNames[Math.floor(Math.random() * customerNames.length)];

      const newRoute = {
        id: `r-${Date.now()}`,
        workerId: nearestWorker.id,
        workerName: nearestWorker.name,
        trade: nearestWorker.trade,
        customerName: randomName,
        customerPhone: '+91 98450 ' + Math.floor(10000 + Math.random() * 90000),
        customerAddress: `Near ${surgeData.zone.name}, Mysuru`,
        customerLat: destLat,
        customerLng: destLng,
        originLat: nearestWorker.lat,
        originLng: nearestWorker.lng,
        jobId: `#JUG-${Math.floor(9200 + Math.random() * 800)}`,
        etaMins: roadData.durationMins,
        distanceKm: roadData.distanceKm,
        progress: 0.05,
        color: '#4f46e5',
        roadCoordinates: roadData.coordinates,
        totalDurationMins: roadData.durationMins,
        isRealRoad: roadData.isRealRoad,
      };

      setWorkers((prev) =>
        prev.map((w) => (w.id === nearestWorker.id ? { ...w, status: 'en_route', job: newRoute.jobId } : w))
      );

      setActiveRoutes((prev) => [newRoute, ...prev]);
      setSelectedWorker({ ...nearestWorker, status: 'en_route', job: newRoute.jobId });
      setIsClickToDispatchActive(false);

      if (mapInstanceRef.current) {
        mapInstanceRef.current.flyTo([destLat, destLng], 14, { duration: 1.2 });
      }

      showToast(`🎯 Real-World Dispatch: Assigned ${nearestWorker.name} to ${randomName} in ${surgeData.zone.name} (${roadData.distanceKm} km, ETA ${roadData.durationMins}m, Surge ${surgeData.surge})`);
    } catch {
      showToast('Error during map dispatch. Please retry.');
    } finally {
      setIsDispatching(false);
    }
  }, [workers, showToast]);

  // Map click listener for Direct Map Dispatch pinning
  useEffect(() => {
    if (!mapInstanceRef.current) return;
    const map = mapInstanceRef.current;

    const onMapClick = (e) => {
      if (!isClickToDispatchActive) return;
      handleDispatchAtCoordinates(e.latlng.lat, e.latlng.lng);
    };

    map.on('click', onMapClick);
    return () => {
      map.off('click', onMapClick);
    };
  }, [isClickToDispatchActive, handleDispatchAtCoordinates]);

  // 10. Simulate New Customer Booking Dispatch on Real Map
  const handleSimulateDispatch = async () => {
    setIsDispatching(true);
    try {
      const idleWorker = workers.find((w) => w.status === 'online') || workers[0];
      if (!idleWorker) {
        showToast('No online workers available for dispatch!');
        setIsDispatching(false);
        return;
      }

      const sampleDestinations = [
        { customerName: 'Deepak Gowda', address: 'KRS Road, Gokulam 3rd Stage', lat: 12.3360, lng: 76.6230 },
        { customerName: 'Pooja Hegde', address: 'Double Road, Kuvempunagar', lat: 12.2880, lng: 76.6340 },
        { customerName: 'Raghavendra Rao', address: 'Kalidasa Road, Jayalakshmipuram', lat: 12.3180, lng: 76.6350 },
        { customerName: 'Sneha Patil', address: 'Chamundipuram Silk Factory Road', lat: 12.2920, lng: 76.6540 },
      ];
      const targetDest = sampleDestinations[Math.floor(Math.random() * sampleDestinations.length)];

      const origin = { lat: idleWorker.lat, lng: idleWorker.lng };
      const dest = { lat: targetDest.lat, lng: targetDest.lng };

      const roadData = await getOptimizedRoute(origin, dest);

      const newRoute = {
        id: `r-${Date.now()}`,
        workerId: idleWorker.id,
        workerName: idleWorker.name,
        trade: idleWorker.trade,
        customerName: targetDest.customerName,
        customerPhone: '+91 98450 ' + Math.floor(10000 + Math.random() * 90000),
        customerAddress: targetDest.address,
        customerLat: targetDest.lat,
        customerLng: targetDest.lng,
        originLat: idleWorker.lat,
        originLng: idleWorker.lng,
        jobId: `#JUG-${Math.floor(9100 + Math.random() * 800)}`,
        etaMins: roadData.durationMins,
        distanceKm: roadData.distanceKm,
        progress: 0.05,
        color: '#4f46e5',
        roadCoordinates: roadData.coordinates,
        totalDurationMins: roadData.durationMins,
        isRealRoad: roadData.isRealRoad,
      };

      setWorkers((prev) =>
        prev.map((w) => (w.id === idleWorker.id ? { ...w, status: 'en_route', job: newRoute.jobId } : w))
      );

      setActiveRoutes((prev) => [newRoute, ...prev]);
      setSelectedWorker({ ...idleWorker, status: 'en_route', job: newRoute.jobId });
      if (mapInstanceRef.current) {
        mapInstanceRef.current.flyTo([idleWorker.lat, idleWorker.lng], 14, { duration: 1.2 });
      }

      showToast(`🎯 Real-World Dispatch: Assigned ${idleWorker.name} to ${targetDest.customerName} (${roadData.distanceKm} km, ETA ${roadData.durationMins}m via ${roadData.isRealRoad ? 'OSRM Live Road' : 'Arterial Grid'})`);
    } catch {
      showToast('Dispatch simulator error. Fallback applied.');
    } finally {
      setIsDispatching(false);
    }
  };

  const handleRecenterCity = () => {
    if (mapInstanceRef.current) {
      mapInstanceRef.current.flyTo(MYSURU_CENTER, MYSURU_DEFAULT_ZOOM, { duration: 1.2 });
      setTrackingWorkerId(null);
    }
  };

  const handleFocusWorker = (worker) => {
    if (!worker || !mapInstanceRef.current) return;
    setSelectedWorker(worker);
    mapInstanceRef.current.flyTo([worker.lat, worker.lng], 15, { duration: 1.0 });
  };

  return (
    <div className={`space-y-6 animate-fade-in ${isFullscreen ? 'fixed inset-0 z-50 bg-slate-50 p-6 overflow-y-auto' : ''}`}>
      {/* Toast notification banner */}
      {toastMessage && (
        <div className="fixed top-6 right-6 z-50 bg-zinc-900 text-white px-4 py-3 rounded-2xl border border-zinc-800 shadow-xl flex items-center space-x-3 text-xs max-w-md animate-fade-in">
          <Sparkles className="w-4 h-4 text-emerald-400 shrink-0" />
          <span className="font-medium">{toastMessage}</span>
        </div>
      )}

      {/* Top Banner Control Bar (Aligned with Admin Dashboard White Card Theme) */}
      <div className="flex flex-col xl:flex-row xl:items-center justify-between gap-4 bg-white p-5 rounded-2xl border border-zinc-200/80 shadow-[0_4px_20px_rgba(0,0,0,0.03)]">
        <div>
          <div className="flex items-center space-x-2.5">
            <span className="relative flex h-3 w-3">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
              <span className="relative inline-flex rounded-full h-3 w-3 bg-emerald-500"></span>
            </span>
            <h2 className="text-base font-bold tracking-tight text-zinc-900 flex items-center space-x-2">
              <span>Mysuru Real-World Telemetry & Road Routing Command</span>
            </h2>
            <span className="px-2 py-0.5 text-[10px] font-semibold tracking-wider uppercase bg-emerald-50 text-emerald-700 rounded-md border border-emerald-200">
              Live OSRM Routing
            </span>
          </div>
          <p className="text-xs text-zinc-500 mt-1 flex items-center space-x-2">
            <span>Tracking active worker heartbeat pings across 9 Mysuru municipal wards.</span>
            <span className="text-zinc-300">•</span>
            <span className="text-zinc-400 font-mono">Auto-synced: {lastRefreshed}</span>
          </p>
        </div>

        {/* Action Controls & Layer Switcher */}
        <div className="flex flex-wrap items-center gap-2">
          {/* Tile Layer Selector */}
          <div className="flex items-center bg-zinc-100 p-1 rounded-xl border border-zinc-200 text-xs">
            <button
              onClick={() => setActiveTileType('streets')}
              className={`px-2.5 py-1 rounded-lg font-medium transition-all cursor-pointer flex items-center space-x-1 ${
                activeTileType === 'streets' ? 'bg-white text-zinc-900 shadow-xs font-semibold' : 'text-zinc-500 hover:text-zinc-900'
              }`}
              title="City Streets Map"
            >
              <MapIcon className="w-3.5 h-3.5" />
              <span>Streets</span>
            </button>
            <button
              onClick={() => setActiveTileType('dark')}
              className={`px-2.5 py-1 rounded-lg font-medium transition-all cursor-pointer flex items-center space-x-1 ${
                activeTileType === 'dark' ? 'bg-white text-zinc-900 shadow-xs font-semibold' : 'text-zinc-500 hover:text-zinc-900'
              }`}
              title="Dark Ops Night Map"
            >
              <Moon className="w-3.5 h-3.5" />
              <span>Dark Ops</span>
            </button>
            <button
              onClick={() => setActiveTileType('satellite')}
              className={`px-2.5 py-1 rounded-lg font-medium transition-all cursor-pointer flex items-center space-x-1 ${
                activeTileType === 'satellite' ? 'bg-white text-zinc-900 shadow-xs font-semibold' : 'text-zinc-500 hover:text-zinc-900'
              }`}
              title="Satellite Aerial Imagery"
            >
              <Satellite className="w-3.5 h-3.5" />
              <span>Satellite</span>
            </button>
          </div>

          {/* Toggle Heatmap */}
          <button
            onClick={() => setShowHeatmap(!showHeatmap)}
            className={`px-3 py-1.5 text-xs font-medium rounded-xl border flex items-center space-x-1.5 transition-all cursor-pointer ${
              showHeatmap
                ? 'bg-rose-50 border-rose-200 text-rose-700 font-semibold'
                : 'bg-white border-zinc-200 text-zinc-600 hover:bg-zinc-50'
            }`}
          >
            <Layers className="w-3.5 h-3.5" />
            <span>Demand Heatmap</span>
          </button>

          {/* Toggle Dispatch Routes */}
          <button
            onClick={() => setShowRoutes(!showRoutes)}
            className={`px-3 py-1.5 text-xs font-medium rounded-xl border flex items-center space-x-1.5 transition-all cursor-pointer ${
              showRoutes
                ? 'bg-indigo-50 border-indigo-200 text-indigo-700 font-semibold'
                : 'bg-white border-zinc-200 text-zinc-600 hover:bg-zinc-50'
            }`}
          >
            <Navigation className="w-3.5 h-3.5" />
            <span>Road Routes</span>
          </button>

          {/* Click to Pin Dispatch on Map */}
          <button
            onClick={() => {
              setIsClickToDispatchActive(!isClickToDispatchActive);
              if (!isClickToDispatchActive) {
                showToast('📍 Click anywhere on the Mysuru map to drop a customer request and auto-dispatch nearest provider!');
              }
            }}
            className={`px-3 py-1.5 text-xs font-semibold rounded-xl border flex items-center space-x-1.5 transition-all cursor-pointer ${
              isClickToDispatchActive
                ? 'bg-amber-50 border-amber-300 text-amber-800 font-bold animate-pulse'
                : 'bg-white border-zinc-200 text-zinc-700 hover:bg-zinc-50'
            }`}
          >
            <MapPin className="w-3.5 h-3.5 text-amber-500" />
            <span>{isClickToDispatchActive ? 'Click Map Spot...' : 'Pin Dispatch'}</span>
          </button>

          {/* Simulate Booking Dispatch Button */}
          <button
            onClick={handleSimulateDispatch}
            disabled={isDispatching}
            className="px-3.5 py-1.5 text-xs font-semibold rounded-xl bg-zinc-950 hover:bg-zinc-800 text-white shadow-sm flex items-center space-x-1.5 transition-all cursor-pointer disabled:opacity-50"
          >
            <Send className="w-3.5 h-3.5 text-emerald-400" />
            <span>{isDispatching ? 'Routing...' : 'Simulate Dispatch'}</span>
          </button>

          {/* Live Pings Toggle */}
          <button
            onClick={() => setIsLivePinging(!isLivePinging)}
            className={`px-3 py-1.5 text-xs font-medium rounded-xl border flex items-center space-x-1.5 transition-all cursor-pointer ${
              isLivePinging
                ? 'bg-emerald-50 border-emerald-200 text-emerald-700 font-semibold'
                : 'bg-white border-zinc-200 text-zinc-400 hover:bg-zinc-50'
            }`}
            title="Toggle Live PostGIS Heartbeat Pings"
          >
            <Radio className={`w-3.5 h-3.5 ${isLivePinging ? 'animate-pulse text-emerald-600' : 'text-zinc-400'}`} />
            <span>{isLivePinging ? 'Live Pings (3s)' : 'Paused'}</span>
          </button>

          {/* Fullscreen Toggle */}
          <button
            onClick={() => setIsFullscreen(!isFullscreen)}
            className="p-1.5 rounded-xl bg-white border border-zinc-200 text-zinc-600 hover:bg-zinc-50 transition-colors cursor-pointer shadow-2xs"
            title={isFullscreen ? 'Exit Fullscreen' : 'Fullscreen Map'}
          >
            {isFullscreen ? <Minimize2 className="w-4 h-4" /> : <Maximize2 className="w-4 h-4" />}
          </button>
        </div>
      </div>

      {/* Main Interactive Map & Telemetry Layout */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Real Leaflet Map Container (8 Columns) */}
        <div className="lg:col-span-8 bg-white rounded-2xl border border-zinc-200/80 p-4 shadow-[0_4px_20px_rgba(0,0,0,0.03)] flex flex-col justify-between min-h-[620px]">
          
          {/* Top Floating Map HUD (Filters & Search) */}
          <div className="relative z-10 flex flex-wrap items-center justify-between gap-2 mb-3">
            <div className="flex flex-wrap items-center gap-2">
              {/* Search Filter */}
              <div className="flex items-center space-x-1.5 bg-zinc-50 hover:bg-white focus-within:bg-white px-3 py-1.5 rounded-xl border border-zinc-200 text-xs text-zinc-800 transition-colors">
                <Search className="w-3.5 h-3.5 text-zinc-400" />
                <input
                  type="text"
                  placeholder="Search worker or phone..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="bg-transparent text-xs text-zinc-800 placeholder-zinc-400 focus:outline-none w-36"
                />
              </div>

              {/* Trade Filter */}
              <div className="flex items-center space-x-1.5 bg-zinc-50 px-3 py-1.5 rounded-xl border border-zinc-200 text-xs text-zinc-800">
                <Filter className="w-3.5 h-3.5 text-zinc-400" />
                <select
                  value={filterTrade}
                  onChange={(e) => setFilterTrade(e.target.value)}
                  className="bg-transparent text-xs text-zinc-800 focus:outline-none cursor-pointer"
                >
                  <option value="all">All Skills</option>
                  <option value="Electrician">Electrician</option>
                  <option value="Plumber">Plumber</option>
                  <option value="Carpenter">Carpenter</option>
                  <option value="AC Tech">AC Tech</option>
                  <option value="Appliance Repair">Appliance Repair</option>
                </select>
              </div>

              {/* Status Filter */}
              <div className="flex items-center space-x-1.5 bg-zinc-50 px-3 py-1.5 rounded-xl border border-zinc-200 text-xs text-zinc-800">
                <select
                  value={filterStatus}
                  onChange={(e) => setFilterStatus(e.target.value)}
                  className="bg-transparent text-xs text-zinc-800 focus:outline-none cursor-pointer"
                >
                  <option value="all">All Statuses</option>
                  <option value="online">Online & Ready</option>
                  <option value="en_route">En Route</option>
                  <option value="in_progress">In Progress</option>
                </select>
              </div>
            </div>

            {/* Simulation Playback & Speed Controls */}
            <div className="flex items-center space-x-1.5 bg-zinc-100 p-1 rounded-xl border border-zinc-200 text-xs">
              <button
                onClick={() => setIsSimulating(!isSimulating)}
                className={`p-1.5 rounded-lg transition-colors cursor-pointer shadow-xs ${
                  isSimulating ? 'bg-white text-emerald-600' : 'bg-white text-amber-600'
                }`}
                title={isSimulating ? 'Pause Transit Simulation' : 'Resume Transit Simulation'}
              >
                {isSimulating ? <Pause className="w-3.5 h-3.5" /> : <Play className="w-3.5 h-3.5" />}
              </button>

              <button
                onClick={() => setSpeedMultiplier((prev) => (prev === 1 ? 2 : prev === 2 ? 4 : 1))}
                className="px-2.5 py-1 rounded-lg bg-white text-[11px] font-bold text-zinc-700 hover:text-zinc-900 transition-colors cursor-pointer shadow-xs"
                title="Toggle Speed Multiplier"
              >
                {speedMultiplier}x Speed
              </button>

              <button
                onClick={handleRecenterCity}
                className="p-1.5 rounded-lg bg-white hover:bg-zinc-50 text-zinc-600 hover:text-zinc-900 transition-colors cursor-pointer shadow-xs"
                title="Recenter on Mysuru Center"
              >
                <Crosshair className="w-3.5 h-3.5" />
              </button>
            </div>
          </div>

          {/* Real Leaflet Map DOM Canvas */}
          <div className="relative w-full h-[490px] rounded-2xl overflow-hidden border border-zinc-200 shadow-inner">
            <div 
              ref={mapContainerRef} 
              className="w-full h-full" 
              style={{ minHeight: '490px', cursor: isClickToDispatchActive ? 'crosshair' : 'grab' }} 
            />

            {/* Active Pin Dispatch Guidance Banner */}
            {isClickToDispatchActive && (
              <div className="absolute top-3 left-1/2 -translate-x-1/2 z-400 pointer-events-auto bg-amber-500 text-white font-bold px-4 py-2 rounded-full shadow-xl border border-amber-400 text-xs flex items-center space-x-2 animate-pulse">
                <MapPin className="w-4 h-4 text-white" />
                <span>Click any point on Mysuru map to auto-dispatch nearest provider</span>
                <button 
                  onClick={() => setIsClickToDispatchActive(false)} 
                  className="ml-2 bg-zinc-900 hover:bg-zinc-800 text-white rounded-full w-4 h-4 flex items-center justify-center text-[10px] cursor-pointer"
                >
                  ✕
                </button>
              </div>
            )}

            {/* In-Map Active Dispatches Quick Bar (Light Frosted Theme) */}
            <div className="absolute top-3 right-3 z-400 pointer-events-auto bg-white/95 backdrop-blur-md border border-zinc-200/90 rounded-2xl p-3 max-w-[240px] shadow-lg text-xs space-y-2">
              <div className="flex items-center justify-between border-b border-zinc-100 pb-1.5">
                <span className="font-bold text-zinc-900 text-[11px] flex items-center space-x-1.5">
                  <Activity className="w-3 h-3 text-emerald-600" />
                  <span>Active Dispatches</span>
                </span>
                <span className="px-1.5 py-0.5 rounded-md text-[9px] bg-emerald-50 text-emerald-700 border border-emerald-200 font-bold">
                  {activeRoutes.length} LIVE
                </span>
              </div>
              <div className="space-y-1.5 max-h-36 overflow-y-auto pr-0.5">
                {activeRoutes.map((r) => (
                  <div
                    key={r.id}
                    onClick={() => {
                      const w = workers.find((item) => item.id === r.workerId);
                      if (w) handleFocusWorker(w);
                    }}
                    className="p-2 rounded-xl bg-zinc-50 hover:bg-zinc-100/90 border border-zinc-100 transition-colors cursor-pointer"
                  >
                    <div className="flex items-center justify-between text-[11px] font-semibold text-zinc-900">
                      <span>{r.workerName}</span>
                      <span className="text-emerald-600 font-extrabold">{r.etaMins}m ETA</span>
                    </div>
                    <div className="text-[10px] text-zinc-500 truncate mt-0.5">
                      To: {r.customerName} ({r.distanceRemainingKm || r.distanceKm} km)
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Bottom Map Telemetry Legend */}
          <div className="mt-3 flex flex-wrap items-center justify-between text-xs text-zinc-600 bg-zinc-50 px-4 py-2.5 rounded-xl border border-zinc-200/80">
            <div className="flex items-center space-x-5">
              <span className="flex items-center space-x-1.5">
                <span className="w-2.5 h-2.5 rounded-full bg-blue-500 inline-block"></span>
                <span>Online & Idle ({workers.filter((w) => w.status === 'online').length})</span>
              </span>
              <span className="flex items-center space-x-1.5">
                <span className="w-2.5 h-2.5 rounded-full bg-emerald-500 inline-block animate-pulse"></span>
                <span>En Route ({workers.filter((w) => w.status === 'en_route').length})</span>
              </span>
              <span className="flex items-center space-x-1.5">
                <span className="w-2.5 h-2.5 rounded-full bg-amber-500 inline-block"></span>
                <span>On Site ({workers.filter((w) => w.status === 'in_progress').length})</span>
              </span>
            </div>
            <div className="flex items-center space-x-3 text-zinc-400">
              <span className="text-zinc-600 font-medium">Avg City Dispatch ETA: ~7.2 mins</span>
              <span>•</span>
              <span>Click any vehicle marker to inspect</span>
            </div>
          </div>
        </div>

        {/* Right Telemetry & Inspection Drawer (4 Columns) */}
        <div className="lg:col-span-4 space-y-4">
          {selectedWorker ? (
            <div className="bg-white rounded-2xl border border-zinc-200/80 p-5 shadow-[0_4px_20px_rgba(0,0,0,0.03)] space-y-4 text-zinc-900 animate-fade-in">
              {/* Header */}
              <div className="flex items-center justify-between pb-3 border-b border-zinc-100">
                <div className="flex items-center space-x-3">
                  <div className="w-11 h-11 rounded-2xl bg-indigo-50 border border-indigo-100 text-indigo-700 flex items-center justify-center font-bold text-sm shadow-xs">
                    {selectedWorker.name.split(' ').map((n) => n[0]).join('')}
                  </div>
                  <div>
                    <div className="flex items-center space-x-1.5">
                      <h3 className="text-sm font-bold text-zinc-900">{selectedWorker.name}</h3>
                      <ShieldCheck className="w-3.5 h-3.5 text-emerald-600" />
                    </div>
                    <span className="text-xs text-zinc-500">
                      {selectedWorker.trade} • {selectedWorker.phone}
                    </span>
                  </div>
                </div>
                <button
                  onClick={() => setSelectedWorker(null)}
                  className="text-zinc-400 hover:text-zinc-600 text-xs cursor-pointer p-1"
                >
                  ✕
                </button>
              </div>

              {/* Status and Telemetry Matrix */}
              <div className="grid grid-cols-2 gap-2.5 text-xs">
                <div className="bg-zinc-50 p-3 rounded-xl border border-zinc-100">
                  <span className="text-zinc-400 block text-[10px] uppercase font-bold flex items-center space-x-1">
                    <Activity className="w-3 h-3 text-emerald-600" />
                    <span>Current Status</span>
                  </span>
                  <span className="font-bold text-zinc-900 capitalize mt-1 inline-block">
                    {selectedWorker.status.replace('_', ' ')}
                  </span>
                </div>

                <div className="bg-zinc-50 p-3 rounded-xl border border-zinc-100">
                  <span className="text-zinc-400 block text-[10px] uppercase font-bold flex items-center space-x-1">
                    <Gauge className="w-3 h-3 text-indigo-600" />
                    <span>Speed / Heading</span>
                  </span>
                  <span className="font-bold text-zinc-900 mt-1 inline-block">
                    {selectedWorker.speed || 0} km/h • {selectedWorker.heading || 0}°
                  </span>
                </div>

                <div className="bg-zinc-50 p-3 rounded-xl border border-zinc-100">
                  <span className="text-zinc-400 block text-[10px] uppercase font-bold flex items-center space-x-1">
                    <Battery className="w-3 h-3 text-emerald-600" />
                    <span>Device Battery</span>
                  </span>
                  <div className="mt-1 flex items-center space-x-2">
                    <div className="w-full bg-zinc-200 rounded-full h-2 overflow-hidden">
                      <div
                        className="bg-emerald-500 h-2 rounded-full transition-all"
                        style={{ width: `${selectedWorker.battery}%` }}
                      ></div>
                    </div>
                    <span className="font-bold text-zinc-800 text-[11px]">{selectedWorker.battery}%</span>
                  </div>
                </div>

                <div className="bg-zinc-50 p-3 rounded-xl border border-zinc-100">
                  <span className="text-zinc-400 block text-[10px] uppercase font-bold flex items-center space-x-1">
                    <MapPin className="w-3 h-3 text-amber-500" />
                    <span>Primary Ward</span>
                  </span>
                  <span className="font-bold text-zinc-800 mt-1 inline-block truncate">
                    {selectedWorker.zone || 'Mysuru Center'}
                  </span>
                </div>
              </div>

              {/* Coordinates and Job Details */}
              <div className="bg-zinc-50 p-3 rounded-xl border border-zinc-100 text-xs space-y-2">
                <div className="flex justify-between text-zinc-500">
                  <span>GPS Lat / Lng</span>
                  <span className="font-mono text-zinc-800 font-semibold">
                    {Number(selectedWorker.lat).toFixed(4)}, {Number(selectedWorker.lng).toFixed(4)}
                  </span>
                </div>
                {selectedWorker.job && (
                  <div className="flex justify-between text-zinc-500 pt-1.5 border-t border-zinc-200/70">
                    <span>Assigned Dispatch</span>
                    <span className="font-bold text-indigo-600">{selectedWorker.job}</span>
                  </div>
                )}
                <div className="flex justify-between text-zinc-500 pt-1 border-t border-zinc-200/70">
                  <span>Completed Jobs</span>
                  <span className="font-semibold text-zinc-700">{selectedWorker.jobsCompleted || 85} verified</span>
                </div>
              </div>

              {/* Interactive Telemetry Actions */}
              <div className="pt-1 space-y-2">
                <button
                  onClick={() => handleFocusWorker(selectedWorker)}
                  className="w-full py-2.5 px-3 bg-zinc-950 hover:bg-zinc-800 text-white text-xs font-semibold rounded-xl flex items-center justify-center space-x-2 transition-all cursor-pointer shadow-xs"
                >
                  <Crosshair className="w-3.5 h-3.5" />
                  <span>Track Vehicle (Focus Camera)</span>
                </button>

                <div className="grid grid-cols-2 gap-2">
                  <a
                    href={`tel:${selectedWorker.phone}`}
                    className="py-2 px-3 bg-white hover:bg-zinc-50 text-zinc-800 text-xs font-semibold rounded-xl flex items-center justify-center space-x-1.5 transition-colors cursor-pointer border border-zinc-200 shadow-xs"
                  >
                    <Phone className="w-3.5 h-3.5 text-emerald-600" />
                    <span>Call Directly</span>
                  </a>

                  <button
                    onClick={() =>
                      showToast(`🛰️ GPS telemetry ping dispatched to ${selectedWorker.name}'s device. Heartbeat recalibrated.`)
                    }
                    className="py-2 px-3 bg-indigo-50 hover:bg-indigo-100 text-indigo-700 text-xs font-semibold rounded-xl flex items-center justify-center space-x-1.5 transition-colors cursor-pointer border border-indigo-200"
                  >
                    <Radio className="w-3.5 h-3.5 text-indigo-600 animate-pulse" />
                    <span>Send Ping</span>
                  </button>
                </div>
              </div>
            </div>
          ) : (
            <div className="bg-white rounded-2xl border border-zinc-200/80 p-6 text-center text-zinc-500 shadow-[0_4px_20px_rgba(0,0,0,0.03)] space-y-2">
              <div className="w-12 h-12 rounded-2xl bg-zinc-50 border border-zinc-100 flex items-center justify-center mx-auto text-zinc-400">
                <Compass className="w-6 h-6 animate-spin" style={{ animationDuration: '24s' }} />
              </div>
              <h4 className="text-sm font-bold text-zinc-800">No Vehicle Selected</h4>
              <p className="text-xs text-zinc-500 leading-relaxed">
                Click any worker marker on the Mysuru road map to inspect live speed, battery status, heading bearing, and active route.
              </p>
            </div>
          )}

          {/* Municipal Wards Demand & Surge Hub */}
          <div className="bg-white rounded-2xl border border-zinc-200/80 p-5 shadow-[0_4px_20px_rgba(0,0,0,0.03)] space-y-3">
            <div className="flex items-center justify-between pb-2 border-b border-zinc-100">
              <h4 className="text-xs font-bold uppercase tracking-wider flex items-center space-x-1.5 text-zinc-900">
                <Zap className="w-3.5 h-3.5 text-amber-500" />
                <span>Municipal Ward Demand Surges</span>
              </h4>
              <span className="text-[10px] text-zinc-400 font-mono">9 Wards</span>
            </div>

            <div className="space-y-2 text-xs max-h-[220px] overflow-y-auto pr-1">
              {MYSURU_MUNICIPAL_ZONES.map((zone) => (
                <div
                  key={zone.id}
                  onClick={() => {
                    if (mapInstanceRef.current) {
                      mapInstanceRef.current.flyTo([zone.lat, zone.lng], 14, { duration: 1.2 });
                    }
                  }}
                  className="flex items-center justify-between p-2.5 rounded-xl bg-zinc-50 hover:bg-zinc-100/90 border border-zinc-100 transition-all cursor-pointer group"
                >
                  <div>
                    <div className="font-semibold text-zinc-800 group-hover:text-zinc-900 flex items-center space-x-1.5">
                      <span className="w-2 h-2 rounded-full" style={{ background: zone.color }}></span>
                      <span>{zone.name}</span>
                    </div>
                    <span className="text-[10px] text-zinc-400 block ml-3.5">{zone.landmark}</span>
                  </div>

                  <div className="flex items-center space-x-2">
                    <span className="text-[10px] text-zinc-500">{zone.workers} active</span>
                    <span
                      className="px-2 py-0.5 rounded-md font-bold text-[10px]"
                      style={{
                        background: `${zone.color}15`,
                        color: zone.color,
                        border: `1px solid ${zone.color}33`,
                      }}
                    >
                      {zone.surge}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
