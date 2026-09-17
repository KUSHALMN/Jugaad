# Universal Multi-Division Search Engine & Regional Customer Advisory

## Architecture Overview

The Jugaad Worker Search Engine provides fault-tolerant geospatial matching across all active divisions, surrounding districts, and upcoming expansion cities.

When a customer searches for a certified service expert (e.g. Electrician, Plumber, AC Repair, RO Water Purifier), the search engine applies a 3-tier resolution strategy:

1. **Tier 1: Hyperlocal Radius**: Searches nearby workers within 3km -> 5km -> 10km tiers.
2. **Tier 2: Citywide High-Rated Fallback**: If workers in that specific region are unavailable or busy, queries certified workers in that specific issue category across the entire city, strictly sorted by Rating DESC, Completed Jobs DESC, and Verification status.
3. **Tier 3: Customer Advisory Banner**: Empathically informs customers that workers in their region are currently busy, offering direct booking with top-rated specialists across the city.

---

## Geospatial Registry & Divisions

The engine maintains a high-precision bounding box and division coordinate registry for all active municipal divisions:
- **Mysuru**: Kuvempunagar, Gokulam, Vijayanagar, Jayalakshmipuram, Hebbal Industrial, Saraswathipuram, Mysore Palace / Central, Vidyaranyapuram, Chamundipuram, Bannimantap, Mandi Mohalla, Alanahalli, Metagalli, Bogadi, Dattagalli, Roopa Nagar, Ramakrishnanagar, JP Nagar, Nazarbad, Yadavagiri.
- **Bengaluru**: Koramangala, Indiranagar, HSR Layout, Whitefield, Jayanagar, Electronic City, BTM Layout, Malleshwaram, Hebbal Bengaluru, Marathahalli, Yelahanka, Rajajinagar, Banashankari, Bellandur, Sarjapur Road, Basavanagudi.
- **Mandya**: Mandya City Center, Sugar Town, Srirangapatna, Maddur, Pandavapura, Malavalli.
- **Hassan**: Hassan City Center, Vidyanagar Hassan, Channarayapatna, Arsikere.
- **Hubli-Dharwad**: Hubli City Center, Vidyanagar Hubli, Dharwad Central, Navanagar, Gokul Road.
- **Mangaluru**: Mangaluru Central, Hampankatta, Kadri, Bejai, Surathkal.
- **Upcoming Cities**: Dynamic geodesic mapping to nearest city hub within 75 km as an expansion zone, or dynamically detected as an Upcoming City.

---

## API Contract (/v1/workers/search)

- mode: "citywide_rating_fallback" (or "nearest" / "no_workers_found")
- is_fallback: 	rue
- dvisory_message: Dynamic advisory message containing user's division, city, and category.
- user_city: City name
- user_division: Division name
- is_upcoming_city: boolean
- category: The resolved category name
- workers: Top-rated verified workers in that specific category/issue.
