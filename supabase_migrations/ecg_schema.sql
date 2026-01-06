-- Pan-Tompkins ECG Storage Schema
-- Integrates with existing PULSO database schema
-- Adds Pan-Tompkins specific tables for R-peak detection and session management

-- ============================================================================
-- OPTION 1: Extend existing ecg_readings table (RECOMMENDED)
-- ============================================================================
-- Add columns to existing ecg_readings table to support Pan-Tompkins sessions
-- This approach reuses your existing table structure

-- Add session metadata columns to ecg_readings
ALTER TABLE public.ecg_readings 
  ADD COLUMN IF NOT EXISTS duration_seconds INTEGER,
  ADD COLUMN IF NOT EXISTS average_heart_rate REAL,
  ADD COLUMN IF NOT EXISTS max_heart_rate REAL,
  ADD COLUMN IF NOT EXISTS min_heart_rate REAL,
  ADD COLUMN IF NOT EXISTS r_peak_count INTEGER,
  ADD COLUMN IF NOT EXISTS session_end_time TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS ecg_image_url TEXT;

-- Table: ecg_r_peaks
-- Stores detected R-peaks for each ECG reading/session
CREATE TABLE IF NOT EXISTS public.ecg_r_peaks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reading_id BIGINT NOT NULL REFERENCES public.ecg_readings(reading_id) ON DELETE CASCADE,
    sample_index INTEGER NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    rr_interval REAL NOT NULL,
    instantaneous_bpm REAL NOT NULL,
    amplitude REAL NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_ecg_r_peaks_reading_id ON public.ecg_r_peaks(reading_id);
CREATE INDEX IF NOT EXISTS idx_ecg_r_peaks_sample_index ON public.ecg_r_peaks(reading_id, sample_index);
CREATE INDEX IF NOT EXISTS idx_ecg_r_peaks_timestamp ON public.ecg_r_peaks(timestamp);

-- Row Level Security (RLS) for ecg_r_peaks
ALTER TABLE public.ecg_r_peaks ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view R-peaks for their own readings
CREATE POLICY "Users can view own R-peaks"
    ON public.ecg_r_peaks FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.ecg_readings
            WHERE ecg_readings.reading_id = ecg_r_peaks.reading_id
            AND ecg_readings.user_id = auth.uid()
        )
    );

-- Policy: Users can insert R-peaks for their own readings
CREATE POLICY "Users can insert own R-peaks"
    ON public.ecg_r_peaks FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.ecg_readings
            WHERE ecg_readings.reading_id = ecg_r_peaks.reading_id
            AND ecg_readings.user_id = auth.uid()
        )
    );

-- Policy: Users can delete R-peaks for their own readings
CREATE POLICY "Users can delete own R-peaks"
    ON public.ecg_r_peaks FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.ecg_readings
            WHERE ecg_readings.reading_id = ecg_r_peaks.reading_id
            AND ecg_readings.user_id = auth.uid()
        )
    );

-- ============================================================================
-- OPTION 2: Standalone Pan-Tompkins tables (ALTERNATIVE)
-- ============================================================================
-- Uncomment this section if you prefer separate tables for Pan-Tompkins data
-- This keeps Pan-Tompkins sessions separate from your existing ecg_readings

/*
CREATE TABLE IF NOT EXISTS public.pt_ecg_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE,
    duration_seconds INTEGER NOT NULL,
    average_heart_rate REAL,
    max_heart_rate REAL,
    min_heart_rate REAL,
    r_peak_count INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.pt_r_peaks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES public.pt_ecg_sessions(id) ON DELETE CASCADE,
    sample_index INTEGER NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    rr_interval REAL NOT NULL,
    instantaneous_bpm REAL NOT NULL,
    amplitude REAL NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_pt_sessions_user_id ON public.pt_ecg_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_pt_sessions_created_at ON public.pt_ecg_sessions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pt_r_peaks_session_id ON public.pt_r_peaks(session_id);

-- RLS Policies
ALTER TABLE public.pt_ecg_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pt_r_peaks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own PT sessions"
    ON public.pt_ecg_sessions FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own PT sessions"
    ON public.pt_ecg_sessions FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own PT sessions"
    ON public.pt_ecg_sessions FOR DELETE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can view own PT R-peaks"
    ON public.pt_r_peaks FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.pt_ecg_sessions
            WHERE pt_ecg_sessions.id = pt_r_peaks.session_id
            AND pt_ecg_sessions.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert own PT R-peaks"
    ON public.pt_r_peaks FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.pt_ecg_sessions
            WHERE pt_ecg_sessions.id = pt_r_peaks.session_id
            AND pt_ecg_sessions.user_id = auth.uid()
        )
    );
*/

-- ============================================================================
-- Helper Views
-- ============================================================================

-- View: ECG readings with R-peak statistics
CREATE OR REPLACE VIEW public.ecg_readings_with_stats AS
SELECT 
    r.reading_id,
    r.user_id,
    r.timestamp,
    r.duration_seconds,
    r.average_heart_rate,
    r.max_heart_rate,
    r.min_heart_rate,
    r.r_peak_count,
    r.session_end_time,
    COUNT(p.id) as actual_r_peak_count,
    ARRAY_AGG(p.instantaneous_bpm ORDER BY p.sample_index) FILTER (WHERE p.id IS NOT NULL) as bpm_series
FROM public.ecg_readings r
LEFT JOIN public.ecg_r_peaks p ON r.reading_id = p.reading_id
GROUP BY r.reading_id;

-- Grant access to the view
GRANT SELECT ON public.ecg_readings_with_stats TO authenticated;
