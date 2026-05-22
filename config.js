// =====================================================
// SASP TEU — Supabase Configuration
// =====================================================
// Get these values from your Supabase project:
//   1. Go to https://app.supabase.com
//   2. Open your project
//   3. Settings (gear icon) → API
//   4. Copy "Project URL" → SUPABASE_URL below
//   5. Copy "anon public" key → SUPABASE_ANON_KEY below
//
// The anon key is SAFE to put in client-side code — that's what it's for.
// Row-Level Security (RLS) in your DB controls who can do what.
// =====================================================

window.SUPABASE_CONFIG = {
  SUPABASE_URL: 'https://vqnwdiuxfpibceroglmq.supabase.co/rest/v1/',
  SUPABASE_ANON_KEY: 'sb_secret_JaXwR7SMTAo3OC1tcus4rg_u0J9HO65',

  // Storage bucket name — leave this as 'vehicles' unless you renamed it
  STORAGE_BUCKET: 'vehicles',
};
