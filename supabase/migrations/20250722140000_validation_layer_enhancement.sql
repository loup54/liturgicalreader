-- Location: supabase/migrations/20250722140000_validation_layer_enhancement.sql
-- Comprehensive Data Validation Layer - Step 5 Enhancement
-- Cross-referencing multiple Catholic sources and administrative review system
-- Date: 2025-07-22 14:00:00

-- 1. Enhanced Types for Validation System
CREATE TYPE public.validation_source AS ENUM ('usccb', 'universalis', 'vatican', 'cna', 'internal');
CREATE TYPE public.validation_status AS ENUM ('pending', 'approved', 'flagged', 'rejected', 'under_review');
CREATE TYPE public.report_category AS ENUM ('content_error', 'citation_error', 'translation_issue', 'formatting_issue', 'missing_content', 'other');

-- 2. Source Cross-Reference Validation Table
CREATE TABLE public.reading_source_validations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reading_id UUID REFERENCES public.liturgical_readings(id) ON DELETE CASCADE,
    source_name public.validation_source NOT NULL,
    source_content TEXT NOT NULL,
    source_citation TEXT,
    source_url TEXT,
    content_similarity_score DECIMAL(5,4) DEFAULT 0.0000,
    citation_match_score DECIMAL(5,4) DEFAULT 0.0000,
    overall_confidence_score DECIMAL(5,4) DEFAULT 0.0000,
    discrepancy_flags JSONB DEFAULT '{}',
    validation_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 3. User Content Reports Table
CREATE TABLE public.user_content_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reading_id UUID REFERENCES public.liturgical_readings(id) ON DELETE CASCADE,
    reporter_id UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    report_category public.report_category NOT NULL,
    report_description TEXT NOT NULL,
    suggested_correction TEXT,
    is_verified BOOLEAN DEFAULT false,
    admin_notes TEXT,
    status public.validation_status DEFAULT 'pending'::public.validation_status,
    resolved_by_admin_id UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 4. Data Quality Rules Table
CREATE TABLE public.data_quality_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_name TEXT NOT NULL UNIQUE,
    rule_description TEXT NOT NULL,
    rule_type TEXT NOT NULL, -- 'content_length', 'citation_format', 'language_quality', etc.
    rule_criteria JSONB NOT NULL, -- Rule parameters and thresholds
    weight_factor DECIMAL(3,2) DEFAULT 1.00, -- How much this rule affects overall score
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 5. Reading Quality Scores Table
CREATE TABLE public.reading_quality_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reading_id UUID REFERENCES public.liturgical_readings(id) ON DELETE CASCADE,
    overall_quality_score DECIMAL(5,4) DEFAULT 0.0000,
    content_quality_score DECIMAL(5,4) DEFAULT 0.0000,
    citation_accuracy_score DECIMAL(5,4) DEFAULT 0.0000,
    source_agreement_score DECIMAL(5,4) DEFAULT 0.0000,
    language_quality_score DECIMAL(5,4) DEFAULT 0.0000,
    user_report_impact_score DECIMAL(5,4) DEFAULT 1.0000, -- Starts at 1.0, decreases with reports
    validation_details JSONB DEFAULT '{}',
    last_calculated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 6. Administrative Review Queue Table
CREATE TABLE public.admin_review_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_id UUID NOT NULL, -- Can reference readings, reports, etc.
    content_type TEXT NOT NULL, -- 'reading', 'report', 'discrepancy'
    priority_level INTEGER DEFAULT 1, -- 1=low, 2=medium, 3=high, 4=urgent
    review_reason TEXT NOT NULL,
    assigned_admin_id UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    status public.validation_status DEFAULT 'pending'::public.validation_status,
    review_notes TEXT,
    resolution_action TEXT, -- What action was taken
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    assigned_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ
);

-- 7. Essential Indexes for Performance
CREATE INDEX idx_reading_source_validations_reading_id ON public.reading_source_validations(reading_id);
CREATE INDEX idx_reading_source_validations_source ON public.reading_source_validations(source_name);
CREATE INDEX idx_user_content_reports_reading_id ON public.user_content_reports(reading_id);
CREATE INDEX idx_user_content_reports_status ON public.user_content_reports(status);
CREATE INDEX idx_user_content_reports_category ON public.user_content_reports(report_category);
CREATE INDEX idx_reading_quality_scores_reading_id ON public.reading_quality_scores(reading_id);
CREATE INDEX idx_reading_quality_scores_overall ON public.reading_quality_scores(overall_quality_score);
CREATE INDEX idx_admin_review_queue_status ON public.admin_review_queue(status);
CREATE INDEX idx_admin_review_queue_priority ON public.admin_review_queue(priority_level);
CREATE INDEX idx_admin_review_queue_assigned ON public.admin_review_queue(assigned_admin_id);

