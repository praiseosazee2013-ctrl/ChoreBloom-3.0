CHOREBLOOM 3.0 — SHARED ONLINE STARTER

This version adds email/password accounts, groups, invite codes, shared chores,
member lists, points and live chore-board updates using Supabase.

IMPORTANT: This is a starter project. You must configure Supabase and test it
before inviting anyone. Ask a parent/guardian to help with online accounts and
publishing. Never put a Supabase service_role/secret key in website files.

SET UP SUPABASE
1. Create a Supabase project with help from a parent/guardian.
2. Open SQL Editor in the Supabase dashboard.
3. Open supabase-setup.sql from this folder, copy all of it, paste into SQL Editor
   and run it.
4. In Supabase project settings, find the Project URL and publishable/anon key.
5. Open config.js and replace the two PASTE... values with those settings.
   Use only the publishable/anon key, never the service_role/secret key.
6. In Supabase Authentication settings, configure the allowed site URL and
   redirect URLs to your GitHub Pages address once published.
7. For email confirmation, use the confirmation link sent by Supabase.

PUBLISH WITH GITHUB PAGES
1. Sign in to GitHub (ask a parent/guardian to help if needed).
2. Create a new public repository named ChoreBloom.
3. Upload the CONTENTS of this folder (not the ZIP file itself) to the repository.
4. Open Settings > Pages.
5. Under Build and deployment, choose Deploy from a branch, select main and /(root),
   then Save.
6. Wait for the Pages deployment and open the published URL.
7. In Supabase Authentication URL settings, add that exact URL to Site URL and
   Redirect URLs. Test sign-up, sign-in, group creation, invite joining and chores.

DOWNLOAD / INSTALL
- The ZIP is a downloadable project backup.
- The published website can be installed as a PWA in supported browsers (for
  example Edge > ... > Apps > Install this site as an app).
- Google Play: a PWA is not automatically listed in Play Store. Publishing there
  requires an Android app package (often a Trusted Web Activity or wrapper),
  Play Console setup, testing, store listing and review. A parent/guardian should
  handle developer registration and publishing. This ZIP is not an Android APK.

LIMITATIONS / SAFETY
- Invite codes are like keys: share privately only with trusted people.
- This starter has no password reset screen or admin member-removal UI yet.
- Group data is protected by Supabase Row Level Security policies in the SQL.
- Review and test security policies before real use. Never add private addresses,
  school details, phone numbers or sensitive information to group profiles.
- Offline mode only caches the app shell; shared data needs internet access.
