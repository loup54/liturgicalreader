-- Location: supabase/migrations/20250722055000_liturgical_reading_platform.sql
-- Liturgical Reading Platform - Complete Database Schema
-- Date: 2025-07-22 05:50:00

-- 1. Types and Enums
CREATE TYPE public.user_role AS ENUM ('admin', 'member', 'reader');
CREATE TYPE public.liturgical_season AS ENUM (
    'advent', 'christmas', 'ordinary_time', 'lent', 
    'easter', 'pentecost', 'ordinary_time_ii'
);
CREATE TYPE public.reading_type AS ENUM (
    'first_reading', 'responsorial_psalm', 'second_reading', 
    'gospel', 'alleluia', 'communion_antiphon'
);
CREATE TYPE public.feast_rank AS ENUM ('solemnity', 'feast', 'memorial', 'optional_memorial');

-- 2. Core Tables - User Management (Intermediary for auth.users)
CREATE TABLE public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    role public.user_role DEFAULT 'member'::public.user_role,
    preferences JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 3. Liturgical Calendar System
CREATE TABLE public.liturgical_days (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    date DATE NOT NULL UNIQUE,
    season public.liturgical_season NOT NULL,
    season_week INTEGER,
    liturgical_year TEXT NOT NULL, -- A, B, or C
    color TEXT NOT NULL DEFAULT 'green',
    is_sunday BOOLEAN DEFAULT false,
    is_holyday BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE public.feast_days (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    date DATE NOT NULL,
    rank public.feast_rank NOT NULL,
    description TEXT,
    liturgical_day_id UUID REFERENCES public.liturgical_days(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 4. Reading Content Management
CREATE TABLE public.biblical_books (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    abbreviation TEXT NOT NULL UNIQUE,
    testament TEXT NOT NULL CHECK (testament IN ('old', 'new')),
    order_number INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE public.liturgical_readings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    liturgical_day_id UUID REFERENCES public.liturgical_days(id) ON DELETE CASCADE,
    reading_type public.reading_type NOT NULL,
    citation TEXT NOT NULL,
    biblical_book_id UUID REFERENCES public.biblical_books(id),
    chapter_verse TEXT,
    content TEXT NOT NULL,
    audio_url TEXT,
    order_sequence INTEGER DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 5. User Interaction Tables
CREATE TABLE public.user_bookmarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    reading_id UUID REFERENCES public.liturgical_readings(id) ON DELETE CASCADE,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, reading_id)
);

CREATE TABLE public.reading_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    reading_id UUID REFERENCES public.liturgical_readings(id) ON DELETE CASCADE,
    viewed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    time_spent_seconds INTEGER DEFAULT 0
);

-- 6. Sync and Status Management
CREATE TABLE public.content_sync_status (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_type TEXT NOT NULL,
    last_sync_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    sync_status TEXT DEFAULT 'success',
    error_message TEXT,
    records_synced INTEGER DEFAULT 0
);

-- 7. Essential Indexes for Performance
CREATE INDEX idx_user_profiles_email ON public.user_profiles(email);
CREATE INDEX idx_liturgical_days_date ON public.liturgical_days(date);
CREATE INDEX idx_liturgical_days_season ON public.liturgical_days(season);
CREATE INDEX idx_feast_days_date ON public.feast_days(date);
CREATE INDEX idx_liturgical_readings_day_type ON public.liturgical_readings(liturgical_day_id, reading_type);
CREATE INDEX idx_user_bookmarks_user_id ON public.user_bookmarks(user_id);
CREATE INDEX idx_reading_history_user_id ON public.reading_history(user_id);
CREATE INDEX idx_reading_history_viewed_at ON public.reading_history(viewed_at);

-- 8. Row Level Security Setup
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.liturgical_days ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feast_days ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.biblical_books ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.liturgical_readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_bookmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reading_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_sync_status ENABLE ROW LEVEL SECURITY;

-- 9. Helper Functions for RLS Policies
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM public.user_profiles up
    WHERE up.id = auth.uid() AND up.role = 'admin'::public.user_role
)
$$;

CREATE OR REPLACE FUNCTION public.is_reader_or_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM public.user_profiles up
    WHERE up.id = auth.uid() 
    AND up.role IN ('admin'::public.user_role, 'reader'::public.user_role)
)
$$;

CREATE OR REPLACE FUNCTION public.owns_bookmark(bookmark_uuid UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM public.user_bookmarks ub
    WHERE ub.id = bookmark_uuid AND ub.user_id = auth.uid()
)
$$;

CREATE OR REPLACE FUNCTION public.owns_reading_history(history_uuid UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM public.reading_history rh
    WHERE rh.id = history_uuid AND rh.user_id = auth.uid()
)
$$;

