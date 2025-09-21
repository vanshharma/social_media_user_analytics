/* © 2024 Social Media Analytics Platform. All rights reserved. 
@https://github.com/yourusername/social-media-analytics-platform
*/

-- =============================================
-- ADVANCED ENGAGEMENT ANALYTICS QUERIES
-- =============================================

-- 1. TOP PERFORMING CONTENT CREATORS BY ENGAGEMENT RATE
-- Identifies users with the highest engagement rates and their content performance
SELECT 
    u.id,
    u.username,
    u.account_type,
    u.follower_count,
    ROUND(AVG(cpm.engagement_rate), 2) as avg_engagement_rate,
    COUNT(cp.id) as total_posts,
    SUM(cpm.likes_count) as total_likes,
    SUM(cpm.comments_count) as total_comments,
    SUM(cpm.shares_count) as total_shares,
    ROUND(SUM(cpm.virality_score), 2) as total_virality_score
FROM users u
JOIN content_posts cp ON u.id = cp.user_id
JOIN content_performance_metrics cpm ON cp.id = cpm.content_id
WHERE cp.created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY u.id, u.username, u.account_type, u.follower_count
HAVING COUNT(cp.id) >= 5  -- Minimum 5 posts for reliable metrics
ORDER BY avg_engagement_rate DESC, total_virality_score DESC
LIMIT 20;

-- 2. CONTENT CATEGORY PERFORMANCE ANALYSIS
-- Analyzes which content categories perform best across different metrics
SELECT 
    cp.content_category,
    COUNT(cp.id) as total_posts,
    ROUND(AVG(cpm.engagement_rate), 2) as avg_engagement_rate,
    ROUND(AVG(cpm.virality_score), 2) as avg_virality_score,
    ROUND(AVG(cpm.reach_count), 0) as avg_reach,
    ROUND(AVG(cpm.impressions_count), 0) as avg_impressions,
    ROUND(SUM(cpm.likes_count)::DECIMAL / COUNT(cp.id), 2) as avg_likes_per_post,
    ROUND(SUM(cpm.comments_count)::DECIMAL / COUNT(cp.id), 2) as avg_comments_per_post
FROM content_posts cp
JOIN content_performance_metrics cpm ON cp.id = cpm.content_id
WHERE cp.created_at >= CURRENT_DATE - INTERVAL '30 days'
    AND cp.content_category IS NOT NULL
GROUP BY cp.content_category
ORDER BY avg_engagement_rate DESC;

-- 3. INFLUENCER IDENTIFICATION AND RANKING
-- Identifies users with high influence based on engagement and follower metrics
WITH influencer_metrics AS (
    SELECT 
        u.id,
        u.username,
        u.follower_count,
        u.following_count,
        ROUND(u.follower_count::DECIMAL / NULLIF(u.following_count, 0), 2) as follower_following_ratio,
        ROUND(AVG(cpm.engagement_rate), 2) as avg_engagement_rate,
        COUNT(cp.id) as total_posts,
        SUM(cpm.reach_count) as total_reach,
        ROUND(SUM(cpm.virality_score), 2) as total_virality_score
    FROM users u
    LEFT JOIN content_posts cp ON u.id = cp.user_id 
        AND cp.created_at >= CURRENT_DATE - INTERVAL '30 days'
    LEFT JOIN content_performance_metrics cpm ON cp.id = cpm.content_id
    WHERE u.follower_count >= 1000  -- Minimum follower threshold
    GROUP BY u.id, u.username, u.follower_count, u.following_count
),
influencer_scores AS (
    SELECT 
        *,
        ROUND(
            (follower_following_ratio * 0.3) + 
            (avg_engagement_rate * 0.4) + 
            (total_virality_score * 0.3), 2
        ) as influence_score
    FROM influencer_metrics
)
SELECT 
    id,
    username,
    follower_count,
    follower_following_ratio,
    avg_engagement_rate,
    total_posts,
    total_reach,
    influence_score,
    CASE 
        WHEN influence_score >= 8.0 THEN 'Top Influencer'
        WHEN influence_score >= 6.0 THEN 'Micro Influencer'
        WHEN influence_score >= 4.0 THEN 'Rising Influencer'
        ELSE 'Emerging Creator'
    END as influencer_tier
FROM influencer_scores
ORDER BY influence_score DESC
LIMIT 50;

-- 4. ENGAGEMENT VELOCITY ANALYSIS
-- Analyzes how quickly content gains engagement after posting
SELECT 
    cp.id,
    u.username,
    cp.content_type,
    cp.content_category,
    cp.created_at,
    cpm.likes_count,
    cpm.comments_count,
    cpm.engagement_rate,
    cpm.peak_engagement_time,
    EXTRACT(EPOCH FROM (cpm.peak_engagement_time - cp.created_at))/3600 as hours_to_peak_engagement,
    CASE 
        WHEN EXTRACT(EPOCH FROM (cpm.peak_engagement_time - cp.created_at))/3600 <= 1 THEN 'Viral Speed'
        WHEN EXTRACT(EPOCH FROM (cpm.peak_engagement_time - cp.created_at))/3600 <= 6 THEN 'Fast Growth'
        WHEN EXTRACT(EPOCH FROM (cpm.peak_engagement_time - cp.created_at))/3600 <= 24 THEN 'Steady Growth'
        ELSE 'Slow Burn'
    END as engagement_velocity
