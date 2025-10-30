-- Create enum for roles
CREATE TYPE public.app_role AS ENUM ('admin', 'user');

-- Create user_roles table
CREATE TABLE public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  role app_role NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE (user_id, role)
);

-- Enable RLS
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- Create security definer function to check roles
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

-- RLS policies for user_roles
CREATE POLICY "Users can view their own roles"
ON public.user_roles
FOR SELECT
USING (user_id = auth.uid());

-- Only allow viewing roles, not modifying (admin management would be separate)
CREATE POLICY "Admins can view all roles"
ON public.user_roles
FOR SELECT
USING (public.has_role(auth.uid(), 'admin'));

-- Insert admin roles for existing admin emails
INSERT INTO public.user_roles (user_id, role)
SELECT id, 'admin'::app_role
FROM auth.users
WHERE email IN (
  'leemwangi250@gmail.com',
  'notifytechgroup@gmail.com',
  'maobenigel@gmail.com',
  'otondeotondenigel@gmail.com',
  'wanyagagloria43@gmail.com'
)
ON CONFLICT (user_id, role) DO NOTHING;

-- Update the handle_new_user function to assign default 'user' role
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
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
  
  -- Assign default user role
  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.id, 'user'::app_role);
  
  RETURN NEW;
END;
$function$;