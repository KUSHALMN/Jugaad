/**
 * Mysuru Geospatial Registry & Telemetry Data Engine
 * High-precision coordinates, municipal ward boundaries, and geospatial utilities.
 */

export const MYSURU_CENTER = [12.3051, 76.6450];
export const MYSURU_DEFAULT_ZOOM = 13;

export const TILE_PROVIDERS = {
  dark: {
    id: 'dark',
    name: 'Dark Ops',
    url: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
    attribution: '&copy; <a href="https://carto.com/">CARTO</a> &copy; OpenStreetMap',
    subdomains: 'abcd',
    maxZoom: 19,
  },
  streets: {
    id: 'streets',
    name: 'City Streets',
    url: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
    attribution: '&copy; <a href="https://openstreetmap.org">OpenStreetMap</a>',
    subdomains: 'abc',
    maxZoom: 19,
  },
  satellite: {
    id: 'satellite',
    name: 'Satellite Aerial',
    url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    attribution: '&copy; Esri &mdash; Earthstar Geographics',
    subdomains: '',
    maxZoom: 18,
  },
};

export const MYSURU_MUNICIPAL_ZONES = [
  {
    id: 'z1',
    name: 'Gokulam 3rd Stage',
    landmark: 'Temple Road / Contour Rd',
    lat: 12.3325,
    lng: 76.6268,
    demand: 'High',
    workers: 14,
    surge: '1.4x',
    color: '#818cf8',
    radiusMeters: 1100,
  },
  {
    id: 'z2',
    name: 'Kuvempunagar',
    landmark: 'Complex & Double Road',
    lat: 12.2852,
    lng: 76.6294,
    demand: 'Very High',
    workers: 22,
    surge: '1.5x',
    color: '#ef4444',
    radiusMeters: 1400,
  },
  {
    id: 'z3',
    name: 'Hebbal Industrial Area',
    landmark: 'Electronic City Outer Ring',
    lat: 12.3621,
    lng: 76.6025,
    demand: 'Moderate',
    workers: 8,
    surge: '1.0x',
    color: '#06b6d4',
    radiusMeters: 1300,
  },
  {
    id: 'z4',
    name: 'Jayalakshmipuram',
    landmark: 'Kalidasa Road Junction',
    lat: 12.3214,
    lng: 76.6385,
    demand: 'High',
    workers: 16,
    surge: '1.3x',
    color: '#a855f7',
    radiusMeters: 1000,
  },
  {
    id: 'z5',
    name: 'Saraswathipuram',
    landmark: 'Fire Brigade / 5th Main',
    lat: 12.3025,
    lng: 76.6340,
    demand: 'Moderate',
    workers: 11,
    surge: '1.1x',
    color: '#10b981',
    radiusMeters: 950,
  },
  {
    id: 'z6',
    name: 'Vidyaranyapuram',
    landmark: 'Chamundeshwari Road',
    lat: 12.2785,
    lng: 76.6492,
    demand: 'High',
    workers: 15,
    surge: '1.3x',
    color: '#f59e0b',
    radiusMeters: 1200,
  },
  {
    id: 'z7',
    name: 'Vijayanagar 2nd Stage',
    landmark: 'Water Tank Circle',
    lat: 12.3395,
    lng: 76.6085,
    demand: 'Low',
    workers: 6,
    surge: '1.0x',
    color: '#38bdf8',
    radiusMeters: 1150,
  },
  {
    id: 'z8',
    name: 'Bannimantap',
    landmark: 'Torch Light Parade Grounds',
    lat: 12.3385,
    lng: 76.6520,
    demand: 'High',
    workers: 12,
    surge: '1.2x',
    color: '#ec4899',
    radiusMeters: 1050,
  },
  {
    id: 'z9',
    name: 'Mysore Palace Central',
    landmark: 'Sayyaji Rao Rd / D. Devaraj Urs Rd',
    lat: 12.3051,
    lng: 76.6551,
    demand: 'Very High',
    workers: 19,
    surge: '1.4x',
    color: '#f43f5e',
    radiusMeters: 1250,
  },
];