FROM content_posts cp
JOIN users u ON cp.user_id = u.id
JOIN content_performance_metrics cpm ON cp.id = cpm.content_id
WHERE cp.created_at >= CURRENT_DATE - INTERVAL '7 days'
    AND cpm.peak_engagement_time IS NOT NULL
ORDER BY hours_to_peak_engagement ASC;

-- 5. USER SEGMENTATION BASED ON ENGAGEMENT PATTERNS
-- Segments users based on their engagement behavior and content performance
WITH user_engagement_stats AS (
    SELECT 
        u.id,
        u.username,
        u.account_type,
        u.follower_count,
        COUNT(cp.id) as total_posts,
        ROUND(AVG(cpm.engagement_rate), 2) as avg_engagement_rate,
        ROUND(AVG(cpm.virality_score), 2) as avg_virality_score,
        SUM(cpm.likes_count) as total_likes,
        SUM(cpm.comments_count) as total_comments,
        SUM(cpm.shares_count) as total_shares,
        COUNT(DISTINCT DATE(cp.created_at)) as active_days
    FROM users u
    LEFT JOIN content_posts cp ON u.id = cp.user_id 
        AND cp.created_at >= CURRENT_DATE - INTERVAL '30 days'
    LEFT JOIN content_performance_metrics cpm ON cp.id = cpm.content_id
    GROUP BY u.id, u.username, u.account_type, u.follower_count
),
user_segments AS (
    SELECT 
        *,
        CASE 
            WHEN avg_engagement_rate >= 8.0 AND total_posts >= 20 THEN 'High Performer'
            WHEN avg_engagement_rate >= 5.0 AND total_posts >= 10 THEN 'Consistent Creator'
            WHEN avg_engagement_rate >= 3.0 AND total_posts >= 5 THEN 'Regular Poster'
            WHEN total_posts >= 1 THEN 'Occasional Poster'
            ELSE 'Inactive User'
        END as user_segment,
        CASE 
            WHEN avg_virality_score >= 7.0 THEN 'Viral Creator'
            WHEN avg_virality_score >= 4.0 THEN 'Trending Creator'
            WHEN avg_virality_score >= 2.0 THEN 'Stable Creator'
            ELSE 'Niche Creator'
        END as content_quality_tier
    FROM user_engagement_stats
)
SELECT 
    user_segment,
    content_quality_tier,
    COUNT(*) as user_count,
    ROUND(AVG(avg_engagement_rate), 2) as avg_engagement_rate,
    ROUND(AVG(total_posts), 0) as avg_posts,
    ROUND(AVG(follower_count), 0) as avg_followers
FROM user_segments
GROUP BY user_segment, content_quality_tier
ORDER BY user_segment, content_quality_tier;

-- 6. OPTIMAL POSTING TIME ANALYSIS
-- Analyzes the best times to post content for maximum engagement
SELECT 
    EXTRACT(HOUR FROM cp.created_at) as posting_hour,
    EXTRACT(DOW FROM cp.created_at) as day_of_week,
    CASE EXTRACT(DOW FROM cp.created_at)
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END as day_name,
    COUNT(cp.id) as total_posts,
    ROUND(AVG(cpm.engagement_rate), 2) as avg_engagement_rate,
    ROUND(AVG(cpm.virality_score), 2) as avg_virality_score,
    ROUND(AVG(cpm.likes_count), 0) as avg_likes,
    ROUND(AVG(cpm.comments_count), 0) as avg_comments
FROM content_posts cp
JOIN content_performance_metrics cpm ON cp.id = cpm.content_id
WHERE cp.created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY EXTRACT(HOUR FROM cp.created_at), EXTRACT(DOW FROM cp.created_at)
ORDER BY avg_engagement_rate DESC, avg_virality_score DESC;

-- 7. HASHTAG PERFORMANCE AND TREND ANALYSIS
-- Analyzes hashtag performance and identifies trending tags
SELECT 
    h.tag_name,
    h.category,
    h.popularity_score,
    h.trend_score,
    COUNT(ch.content_id) as usage_count_30d,
    COUNT(DISTINCT ch.content_id) as unique_posts_30d,
    ROUND(AVG(cpm.engagement_rate), 2) as avg_engagement_rate,
    ROUND(AVG(cpm.virality_score), 2) as avg_virality_score,
    ROUND(SUM(cpm.likes_count)::DECIMAL / COUNT(ch.content_id), 0) as avg_likes_per_post
FROM hashtags h
JOIN content_hashtags ch ON h.id = ch.hashtag_id
JOIN content_posts cp ON ch.content_id = cp.id 
    AND cp.created_at >= CURRENT_DATE - INTERVAL '30 days'
