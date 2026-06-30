# Profile & User Data

This app uses a `profiles` table to store user information. The table is protected by RLS.

## RLS note (important)

Direct reads like:

- `supabase.from('profiles').select()`

are not allowed anymore for listing users. They will only return the current user (or be blocked), depending on policy.

## Approved RPCs

### 1) List all users (Directory)

```dart
final data = await supabase.rpc('list_directory_profiles');
```

Returns (public directory fields):

- `id, name, role, location, user_role, created_at, email`
- `email` is `null` unless you are connected to that user (or rules allow it).

### 2) Fetch public profiles by IDs (connected users, send flows, requests, etc.)

```dart
final data = await supabase.rpc(
  'get_public_profiles',
  params: {'_ids': userIds},
);
```

Same public fields; `email` is present only for connected users or self.

### 3) Fetch current user full profile

```dart
final data = await supabase.rpc('get_my_profile');
```

Returns the full profile (may include private fields like `email`, `fcm_token`, etc.).

## Display rule for email

If `email == null`, show:

`ID •••• ${profile['id'].substring(profile['id'].length - 4)}`

Example:

- `email`: `null`
- `id`: `c2f8...a91e`
- Display: `ID •••• a91e`

