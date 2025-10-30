-- Add is_deployed field to templates table for marking templates available to all schools
ALTER TABLE templates ADD COLUMN IF NOT EXISTS is_deployed BOOLEAN DEFAULT FALSE;

-- Create storage bucket for template images if not exists
INSERT INTO storage.buckets (id, name, public) 
VALUES ('template-images', 'template-images', true)
ON CONFLICT (id) DO NOTHING;