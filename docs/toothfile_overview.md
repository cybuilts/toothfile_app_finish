# What is Toothfile?

Toothfile is a file-sharing and workflow app built for dental teams.

## Core ideas

- Share files securely between connected users.
- Support sending files to your own devices (multi-device workflows).
- Track and manage lab/order form workflows in-app.

## Main features (high level)

- **Send / Receive Files**: Upload files to Supabase Storage and register metadata in `shared_files`.
- **Directory + Connections**: Discover users, connect, and safely reveal contact info (email) only when permitted.
- **Devices**: Register each device, show online/offline status, and route files to a specific device or broadcast to all.
- **Orders**: Create and manage dental order forms and attachments.

## Data privacy & access rules

- Most tables use Row Level Security (RLS). The Flutter app must use the approved access methods (RPC functions where required).
- Profile email visibility is conditional: if `email` is `null`, treat it as “not visible” and show a masked ID label.

