-- Location: supabase/migrations/20250722110000_liturgical_calendar_calculator.sql
-- Liturgical Calendar Calculator - Step 2: Date-to-Reading Mapping System
-- Comprehensive liturgical year calculator with Easter calculation and moveable feasts

-- 1. Additional Types for Enhanced Calendar System
CREATE TYPE public.liturgical_year_cycle AS ENUM ('A', 'B', 'C');
CREATE TYPE public.moveable_feast_type AS ENUM (
    'ash_wednesday', 'palm_sunday', 'holy_thursday', 'good_friday', 
    'easter_sunday', 'divine_mercy_sunday', 'ascension', 'pentecost',
    'trinity_sunday', 'corpus_christi', 'sacred_heart', 'christ_the_king'
);

-- 2. Enhanced Liturgical Days Table Updates
ALTER TABLE public.liturgical_days 
ADD COLUMN IF NOT EXISTS liturgical_year_cycle public.liturgical_year_cycle,
ADD COLUMN IF NOT EXISTS advent_year INTEGER,
ADD COLUMN IF NOT EXISTS days_from_easter INTEGER,
ADD COLUMN IF NOT EXISTS is_moveable_feast BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS moveable_feast_type public.moveable_feast_type;

-- 3. Moveable Feasts Calculation Table
CREATE TABLE IF NOT EXISTS public.moveable_feasts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    year INTEGER NOT NULL,
    feast_type public.moveable_feast_type NOT NULL,
    date DATE NOT NULL,
    liturgical_year_cycle public.liturgical_year_cycle NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(year, feast_type)
);

-- 4. Liturgical Year Boundaries Table
CREATE TABLE IF NOT EXISTS public.liturgical_year_boundaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    liturgical_year INTEGER NOT NULL, -- e.g., 2024 for 2024-2025 liturgical year
    cycle public.liturgical_year_cycle NOT NULL,
    first_sunday_advent DATE NOT NULL,
    christmas_date DATE NOT NULL,
    ash_wednesday DATE NOT NULL,
    easter_date DATE NOT NULL,
    pentecost_date DATE NOT NULL,
    first_sunday_ordinary_time DATE NOT NULL,
    last_sunday_ordinary_time DATE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(liturgical_year)
);

-- 5. Core Easter Calculation Function (Gregorian Algorithm)
CREATE OR REPLACE FUNCTION public.calculate_easter_date(year_val INTEGER)
RETURNS DATE
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    a INTEGER;
    b INTEGER;
    c INTEGER;
    d INTEGER;
    e INTEGER;
    f INTEGER;
    g INTEGER;
    h INTEGER;
    i INTEGER;
    k INTEGER;
    l INTEGER;
    m INTEGER;
    month_val INTEGER;
    day_val INTEGER;
BEGIN
    -- Gregorian Easter calculation algorithm
    a := year_val % 19;
    b := year_val / 100;
    c := year_val % 100;
    d := b / 4;
    e := b % 4;
    f := (b + 8) / 25;
    g := (b - f + 1) / 3;
    h := (19 * a + b - d - g + 15) % 30;
    i := c / 4;
    k := c % 4;
    l := (32 + 2 * e + 2 * i - h - k) % 7;
    m := (a + 11 * h + 22 * l) / 451;
    
    month_val := (h + l - 7 * m + 114) / 31;
    day_val := ((h + l - 7 * m + 114) % 31) + 1;
    
    RETURN make_date(year_val, month_val, day_val);
END;
$$;

-- 6. First Sunday of Advent Calculation
CREATE OR REPLACE FUNCTION public.calculate_first_sunday_advent(year_val INTEGER)
RETURNS DATE
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    christmas_date DATE := make_date(year_val, 12, 25);
    days_back INTEGER;
    first_advent DATE;
BEGIN
    -- Calculate how many days to go back to get to the 4th Sunday before
    -- Christmas is always December 25th
    days_back := (EXTRACT(DOW FROM christmas_date)::INTEGER + 21) % 7;
    IF days_back = 0 THEN
        days_back := 21; -- If Christmas is Sunday, go back exactly 3 weeks
    ELSE
        days_back := days_back + 21;
    END IF;
    
    first_advent := christmas_date - days_back;
    RETURN first_advent;
END;
$$;

-- 7. Liturgical Year Cycle Calculation (A, B, C)
CREATE OR REPLACE FUNCTION public.calculate_liturgical_year_cycle(liturgical_year INTEGER)
RETURNS public.liturgical_year_cycle
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    -- Year A: when liturgical year is divisible by 3
    -- Year B: when liturgical year mod 3 = 1  
    -- Year C: when liturgical year mod 3 = 2
    CASE liturgical_year % 3
        WHEN 0 THEN RETURN 'A'::public.liturgical_year_cycle;
        WHEN 1 THEN RETURN 'B'::public.liturgical_year_cycle;
        ELSE RETURN 'C'::public.liturgical_year_cycle;
    END CASE;