-- 8. Row Level Security Setup
ALTER TABLE public.reading_source_validations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_content_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.data_quality_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reading_quality_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_review_queue ENABLE ROW LEVEL SECURITY;

-- 9. Enhanced Helper Functions for RLS Policies
CREATE OR REPLACE FUNCTION public.can_view_validation_data()
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

CREATE OR REPLACE FUNCTION public.owns_content_report(report_uuid UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM public.user_content_reports ucr
    WHERE ucr.id = report_uuid AND ucr.reporter_id = auth.uid()
)
$$;

CREATE OR REPLACE FUNCTION public.can_manage_admin_queue()
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

-- 10. RLS Policies
-- Validation data: Readers and admins can view, admins can manage
CREATE POLICY "readers_view_source_validations" ON public.reading_source_validations
FOR SELECT TO authenticated
USING (public.can_view_validation_data());

CREATE POLICY "admin_manage_source_validations" ON public.reading_source_validations
FOR ALL TO authenticated
USING (public.is_admin()) WITH CHECK (public.is_admin());

-- User reports: Users can create and view their own reports, admins can manage all
CREATE POLICY "users_manage_own_reports" ON public.user_content_reports
FOR ALL TO authenticated
USING (public.owns_content_report(id) OR public.is_admin())
WITH CHECK (auth.uid() = reporter_id OR public.is_admin());

-- Quality rules: Readers can view, admins can manage
CREATE POLICY "readers_view_quality_rules" ON public.data_quality_rules
FOR SELECT TO authenticated
USING (public.can_view_validation_data());

CREATE POLICY "admin_manage_quality_rules" ON public.data_quality_rules
FOR ALL TO authenticated
USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Quality scores: Public can view, system can update
CREATE POLICY "public_view_quality_scores" ON public.reading_quality_scores
FOR SELECT TO public USING (true);

CREATE POLICY "system_manage_quality_scores" ON public.reading_quality_scores
FOR ALL TO authenticated
USING (public.can_view_validation_data()) WITH CHECK (public.can_view_validation_data());

-- Admin review queue: Admins only
CREATE POLICY "admin_manage_review_queue" ON public.admin_review_queue
FOR ALL TO authenticated
USING (public.can_manage_admin_queue()) WITH CHECK (public.can_manage_admin_queue());

-- 11. Update Timestamp Triggers
CREATE TRIGGER update_data_quality_rules_updated_at
    BEFORE UPDATE ON public.data_quality_rules
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 12. Advanced Validation Functions
CREATE OR REPLACE FUNCTION public.calculate_content_similarity(
    content1 TEXT,
    content2 TEXT
) RETURNS DECIMAL(5,4)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    similarity_score DECIMAL(5,4) := 0.0000;
    words1 TEXT[];
    words2 TEXT[];
    common_words INTEGER := 0;
    total_unique_words INTEGER;
BEGIN
    -- Simple word-based similarity calculation
    words1 := string_to_array(lower(regexp_replace(content1, '[^\w\s]', '', 'g')), ' ');
    words2 := string_to_array(lower(regexp_replace(content2, '[^\w\s]', '', 'g')), ' ');
    
    -- Count common words
    SELECT COUNT(*)
    INTO common_words
    FROM unnest(words1) w1
    WHERE w1 = ANY(words2);
    
    -- Calculate total unique words
    total_unique_words := (
        SELECT COUNT(DISTINCT w) 
        FROM (
            SELECT unnest(words1) as w
            UNION ALL
            SELECT unnest(words2) as w
        ) combined
    );
    
    IF total_unique_words > 0 THEN
        similarity_score := (common_words * 2.0) / total_unique_words;
    END IF;
    
    RETURN LEAST(similarity_score, 1.0000);
END;
$$;

CREATE OR REPLACE FUNCTION public.validate_citation_format(citation TEXT)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    result JSONB := '{}';
    is_valid BOOLEAN := false;
    confidence DECIMAL(5,4) := 0.0000;
