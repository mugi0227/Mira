# Mira Design System — Master

## Direction

**Soft, calm, adult-friendly productivity with a playful optional companion.**

The base product should feel trustworthy and spacious. Pixel Cat adds warmth without changing the information architecture.

## Design dials

- Variance: 4/10
- Motion: 5/10
- Density: 3/10

## Layout tokens

| Token | Value |
|---|---:|
| xxs | 4pt |
| xs | 8pt |
| sm | 12pt |
| md | 16pt |
| lg | 24pt |
| xl | 32pt |
| xxl | 48pt |

Phone horizontal gutter: 16pt. All fixed controls respect safe areas. Minimum touch area: 44×44pt.

## Radius

- small: 12pt
- medium: 18pt
- large: 26pt

## Typography

Use Dynamic Type styles, not fixed custom fonts.

- Large title: primary emotional statement
- Title 2/3: month, section title
- Headline: card title / primary row label
- Body: explanation
- Subheadline/caption: metadata and reasons
- Monospaced digits: progress and counts

## Iconography

- SF Symbols only for structural UI
- consistent symbol weight within each hierarchy
- no emoji as controls
- decorative icons hidden from VoiceOver
- standalone icon buttons always have accessibility labels

## Color

Components use semantic tokens only:

- background
- surface
- elevatedSurface
- primaryText
- secondaryText
- accent / accentSoft
- rest
- reading
- important
- pending
- adjustment
- warning
- critical
- success

State is never communicated by color alone. Use label, symbol, border style, opacity, or text as well.

## Motion

- quick feedback: 160ms ease-out
- spatial/state transition: responsive spring
- calm content change: gentle spring/crossfade
- exit faster than enter
- no motion required for correctness
- Reduce Motion removes floating and scale motion
- animations remain interruptible

## Soft Minimal

- warm neutral background
- quiet green accent
- subtle one-pixel borders
- low-elevation cards
- no mascot requirement
- direct, neutral language

## Pixel Cat

- warm blush accent
- original in-code pixel cat
- cat appears in guidance, onboarding, success, warning, and empty states
- cat does not replace system icons
- cat text stays short
- cat notification voice is independently configurable
- Art direction, ginger-tabby emotion concepts, and the deferred Washi Cat skin are documented in [skin-art-directions.md](../skin-art-directions.md).

## Interaction rules

- one primary action per sheet
- pressed state within 100ms
- destructive action separated and confirmed
- drag always has a button/tap alternative
- inline reasons next to load and conflict states
- no blocking animation
- no surprise automatic schedule changes

## Accessibility checklist

- Dynamic Type
- VoiceOver reading order
- 44pt targets
- sufficient light/dark contrast
- no color-only status
- Reduce Motion
- landscape-safe layout
- sheet cancel routes
- labels for fields and icon buttons
