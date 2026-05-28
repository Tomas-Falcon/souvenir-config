# NFC Souvenirs Platform

## Overview
The platform links unique hardware identifiers (NFC Tags) with multimedia collections in the cloud.

## Project Structure
- `app/`: Mobile application (Full App & Instant Apps).
- `backend/`: Supabase configuration, migrations, and edge functions.
- `scripts/`: Production scripts (Tag writing, batch processing).
- `docs/`: Architectural documentation and requirements.

## Architecture
- **Backend:** Supabase (PostgreSQL, Auth, Storage).
- **Mobile:** Flutter/React Native (Full App) + Native (Instant Apps).
- **Hardware:** NTAG215 Anti-Metal.

## Database Schema (Planned)
- `Users`: ID, email, created_at.
- `Tags`: UUID, status (unassigned, active), album_id (FK), batch_id.
- `Albums`: ID, user_id (FK), title, cover_url, is_private, pin_code.
- `Media`: ID, album_id (FK), type (image/video), url, order_index.
