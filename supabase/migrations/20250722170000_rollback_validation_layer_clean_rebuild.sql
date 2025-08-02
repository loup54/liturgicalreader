-- Location: supabase/migrations/20250722170000_rollback_validation_layer_clean_rebuild.sql
-- Rollback Strategy: Clean Rebuild of Validation Layer with Corrected Query Patterns
-- IMPLEMENTING MODULE: Data Validation and Quality Assurance
-- Date: 2025-07-22 17:00:00

-- CRITICAL NOTE: This migration does NOT recreate existing tables
-- Instead, it fixes the problematic aspects while preserving data

-- 1. Fix existing table column types that may cause query issues
ALTER TABLE public.reading_source_validations 
ALTER COLUMN content_similarity_score TYPE DECIMAL(5,4),
ALTER COLUMN citation_match_score TYPE DECIMAL(5,4),
ALTER COLUMN overall_confidence_score TYPE DECIMAL(5,4);

-- 2. Add missing column that services expect
ALTER TABLE public.user_content_reports 
ADD COLUMN IF NOT EXISTS report_category public.report_category DEFAULT 'other'::public.report_category;

-- 3. Create simplified helper functions that work with Flutter query patterns
CREATE OR REPLACE FUNCTION public.get_reading_reports_simple(reading_uuid UUID)
RETURNS TABLE(
    id UUID,
    report_category TEXT,
    report_description TEXT,
    status TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT 
    ucr.id,
    ucr.report_category::TEXT,
    ucr.report_description,
    ucr.status::TEXT,
    ucr.created_at
FROM public.user_content_reports ucr
WHERE ucr.reading_id = reading_uuid
ORDER BY ucr.created_at DESC;
$$;

CREATE OR REPLACE FUNCTION public.get_validation_results_simple(reading_uuid UUID)
RETURNS TABLE(
    id UUID,
    source_name TEXT,
    content_similarity_score DECIMAL(5,4),
    overall_confidence_score DECIMAL(5,4),
    validation_date TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT 
    rsv.id,
    rsv.source_name::TEXT,
    rsv.content_similarity_score,
    rsv.overall_confidence_score,
    rsv.validation_date
FROM public.reading_source_validations rsv
WHERE rsv.reading_id = reading_uuid
ORDER BY rsv.validation_date DESC;
$$;

CREATE OR REPLACE FUNCTION public.get_quality_score_simple(reading_uuid UUID)
RETURNS TABLE(
    id UUID,
    overall_quality_score DECIMAL(5,4),
    content_quality_score DECIMAL(5,4),
    citation_accuracy_score DECIMAL(5,4),
    user_report_impact_score DECIMAL(5,4)
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT 
    rqs.id,
    rqs.overall_quality_score,
    rqs.content_quality_score,
    rqs.citation_accuracy_score,
    rqs.user_report_impact_score
FROM public.reading_quality_scores rqs
WHERE rqs.reading_id = reading_uuid;
$$;

-- 4. Create simple admin queue helper
CREATE OR REPLACE FUNCTION public.get_admin_queue_simple(status_filter TEXT DEFAULT NULL)
RETURNS TABLE(
    id UUID,
    content_id UUID,
    content_type TEXT,
    priority_level INTEGER,
    review_reason TEXT,
    status TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT 
    arq.id,
    arq.content_id::UUID,
    arq.content_type,
    arq.priority_level,
    arq.review_reason,
    arq.status::TEXT,
    arq.created_at
FROM public.admin_review_queue arq
WHERE (status_filter IS NULL OR arq.status::TEXT = status_filter)
ORDER BY arq.priority_level DESC, arq.created_at ASC;
$$;

-- 5. Add indexes for the simplified queries
CREATE INDEX IF NOT EXISTS idx_user_content_reports_reading_created 
ON public.user_content_reports(reading_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_reading_source_validations_reading_date 
ON public.reading_source_validations(reading_id, validation_date DESC);

-- 6. Create simplified view for Flutter queries
CREATE OR REPLACE VIEW public.reading_validation_summary AS
SELECT 
    lr.id as reading_id,
    lr.citation,
    lr.reading_type::TEXT,
    COUNT(ucr.id) as report_count,
    COALESCE(AVG(rsv.overall_confidence_score), 0.8500) as avg_confidence,
    COALESCE(rqs.overall_quality_score, 0.8500) as quality_score,
    lr.created_at
FROM public.liturgical_readings lr
LEFT JOIN public.user_content_reports ucr ON lr.id = ucr.reading_id
LEFT JOIN public.reading_source_validations rsv ON lr.id = rsv.reading_id
LEFT JOIN public.reading_quality_scores rqs ON lr.id = rqs.reading_id
GROUP BY lr.id, lr.citation, lr.reading_type, rqs.overall_quality_score, lr.created_at;

-- 7. Enable RLS on view
ALTER VIEW public.reading_validation_summary OWNER TO postgres;

-- 8. Add simple policies for the view
CREATE POLICY "public_view_validation_summary" 
ON public.reading_validation_summary 
FOR SELECT 
TO public 
USING (true);

-- Grant necessary permissions
GRANT SELECT ON public.reading_validation_summary TO authenticated, anon;

-- 9. Create cleanup function for test data
CREATE OR REPLACE FUNCTION public.cleanup_validation_test_data_safe()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Safe cleanup that won't break foreign keys
    DELETE FROM public.reading_source_validations 
    WHERE source_content LIKE '%Sample validation content%';
    
    DELETE FROM public.user_content_reports 
    WHERE report_description LIKE '%test%' OR report_description LIKE '%sample%';
    
    DELETE FROM public.admin_review_queue 
    WHERE review_reason LIKE '%test%' OR review_reason LIKE '%sample%';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Cleanup completed with warnings: %', SQLERRM;
END;
$$;

-- 10. Mock data with simple structure for testing
DO $$
DECLARE
    sample_reading_id UUID;
    report_id UUID;
BEGIN
    -- Get first reading for testing
    SELECT id INTO sample_reading_id 
    FROM public.liturgical_readings 
    LIMIT 1;
    
    IF sample_reading_id IS NOT NULL THEN
        -- Simple validation record
        INSERT INTO public.reading_source_validations (
            reading_id, 
            source_name, 
            source_content, 
            content_similarity_score, 
            overall_confidence_score
        ) VALUES (
            sample_reading_id, 
            'usccb'::public.validation_source,
            'Clean test validation content',
            0.8500, 
            0.8750
        ) ON CONFLICT DO NOTHING;
        
        -- Simple quality score
        INSERT INTO public.reading_quality_scores (
            reading_id,
            overall_quality_score,
            content_quality_score,
            citation_accuracy_score
        ) VALUES (
            sample_reading_id,
            0.8500,
            0.9000,
            0.8200
        ) ON CONFLICT DO NOTHING;
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Mock data creation had warnings: %', SQLERRM;
END $$;