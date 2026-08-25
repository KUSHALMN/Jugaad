import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL || 'https://ampsqwrdldvkldjwckrb.supabase.co';
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFtcHNxd3JkbGR2a2xkandja3JiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk5NjY1NzksImV4cCI6MjA5NTU0MjU3OX0.AUK6KqOeg-Vd9uMRy4DGD9qzfuytxPnTy0LLXnzgViI';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
