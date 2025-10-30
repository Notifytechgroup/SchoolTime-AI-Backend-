-- Create templates table for admin-managed timetable templates
CREATE TABLE public.templates (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  school_type TEXT NOT NULL,
  description TEXT,
  periods_per_day INTEGER NOT NULL DEFAULT 8,
  period_duration INTEGER NOT NULL DEFAULT 40,
  days_per_week INTEGER NOT NULL DEFAULT 5,
  start_time TIME NOT NULL DEFAULT '08:00:00',
  end_time TIME NOT NULL DEFAULT '16:00:00',
  break_config JSONB DEFAULT '[]'::jsonb,
  structure_config JSONB NOT NULL,
  rules JSONB DEFAULT '{}'::jsonb,
  preview_image TEXT,
  is_active BOOLEAN DEFAULT true,
  usage_count INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  created_by UUID REFERENCES auth.users(id)
);

-- Enable RLS
ALTER TABLE public.templates ENABLE ROW LEVEL SECURITY;

-- Admins can do everything with templates
CREATE POLICY "Admins can view all templates"
  ON public.templates FOR SELECT
  USING (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can insert templates"
  ON public.templates FOR INSERT
  WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can update templates"
  ON public.templates FOR UPDATE
  USING (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can delete templates"
  ON public.templates FOR DELETE
  USING (has_role(auth.uid(), 'admin'::app_role));

-- Users can view active templates
CREATE POLICY "Users can view active templates"
  ON public.templates FOR SELECT
  USING (is_active = true);

-- Create activity_logs table for real-time activity feed
CREATE TABLE public.activity_logs (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  activity_type TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  user_id UUID REFERENCES auth.users(id),
  school_id UUID REFERENCES public.schools(id),
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

-- Admins can view all activity logs
CREATE POLICY "Admins can view all activity logs"
  ON public.activity_logs FOR SELECT
  USING (has_role(auth.uid(), 'admin'::app_role));

-- System can insert activity logs
CREATE POLICY "System can insert activity logs"
  ON public.activity_logs FOR INSERT
  WITH CHECK (true);

-- Create trigger for updated_at on templates
CREATE TRIGGER update_templates_updated_at
  BEFORE UPDATE ON public.templates
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Create index for activity logs ordering
CREATE INDEX idx_activity_logs_created_at ON public.activity_logs(created_at DESC);