END;
$$;

-- 8. Calculate All Moveable Feasts for a Year
CREATE OR REPLACE FUNCTION public.calculate_moveable_feasts(year_val INTEGER)
RETURNS TABLE(
    feast_type public.moveable_feast_type,
    feast_date DATE,
    cycle public.liturgical_year_cycle
)
LANGUAGE plpgsql
AS $$
DECLARE
    easter_date DATE;
    liturgical_year INTEGER;
    year_cycle public.liturgical_year_cycle;
BEGIN
    easter_date := public.calculate_easter_date(year_val);
    liturgical_year := CASE 
        WHEN CURRENT_DATE >= public.calculate_first_sunday_advent(year_val - 1) 
        THEN year_val - 1 
        ELSE year_val - 2 
    END;
    year_cycle := public.calculate_liturgical_year_cycle(liturgical_year);
    
    -- Return all moveable feasts based on Easter
    RETURN QUERY VALUES
        ('ash_wednesday'::public.moveable_feast_type, easter_date - 46, year_cycle),
        ('palm_sunday'::public.moveable_feast_type, easter_date - 7, year_cycle),
        ('holy_thursday'::public.moveable_feast_type, easter_date - 3, year_cycle),
        ('good_friday'::public.moveable_feast_type, easter_date - 2, year_cycle),
        ('easter_sunday'::public.moveable_feast_type, easter_date, year_cycle),
        ('divine_mercy_sunday'::public.moveable_feast_type, easter_date + 7, year_cycle),
        ('ascension'::public.moveable_feast_type, easter_date + 39, year_cycle),
        ('pentecost'::public.moveable_feast_type, easter_date + 49, year_cycle),
        ('trinity_sunday'::public.moveable_feast_type, easter_date + 56, year_cycle),
        ('corpus_christi'::public.moveable_feast_type, easter_date + 63, year_cycle),
        ('sacred_heart'::public.moveable_feast_type, easter_date + 68, year_cycle),
        ('christ_the_king'::public.moveable_feast_type, 
         public.calculate_first_sunday_advent(year_val) - 7, year_cycle);
END;
$$;

-- 9. Populate Liturgical Year Boundaries
CREATE OR REPLACE FUNCTION public.populate_liturgical_year(year_val INTEGER)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    cycle public.liturgical_year_cycle;
    first_advent DATE;
    easter_date DATE;
    pentecost_date DATE;
    ash_wednesday_date DATE;
BEGIN
    cycle := public.calculate_liturgical_year_cycle(year_val);
    first_advent := public.calculate_first_sunday_advent(year_val);
    easter_date := public.calculate_easter_date(year_val + 1); -- Easter of following year
    pentecost_date := easter_date + 49;
    ash_wednesday_date := easter_date - 46;
    
    -- Insert liturgical year boundaries
    INSERT INTO public.liturgical_year_boundaries (
        liturgical_year, cycle, first_sunday_advent, christmas_date,
        ash_wednesday, easter_date, pentecost_date,
        first_sunday_ordinary_time, last_sunday_ordinary_time
    ) VALUES (
        year_val, cycle, first_advent, make_date(year_val, 12, 25),
        ash_wednesday_date, easter_date, pentecost_date,
        easter_date + 56, first_advent - 7 -- Trinity Sunday and Christ the King
    )
    ON CONFLICT (liturgical_year) DO UPDATE SET
        cycle = EXCLUDED.cycle,
        first_sunday_advent = EXCLUDED.first_sunday_advent,
        christmas_date = EXCLUDED.christmas_date,
        ash_wednesday = EXCLUDED.ash_wednesday,
        easter_date = EXCLUDED.easter_date,
        pentecost_date = EXCLUDED.pentecost_date,
        first_sunday_ordinary_time = EXCLUDED.first_sunday_ordinary_time,
        last_sunday_ordinary_time = EXCLUDED.last_sunday_ordinary_time;
        
    -- Populate moveable feasts for the year
    INSERT INTO public.moveable_feasts (year, feast_type, date, liturgical_year_cycle)
    SELECT year_val + 1, feast_type, feast_date, cycle
    FROM public.calculate_moveable_feasts(year_val + 1)
    ON CONFLICT (year, feast_type) DO UPDATE SET
        date = EXCLUDED.date,
        liturgical_year_cycle = EXCLUDED.liturgical_year_cycle;
