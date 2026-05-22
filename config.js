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
  SUPABASE_URL: 'https://vqnwdiuxfpibceroglmq.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxbndkaXV4ZnBpYmNlcm9nbG1xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk0Njg1MDQsImV4cCI6MjA5NTA0NDUwNH0.qkVjv4YED9Vmcg_qDvbgHiFSqXdNn3ZEgl0mzCniaHA',

  // Storage bucket name — leave this as 'vehicles' unless you renamed it
  STORAGE_BUCKET: 'vehicles',
};
