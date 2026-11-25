# Jugaad Experts Directory — UI/UX Redesign Specification

## 1. Overview
The **Jugaad Experts** directory (`WorkerListScreen`) has been elevated to an enterprise-grade marketplace directory featuring live trust indicators, city-level filtering, icon-enriched service categories, and conversion-focused action cards.

---

## 2. Layout & Visual Hierarchy

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ [🔧] Jugaad Experts                                 [👥 120+] [⭐ 4.8 ★] [⚡ 24/7]     │
│      Browse all skilled workers and their live status.                                  │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ 🔍 Search by name, skill, area, or email...                           | 📍 Mysuru ⌄   │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ [⊞ All] [⚡ Electrician] [🔧 Plumber] [💻 Laptop Repair] [📱 Phone Repair] [🔨 Carpe...]│
├────────────────────────────────────────────────────────────────────────────────────────┤
│  (S)  SAN TECHNOLOGIES Water Purifier Services ✓       ┌────────┐  |  ₹200/hr          │
│   ●   [💧 RO SERVICE]                                  │  💧    │  |  [📅 Book Now >]  │
│       ★ 5.0 • 440 completed jobs                       │     ✓  │  |  [📞]             │
│       [⚙️ RO Repair] [💧 RO Service]                    └────────┘  |                    │
│       💼 5+ Years Experience | 📍 #99, 3rd Main Road...             |                    │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

### Key Enhancements
1. **KPI Trust Pills**: Displays verified worker count (`120+`), average rating (`4.8 ★`), and availability (`24/7`) directly in the header.
2. **Integrated Location Selector**: Built-in dropdown inside the search bar (`Mysuru`, `Bengaluru`, `All Cities`).
3. **Icon-Enriched Category Chips**: Every filter chip features a tailored Material icon for rapid visual scanning.
4. **Conversion-Ready Worker Cards**:
   - Category-themed pastel illustration badge with verified overlay.
   - Skill chips with leading micro-icons.
   - Dedicated right-hand action column (or responsive bottom bar on mobile) with bold hourly rate, emerald `Book Now >` CTA, and 1-tap `📞` call button.
