/* © 2024 Social Media Analytics Platform. All rights reserved. 
@https://github.com/yourusername/social-media-analytics-platform
*/

-- =============================================
-- CONTENT PERFORMANCE ANALYTICS QUERIES
-- =============================================

-- 1. VIRAL CONTENT IDENTIFICATION
-- Identifies content with highest viral potential and engagement
WITH viral_content_metrics AS (
    SELECT 
        cp.id,
        u.username,
        cp.content_type,
        cp.content_category,
        cp.caption,
        cp.created_at,
        cpm.likes_count,
        cpm.comments_count,
        cpm.shares_count,
        cpm.engagement_rate,
        cpm.virality_score,
        cpm.reach_count,
        cpm.impressions_count,
        -- Viral coefficient calculation
        ROUND(
            (cpm.shares_count::DECIMAL / NULLIF(cpm.likes_count, 0)) * 
            (cpm.comments_count::DECIMAL / NULLIF(cpm.likes_count, 0)) * 
            cpm.virality_score, 2
        ) as viral_coefficient
    FROM content_posts cp
    JOIN users u ON cp.user_id = u.id
    JOIN content_performance_metrics cpm ON cp.id = cpm.content_id
    WHERE cp.created_at >= CURRENT_DATE - INTERVAL '7 days'
        AND cpm.likes_count >= 100  -- Minimum engagement threshold
)
SELECT 
    *,
    CASE 
        WHEN viral_coefficient >= 2.0 THEN 'Highly Viral'
        WHEN viral_coefficient >= 1.0 THEN 'Viral'
        WHEN viral_coefficient >= 0.5 THEN 'Trending'
        ELSE 'Regular'
    END as viral_status
FROM viral_content_metrics
ORDER BY viral_coefficient DESC, virality_score DESC
LIMIT 25;

-- 2. CONTENT PERFORMANCE BY TIME OF DAY
-- Analyzes content performance based on posting time
SELECT 
    EXTRACT(HOUR FROM cp.created_at) as posting_hour,
    COUNT(cp.id) as total_posts,
    ROUND(AVG(cpm.engagement_rate), 2) as avg_engagement_rate,
    ROUND(AVG(cpm.virality_score), 2) as avg_virality_score,
    ROUND(AVG(cpm.likes_count), 0) as avg_likes,
    ROUND(AVG(cpm.comments_count), 0) as avg_comments,
    ROUND(AVG(cpm.shares_count), 0) as avg_shares,
    ROUND(AVG(cpm.reach_count), 0) as avg_reach,
    ROUND(MAX(cpm.engagement_rate), 2) as max_engagement_rate,
    ROUND(MAX(cpm.virality_score), 2) as max_virality_score
FROM content_posts cp
JOIN content_performance_metrics cpm ON cp.id = cpm.content_id
WHERE cp.created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY EXTRACT(HOUR FROM cp.created_at)
ORDER BY avg_engagement_rate DESC;

-- 3. CONTENT LIFECYCLE ANALYSIS
-- Analyzes how content performance changes over time
WITH content_lifecycle AS (
    SELECT 
        cp.id,
        u.username,
        cp.content_type,
        cp.created_at,
        cpm.engagement_rate,
        cpm.virality_score,
        cpm.peak_engagement_time,
        EXTRACT(EPOCH FROM (cpm.peak_engagement_time - cp.created_at))/3600 as hours_to_peak,
        EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - cp.created_at))/3600 as total_hours_active,
        CASE 
            WHEN EXTRACT(EPOCH FROM (cpm.peak_engagement_time - cp.created_at))/3600 <= 1 THEN 'Immediate'
            WHEN EXTRACT(EPOCH FROM (cpm.peak_engagement_time - cp.created_at))/3600 <= 6 THEN 'Fast'
            WHEN EXTRACT(EPOCH FROM (cpm.peak_engagement_time - cp.created_at))/3600 <= 24 THEN 'Steady'
            ELSE 'Slow'
        END as growth_pattern
    FROM content_posts cp
    JOIN users u ON cp.user_id = u.id
    JOIN content_performance_metrics cpm ON cp.id = cpm.content_id
    WHERE cp.created_at >= CURRENT_DATE - INTERVAL '14 days'
        AND cpm.peak_engagement_time IS NOT NULL
)
SELECT 
    growth_pattern,
    COUNT(*) as content_count,
    ROUND(AVG(hours_to_peak), 1) as avg_hours_to_peak,
    ROUND(AVG(engagement_rate), 2) as avg_engagement_rate,
    ROUND(AVG(virality_score), 2) as avg_virality_score,
    ROUND(AVG(total_hours_active), 1) as avg_total_hours_active
