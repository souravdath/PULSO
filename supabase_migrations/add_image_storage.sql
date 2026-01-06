-- ============================================================================
-- ECG Session Image Storage - Incremental Update
-- ============================================================================
-- Run this if you've already applied the previous ecg_schema.sql migration
-- This adds support for storing ECG chart images in Supabase Storage

-- Add image URL column to existing ecg_readings table
ALTER TABLE public.ecg_readings 
  ADD COLUMN IF NOT EXISTS ecg_image_url TEXT;

-- Create storage bucket (run this in Supabase Dashboard → Storage → Create Bucket)
-- Bucket name: ecg-images
-- Public: No (keep private)

-- Storage RLS Policies
-- Run these in Supabase Dashboard → SQL Editor after creating the bucket

-- Allow users to upload their own ECG images
CREATE POLICY "Users can upload own ECG images"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'ecg-images' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow users to view their own ECG images
CREATE POLICY "Users can view own ECG images"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'ecg-images' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow users to delete their own ECG images
CREATE POLICY "Users can delete own ECG images"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'ecg-images' AND
  auth.uid()::text = (storage.foldername(name))[1]
);