-- 10. RLS Policies
-- User profiles: Users can only view and edit their own profile
CREATE POLICY "users_own_profile" ON public.user_profiles
FOR ALL TO authenticated
USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- Liturgical content: Public read access, admin write access
CREATE POLICY "public_read_liturgical_days" ON public.liturgical_days
FOR SELECT TO public USING (true);

CREATE POLICY "admin_manage_liturgical_days" ON public.liturgical_days
FOR ALL TO authenticated
USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE POLICY "public_read_feast_days" ON public.feast_days
FOR SELECT TO public USING (true);

CREATE POLICY "admin_manage_feast_days" ON public.feast_days
FOR ALL TO authenticated
USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE POLICY "public_read_biblical_books" ON public.biblical_books
FOR SELECT TO public USING (true);

CREATE POLICY "admin_manage_biblical_books" ON public.biblical_books
FOR ALL TO authenticated
USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE POLICY "public_read_liturgical_readings" ON public.liturgical_readings
FOR SELECT TO public USING (true);

CREATE POLICY "readers_manage_liturgical_readings" ON public.liturgical_readings
FOR ALL TO authenticated
USING (public.is_reader_or_admin()) WITH CHECK (public.is_reader_or_admin());

-- User-specific content: Users can only access their own data
CREATE POLICY "users_own_bookmarks" ON public.user_bookmarks
FOR ALL TO authenticated
USING (public.owns_bookmark(id)) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_own_reading_history" ON public.reading_history
FOR ALL TO authenticated
USING (public.owns_reading_history(id)) WITH CHECK (auth.uid() = user_id);

-- Content sync status: Admins only
CREATE POLICY "admin_sync_status" ON public.content_sync_status
FOR ALL TO authenticated
USING (public.is_admin()) WITH CHECK (public.is_admin());

-- 11. Automatic User Profile Creation Trigger
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.user_profiles (id, email, full_name, role)
  VALUES (
    NEW.id, 
    NEW.email, 
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'role', 'member')::public.user_role
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 12. Update Timestamp Triggers
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON public.user_profiles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_liturgical_readings_updated_at
    BEFORE UPDATE ON public.liturgical_readings
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 13. Mock Data for Testing
DO $$
DECLARE
    admin_uuid UUID := gen_random_uuid();
    user_uuid UUID := gen_random_uuid();
    today_date DATE := CURRENT_DATE;
    liturgical_day_id UUID := gen_random_uuid();
    matthew_book_id UUID := gen_random_uuid();
    isaiah_book_id UUID := gen_random_uuid();
    psalm_book_id UUID := gen_random_uuid();
    romans_book_id UUID := gen_random_uuid();
    first_reading_id UUID := gen_random_uuid();
    psalm_reading_id UUID := gen_random_uuid();
    second_reading_id UUID := gen_random_uuid();
    gospel_reading_id UUID := gen_random_uuid();
