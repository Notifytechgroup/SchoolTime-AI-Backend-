-- Add school type to schools table
ALTER TABLE public.schools 
ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'primary' 
CHECK (type IN ('primary', 'secondary', 'college', 'university', 'training', 'international')),
ADD COLUMN IF NOT EXISTS location TEXT;

-- Add workload and availability to teachers
ALTER TABLE public.teachers 
ADD COLUMN IF NOT EXISTS workload INTEGER DEFAULT 20,
ADD COLUMN IF NOT EXISTS availability JSONB DEFAULT '{"monday": ["8:00-16:00"], "tuesday": ["8:00-16:00"], "wednesday": ["8:00-16:00"], "thursday": ["8:00-16:00"], "friday": ["8:00-16:00"]}'::jsonb;

-- Add generated_by and template_type to timetables
ALTER TABLE public.timetables 
ADD COLUMN IF NOT EXISTS generated_by TEXT DEFAULT 'AI',
ADD COLUMN IF NOT EXISTS template_type TEXT;

-- Create constraints table
CREATE TABLE IF NOT EXISTS public.constraints (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  rule TEXT NOT NULL,
  level TEXT NOT NULL CHECK (level IN ('class', 'teacher', 'school')),
  details JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create uploads table
CREATE TABLE IF NOT EXISTS public.uploads (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  file_url TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('past_tt', 'teachers', 'subjects')),
  uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS on new tables
ALTER TABLE public.constraints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.uploads ENABLE ROW LEVEL SECURITY;

-- RLS policies for constraints
CREATE POLICY "Users can view constraints in their school"
  ON public.constraints FOR SELECT
  USING (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Users can insert constraints in their school"
  ON public.constraints FOR INSERT
  WITH CHECK (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Users can update constraints in their school"
  ON public.constraints FOR UPDATE
  USING (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Users can delete constraints in their school"
  ON public.constraints FOR DELETE
  USING (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

-- RLS policies for uploads
CREATE POLICY "Users can view uploads in their school"
  ON public.uploads FOR SELECT
  USING (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Users can insert uploads in their school"
  ON public.uploads FOR INSERT
  WITH CHECK (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Users can delete uploads in their school"
  ON public.uploads FOR DELETE
  USING (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

-- Create storage bucket for timetable uploads
INSERT INTO storage.buckets (id, name, public)
VALUES ('timetable-uploads', 'timetable-uploads', false)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for timetable uploads
CREATE POLICY "Users can upload files to their school folder"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'timetable-uploads' AND
    (storage.foldername(name))[1] IN (
      SELECT school_id::text FROM public.profiles WHERE id = auth.uid()
    )
  );

CREATE POLICY "Users can view their school files"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'timetable-uploads' AND
    (storage.foldername(name))[1] IN (
      SELECT school_id::text FROM public.profiles WHERE id = auth.uid()
    )
  );

CREATE POLICY "Users can delete their school files"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'timetable-uploads' AND
    (storage.foldername(name))[1] IN (
      SELECT school_id::text FROM public.profiles WHERE id = auth.uid()
    )
  );