FROM content_lifecycle
GROUP BY growth_pattern
ORDER BY avg_engagement_rate DESC;

-- 4. HASHTAG IMPACT ON CONTENT PERFORMANCE
-- Analyzes how hashtags affect content performance
WITH hashtag_performance AS (
    SELECT 
        cp.id,
        cp.content_category,
        cp.created_at,
        cpm.engagement_rate,
        cpm.virality_score,
        cpm.likes_count,
        cpm.comments_count,
        cpm.shares_count,
        COUNT(ch.hashtag_id) as hashtag_count,
        STRING_AGG(h.tag_name, ', ' ORDER BY h.popularity_score DESC) as top_hashtags,
        ROUND(AVG(h.popularity_score), 2) as avg_hashtag_popularity,
        ROUND(AVG(h.trend_score), 2) as avg_hashtag_trend
    FROM content_posts cp
    JOIN content_performance_metrics cpm ON cp.id = cpm.content_id
    LEFT JOIN content_hashtags ch ON cp.id = ch.content_id
    LEFT JOIN hashtags h ON ch.hashtag_id = h.id
    WHERE cp.created_at >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY cp.id, cp.content_category, cp.created_at, 
             cpm.engagement_rate, cpm.virality_score, 
             cpm.likes_count, cpm.comments_count, cpm.shares_count
)
SELECT 
    CASE 
        WHEN hashtag_count = 0 THEN 'No Hashtags'
        WHEN hashtag_count BETWEEN 1 AND 3 THEN 'Few Hashtags (1-3)'
        WHEN hashtag_count BETWEEN 4 AND 7 THEN 'Moderate Hashtags (4-7)'
        WHEN hashtag_count BETWEEN 8 AND 15 THEN 'Many Hashtags (8-15)'
        ELSE 'Excessive Hashtags (15+)'
    END as hashtag_strategy,
    COUNT(*) as content_count,
    ROUND(AVG(engagement_rate), 2) as avg_engagement_rate,
    ROUND(AVG(virality_score), 2) as avg_virality_score,
    ROUND(AVG(likes_count), 0) as avg_likes,
    ROUND(AVG(comments_count), 0) as avg_comments,
    ROUND(AVG(shares_count), 0) as avg_shares,
    ROUND(AVG(avg_hashtag_popularity), 2) as avg_hashtag_popularity,
    ROUND(AVG(avg_hashtag_trend), 2) as avg_hashtag_trend
FROM hashtag_performance
GROUP BY 
    CASE 
        WHEN hashtag_count = 0 THEN 'No Hashtags'
        WHEN hashtag_count BETWEEN 1 AND 3 THEN 'Few Hashtags (1-3)'
        WHEN hashtag_count BETWEEN 4 AND 7 THEN 'Moderate Hashtags (4-7)'
        WHEN hashtag_count BETWEEN 8 AND 15 THEN 'Many Hashtags (8-15)'
        ELSE 'Excessive Hashtags (15+)'
    END
ORDER BY avg_engagement_rate DESC;