JOIN content_performance_metrics cpm ON cp.id = cpm.content_id
GROUP BY h.id, h.tag_name, h.category, h.popularity_score, h.trend_score
HAVING COUNT(ch.content_id) >= 5  -- Minimum usage threshold
ORDER BY h.trend_score DESC, avg_engagement_rate DESC
LIMIT 30;

-- 8. CROSS-PLATFORM ENGAGEMENT COMPARISON
-- Compares engagement patterns across different content types
SELECT 
    cp.content_type,
    COUNT(cp.id) as total_posts,
    ROUND(AVG(cpm.engagement_rate), 2) as avg_engagement_rate,
    ROUND(AVG(cpm.virality_score), 2) as avg_virality_score,
    ROUND(AVG(cpm.reach_count), 0) as avg_reach,
    ROUND(AVG(cpm.impressions_count), 0) as avg_impressions,
    ROUND(SUM(cpm.likes_count)::DECIMAL / COUNT(cp.id), 2) as avg_likes_per_post,
    ROUND(SUM(cpm.comments_count)::DECIMAL / COUNT(cp.id), 2) as avg_comments_per_post,
    ROUND(SUM(cpm.shares_count)::DECIMAL / COUNT(cp.id), 2) as avg_shares_per_post
FROM content_posts cp
JOIN content_performance_metrics cpm ON cp.id = cpm.content_id
WHERE cp.created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY cp.content_type
ORDER BY avg_engagement_rate DESC;

-- 9. ENGAGEMENT QUALITY SCORE CALCULATION
-- Calculates a comprehensive engagement quality score for content
WITH engagement_quality AS (
    SELECT 
        cp.id,
        u.username,
        cp.content_type,
        cp.content_category,
        cpm.likes_count,
        cpm.comments_count,
        cpm.shares_count,
        cpm.engagement_rate,
        cpm.virality_score,
        cpm.reach_count,
        cpm.impressions_count,
        -- Weighted engagement quality score
        ROUND(
            (cpm.engagement_rate * 0.3) +
            (cpm.virality_score * 0.25) +
            (LOG(1 + cpm.likes_count) * 0.2) +
            (LOG(1 + cpm.comments_count) * 0.15) +
            (LOG(1 + cpm.shares_count) * 0.1), 2
        ) as engagement_quality_score
    FROM content_posts cp
    JOIN users u ON cp.user_id = u.id
    JOIN content_performance_metrics cpm ON cp.id = cpm.content_id
    WHERE cp.created_at >= CURRENT_DATE - INTERVAL '7 days'
)
SELECT 
    *,
    CASE 
        WHEN engagement_quality_score >= 8.0 THEN 'Exceptional'
        WHEN engagement_quality_score >= 6.0 THEN 'High Quality'
        WHEN engagement_quality_score >= 4.0 THEN 'Good'
        WHEN engagement_quality_score >= 2.0 THEN 'Average'
        ELSE 'Below Average'
    END as quality_tier
FROM engagement_quality
ORDER BY engagement_quality_score DESC
LIMIT 50;

-- 10. USER RETENTION AND ACTIVITY ANALYSIS
-- Analyzes user retention patterns and activity levels
WITH user_activity_analysis AS (
    SELECT 
        u.id,
        u.username,
        u.created_at as account_created,
        COUNT(DISTINCT DATE(cp.created_at)) as active_days_30d,
        COUNT(cp.id) as posts_30d,
        MAX(cp.created_at) as last_post_date,
        ROUND(AVG(cpm.engagement_rate), 2) as avg_engagement_rate,
        CASE 
            WHEN COUNT(cp.id) = 0 THEN 'Inactive'
            WHEN COUNT(cp.id) BETWEEN 1 AND 5 THEN 'Low Activity'
            WHEN COUNT(cp.id) BETWEEN 6 AND 15 THEN 'Moderate Activity'
            WHEN COUNT(cp.id) BETWEEN 16 AND 30 THEN 'High Activity'
            ELSE 'Very High Activity'
        END as activity_level
    FROM users u
    LEFT JOIN content_posts cp ON u.id = cp.user_id 
        AND cp.created_at >= CURRENT_DATE - INTERVAL '30 days'
    LEFT JOIN content_performance_metrics cpm ON cp.id = cpm.content_id
    GROUP BY u.id, u.username, u.created_at
)
SELECT 
    activity_level,
    COUNT(*) as user_count,
    ROUND(AVG(active_days_30d), 1) as avg_active_days,
    ROUND(AVG(posts_30d), 1) as avg_posts,
    ROUND(AVG(avg_engagement_rate), 2) as avg_engagement_rate,
    ROUND(COUNT(*)::DECIMAL / (SELECT COUNT(*) FROM users) * 100, 1) as percentage_of_users
FROM user_activity_analysis
GROUP BY activity_level
ORDER BY 
    CASE activity_level
        WHEN 'Very High Activity' THEN 1
        WHEN 'High Activity' THEN 2
        WHEN 'Moderate Activity' THEN 3
        WHEN 'Low Activity' THEN 4
        WHEN 'Inactive' THEN 5
    END;
