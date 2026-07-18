# Debug Session: signup-email-failure
- **Status**: [OPEN]
- **Issue**: Signup shows "Couldn't send email. Please try again shortly." instead of the real failure reason.
- **Debug Server**: http://127.0.0.1:8787/event
- **Log File**: .dbg/trae-debug-log-signup-email-failure.ndjson

## Reproduction Steps
1. Open the app.
2. Go to sign up.
3. Enter full name, email, password, and role.
4. Submit signup.
5. Observe the red error banner.

## Hypotheses & Verification
| ID | Hypothesis | Likelihood | Effort | Evidence |
|----|------------|------------|--------|----------|
| A | The edge function returns a non-2xx error and the client still collapses it to the generic fallback. | High | Low | Rejected: runtime log shows an exception path, not a handled non-2xx response object. |
| B | The edge function returns `200` with `success: false` and a message that the client is not extracting correctly. | High | Low | Rejected: runtime log shows no successful response payload. |
| C | The signup request reaches Supabase but server-side validation or missing configuration causes the email send to fail. | Medium | Medium | Confirmed: `FunctionException(status: 400, details: {error: Please enter your full name.})`. |
| D | The running app build does not include the latest auth-service patch, so the old message path is still active. | Medium | Low | Rejected: instrumentation logs were received from the rebuilt app. |

## Log Evidence
- `supabase_auth_service.dart:signUp:beforeInvoke` logged `hasFullName: true`
- `supabase_auth_service.dart:signUp:exception` logged `FunctionException(status: 400, details: {error: Please enter your full name.})`
- Applied fix: send `fullName`, `full_name`, and `name` in the function payload and surface `FunctionException.details` to the UI.

## Verification Conclusion
- Pre-fix: non-empty full name in app, but server rejected signup with "Please enter your full name."
- Post-fix: pending user verification after payload compatibility fix and improved error surfacing.
