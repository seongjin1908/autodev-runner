# 2026 PRODUCT DESIGN STANDARD — launch products

This standard applies to DESIGN LANE runs. The goal is not decoration. The goal is a contemporary, credible, conversion-oriented product that does not look like generic AI-generated UI.

## Contemporary direction
- Use strong editorial typography, restrained copy, deliberate whitespace and a clear visual hierarchy.
- Let the actual product interaction/result be the visual focus. Do not fill the page with generic marketing cards.
- Mobile is the primary composition. Desktop is an expansion of the mobile hierarchy, not a separate design.
- Use subtle motion only when it clarifies state, hierarchy or cause/effect. Respect prefers-reduced-motion.
- Keep interactions tactile and obvious. Primary touch targets should be comfortably tappable; avoid tiny links as primary actions.
- Use design tokens for type scale, spacing, radius, border, surface, shadow and semantic states.
- Prefer a small number of strong surfaces over card soup.

## Anti-AI / anti-template rules
Do NOT introduce:
- purple/blue gradient blobs as a default brand treatment;
- glassmorphism everywhere;
- glowing neon borders;
- random sparkles/robot/brain icons;
- a grid of 8–12 identical rounded cards;
- huge empty hero sections with vague AI copy;
- repeated "AI-powered", "revolutionary", "smart", "next-generation" labels;
- fake testimonials, fake customer counts, fake logos, fake ratings or fake trust badges;
- excessive pill badges;
- excessive 20–32px corner radii on every element;
- low-contrast gray body text;
- decorative charts with invented data.

## UX rules
1. One dominant action per screen/section.
2. The user must understand what to do within a few seconds.
3. Remove explanatory copy that does not change a decision.
4. Keep pricing, trust, error and recovery information near the decision that needs it.
5. Loading, empty, success, failure, retry and offline/slow states must be designed, not left as browser/default text.
6. Preserve keyboard navigation, visible focus, semantic labels and accessible contrast.
7. No horizontal overflow at 360/390/430 widths.
8. Sticky mobile CTA must never cover content or system-safe areas.
9. Do not hide critical terms or payment facts behind hover-only UI.
10. Use progressive disclosure for dense secondary details, but keep the user's current next action visible.

## Engineering constraints
- Preserve all working product logic and security boundaries.
- Do not redesign data structures or payment logic merely for visual convenience.
- Do not add paid fonts, paid component kits, external trackers or paid design APIs.
- Reuse the existing stack and components where practical.
- Consolidate repeated visual values into tokens/components instead of scattering magic numbers.
- Keep the batch reviewable: redesign one coherent user journey per run.
- Add/update regression or structural tests when UI behavior changes.
- Validation must pass before the design batch is eligible to commit.

## Design-lane completion rule
A design run counts only if it improves a real user journey such as:
landing -> input/upload/search -> result -> product/CTA -> payment/recovery,
or fixes a measurable usability/accessibility/mobile problem.
Pure recoloring is not meaningful progress.
