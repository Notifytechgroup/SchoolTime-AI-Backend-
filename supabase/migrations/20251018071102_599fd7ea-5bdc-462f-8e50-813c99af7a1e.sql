-- Update the handle_new_user function to automatically assign admin role to specific emails
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
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
$function$;