-- 5. CONTENT CATEGORY PERFORMANCE TRENDS
-- Analyzes performance trends across different content categories
WITH category_trends AS (
    SELECT 
        cp.content_category,
        DATE_TRUNC('week', cp.created_at) as week_start,
        COUNT(cp.id) as posts_count,
        ROUND(AVG(cpm.engagement_rate), 2) as avg_engagement_rate,
        ROUND(AVG(cpm.virality_score), 2) as avg_virality_score,
        ROUND(SUM(cpm.likes_count), 0) as total_likes,
        ROUND(SUM(cpm.comments_count), 0) as total_comments,
        ROUND(SUM(cpm.shares_count), 0) as total_shares
    FROM content_posts cp
    JOIN content_performance_metrics cpm ON cp.id = cpm.content_id
    WHERE cp.created_at >= CURRENT_DATE - INTERVAL '12 weeks'
        AND cp.content_category IS NOT NULL
    GROUP BY cp.content_category, DATE_TRUNC('week', cp.created_at)
)
SELECT 
    content_category,
    week_start,
    posts_count,
    avg_engagement_rate,
    avg_virality_score,
    total_likes,
    total_comments,
    total_shares,
    -- Week-over-week growth calculation
    LAG(avg_engagement_rate) OVER (PARTITION BY content_category ORDER BY week_start) as prev_week_engagement,
    ROUND(
        ((avg_engagement_rate - LAG(avg_engagement_rate) OVER (PARTITION BY content_category ORDER BY week_start)) / 
         NULLIF(LAG(avg_engagement_rate) OVER (PARTITION BY content_category ORDER BY week_start), 0)) * 100, 2
    ) as engagement_growth_pct
FROM category_trends
ORDER BY content_category, week_start DESC;

-- 6. CONTENT PERFORMANCE PREDICTION FACTORS
-- Identifies key factors that predict high-performing content
WITH content_factors AS (
    SELECT 
        cp.id,
        cp.content_type,
        cp.content_category,
        EXTRACT(HOUR FROM cp.created_at) as posting_hour,
        EXTRACT(DOW FROM cp.created_at) as posting_day,
        LENGTH(cp.caption) as caption_length,
        CASE WHEN cp.location IS NOT NULL THEN 1 ELSE 0 END as has_location,
        CASE WHEN cp.is_promoted THEN 1 ELSE 0 END as is_promoted,
        COUNT(ch.hashtag_id) as hashtag_count,
        ROUND(AVG(h.popularity_score), 2) as avg_hashtag_popularity,
        cpm.engagement_rate,
        cpm.virality_score,
        CASE WHEN cpm.engagement_rate >= 5.0 THEN 1 ELSE 0 END as is_high_performing
    FROM content_posts cp
    JOIN content_performance_metrics cpm ON cp.id = cpm.content_id
    LEFT JOIN content_hashtags ch ON cp.id = ch.content_id
    LEFT JOIN hashtags h ON ch.hashtag_id = h.id
    WHERE cp.created_at >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY cp.id, cp.content_type, cp.content_category, 
             EXTRACT(HOUR FROM cp.created_at), EXTRACT(DOW FROM cp.created_at),
             LENGTH(cp.caption), cp.location, cp.is_promoted, 
             cpm.engagement_rate, cpm.virality_score
)
SELECT 
    content_type,
    content_category,
    posting_hour,
    posting_day,
    CASE 
        WHEN caption_length = 0 THEN 'No Caption'
        WHEN caption_length <= 50 THEN 'Short Caption'
        WHEN caption_length <= 150 THEN 'Medium Caption'
        ELSE 'Long Caption'
    END as caption_length_category,
    CASE WHEN has_location = 1 THEN 'With Location' ELSE 'No Location' END as location_status,
    CASE WHEN is_promoted = 1 THEN 'Promoted' ELSE 'Organic' END as promotion_status,
    CASE 
        WHEN hashtag_count = 0 THEN 'No Hashtags'
        WHEN hashtag_count <= 5 THEN 'Few Hashtags'
        WHEN hashtag_count <= 10 THEN 'Moderate Hashtags'
        ELSE 'Many Hashtags'
    END as hashtag_strategy,
    COUNT(*) as total_posts,
    SUM(is_high_performing) as high_performing_posts,
    ROUND(SUM(is_high_performing)::DECIMAL / COUNT(*) * 100, 1) as high_performance_rate,
    ROUND(AVG(engagement_rate), 2) as avg_engagement_rate,
    ROUND(AVG(virality_score), 2) as avg_virality_score
