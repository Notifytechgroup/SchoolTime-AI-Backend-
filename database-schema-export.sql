-- =====================================================
-- Complete Supabase Database Schema Export
-- =====================================================
-- This SQL file contains the complete database schema including:
-- - Enums
-- - Tables with all columns and constraints
-- - Functions
-- - Triggers
-- - Row Level Security (RLS) policies
-- - Storage buckets and policies
-- =====================================================

-- =====================================================
-- EXTENSIONS
-- =====================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- ENUMS
-- =====================================================
CREATE TYPE public.app_role AS ENUM ('admin', 'user');

-- =====================================================
-- TABLES
-- =====================================================

-- Schools Table
CREATE TABLE public.schools (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    name TEXT NOT NULL,
    timetable_template TEXT DEFAULT 'classic',
    type TEXT DEFAULT 'primary',
    location TEXT,
    logo_url TEXT
);

-- Profiles Table
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY,
    full_name TEXT NOT NULL,
    email TEXT NOT NULL,
    school_id UUID NOT NULL REFERENCES public.schools(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- User Roles Table
CREATE TABLE public.user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    role public.app_role NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE (user_id, role)
);

-- Subscriptions Table
CREATE TABLE public.subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_id UUID NOT NULL REFERENCES public.schools(id),
    plan_type TEXT NOT NULL DEFAULT 'free_trial',
    status TEXT NOT NULL DEFAULT 'active',
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Streams Table
CREATE TABLE public.streams (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_id UUID NOT NULL REFERENCES public.schools(id),
    stream_name TEXT NOT NULL,
    grade INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Subjects Table
CREATE TABLE public.subjects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_id UUID NOT NULL REFERENCES public.schools(id),
    name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Teachers Table
CREATE TABLE public.teachers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_id UUID NOT NULL REFERENCES public.schools(id),
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    availability JSONB DEFAULT '{"monday": ["8:00-16:00"], "tuesday": ["8:00-16:00"], "wednesday": ["8:00-16:00"], "thursday": ["8:00-16:00"], "friday": ["8:00-16:00"]}'::jsonb,
    workload INTEGER DEFAULT 20,
    max_lessons_per_week INTEGER DEFAULT 25,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Teacher Subjects Table
CREATE TABLE public.teacher_subjects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID NOT NULL REFERENCES public.teachers(id),
    subject_id UUID NOT NULL REFERENCES public.subjects(id)
);

-- Teacher Responsibilities Table
CREATE TABLE public.teacher_responsibilities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID NOT NULL REFERENCES public.teachers(id),
    stream_id UUID NOT NULL REFERENCES public.streams(id)
);

-- Templates Table
CREATE TABLE public.templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    school_type TEXT NOT NULL,
    description TEXT,
    structure_config JSONB NOT NULL,
    start_time TIME WITHOUT TIME ZONE NOT NULL DEFAULT '08:00:00',
    end_time TIME WITHOUT TIME ZONE NOT NULL DEFAULT '16:00:00',
    period_duration INTEGER NOT NULL DEFAULT 40,
    periods_per_day INTEGER NOT NULL DEFAULT 8,
    days_per_week INTEGER NOT NULL DEFAULT 5,
    break_config JSONB DEFAULT '[]'::jsonb,
    rules JSONB DEFAULT '{}'::jsonb,
    preview_image TEXT,
    is_deployed BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_by UUID,
    usage_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Timetables Table
CREATE TABLE public.timetables (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_id UUID NOT NULL REFERENCES public.schools(id),
    stream_id UUID NOT NULL REFERENCES public.streams(id),
    timetable_data JSONB NOT NULL,
    template_type TEXT,
    generated_by TEXT DEFAULT 'AI',
    generated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Constraints Table
CREATE TABLE public.constraints (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_id UUID NOT NULL REFERENCES public.schools(id),
    rule TEXT NOT NULL,
    level TEXT NOT NULL,
    details JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Uploads Table
CREATE TABLE public.uploads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_id UUID NOT NULL REFERENCES public.schools(id),
    type TEXT NOT NULL,
    file_url TEXT NOT NULL,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Activity Logs Table
CREATE TABLE public.activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    activity_type TEXT NOT NULL,
    description TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    school_id UUID REFERENCES public.schools(id),
    user_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- =====================================================
-- FUNCTIONS
-- =====================================================

-- Function to check if a user has a specific role
CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role app_role)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE user_id = _user_id
      AND role = _role
  )
$$;

-- Function to handle new user registration
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_school_id UUID;
  user_role app_role;
