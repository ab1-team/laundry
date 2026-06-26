---
name: Laundry Management System
colors:
  surface: '#fbf8fb'
  surface-dim: '#dcd9dc'
  surface-bright: '#fbf8fb'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f6f3f6'
  surface-container: '#f0edf0'
  surface-container-high: '#eae7ea'
  surface-container-highest: '#e4e2e5'
  on-surface: '#1b1b1e'
  on-surface-variant: '#45464d'
  inverse-surface: '#303033'
  inverse-on-surface: '#f3f0f3'
  outline: '#76767e'
  outline-variant: '#c6c6ce'
  surface-tint: '#545d7d'
  primary: '#040d2a'
  on-primary: '#ffffff'
  primary-container: '#1a2340'
  on-primary-container: '#828aad'
  inverse-primary: '#bdc5ea'
  secondary: '#006688'
  on-secondary: '#ffffff'
  secondary-container: '#58cafe'
  on-secondary-container: '#005370'
  tertiary: '#180d00'
  on-tertiary: '#ffffff'
  tertiary-container: '#332100'
  on-tertiary-container: '#a4875a'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dbe1ff'
  primary-fixed-dim: '#bdc5ea'
  on-primary-fixed: '#111a37'
  on-primary-fixed-variant: '#3d4665'
  secondary-fixed: '#c2e8ff'
  secondary-fixed-dim: '#75d1ff'
  on-secondary-fixed: '#001e2b'
  on-secondary-fixed-variant: '#004d67'
  tertiary-fixed: '#ffdeab'
  tertiary-fixed-dim: '#e2c290'
  on-tertiary-fixed: '#281900'
  on-tertiary-fixed-variant: '#59431c'
  background: '#fbf8fb'
  on-background: '#1b1b1e'
  surface-variant: '#e4e2e5'
typography:
  display-lg:
    fontFamily: DM Sans
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: DM Sans
    fontSize: 22px
    fontWeight: '700'
    lineHeight: 28px
  title-lg:
    fontFamily: DM Sans
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: DM Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: DM Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-lg:
    fontFamily: DM Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.1px
  label-sm:
    fontFamily: DM Sans
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.5px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 4px
  container-padding: 20px
  gutter: 16px
  stack-sm: 8px
  stack-md: 16px
  stack-lg: 24px
---

## Brand & Style

The design system is engineered for a high-frequency operational environment that demands both professional reliability and consumer-grade friendliness. The personality is **Expressive and Tactile**, blending the systematic logic of an enterprise SaaS with the approachable energy of leading Southeast Asian super-apps.

The visual style leverages **Rounded Minimalism with Tactile Depth**. By utilizing hyper-rounded corners and a cushioned layout, the UI reduces cognitive load for laundry operators and staff. The emotional response is one of "organized softness"—where heavy operational data feels lightweight and easy to manage. The aesthetic draws from Material Design 3 but pushes further into rounded, pill-shaped geometries to create a distinct, friendly brand presence.

## Colors

The palette is anchored by **Deep Navy (#1A2340)**, providing a sense of authority and professional stability. This is balanced by the **Sky Blue (#4FC3F7)** accent, which injects freshness and airiness—reminiscent of clean water and fresh linen.

**Functional Color Mapping (Bahasa Indonesia):**
- **Masuk (Pending):** Amber (#FFB74D) signaling high priority/attention.
- **Dicuci (Processing):** Blue (#42A5F5) representing active workflow.
- **Selesai (Completed):** Green (#66BB6A) indicating success and readiness.
- **Diambil (Collected):** Gray (#90A4AE) for archived or finalized states.

The background uses a soft cool-grey **(#F5F7FA)** to allow white cards to "pop" with distinct elevation, while the primary text maintains high contrast against the neutral surface.

## Typography

The design system utilizes **DM Sans** for its geometric clarity and modern, approachable character. The type scale is optimized for Android mobile (390px) with an emphasis on legibility during fast-paced operational tasks.

- **Headlines:** Use Bold (700) weight for clear section differentiation.
- **Body Text:** Primarily uses Regular (400) for high readability in long lists or order details.
- **Labels:** Use Semi-Bold (600) for buttons and status chips to ensure they stand out against vibrant background colors.
- **Numerical Data:** Price points and order weights should use the `title-lg` or `headline-md` tokens to ensure clarity in transaction summaries.

## Layout & Spacing

This design system follows a **Fluid Grid** model optimized for a 390px mobile viewport. It utilizes a 4-column structure with 16px gutters and a generous 20px outer margin to emphasize the "cushioned" feel.

**Key Layout Rules:**
- **Vertical Rhythm:** Elements are stacked using multiples of 8px.
- **Card Padding:** All primary containers/cards must use 20px internal padding to maintain the soft, spacious aesthetic.
- **Safe Areas:** Ensure interactive elements (Buttons/Inputs) maintain at least 12px of vertical clearance from each other to prevent "fat-finger" errors in a busy laundry environment.
- **Bottom Navigation:** Fixed at the bottom with a 28px top-corner radius, creating a "docked" appearance.

## Elevation & Depth

Visual hierarchy is achieved through **Tonal Layers** combined with **Ambient Shadows**. The design avoids harsh lines, opting for depth that feels physical and soft.

- **Level 0 (Background):** #F5F7FA (Base layer).
- **Level 1 (Cards/Surfaces):** White #FFFFFF with a soft, 12% opacity Deep Navy shadow (Blur: 16px, Y: 4px).
- **Level 2 (Interactive/FAB):** A more pronounced shadow (Blur: 20px, Y: 8px) with a 20% opacity primary color tint to make the Floating Action Button feel "lifted."
- **Overlays:** Modals and Bottom Sheets use a 40% opacity backdrop blur to maintain context while focusing user attention.

## Shapes

The shape language is the defining characteristic of this design system. It is **Hyper-Rounded**, moving away from standard corporate sharp corners to create an "organic" feel.

- **Primary Cards:** 28px - 32px radius. This creates a "bubble" container effect that feels friendly.
- **Inputs:** 20px radius. Balanced to feel softer than standard inputs but distinct from pill-shaped buttons.
- **Interactive Elements:** Buttons, Chips, and the FAB use a 999px (Pill) radius to maximize the "friendly/touchable" metaphor.
- **Sheet Components:** Modals and Bottom Navs only round the top corners (28px-32px), creating a "growing from the bottom" visual effect.

## Components

**Buttons:**
- **Primary:** Pill-shaped, Deep Navy background, White text.
- **Secondary:** Pill-shaped, Sky Blue background, Deep Navy text.
- **FAB:** 64px circular (999px), Sky Blue with a White icon for high-visibility "New Order" actions.

**Status Chips:**
- Always pill-shaped. Use 15% opacity of the status color for the background and 100% opacity for the text to ensure WCAG compliance while maintaining a soft "wash" of color.

**Input Fields:**
- 20px rounded corners. Background #FFFFFF with a subtle 1px border in #90A4AE. On focus, the border shifts to Sky Blue with a 2px stroke.

**Cards (Pesanan):**
- 32px rounded corners. Includes a distinct Status Chip in the top right. Large typography for "Nama Pelanggan" and "Berat (kg)".

**Bottom Navigation:**
- Top corners 28px. Icons are filled when active, accompanied by a small "dot" indicator below the active icon in Sky Blue.

**Modals (Bottom Sheets):**
- Top corners 32px. Must include a "grabber" handle (40px wide, 4px height, 8px radius) at the top center.