FROM content_factors
GROUP BY content_type, content_category, posting_hour, posting_day,
         CASE 
             WHEN caption_length = 0 THEN 'No Caption'
             WHEN caption_length <= 50 THEN 'Short Caption'
             WHEN caption_length <= 150 THEN 'Medium Caption'
             ELSE 'Long Caption'
         END,
         CASE WHEN has_location = 1 THEN 'With Location' ELSE 'No Location' END,
         CASE WHEN is_promoted = 1 THEN 'Promoted' ELSE 'Organic' END,
         CASE 
             WHEN hashtag_count = 0 THEN 'No Hashtags'
             WHEN hashtag_count <= 5 THEN 'Few Hashtags'
             WHEN hashtag_count <= 10 THEN 'Moderate Hashtags'
             ELSE 'Many Hashtags'
         END
HAVING COUNT(*) >= 5  -- Minimum sample size
ORDER BY high_performance_rate DESC, avg_engagement_rate DESC;

-- 7. CONTENT PERFORMANCE BY USER SEGMENT
-- Analyzes how different user segments perform with their content
SELECT 
    usa.user_segment,
    cp.content_type,
    cp.content_category,
    COUNT(cp.id) as total_posts,
    ROUND(AVG(cpm.engagement_rate), 2) as avg_engagement_rate,
    ROUND(AVG(cpm.virality_score), 2) as avg_virality_score,
    ROUND(AVG(cpm.likes_count), 0) as avg_likes,
    ROUND(AVG(cpm.comments_count), 0) as avg_comments,
    ROUND(AVG(cpm.shares_count), 0) as avg_shares,
    ROUND(AVG(cpm.reach_count), 0) as avg_reach,
    ROUND(AVG(cpm.impressions_count), 0) as avg_impressions
FROM content_posts cp
JOIN content_performance_metrics cpm ON cp.id = cpm.content_id
JOIN user_segment_assignments usa ON cp.user_id = usa.user_id
JOIN user_segments us ON usa.segment_id = us.id
WHERE cp.created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY usa.user_segment, cp.content_type, cp.content_category
ORDER BY usa.user_segment, avg_engagement_rate DESC;

-- 8. CONTENT PERFORMANCE CORRELATION ANALYSIS
-- Analyzes correlations between different performance metrics
WITH performance_correlations AS (
    SELECT 
        cp.id,
        cpm.likes_count,
        cpm.comments_count,
        cpm.shares_count,
        cpm.engagement_rate,
        cpm.virality_score,
        cpm.reach_count,
        cpm.impressions_count,
        -- Calculate engagement ratios
        ROUND(cpm.comments_count::DECIMAL / NULLIF(cpm.likes_count, 0), 3) as comment_like_ratio,
        ROUND(cpm.shares_count::DECIMAL / NULLIF(cpm.likes_count, 0), 3) as share_like_ratio,
        ROUND(cpm.reach_count::DECIMAL / NULLIF(cpm.impressions_count, 0), 3) as reach_impression_ratio
    FROM content_posts cp
    JOIN content_performance_metrics cpm ON cp.id = cpm.content_id
    WHERE cp.created_at >= CURRENT_DATE - INTERVAL '30 days'
        AND cpm.likes_count > 0
)
SELECT 
    'Likes vs Comments' as metric_pair,
    ROUND(CORR(likes_count, comments_count), 3) as correlation_coefficient,
    'Strong Positive' as correlation_strength
