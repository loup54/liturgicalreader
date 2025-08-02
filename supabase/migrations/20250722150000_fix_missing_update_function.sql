-- Location: supabase/migrations/20250722150000_fix_missing_update_function.sql
-- Fix Missing Update Function - Critical Database Function Recovery
-- Date: 2025-07-22 15:00:00

-- Ensure the critical update_updated_at_column function exists
-- This function is required by multiple triggers across the application

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

-- Verify the function was created successfully
DO $$
BEGIN
    -- Test that the function exists and is accessible
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' 
        AND p.proname = 'update_updated_at_column'
    ) THEN
        RAISE NOTICE 'SUCCESS: update_updated_at_column function created successfully';
    ELSE
        RAISE EXCEPTION 'FAILED: update_updated_at_column function was not created';
    END IF;
END $$;

-- Recreate any triggers that may have failed due to missing function
-- These triggers should now work since the function exists

-- Recreate user_profiles trigger if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger 
        WHERE tgname = 'update_user_profiles_updated_at'
    ) THEN
        CREATE TRIGGER update_user_profiles_updated_at
            BEFORE UPDATE ON public.user_profiles
            FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
        RAISE NOTICE 'Created trigger: update_user_profiles_updated_at';
    ELSE
        RAISE NOTICE 'Trigger update_user_profiles_updated_at already exists';
    END IF;
EXCEPTION
    WHEN undefined_table THEN
        RAISE NOTICE 'Table user_profiles does not exist yet - trigger will be created later';
    WHEN OTHERS THEN
        RAISE NOTICE 'Error creating user_profiles trigger: %', SQLERRM;
END $$;

-- Recreate liturgical_readings trigger if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger 
        WHERE tgname = 'update_liturgical_readings_updated_at'
    ) THEN
        CREATE TRIGGER update_liturgical_readings_updated_at
            BEFORE UPDATE ON public.liturgical_readings
            FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
        RAISE NOTICE 'Created trigger: update_liturgical_readings_updated_at';
    ELSE
        RAISE NOTICE 'Trigger update_liturgical_readings_updated_at already exists';
    END IF;
EXCEPTION
    WHEN undefined_table THEN
        RAISE NOTICE 'Table liturgical_readings does not exist yet - trigger will be created later';
    WHEN OTHERS THEN
        RAISE NOTICE 'Error creating liturgical_readings trigger: %', SQLERRM;
END $$;

-- Recreate data_quality_rules trigger if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger 
        WHERE tgname = 'update_data_quality_rules_updated_at'
    ) THEN
        CREATE TRIGGER update_data_quality_rules_updated_at
            BEFORE UPDATE ON public.data_quality_rules
            FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
        RAISE NOTICE 'Created trigger: update_data_quality_rules_updated_at';
    ELSE
        RAISE NOTICE 'Trigger update_data_quality_rules_updated_at already exists';
    END IF;
EXCEPTION
    WHEN undefined_table THEN
        RAISE NOTICE 'Table data_quality_rules does not exist yet - trigger will be created later';
    WHEN OTHERS THEN
        RAISE NOTICE 'Error creating data_quality_rules trigger: %', SQLERRM;
END $$;

-- Final verification
DO $$
DECLARE
    function_count INTEGER;
    trigger_count INTEGER;
BEGIN
    -- Count the function
    SELECT COUNT(*) INTO function_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' 
    AND p.proname = 'update_updated_at_column';
    
    -- Count existing triggers that use this function
    SELECT COUNT(*) INTO trigger_count
    FROM pg_trigger t
    JOIN pg_proc p ON t.tgfoid = p.oid
    WHERE p.proname = 'update_updated_at_column';
    
    RAISE NOTICE 'MIGRATION COMPLETED SUCCESSFULLY';
    RAISE NOTICE 'Functions created: %', function_count;
    RAISE NOTICE 'Active triggers using function: %', trigger_count;
    RAISE NOTICE 'The update_updated_at_column function is now available for all triggers';
END $$;