END;
$$;

-- 10. Get Liturgical Information for Any Date
CREATE OR REPLACE FUNCTION public.get_liturgical_day_info(input_date DATE)
RETURNS TABLE(
    liturgical_season public.liturgical_season,
    liturgical_year_cycle public.liturgical_year_cycle,
    season_week INTEGER,
    days_from_easter INTEGER,
    is_sunday BOOLEAN,
    is_moveable_feast BOOLEAN,
    moveable_feast_type public.moveable_feast_type,
    liturgical_color TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    easter_date DATE;
    first_advent DATE;
    christmas_date DATE;
    ash_wednesday_date DATE;
    pentecost_date DATE;
    cycle public.liturgical_year_cycle;
    season public.liturgical_season;
    week_num INTEGER;
    days_easter INTEGER;
    is_sunday_val BOOLEAN;
    is_feast BOOLEAN;
    feast_type public.moveable_feast_type;
    color TEXT;
    current_year INTEGER;
BEGIN
    current_year := EXTRACT(YEAR FROM input_date)::INTEGER;
    is_sunday_val := EXTRACT(DOW FROM input_date) = 0;
    
    -- Get liturgical year boundaries
    SELECT 
        lyb.easter_date, lyb.first_sunday_advent, lyb.christmas_date,
        lyb.ash_wednesday, lyb.pentecost_date, lyb.cycle
    INTO easter_date, first_advent, christmas_date, ash_wednesday_date, pentecost_date, cycle
    FROM public.liturgical_year_boundaries lyb
    WHERE lyb.liturgical_year = CASE 
        WHEN input_date >= public.calculate_first_sunday_advent(current_year - 1) 
        THEN current_year - 1 
        ELSE current_year - 2 
    END;
    
    -- If boundaries not found, calculate them
    IF easter_date IS NULL THEN
        PERFORM public.populate_liturgical_year(current_year - 1);
        PERFORM public.populate_liturgical_year(current_year);
        
        SELECT 
            lyb.easter_date, lyb.first_sunday_advent, lyb.christmas_date,
            lyb.ash_wednesday, lyb.pentecost_date, lyb.cycle
        INTO easter_date, first_advent, christmas_date, ash_wednesday_date, pentecost_date, cycle
        FROM public.liturgical_year_boundaries lyb
        WHERE lyb.liturgical_year = CASE 
            WHEN input_date >= public.calculate_first_sunday_advent(current_year - 1) 
            THEN current_year - 1 
            ELSE current_year - 2 
        END;
    END IF;
    
    days_easter := input_date - easter_date;
    
    -- Check if it's a moveable feast
    SELECT mf.feast_type INTO feast_type
    FROM public.moveable_feasts mf
    WHERE mf.date = input_date
    LIMIT 1;
    
    is_feast := feast_type IS NOT NULL;
    
    -- Determine liturgical season
    IF input_date >= first_advent AND input_date < christmas_date THEN
        season := 'advent'::public.liturgical_season;
        week_num := ((input_date - first_advent) / 7) + 1;
        color := 'purple';
    ELSIF input_date >= christmas_date AND input_date < ash_wednesday_date THEN
        season := 'christmas'::public.liturgical_season;
        week_num := ((input_date - christmas_date) / 7) + 1;
        color := 'white';
    ELSIF input_date >= ash_wednesday_date AND input_date < easter_date THEN
        season := 'lent'::public.liturgical_season;
        week_num := ((input_date - ash_wednesday_date) / 7) + 1;
        color := 'purple';
    ELSIF input_date >= easter_date AND input_date < pentecost_date THEN
        season := 'easter'::public.liturgical_season;
        week_num := ((input_date - easter_date) / 7) + 1;
        color := 'white';
    ELSE
        season := 'ordinary_time'::public.liturgical_season;
        IF input_date < ash_wednesday_date THEN
            week_num := ((input_date - (christmas_date + 7)) / 7) + 1;
        ELSE
            week_num := ((input_date - pentecost_date) / 7) + 1;
        END IF;
        color := 'green';
    END IF;
    
    -- Special color overrides for feasts
    IF is_feast THEN
        CASE feast_type
            WHEN 'easter_sunday', 'christmas', 'epiphany' THEN color := 'white';
            WHEN 'good_friday' THEN color := 'red';
            WHEN 'palm_sunday' THEN color := 'red';
            ELSE color := COALESCE(color, 'white');
        END CASE;
    END IF;
    
    RETURN QUERY SELECT 
        season, cycle, week_num, days_easter, is_sunday_val, 
        is_feast, feast_type, color;
END;
$$;

-- 11. Enhanced Indexes for Performance
CREATE INDEX IF NOT EXISTS idx_moveable_feasts_date ON public.moveable_feasts(date);
CREATE INDEX IF NOT EXISTS idx_moveable_feasts_year ON public.moveable_feasts(year);
CREATE INDEX IF NOT EXISTS idx_liturgical_year_boundaries_year ON public.liturgical_year_boundaries(liturgical_year);
CREATE INDEX IF NOT EXISTS idx_liturgical_days_cycle ON public.liturgical_days(liturgical_year_cycle);
CREATE INDEX IF NOT EXISTS idx_liturgical_days_moveable ON public.liturgical_days(is_moveable_feast);

-- 12. Enable RLS for New Tables
ALTER TABLE public.moveable_feasts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.liturgical_year_boundaries ENABLE ROW LEVEL SECURITY;

-- 13. RLS Policies for New Tables (Public Read, Admin Write)
CREATE POLICY "public_read_moveable_feasts" ON public.moveable_feasts
FOR SELECT TO public USING (true);

CREATE POLICY "admin_manage_moveable_feasts" ON public.moveable_feasts
FOR ALL TO authenticated
USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE POLICY "public_read_liturgical_year_boundaries" ON public.liturgical_year_boundaries
FOR SELECT TO public USING (true);

CREATE POLICY "admin_manage_liturgical_year_boundaries" ON public.liturgical_year_boundaries
FOR ALL TO authenticated
USING (public.is_admin()) WITH CHECK (public.is_admin());

-- 14. Initialize Current and Next Liturgical Years
DO $$
DECLARE
    current_year INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
BEGIN
    -- Populate current and next liturgical years
    PERFORM public.populate_liturgical_year(current_year - 1);
    PERFORM public.populate_liturgical_year(current_year);
    PERFORM public.populate_liturgical_year(current_year + 1);
    
    -- Update existing liturgical_days with enhanced information
    UPDATE public.liturgical_days 
    SET 
        liturgical_year_cycle = info.liturgical_year_cycle,
        season = info.liturgical_season,
        season_week = info.season_week,
        days_from_easter = info.days_from_easter,
        is_moveable_feast = info.is_moveable_feast,
        moveable_feast_type = info.moveable_feast_type,
        color = info.liturgical_color
    FROM public.get_liturgical_day_info(date) AS info
    WHERE liturgical_days.date >= CURRENT_DATE - INTERVAL '1 year'
      AND liturgical_days.date <= CURRENT_DATE + INTERVAL '2 years';
      
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error initializing liturgical years: %', SQLERRM;
END $$;

-- 15. Auto-update Function for Daily Liturgical Information
CREATE OR REPLACE FUNCTION public.ensure_liturgical_day_exists(input_date DATE)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    existing_id UUID;
    new_id UUID;
    liturgical_info RECORD;
BEGIN
    -- Check if liturgical day already exists
    SELECT id INTO existing_id
    FROM public.liturgical_days
    WHERE date = input_date;
    
    IF existing_id IS NOT NULL THEN
        RETURN existing_id;
    END IF;
    
    -- Get liturgical information for the date
    SELECT * INTO liturgical_info
    FROM public.get_liturgical_day_info(input_date);
    
    -- Create new liturgical day
    INSERT INTO public.liturgical_days (
        date, season, liturgical_year_cycle, season_week, color,
        is_sunday, is_holyday, days_from_easter, is_moveable_feast,
        moveable_feast_type, liturgical_year
    ) VALUES (
        input_date,
        liturgical_info.liturgical_season,
        liturgical_info.liturgical_year_cycle,
        liturgical_info.season_week,
        liturgical_info.liturgical_color,
        liturgical_info.is_sunday,
        liturgical_info.is_moveable_feast,
        liturgical_info.days_from_easter,
        liturgical_info.is_moveable_feast,
        liturgical_info.moveable_feast_type,
        CASE 
            WHEN input_date >= public.calculate_first_sunday_advent(EXTRACT(YEAR FROM input_date)::INTEGER - 1)
            THEN (EXTRACT(YEAR FROM input_date) - 1)::TEXT
            ELSE (EXTRACT(YEAR FROM input_date) - 2)::TEXT
        END || '-' || EXTRACT(YEAR FROM input_date)::TEXT
    ) RETURNING id INTO new_id;
    
    RETURN new_id;
END;
$$;

-- Enable realtime for new tables
ALTER PUBLICATION supabase_realtime ADD TABLE public.moveable_feasts;
ALTER PUBLICATION supabase_realtime ADD TABLE public.liturgical_year_boundaries;