BEGIN
    -- Create auth users with complete required fields
    INSERT INTO auth.users (
        id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
        created_at, updated_at, raw_user_meta_data, raw_app_meta_data,
        is_sso_user, is_anonymous, confirmation_token, confirmation_sent_at,
        recovery_token, recovery_sent_at, email_change_token_new, email_change,
        email_change_sent_at, email_change_token_current, email_change_confirm_status,
        reauthentication_token, reauthentication_sent_at, phone, phone_change,
        phone_change_token, phone_change_sent_at
    ) VALUES
        (admin_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'admin@liturgicalreader.com', crypt('password123', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "Admin User", "role": "admin"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null),
        (user_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'user@liturgicalreader.com', crypt('password123', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "Regular User"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null);

    -- Create biblical books
    INSERT INTO public.biblical_books (id, name, abbreviation, testament, order_number) VALUES
        (isaiah_book_id, 'Isaiah', 'Is', 'old', 23),
        (psalm_book_id, 'Psalms', 'Ps', 'old', 19),
        (romans_book_id, 'Romans', 'Rom', 'new', 6),
        (matthew_book_id, 'Matthew', 'Mt', 'new', 1);

    -- Create liturgical day for today
    INSERT INTO public.liturgical_days (id, date, season, season_week, liturgical_year, color, is_sunday, is_holyday)
    VALUES (liturgical_day_id, today_date, 'ordinary_time'::public.liturgical_season, 16, 'A', 'green', false, false);

    -- Create today's readings
    INSERT INTO public.liturgical_readings (id, liturgical_day_id, reading_type, citation, biblical_book_id, chapter_verse, content, order_sequence) VALUES
        (first_reading_id, liturgical_day_id, 'first_reading'::public.reading_type, 'Isaiah 55:10-11', isaiah_book_id, '55:10-11',
         'Thus says the LORD: Just as from the heavens the rain and snow come down and do not return there till they have watered the earth, making it fertile and fruitful, giving seed to the one who sows and bread to the one who eats, so shall my word be that goes forth from my mouth; my word shall not return to me void, but shall do my will, achieving the end for which I sent it.', 1),
        
        (psalm_reading_id, liturgical_day_id, 'responsorial_psalm'::public.reading_type, 'Psalm 65:10, 11, 12-13, 14', psalm_book_id, '65:10-14',
         'R. The seed that falls on good ground will yield a fruitful harvest. You have visited the land and watered it; greatly have you enriched it. God''s watercourses are filled; you have prepared the grain. R. The seed that falls on good ground will yield a fruitful harvest.', 2),
        
        (second_reading_id, liturgical_day_id, 'second_reading'::public.reading_type, 'Romans 8:18-23', romans_book_id, '8:18-23',
         'Brothers and sisters: I consider that the sufferings of this present time are as nothing compared with the glory to be revealed for us. For creation awaits with eager expectation the revelation of the children of God; for creation was made subject to futility, not of its own accord but because of the one who subjected it, in hope that creation itself would be set free from slavery to corruption and share in the glorious freedom of the children of God.', 3),
        
        (gospel_reading_id, liturgical_day_id, 'gospel'::public.reading_type, 'Matthew 13:1-23', matthew_book_id, '13:1-23',
         'On that day, Jesus went out of the house and sat down by the sea. Such large crowds gathered around him that he got into a boat and sat down, and the whole crowd stood along the shore. And he spoke to them at length in parables, saying: "A sower went out to sow. And as he sowed, some seed fell on the path, and birds came and ate it up. Some fell on rocky ground, where it had little soil."', 4);

    -- Create sample bookmarks for the regular user
    INSERT INTO public.user_bookmarks (user_id, reading_id, notes) VALUES
        (user_uuid, psalm_reading_id, 'Beautiful reflection on God''s providence');

    -- Initialize sync status
    INSERT INTO public.content_sync_status (content_type, sync_status, records_synced) VALUES
        ('liturgical_readings', 'success', 4),
        ('biblical_books', 'success', 4),
        ('liturgical_days', 'success', 1);

EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Foreign key error during mock data creation: %', SQLERRM;
    WHEN unique_violation THEN
        RAISE NOTICE 'Unique constraint error during mock data creation: %', SQLERRM;
    WHEN OTHERS THEN
        RAISE NOTICE 'Unexpected error during mock data creation: %', SQLERRM;
END $$;

-- 14. Cleanup Function for Testing
CREATE OR REPLACE FUNCTION public.cleanup_test_data()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    auth_user_ids_to_delete UUID[];
BEGIN
    -- Get auth user IDs for cleanup
    SELECT ARRAY_AGG(id) INTO auth_user_ids_to_delete
    FROM auth.users
    WHERE email LIKE '%@liturgicalreader.com';

    -- Delete in dependency order (children first)
    DELETE FROM public.reading_history WHERE user_id = ANY(auth_user_ids_to_delete);
    DELETE FROM public.user_bookmarks WHERE user_id = ANY(auth_user_ids_to_delete);
    DELETE FROM public.liturgical_readings WHERE liturgical_day_id IN (
        SELECT id FROM public.liturgical_days WHERE date = CURRENT_DATE
    );
    DELETE FROM public.feast_days WHERE liturgical_day_id IN (
        SELECT id FROM public.liturgical_days WHERE date = CURRENT_DATE
    );
    DELETE FROM public.liturgical_days WHERE date = CURRENT_DATE;
    DELETE FROM public.biblical_books WHERE name IN ('Isaiah', 'Psalms', 'Romans', 'Matthew');
    DELETE FROM public.content_sync_status WHERE content_type IN ('liturgical_readings', 'biblical_books', 'liturgical_days');
    DELETE FROM public.user_profiles WHERE id = ANY(auth_user_ids_to_delete);

    -- Delete auth users last
    DELETE FROM auth.users WHERE id = ANY(auth_user_ids_to_delete);

EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Foreign key constraint prevents cleanup: %', SQLERRM;
    WHEN OTHERS THEN
        RAISE NOTICE 'Cleanup failed: %', SQLERRM;
END;
$$;

-- Enable realtime for tables that need live updates
ALTER PUBLICATION supabase_realtime ADD TABLE public.liturgical_readings;
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_bookmarks;
ALTER PUBLICATION supabase_realtime ADD TABLE public.content_sync_status;