BEGIN
    -- Check various biblical citation patterns
    IF citation ~ '^[A-Za-z\s]+\s+\d+:\d+(-\d+)?$' THEN
        is_valid := true;
        confidence := 0.9000;
    ELSIF citation ~ '^[A-Za-z\s]+\s+\d+:\d+-\d+:\d+$' THEN
        is_valid := true;
        confidence := 0.8500;
    ELSIF citation ~ '^[A-Za-z\s]+\s+\d+$' THEN
        is_valid := true;
        confidence := 0.7000;
    ELSIF citation ~ '^\w+' AND length(citation) > 3 THEN
        is_valid := false;
        confidence := 0.3000;
    END IF;
    
    result := jsonb_build_object(
        'is_valid', is_valid,
        'confidence_score', confidence,
        'format_type', CASE 
            WHEN citation ~ '^[A-Za-z\s]+\s+\d+:\d+(-\d+)?$' THEN 'standard'
            WHEN citation ~ '^[A-Za-z\s]+\s+\d+:\d+-\d+:\d+$' THEN 'cross_chapter'
            WHEN citation ~ '^[A-Za-z\s]+\s+\d+$' THEN 'chapter_only'
            ELSE 'unknown'
        END
    );
    
    RETURN result;
END;
$$;

-- 13. Initialize Default Data Quality Rules
INSERT INTO public.data_quality_rules (rule_name, rule_description, rule_type, rule_criteria, weight_factor) VALUES
    ('minimum_content_length', 'Reading content must be at least 50 characters', 'content_length', '{"min_length": 50}', 1.00),
    ('maximum_content_length', 'Reading content should not exceed 10000 characters', 'content_length', '{"max_length": 10000}', 0.50),
    ('citation_format_standard', 'Citation must follow standard biblical format', 'citation_format', '{"pattern": "book chapter:verse"}', 1.20),
    ('no_html_content', 'Content should not contain HTML tags', 'content_quality', '{"forbidden_patterns": ["<", ">", "&lt;", "&gt;"]}', 0.80),
    ('no_encoding_errors', 'Content should not contain encoding errors', 'content_quality', '{"forbidden_patterns": ["???", "â€", "&amp;"]}', 1.10),
    ('language_readability', 'Content should maintain appropriate reading level', 'language_quality', '{"min_score": 0.60}', 0.90);

-- 14. Mock Validation Data for Testing
DO $$
DECLARE
    sample_reading_id UUID;
    quality_rule_id UUID;
    report_id UUID;
BEGIN
    -- Get a sample reading ID
    SELECT id INTO sample_reading_id 
    FROM public.liturgical_readings 
    LIMIT 1;
    
    IF sample_reading_id IS NOT NULL THEN
        -- Create sample source validation
        INSERT INTO public.reading_source_validations (
            reading_id, source_name, source_content, source_citation, 
            content_similarity_score, citation_match_score, overall_confidence_score
        ) VALUES (
            sample_reading_id, 'usccb'::public.validation_source,
            'Sample validation content from USCCB source for cross-referencing accuracy.',
            'Sample Citation Format',
            0.8500, 0.9200, 0.8850
        );
        
        -- Create sample quality score
        INSERT INTO public.reading_quality_scores (
            reading_id, overall_quality_score, content_quality_score, 
            citation_accuracy_score, source_agreement_score, language_quality_score
        ) VALUES (
            sample_reading_id, 0.8750, 0.9000, 0.8200, 0.8500, 0.9100
        );
        
        -- Create sample admin review queue item
        INSERT INTO public.admin_review_queue (
            content_id, content_type, priority_level, review_reason
        ) VALUES (
            sample_reading_id, 'reading', 2, 'Automated validation detected potential citation format issue'
        );
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error creating sample validation data: %', SQLERRM;
END $$;

-- 15. Cleanup Function for Validation Data
CREATE OR REPLACE FUNCTION public.cleanup_validation_test_data()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Delete validation test data
    DELETE FROM public.reading_source_validations WHERE source_content LIKE 'Sample validation content%';
    DELETE FROM public.reading_quality_scores WHERE overall_quality_score = 0.8750;
    DELETE FROM public.admin_review_queue WHERE review_reason LIKE 'Automated validation detected%';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Validation cleanup failed: %', SQLERRM;
END;
$$;

-- Enable realtime for admin tables
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_content_reports;
ALTER PUBLICATION supabase_realtime ADD TABLE public.admin_review_queue;
ALTER PUBLICATION supabase_realtime ADD TABLE public.reading_quality_scores;