BEGIN
  -- Create a new school
  INSERT INTO public.schools (name)
  VALUES (NEW.raw_user_meta_data->>'school_name')
  RETURNING id INTO new_school_id;
  
  -- Create the user profile
  INSERT INTO public.profiles (id, full_name, email, school_id)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'full_name',
    NEW.email,
    new_school_id
  );
  
  -- Create a free trial subscription
  INSERT INTO public.subscriptions (school_id, plan_type, status, expires_at)
  VALUES (
    new_school_id,
    'free_trial',
    'active',
    NOW() + INTERVAL '14 days'
  );
  
  -- Determine role based on email
  IF NEW.email IN (
    'leemwangi250@gmail.com',
    'notifytechgroup@gmail.com',
    'maobenigel@gmail.com',
    'otondeotondenigel@gmail.com',
    'wanyagagloria43@gmail.com'
  ) THEN
    user_role := 'admin'::app_role;
  ELSE
    user_role := 'user'::app_role;
  END IF;
  
  -- Assign role
  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.id, user_role);
  
  RETURN NEW;
END;
$$;

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- =====================================================
-- TRIGGERS
-- =====================================================

-- Trigger for new user registration
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Triggers for updated_at columns
CREATE TRIGGER update_schools_updated_at
  BEFORE UPDATE ON public.schools
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_subscriptions_updated_at
  BEFORE UPDATE ON public.subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_teachers_updated_at
  BEFORE UPDATE ON public.teachers
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_templates_updated_at
  BEFORE UPDATE ON public.templates
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- =====================================================
-- ROW LEVEL SECURITY (RLS)
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE public.schools ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.streams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teacher_subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teacher_responsibilities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.timetables ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.constraints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.uploads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- RLS POLICIES: Schools
-- =====================================================
CREATE POLICY "Users can view their school"
  ON public.schools FOR SELECT
  USING (id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Users can update their school"
  ON public.schools FOR UPDATE
  USING (id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Admins can view all schools"
  ON public.schools FOR SELECT
  USING (public.has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can delete schools"
  ON public.schools FOR DELETE
  USING (public.has_role(auth.uid(), 'admin'::app_role));

-- =====================================================
-- RLS POLICIES: Profiles
-- =====================================================
CREATE POLICY "Users can view their own profile"
  ON public.profiles FOR SELECT
  USING (id = auth.uid());

CREATE POLICY "Users can insert their own profile"
  ON public.profiles FOR INSERT
  WITH CHECK (id = auth.uid());

CREATE POLICY "Users can update their own profile"
  ON public.profiles FOR UPDATE
  USING (id = auth.uid());

CREATE POLICY "Admins can view all profiles"
  ON public.profiles FOR SELECT
  USING (public.has_role(auth.uid(), 'admin'::app_role));

-- =====================================================
-- RLS POLICIES: User Roles
-- =====================================================
CREATE POLICY "Users can view their own roles"
  ON public.user_roles FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Admins can view all roles"
  ON public.user_roles FOR SELECT
  USING (public.has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can view all user roles"
  ON public.user_roles FOR SELECT
  USING (public.has_role(auth.uid(), 'admin'::app_role));

-- =====================================================
-- RLS POLICIES: Subscriptions
-- =====================================================
CREATE POLICY "Users can view subscriptions for their school"
  ON public.subscriptions FOR SELECT
  USING (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Users can update subscriptions for their school"
  ON public.subscriptions FOR UPDATE
  USING (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Admins can view all subscriptions"
  ON public.subscriptions FOR SELECT
  USING (public.has_role(auth.uid(), 'admin'::app_role));

-- =====================================================
-- RLS POLICIES: Streams
-- =====================================================
CREATE POLICY "Users can view streams in their school"
  ON public.streams FOR SELECT
  USING (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Users can insert streams in their school"
  ON public.streams FOR INSERT
  WITH CHECK (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Users can delete streams in their school"
  ON public.streams FOR DELETE
  USING (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Admins can view all streams"
  ON public.streams FOR SELECT
  USING (public.has_role(auth.uid(), 'admin'::app_role));

-- =====================================================
-- RLS POLICIES: Subjects
-- =====================================================
CREATE POLICY "Users can view subjects in their school"
  ON public.subjects FOR SELECT
  USING (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Users can insert subjects in their school"
  ON public.subjects FOR INSERT
  WITH CHECK (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Users can delete subjects in their school"
  ON public.subjects FOR DELETE
  USING (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Admins can view all subjects"
  ON public.subjects FOR SELECT
  USING (public.has_role(auth.uid(), 'admin'::app_role));

-- =====================================================
-- RLS POLICIES: Teachers
-- =====================================================
CREATE POLICY "Users can view teachers in their school"
  ON public.teachers FOR SELECT
  USING (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Users can insert teachers in their school"
  ON public.teachers FOR INSERT
  WITH CHECK (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Users can update teachers in their school"
  ON public.teachers FOR UPDATE
  USING (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Users can delete teachers in their school"
  ON public.teachers FOR DELETE
  USING (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Admins can view all teachers"
  ON public.teachers FOR SELECT
  USING (public.has_role(auth.uid(), 'admin'::app_role));

-- =====================================================
-- RLS POLICIES: Teacher Subjects
-- =====================================================
CREATE POLICY "Users can view teacher_subjects in their school"
  ON public.teacher_subjects FOR SELECT
  USING (teacher_id IN (SELECT id FROM public.teachers WHERE school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid())));

CREATE POLICY "Users can insert teacher_subjects in their school"
  ON public.teacher_subjects FOR INSERT
  WITH CHECK (teacher_id IN (SELECT id FROM public.teachers WHERE school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid())));

CREATE POLICY "Users can delete teacher_subjects in their school"
  ON public.teacher_subjects FOR DELETE
  USING (teacher_id IN (SELECT id FROM public.teachers WHERE school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid())));

-- =====================================================
-- RLS POLICIES: Teacher Responsibilities
-- =====================================================
CREATE POLICY "Users can view teacher_responsibilities in their school"
  ON public.teacher_responsibilities FOR SELECT
  USING (teacher_id IN (SELECT id FROM public.teachers WHERE school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid())));

CREATE POLICY "Users can insert teacher_responsibilities in their school"
  ON public.teacher_responsibilities FOR INSERT
  WITH CHECK (teacher_id IN (SELECT id FROM public.teachers WHERE school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid())));

CREATE POLICY "Users can delete teacher_responsibilities in their school"
  ON public.teacher_responsibilities FOR DELETE
  USING (teacher_id IN (SELECT id FROM public.teachers WHERE school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid())));

-- =====================================================
-- RLS POLICIES: Templates
-- =====================================================
CREATE POLICY "Users can view active templates"
  ON public.templates FOR SELECT
  USING (is_active = true);

CREATE POLICY "Admins can view all templates"
  ON public.templates FOR SELECT
  USING (public.has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can insert templates"
  ON public.templates FOR INSERT
  WITH CHECK (public.has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can update templates"
  ON public.templates FOR UPDATE
  USING (public.has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can delete templates"
  ON public.templates FOR DELETE
  USING (public.has_role(auth.uid(), 'admin'::app_role));

-- =====================================================
-- RLS POLICIES: Timetables
-- =====================================================
CREATE POLICY "Users can view timetables in their school"
  ON public.timetables FOR SELECT
  USING (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Users can insert timetables in their school"
  ON public.timetables FOR INSERT
  WITH CHECK (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Admins can view all timetables"
  ON public.timetables FOR SELECT
  USING (public.has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can insert timetables for any school"
  ON public.timetables FOR INSERT
  WITH CHECK (public.has_role(auth.uid(), 'admin'::app_role));

-- =====================================================
-- RLS POLICIES: Constraints
-- =====================================================
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

-- =====================================================
-- RLS POLICIES: Uploads
-- =====================================================
CREATE POLICY "Users can view uploads in their school"
  ON public.uploads FOR SELECT
  USING (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Users can insert uploads in their school"
  ON public.uploads FOR INSERT
  WITH CHECK (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Users can delete uploads in their school"
  ON public.uploads FOR DELETE
  USING (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

-- =====================================================
-- RLS POLICIES: Activity Logs
-- =====================================================
CREATE POLICY "Admins can view all activity logs"
  ON public.activity_logs FOR SELECT
  USING (public.has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can insert activity logs"
  ON public.activity_logs FOR INSERT
  WITH CHECK (public.has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "System can insert activity logs"
  ON public.activity_logs FOR INSERT
  WITH CHECK (true);

-- =====================================================
-- STORAGE BUCKETS
-- =====================================================
-- Note: Storage buckets need to be created via Supabase dashboard or CLI
-- Bucket: timetable-uploads (private)
-- Bucket: template-images (public)

-- Storage policies for timetable-uploads
CREATE POLICY "Users can view uploads in their school"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'timetable-uploads' AND auth.uid()::text IN (
    SELECT id::text FROM public.profiles WHERE school_id IN (
      SELECT school_id FROM public.profiles WHERE id = auth.uid()
    )
  ));

CREATE POLICY "Users can upload to their school folder"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'timetable-uploads' AND auth.uid()::text IN (
    SELECT id::text FROM public.profiles WHERE school_id IN (
      SELECT school_id FROM public.profiles WHERE id = auth.uid()
    )
  ));

-- Storage policies for template-images (public bucket)
CREATE POLICY "Anyone can view template images"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'template-images');

CREATE POLICY "Admins can upload template images"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'template-images' AND public.has_role(auth.uid(), 'admin'::app_role));

-- =====================================================
-- END OF SCHEMA EXPORT
-- =====================================================
