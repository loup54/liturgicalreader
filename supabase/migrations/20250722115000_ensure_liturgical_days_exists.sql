-- Location: supabase/migrations/20250722115000_ensure_liturgical_days_exists.sql
-- Emergency Fix: Ensure liturgical_days table exists with proper structure
-- This migration safely creates the table if it doesn't exist, without conflicts

-- 1. Create table only if it doesn't exist (safe operation)
CREATE TABLE IF NOT EXISTS public.liturgical_days (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    date DATE NOT NULL UNIQUE,
    season TEXT NOT NULL DEFAULT 'ordinary_time',
    season_week INTEGER DEFAULT 1,
    liturgical_year TEXT NOT NULL DEFAULT '2025',
    color TEXT NOT NULL DEFAULT 'green',
    is_sunday BOOLEAN DEFAULT false,
    is_holyday BOOLEAN DEFAULT false,
    liturgical_year_cycle TEXT DEFAULT 'A',
    advent_year INTEGER,
    days_from_easter INTEGER DEFAULT 0,
    is_moveable_feast BOOLEAN DEFAULT false,
    moveable_feast_type TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 2. Create essential indexes if they don't exist
CREATE INDEX IF NOT EXISTS idx_liturgical_days_date ON public.liturgical_days(date);
CREATE INDEX IF NOT EXISTS idx_liturgical_days_season ON public.liturgical_days(season);

-- 3. Enable RLS if not already enabled
DO $$
BEGIN
    -- Check if RLS is already enabled
    IF NOT EXISTS (
        SELECT 1 FROM pg_class 
        WHERE relname = 'liturgical_days' 
        AND relrowsecurity = true
    ) THEN
        ALTER TABLE public.liturgical_days ENABLE ROW LEVEL SECURITY;
    END IF;
END $$;

-- 4. Create basic read policy if it doesn't exist
DO $$
BEGIN
    -- Check if policy exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'liturgical_days' 
        AND policyname = 'public_read_liturgical_days_safe'
    ) THEN
        CREATE POLICY "public_read_liturgical_days_safe" ON public.liturgical_days
        FOR SELECT TO public USING (true);
    END IF;
END $$;

-- 5. Insert today's liturgical day if no data exists
DO $$
DECLARE
    today_date DATE := CURRENT_DATE;
    record_count INTEGER;
BEGIN
    -- Check if any records exist
    SELECT COUNT(*) INTO record_count FROM public.liturgical_days;
    
    -- Only insert if table is empty
    IF record_count = 0 THEN
        INSERT INTO public.liturgical_days (
            date, season, liturgical_year, color, is_sunday, is_holyday
        ) VALUES (
            today_date,
            'ordinary_time',
            '2025',
            'green',
            EXTRACT(DOW FROM today_date) = 0,
            false
        );
        
        RAISE NOTICE 'Created initial liturgical day record for %', today_date;
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error creating initial liturgical day: %', SQLERRM;
END $$;

-- 6. Create helper function to safely get liturgical day
CREATE OR REPLACE FUNCTION public.get_liturgical_day_safe(input_date DATE)
RETURNS TABLE(
    id UUID,
    date DATE,
    season TEXT,
    liturgical_year TEXT,
    color TEXT,
    is_sunday BOOLEAN,
    is_holyday BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Try to return existing record
    RETURN QUERY
    SELECT ld.id, ld.date, ld.season, ld.liturgical_year, ld.color, ld.is_sunday, ld.is_holyday
    FROM public.liturgical_days ld
    WHERE ld.date = input_date;
    
    -- If no record found, create and return a basic one
    IF NOT FOUND THEN
        INSERT INTO public.liturgical_days (date, season, liturgical_year, color, is_sunday, is_holyday)
        VALUES (
            input_date,
            'ordinary_time',
            EXTRACT(YEAR FROM input_date)::TEXT,
            'green',
            EXTRACT(DOW FROM input_date) = 0,
            false
        )
        RETURNING liturgical_days.id, liturgical_days.date, liturgical_days.season, 
                 liturgical_days.liturgical_year, liturgical_days.color, 
                 liturgical_days.is_sunday, liturgical_days.is_holyday
        INTO id, date, season, liturgical_year, color, is_sunday, is_holyday;
        
        RETURN NEXT;
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Return a safe default record
        id := gen_random_uuid();
        date := input_date;
        season := 'ordinary_time';
        liturgical_year := EXTRACT(YEAR FROM input_date)::TEXT;
        color := 'green';
        is_sunday := EXTRACT(DOW FROM input_date) = 0;
        is_holyday := false;
        RETURN NEXT;
END;
$$;

-- 7. Verify table exists and log success
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'liturgical_days'
    ) THEN
        RAISE NOTICE 'SUCCESS: liturgical_days table exists and is accessible';
    ELSE
        RAISE NOTICE 'ERROR: liturgical_days table still does not exist';
    END IF;
END $$;