export const INITIAL_REAL_WORKERS = [
  {
    id: 'w1',
    name: 'Suresh Kumar',
    trade: 'Electrician',
    status: 'en_route',
    lat: 12.3312,
    lng: 76.6212,
    speed: 28,
    heading: 45,
    battery: 88,
    phone: '+91 98450 12345',
    job: '#JUG-8821',
    rating: 4.9,
    jobsCompleted: 142,
    zone: 'Gokulam',
  },
  {
    id: 'w2',
    name: 'Ramesh Gowda',
    trade: 'Plumber',
    status: 'online',
    lat: 12.2852,
    lng: 76.6294,
    speed: 0,
    heading: 0,
    battery: 94,
    phone: '+91 97412 67890',
    job: null,
    rating: 4.8,
    jobsCompleted: 98,
    zone: 'Kuvempunagar',
  },
  {
    id: 'w3',
    name: 'Manjunath B.',
    trade: 'Carpenter',
    status: 'in_progress',
    lat: 12.3214,
    lng: 76.6385,
    speed: 0,
    heading: 0,
    battery: 62,
    phone: '+91 99001 44556',
    job: '#JUG-8819',
    rating: 4.7,
    jobsCompleted: 76,
    zone: 'Jayalakshmipuram',
  },
  {
    id: 'w4',
    name: 'Arun Prakash',
    trade: 'AC Tech',
    status: 'en_route',
    lat: 12.3550,
    lng: 76.6120,
    speed: 34,
    heading: 120,
    battery: 79,
    phone: '+91 94481 99887',
    job: '#JUG-8825',
    rating: 4.9,
    jobsCompleted: 189,
    zone: 'Hebbal',
  },
  {
    id: 'w5',
    name: 'Praveen Naik',
    trade: 'Plumber',
    status: 'online',
    lat: 12.2785,
    lng: 76.6492,
    speed: 0,
    heading: 0,
    battery: 91,
    phone: '+91 98860 33221',
    job: null,
    rating: 4.6,
    jobsCompleted: 64,
    zone: 'Vidyaranyapuram',
  },
  {
    id: 'w6',
    name: 'Kiran Swamy',
    trade: 'Electrician',
    status: 'online',
    lat: 12.3395,
    lng: 76.6085,
    speed: 0,
    heading: 0,
    battery: 83,
    phone: '+91 94800 77112',
    job: null,
    rating: 4.8,
    jobsCompleted: 112,
    zone: 'Vijayanagar',
  },
  {
    id: 'w7',
    name: 'Sunita Devi',
    trade: 'Appliance Repair',
    status: 'online',
    lat: 12.3025,
    lng: 76.6340,
    speed: 0,
    heading: 0,
    battery: 86,
    phone: '+91 98455 66778',
    job: null,
    rating: 4.9,
    jobsCompleted: 130,
    zone: 'Saraswathipuram',
  },
];

export const INITIAL_ACTIVE_ROUTES = [
  {
    id: 'r1',
    workerId: 'w1',
    workerName: 'Suresh Kumar',
    trade: 'Electrician',
    customerName: 'Ananya Rao',
    customerPhone: '+91 99002 11223',
    customerAddress: 'Kalidasa Road, Vontikoppal, Mysuru',
    customerLat: 12.3214,
    customerLng: 76.6385,
    originLat: 12.3385,
    originLng: 76.6212,
    jobId: '#JUG-8821',
    etaMins: 6,
    distanceKm: 2.4,
    progress: 0.35,
    color: '#10b981',
  },
  {
    id: 'r2',
    workerId: 'w4',
    workerName: 'Arun Prakash',
    trade: 'AC Tech',
    customerName: 'Vikram Joshi',
    customerPhone: '+91 98440 99881',
    customerAddress: 'KRS Road, Hebbal 2nd Stage, Mysuru',
    customerLat: 12.3621,
    customerLng: 76.6025,
    originLat: 12.3480,
    originLng: 76.6250,
    jobId: '#JUG-8825',
    etaMins: 9,
    distanceKm: 3.8,
    progress: 0.55,
    color: '#6366f1',
  },
];

/**
 * Calculates Haversine distance in kilometers between two lat/lng coordinates.
 */
export function haversineDistanceKm(lat1, lon1, lat2, lon2) {
  const R = 6371; // Earth radius in km
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return parseFloat((R * c).toFixed(2));
}

/**
 * Calculates compass heading bearing (0 - 360 degrees) between two coordinates.
 */
export function calculateBearing(lat1, lon1, lat2, lon2) {
  const phi1 = (lat1 * Math.PI) / 180;
  const phi2 = (lat2 * Math.PI) / 180;
  const deltaLambda = ((lon2 - lon1) * Math.PI) / 180;

  const y = Math.sin(deltaLambda) * Math.cos(phi2);
  const x =
    Math.cos(phi1) * Math.sin(phi2) -
    Math.sin(phi1) * Math.cos(phi2) * Math.cos(deltaLambda);

  const theta = Math.atan2(y, x);
  const bearing = ((theta * 180) / Math.PI + 360) % 360;
  return Math.round(bearing);
}

// In-memory cache for road route coordinates
const ROUTE_CACHE = new Map();

/**
 * Key Mysuru arterial road network junctions for realistic fallback routing.
 */
const MYSURU_ROAD_JUNCTIONS = [
  { name: 'KRS Road & Outer Ring Rd', lat: 12.3580, lng: 76.6180 },
  { name: 'Hunsur Road Junction', lat: 12.3250, lng: 76.6290 },
  { name: 'Sayyaji Rao Road Circle', lat: 12.3120, lng: 76.6510 },
  { name: 'Kantharaj Urs Road Double Rd', lat: 12.2980, lng: 76.6320 },
  { name: 'Outer Ring South (JP Nagar)', lat: 12.2700, lng: 76.6400 },
  { name: 'Vontikoppal Temple Junction', lat: 12.3290, lng: 76.6350 },
  { name: 'Bogadi 80ft Road', lat: 12.3020, lng: 76.6150 },
];

