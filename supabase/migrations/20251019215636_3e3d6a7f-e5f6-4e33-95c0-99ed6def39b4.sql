-- Ensure admin role can view all data across schools
-- Update RLS policies for admin access using proper syntax

-- Activity Logs: Allow admins to insert
DROP POLICY IF EXISTS "Admins can insert activity logs" ON public.activity_logs;
CREATE POLICY "Admins can insert activity logs" 
ON public.activity_logs 
FOR INSERT 
TO authenticated
WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

-- Schools: Allow admins to view all schools
DROP POLICY IF EXISTS "Admins can view all schools" ON public.schools;
CREATE POLICY "Admins can view all schools" 
ON public.schools 
FOR SELECT 
TO authenticated
USING (has_role(auth.uid(), 'admin'::app_role));

-- Schools: Allow admins to delete schools
DROP POLICY IF EXISTS "Admins can delete schools" ON public.schools;
CREATE POLICY "Admins can delete schools" 
ON public.schools 
FOR DELETE 
TO authenticated
USING (has_role(auth.uid(), 'admin'::app_role));

-- Teachers: Allow admins to view all teachers
DROP POLICY IF EXISTS "Admins can view all teachers" ON public.teachers;
CREATE POLICY "Admins can view all teachers" 
ON public.teachers 
FOR SELECT 
TO authenticated
USING (has_role(auth.uid(), 'admin'::app_role));

-- Streams: Allow admins to view all streams
DROP POLICY IF EXISTS "Admins can view all streams" ON public.streams;
CREATE POLICY "Admins can view all streams" 
ON public.streams 
FOR SELECT 
TO authenticated
USING (has_role(auth.uid(), 'admin'::app_role));

-- Subjects: Allow admins to view all subjects
DROP POLICY IF EXISTS "Admins can view all subjects" ON public.subjects;
CREATE POLICY "Admins can view all subjects" 
ON public.subjects 
FOR SELECT 
TO authenticated
USING (has_role(auth.uid(), 'admin'::app_role));

-- Timetables: Allow admins to view all timetables
DROP POLICY IF EXISTS "Admins can view all timetables" ON public.timetables;
CREATE POLICY "Admins can view all timetables" 
ON public.timetables 
FOR SELECT 
TO authenticated
USING (has_role(auth.uid(), 'admin'::app_role));

-- Timetables: Allow admins to insert timetables for any school
DROP POLICY IF EXISTS "Admins can insert timetables for any school" ON public.timetables;
CREATE POLICY "Admins can insert timetables for any school" 
ON public.timetables 
FOR INSERT 
TO authenticated
WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

-- Subscriptions: Allow admins to view all subscriptions
DROP POLICY IF EXISTS "Admins can view all subscriptions" ON public.subscriptions;
CREATE POLICY "Admins can view all subscriptions" 
ON public.subscriptions 
FOR SELECT 
TO authenticated
USING (has_role(auth.uid(), 'admin'::app_role));