# Real-World Telemetry Radar & Road Routing Command Center

## Executive Overview

The Jugaad Admin Operations Dashboard features a real-world geospatial telemetry and road network routing command center, upgrading the previous static vector map into an interactive, real-world GIS radar engine.

Built for the city of Mysuru (with expansion capabilities across Bengaluru, Mandya, Hassan, Hubli, and Mangaluru), this system tracks certified trade providers (Electricians, Plumbers, Carpenters, AC Technicians, Appliance Repair, Painters) in real time and visualizes live vehicular dispatches with turn-by-turn road geometries and dynamic traffic ETAs.

---

## Architecture & Core Capabilities

### 1. Real-World Interactive Mapping Engine
- **Engine**: Leaflet with custom DOM/SVG layers and hardware-accelerated animations.
- **Tile Providers**:
  - **Dark Ops (Default)**: CartoDB Dark Matter night-mode tiles matching the tactical operations aesthetic.
  - **City Streets**: OpenStreetMap high-detail street grid with landmarks and building footprints.
  - **Satellite Aerial**: Esri World Imagery high-resolution satellite photography.
- **Geospatial Anchor**: Anchored to Mysuru Municipal Corporation center (`[12.3051, 76.6450]`) across 9 active wards:
  - *Gokulam 3rd Stage* (`12.3325, 76.6268`)
  - *Kuvempunagar & TK Layout* (`12.2852, 76.6294`)
  - *Hebbal Industrial Area* (`12.3621, 76.6025`)
  - *Jayalakshmipuram & Vontikoppal* (`12.3214, 76.6385`)
  - *Saraswathipuram & Tonachikoppal* (`12.3025, 76.6340`)
  - *Vidyaranyapuram & JP Nagar* (`12.2785, 76.6492`)
  - *Vijayanagar 2nd Stage* (`12.3395, 76.6085`)
  - *Bannimantap* (`12.3385, 76.6520`)
  - *Mysore Palace / Central* (`12.3051, 76.6551`)

---

### 2. Road Network Routing & OSRM Engine
- **Live Routing API**: Communicates with the Open Source Routing Machine (`OSRM`) driving service to calculate true street paths:
  `https://router.project-osrm.org/route/v1/driving/{lng1},{lat1};{lng2},{lat2}?overview=full&geometries=geojson`
- **Fault-Tolerant Arterial Grid Fallback**: When offline or if network latency exceeds 3.5s, dynamically snaps origin and destination across key Mysuru arterial corridors (KRS Road, Hunsur Road, Outer Ring Road, Sayyaji Rao Road, Double Road) generating realistic curved road waypoints.
- **In-Memory Route Caching**: Caches computed paths for instantaneous re-renders and zero redundant network overhead.
- **Animated Polyline Styling**:
  - Outer translucent glow layer for high-visibility cyber neon aesthetic.
  - Inner animated directional dash-array (`.leaflet-route-flow`) flowing in the direction of transit.
  - Pulsing destination radar beacons (`.radar-beacon-ring`) with real-time ETA tags.

---

### 3. Vehicular Transit Simulation & Physics
- **Interpolated Road Movement**: Vehicles smoothly traverse street coordinates using `interpolateRouteProgress`.
- **Compass Bearing**: Dynamically calculates heading angles (`calculateBearing`) between consecutive road coordinates, smoothly rotating the directional arrow on vehicle markers to match street curves.
- **Live Telemetry Calculation**: Real-time speed oscillation (25–38 km/h), remaining distance in kilometers, and dynamic ETA countdowns.
- **Simulation Controls**:
  - Play / Pause transit execution.
  - Speed Multiplier: 1x, 2x, and 4x accelerated playback.
  - Camera Chase: Locks viewport to follow moving vehicles in real time.

---

### 4. Interactive Booking Dispatch Simulator
- **Auto Dispatch Simulation**: Automatically pairs idle online workers with randomized emergency job requests across Mysuru wards, calculating full road routes and updating status to `en_route`.
- **Map Click-to-Dispatch Pinning**: Admins can activate "Pin Dispatch" mode and click any coordinate on the map. The system:
  1. Identifies the nearest online provider using Haversine geodesic distance.
  2. Resolves municipal ward surge pricing and emergency base fees.
  3. Fetches the driving road path.
  4. Automatically transitions provider to `en_route` and initiates live navigation.

---

### 5. Telematics & Operations Inspection Drawer
- **Worker Dossier**: Profile picture, trade specialization, verified status, rating, total completed tasks, direct phone link.
- **Hardware Telemetry**: Device battery gauge with color-coded health bars, GPS latitude/longitude in monospace font, vehicle speed, heading degree.
- **Action Suite**:
  - *Focus Camera*: Smoothly flies viewport to target vehicle.
  - *Send Ping*: Emulates PostGIS heartbeat recalibration ping.
  - *Call Directly*: One-click `tel:` link to initiate direct voice call.

---

## File Reference Map

- [RadarMapModal.jsx](file:///c:/Users/Kushal%20M%20N/Downloads/jugaad%20app%20update/jugaad%20app%20update/apps/admin/src/components/RadarMapModal.jsx) - Main command center component with Leaflet integration, controls, and telemetry drawer.
- [mapRoutingUtils.js](file:///c:/Users/Kushal%20M%20N/Downloads/jugaad%20app%20update/jugaad%20app%20update/apps/admin/src/utils/mapRoutingUtils.js) - Mysuru coordinate registry, OSRM routing client, arterial fallback, and simulation math.
- [mapIconUtils.js](file:///c:/Users/Kushal%20M%20N/Downloads/jugaad%20app%20update/jugaad%20app%20update/apps/admin/src/utils/mapIconUtils.js) - Custom high-tech SVG DivIcons for vehicles, destination beacons, and surge badges.
- [index.css](file:///c:/Users/Kushal%20M%20N/Downloads/jugaad%20app%20update/jugaad%20app%20update/apps/admin/src/index.css) - Animations for route flow dash-offset, radar beacon pulse, vehicle aura, and dark glass popups.
