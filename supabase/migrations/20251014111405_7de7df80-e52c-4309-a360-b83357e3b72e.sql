-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create schools table (one per organization)
CREATE TABLE public.schools (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  logo_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create profiles table linked to auth.users
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create subjects table
CREATE TABLE public.subjects (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create teachers table
CREATE TABLE public.teachers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  max_lessons_per_week INTEGER DEFAULT 25,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create teacher_subjects junction table
CREATE TABLE public.teacher_subjects (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  teacher_id UUID REFERENCES public.teachers(id) ON DELETE CASCADE NOT NULL,
  subject_id UUID REFERENCES public.subjects(id) ON DELETE CASCADE NOT NULL,
  UNIQUE(teacher_id, subject_id)
);

-- Create streams table (e.g., Blue, Pink, Green)
CREATE TABLE public.streams (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
  grade INTEGER NOT NULL CHECK (grade >= 1 AND grade <= 12),
  stream_name TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create teacher responsibilities (which streams they're responsible for)
CREATE TABLE public.teacher_responsibilities (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  teacher_id UUID REFERENCES public.teachers(id) ON DELETE CASCADE NOT NULL,
  stream_id UUID REFERENCES public.streams(id) ON DELETE CASCADE NOT NULL,
  UNIQUE(teacher_id, stream_id)
);

-- Create timetables table
CREATE TABLE public.timetables (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
  stream_id UUID REFERENCES public.streams(id) ON DELETE CASCADE NOT NULL,
  generated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  timetable_data JSONB NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create subscriptions table for billing
CREATE TABLE public.subscriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
  plan_type TEXT NOT NULL DEFAULT 'free_trial',
  status TEXT NOT NULL DEFAULT 'active',
  expires_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS on all tables
ALTER TABLE public.schools ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teacher_subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.streams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teacher_responsibilities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.timetables ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

-- RLS Policies for schools
CREATE POLICY "Users can view their school"
  ON public.schools FOR SELECT
  USING (id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Users can update their school"
  ON public.schools FOR UPDATE
  USING (id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

-- RLS Policies for profiles
CREATE POLICY "Users can view their own profile"
  ON public.profiles FOR SELECT
  USING (id = auth.uid());

CREATE POLICY "Users can insert their own profile"
  ON public.profiles FOR INSERT
  WITH CHECK (id = auth.uid());

CREATE POLICY "Users can update their own profile"
  ON public.profiles FOR UPDATE
  USING (id = auth.uid());

-- RLS Policies for subjects
CREATE POLICY "Users can view subjects in their school"
  ON public.subjects FOR SELECT
  USING (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Users can insert subjects in their school"
  ON public.subjects FOR INSERT
  WITH CHECK (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Users can delete subjects in their school"
  ON public.subjects FOR DELETE
  USING (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

-- RLS Policies for teachers
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

-- RLS Policies for teacher_subjects
CREATE POLICY "Users can view teacher_subjects in their school"
  ON public.teacher_subjects FOR SELECT
  USING (teacher_id IN (SELECT id FROM public.teachers WHERE school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid())));

CREATE POLICY "Users can insert teacher_subjects in their school"
  ON public.teacher_subjects FOR INSERT
  WITH CHECK (teacher_id IN (SELECT id FROM public.teachers WHERE school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid())));

CREATE POLICY "Users can delete teacher_subjects in their school"
  ON public.teacher_subjects FOR DELETE
  USING (teacher_id IN (SELECT id FROM public.teachers WHERE school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid())));

-- RLS Policies for streams
CREATE POLICY "Users can view streams in their school"
  ON public.streams FOR SELECT
  USING (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Users can insert streams in their school"
  ON public.streams FOR INSERT
  WITH CHECK (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Users can delete streams in their school"
  ON public.streams FOR DELETE
  USING (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

-- RLS Policies for teacher_responsibilities
CREATE POLICY "Users can view teacher_responsibilities in their school"
  ON public.teacher_responsibilities FOR SELECT
  USING (teacher_id IN (SELECT id FROM public.teachers WHERE school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid())));

CREATE POLICY "Users can insert teacher_responsibilities in their school"
  ON public.teacher_responsibilities FOR INSERT
  WITH CHECK (teacher_id IN (SELECT id FROM public.teachers WHERE school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid())));

CREATE POLICY "Users can delete teacher_responsibilities in their school"
  ON public.teacher_responsibilities FOR DELETE
  USING (teacher_id IN (SELECT id FROM public.teachers WHERE school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid())));

-- RLS Policies for timetables
CREATE POLICY "Users can view timetables in their school"
  ON public.timetables FOR SELECT
  USING (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Users can insert timetables in their school"
  ON public.timetables FOR INSERT
  WITH CHECK (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

-- RLS Policies for subscriptions
CREATE POLICY "Users can view subscriptions for their school"
  ON public.subscriptions FOR SELECT
  USING (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "Users can update subscriptions for their school"
  ON public.subscriptions FOR UPDATE
  USING (school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid()));

-- Function to handle new user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  new_school_id UUID;
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
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Trigger for new user signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Function to update timestamps
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_schools_updated_at BEFORE UPDATE ON public.schools
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_teachers_updated_at BEFORE UPDATE ON public.teachers
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_subscriptions_updated_at BEFORE UPDATE ON public.subscriptions
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();