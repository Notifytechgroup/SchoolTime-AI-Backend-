-- Add timetable_template column to schools table
ALTER TABLE public.schools 
ADD COLUMN timetable_template text DEFAULT 'classic';

-- Add comment for clarity
COMMENT ON COLUMN public.schools.timetable_template IS 'Selected timetable display template (classic, modern, minimal, colorful)';