/**
 * Generates smooth, realistic multi-waypoint street routes snapping to Mysuru road grid.
 */
export function generateArterialFallbackRoute(origin, destination) {
  const points = [];
  const start = [origin.lat, origin.lng];
  const end = [destination.lat, destination.lng];
  points.push(start);

  // Find intermediate road junction that lies somewhat between start and end
  const midLat = (origin.lat + destination.lat) / 2;
  const midLng = (origin.lng + destination.lng) / 2;

  let bestJunction = null;
  let minJunctionDist = Infinity;

  for (const junc of MYSURU_ROAD_JUNCTIONS) {
    const d = haversineDistanceKm(midLat, midLng, junc.lat, junc.lng);
    if (d < minJunctionDist && d < 3.5) {
      minJunctionDist = d;
      bestJunction = [junc.lat, junc.lng];
    }
  }

  // Create curved road path segments
  const waypoints = bestJunction ? [start, bestJunction, end] : [start, [midLat + 0.002, midLng - 0.002], end];

  // Interpolate bezier/sub-segments for authentic vehicular road curvature
  const densePoints = [];
  for (let i = 0; i < waypoints.length - 1; i++) {
    const p1 = waypoints[i];
    const p2 = waypoints[i + 1];
    const steps = 14;
    for (let s = 0; s <= steps; s++) {
      const t = s / steps;
      // Slight natural road jitter
      const bendFactor = Math.sin(t * Math.PI) * 0.0012;
      const lat = p1[0] + (p2[0] - p1[0]) * t + bendFactor;
      const lng = p1[1] + (p2[1] - p1[1]) * t + bendFactor * 0.7;
      densePoints.push([lat, lng]);
    }
  }

  return densePoints;
}

/**
 * Fetches real driving road path using Open Source Routing Machine (OSRM).
 * Falls back seamlessly to arterial street interpolation if network is unavailable.
 */
export async function getOptimizedRoute(origin, destination) {
  const cacheKey = `${origin.lat.toFixed(4)},${origin.lng.toFixed(4)}->${destination.lat.toFixed(4)},${destination.lng.toFixed(4)}`;
  if (ROUTE_CACHE.has(cacheKey)) {
    return ROUTE_CACHE.get(cacheKey);
  }

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 3500);

    const url = `https://router.project-osrm.org/route/v1/driving/${origin.lng},${origin.lat};${destination.lng},${destination.lat}?overview=full&geometries=geojson`;
    const response = await fetch(url, { signal: controller.signal });
    clearTimeout(timeoutId);

    if (response.ok) {
      const data = await response.json();
      if (data.routes && data.routes.length > 0) {
        const route = data.routes[0];
        // OSRM returns coordinates as [lng, lat], convert to Leaflet's [lat, lng]
        const latLngs = route.geometry.coordinates.map(c => [c[1], c[0]]);
        const result = {
          coordinates: latLngs,
          distanceKm: parseFloat((route.distance / 1000).toFixed(2)),
          durationMins: Math.max(1, Math.round(route.duration / 60)),
          isRealRoad: true,
        };
        ROUTE_CACHE.set(cacheKey, result);
        return result;
      }
    }
  } catch (err) {
    // Network offline or timeout, use smart arterial fallback
  }

  // Fallback path
  const fallbackCoords = generateArterialFallbackRoute(origin, destination);
  const directDist = haversineDistanceKm(origin.lat, origin.lng, destination.lat, destination.lng);
  const roadDist = parseFloat((directDist * 1.25).toFixed(2));
  const fallbackDuration = Math.max(2, Math.round((roadDist / 25) * 60)); // ~25 km/h city speed

  const result = {
    coordinates: fallbackCoords,
    distanceKm: roadDist,
    durationMins: fallbackDuration,
    isRealRoad: false,
  };
  ROUTE_CACHE.set(cacheKey, result);
  return result;
}

/**
 * Interpolates vehicle position and bearing along a road path coordinate array.
 */
export function interpolateRouteProgress(coordinates, progressPercent) {
  if (!coordinates || coordinates.length === 0) {
    return null;
  }
  if (coordinates.length === 1) {
    return {
      lat: coordinates[0][0],
      lng: coordinates[0][1],
      bearing: 0,
      nextPointIndex: 0,
    };
  }

  const clampedProgress = Math.max(0, Math.min(1, progressPercent));
  const totalSegments = coordinates.length - 1;
  const exactIndex = clampedProgress * totalSegments;
  const lowerIndex = Math.floor(exactIndex);
  const upperIndex = Math.min(totalSegments, lowerIndex + 1);
  const segmentFraction = exactIndex - lowerIndex;

  const p1 = coordinates[lowerIndex];
  const p2 = coordinates[upperIndex];

  const currentLat = p1[0] + (p2[0] - p1[0]) * segmentFraction;
  const currentLng = p1[1] + (p2[1] - p1[1]) * segmentFraction;
  const bearing = calculateBearing(p1[0], p1[1], p2[0], p2[1]);

  return {
    lat: currentLat,
    lng: currentLng,
    bearing,
    nextPointIndex: upperIndex,
  };
}

