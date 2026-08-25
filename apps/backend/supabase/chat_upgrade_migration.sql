-- Track read timestamps for chats
ALTER TABLE messages ADD COLUMN IF NOT EXISTS read_at TIMESTAMP WITH TIME ZONE;

-- Real-time typing states table
CREATE TABLE IF NOT EXISTS typing_states (
    job_id UUID REFERENCES jobs(id) ON DELETE CASCADE,
    user_id VARCHAR REFERENCES users(id) ON DELETE CASCADE,
    is_typing BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (job_id, user_id)
);

-- Enable Realtime for typing states
ALTER PUBLICATION supabase_realtime ADD TABLE typing_states;