FROM performance_correlations
UNION ALL
SELECT 
    'Likes vs Shares' as metric_pair,
    ROUND(CORR(likes_count, shares_count), 3) as correlation_coefficient,
    'Strong Positive' as correlation_strength
FROM performance_correlations
UNION ALL
SELECT 
    'Engagement Rate vs Virality Score' as metric_pair,
    ROUND(CORR(engagement_rate, virality_score), 3) as correlation_coefficient,
    'Strong Positive' as correlation_strength
FROM performance_correlations
UNION ALL
SELECT 
    'Reach vs Impressions' as metric_pair,
    ROUND(CORR(reach_count, impressions_count), 3) as correlation_coefficient,
    'Strong Positive' as correlation_strength
FROM performance_correlations
ORDER BY ABS(correlation_coefficient) DESC;

-- 9. CONTENT PERFORMANCE ANOMALY DETECTION
-- Identifies content with unusual performance patterns
WITH performance_stats AS (
    SELECT 
        AVG(engagement_rate) as avg_engagement,
        STDDEV(engagement_rate) as stddev_engagement,
        AVG(virality_score) as avg_virality,
        STDDEV(virality_score) as stddev_virality
    FROM content_performance_metrics cpm
    JOIN content_posts cp ON cpm.content_id = cp.id
    WHERE cp.created_at >= CURRENT_DATE - INTERVAL '30 days'
),
anomaly_detection AS (
    SELECT 
        cp.id,
        u.username,
        cp.content_type,
        cp.content_category,
        cpm.engagement_rate,
        cpm.virality_score,
        cpm.likes_count,
        cpm.comments_count,
        cpm.shares_count,
        -- Z-score calculation for anomaly detection
        ROUND(ABS((cpm.engagement_rate - ps.avg_engagement) / ps.stddev_engagement), 2) as engagement_z_score,
        ROUND(ABS((cpm.virality_score - ps.avg_virality) / ps.stddev_virality), 2) as virality_z_score
    FROM content_posts cp
    JOIN users u ON cp.user_id = u.id
    JOIN content_performance_metrics cpm ON cp.id = cpm.content_id
    CROSS JOIN performance_stats ps
    WHERE cp.created_at >= CURRENT_DATE - INTERVAL '7 days'
)
SELECT 
    *,
    CASE 
        WHEN engagement_z_score >= 2.0 OR virality_z_score >= 2.0 THEN 'High Anomaly'
        WHEN engagement_z_score >= 1.5 OR virality_z_score >= 1.5 THEN 'Medium Anomaly'
        ELSE 'Normal'
    END as anomaly_level
FROM anomaly_detection
WHERE engagement_z_score >= 1.5 OR virality_z_score >= 1.5
ORDER BY (engagement_z_score + virality_z_score) DESC;

-- 10. CONTENT PERFORMANCE FORECASTING DATA
-- Prepares data for time series forecasting of content performance
SELECT 
    DATE_TRUNC('day', cp.created_at) as date,
    cp.content_type,
    cp.content_category,
    COUNT(cp.id) as daily_posts,
    ROUND(AVG(cpm.engagement_rate), 2) as avg_engagement_rate,
    ROUND(AVG(cpm.virality_score), 2) as avg_virality_score,
    ROUND(SUM(cpm.likes_count), 0) as total_likes,
    ROUND(SUM(cpm.comments_count), 0) as total_comments,
    ROUND(SUM(cpm.shares_count), 0) as total_shares,
    ROUND(SUM(cpm.reach_count), 0) as total_reach,
    ROUND(SUM(cpm.impressions_count), 0) as total_impressions
FROM content_posts cp
JOIN content_performance_metrics cpm ON cp.id = cpm.content_id
WHERE cp.created_at >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY DATE_TRUNC('day', cp.created_at), cp.content_type, cp.content_category
ORDER BY date DESC, avg_engagement_rate DESC;
