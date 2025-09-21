/* © 2024 Social Media Analytics Platform. All rights reserved. 
@https://github.com/yourusername/social-media-analytics-platform
*/

-- =============================================
-- USER BEHAVIOR ANALYTICS QUERIES
-- =============================================

-- 1. USER ACTIVITY PATTERNS ANALYSIS
-- Analyzes user activity patterns and engagement behaviors
WITH user_activity_metrics AS (
    SELECT 
        u.id,
        u.username,
        u.account_type,
        u.follower_count,
        u.following_count,
        u.created_at as account_created,
        COUNT(DISTINCT cp.id) as total_posts,
        COUNT(DISTINCT DATE(cp.created_at)) as active_days,
        MIN(cp.created_at) as first_post_date,
        MAX(cp.created_at) as last_post_date,
        COUNT(DISTINCT c.id) as total_comments_made,
        COUNT(DISTINCT l.content_id) as total_likes_given,
        COUNT(DISTINCT f.followee_id) as total_following,
        ROUND(AVG(cpm.engagement_rate), 2) as avg_engagement_rate,
        ROUND(AVG(cpm.virality_score), 2) as avg_virality_score
    FROM users u
    LEFT JOIN content_posts cp ON u.id = cp.user_id
    LEFT JOIN content_performance_metrics cpm ON cp.id = cpm.content_id
    LEFT JOIN comments c ON u.id = c.user_id
    LEFT JOIN likes l ON u.id = l.user_id
    LEFT JOIN follows f ON u.id = f.follower_id
    GROUP BY u.id, u.username, u.account_type, u.follower_count, u.following_count, u.created_at
),
user_behavior_classification AS (
    SELECT 
        *,
        CASE 
            WHEN total_posts = 0 THEN 'Inactive User'
            WHEN total_posts BETWEEN 1 AND 5 THEN 'Occasional Poster'
            WHEN total_posts BETWEEN 6 AND 20 THEN 'Regular Poster'
            WHEN total_posts BETWEEN 21 AND 50 THEN 'Frequent Poster'
            ELSE 'Power User'
        END as posting_frequency,
        CASE 
            WHEN active_days = 0 THEN 'Never Active'
            WHEN active_days BETWEEN 1 AND 7 THEN 'Low Activity'
            WHEN active_days BETWEEN 8 AND 20 THEN 'Moderate Activity'
            WHEN active_days BETWEEN 21 AND 30 THEN 'High Activity'
            ELSE 'Very High Activity'
        END as activity_level,
        CASE 
            WHEN total_likes_given = 0 THEN 'Non-Engager'
            WHEN total_likes_given BETWEEN 1 AND 50 THEN 'Light Engager'
            WHEN total_likes_given BETWEEN 51 AND 200 THEN 'Moderate Engager'
            WHEN total_likes_given BETWEEN 201 AND 500 THEN 'Heavy Engager'
            ELSE 'Super Engager'
        END as engagement_behavior,
        ROUND(follower_count::DECIMAL / NULLIF(following_count, 0), 2) as follower_following_ratio
    FROM user_activity_metrics
)
SELECT 
    posting_frequency,
    activity_level,
    engagement_behavior,
    COUNT(*) as user_count,
    ROUND(AVG(follower_count), 0) as avg_followers,
    ROUND(AVG(following_count), 0) as avg_following,
    ROUND(AVG(follower_following_ratio), 2) as avg_follower_following_ratio,
    ROUND(AVG(total_posts), 1) as avg_posts,
    ROUND(AVG(active_days), 1) as avg_active_days,
    ROUND(AVG(avg_engagement_rate), 2) as avg_engagement_rate,
    ROUND(AVG(avg_virality_score), 2) as avg_virality_score
FROM user_behavior_classification
GROUP BY posting_frequency, activity_level, engagement_behavior
ORDER BY user_count DESC;

-- 2. USER JOURNEY AND LIFECYCLE ANALYSIS
-- Analyzes user journey from registration to current activity level
WITH user_lifecycle AS (
    SELECT 
        u.id,
        u.username,
        u.account_type,
        u.created_at as registration_date,
        MIN(cp.created_at) as first_post_date,
        MAX(cp.created_at) as last_post_date,
        COUNT(cp.id) as total_posts,
        EXTRACT(DAYS FROM (COALESCE(MAX(cp.created_at), u.created_at) - u.created_at)) as days_since_registration,
        EXTRACT(DAYS FROM (COALESCE(MAX(cp.created_at), u.created_at) - COALESCE(MIN(cp.created_at), u.created_at))) as active_period_days,
        CASE 
            WHEN MIN(cp.created_at) IS NULL THEN 'Never Posted'
            WHEN EXTRACT(DAYS FROM (MIN(cp.created_at) - u.created_at)) <= 1 THEN 'Immediate Poster'
            WHEN EXTRACT(DAYS FROM (MIN(cp.created_at) - u.created_at)) <= 7 THEN 'Quick Starter'
            WHEN EXTRACT(DAYS FROM (MIN(cp.created_at) - u.created_at)) <= 30 THEN 'Delayed Starter'
            ELSE 'Late Starter'
        END as posting_behavior,
        CASE 
            WHEN MAX(cp.created_at) IS NULL THEN 'Never Active'
            WHEN EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - MAX(cp.created_at))) <= 1 THEN 'Very Recent'
            WHEN EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - MAX(cp.created_at))) <= 7 THEN 'Recent'
            WHEN EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - MAX(cp.created_at))) <= 30 THEN 'Moderate'
            ELSE 'Inactive'
        END as current_activity_status
    FROM users u
    LEFT JOIN content_posts cp ON u.id = cp.user_id
    GROUP BY u.id, u.username, u.account_type, u.created_at
)
SELECT 
    posting_behavior,
    current_activity_status,
    COUNT(*) as user_count,
    ROUND(AVG(days_since_registration), 1) as avg_days_since_registration,
    ROUND(AVG(active_period_days), 1) as avg_active_period_days,
    ROUND(AVG(total_posts), 1) as avg_total_posts,
    ROUND(COUNT(*)::DECIMAL / (SELECT COUNT(*) FROM users) * 100, 1) as percentage_of_users
FROM user_lifecycle
GROUP BY posting_behavior, current_activity_status
ORDER BY user_count DESC;

-- 3. USER ENGAGEMENT QUALITY ANALYSIS
-- Analyzes the quality of user engagement based on various metrics
WITH user_engagement_quality AS (
    SELECT 
        u.id,
        u.username,
        u.account_type,
        u.follower_count,
        -- Content creation metrics
        COUNT(cp.id) as posts_created,
        ROUND(AVG(cpm.engagement_rate), 2) as avg_engagement_rate,
        ROUND(AVG(cpm.virality_score), 2) as avg_virality_score,
        ROUND(SUM(cpm.likes_count), 0) as total_likes_received,
        ROUND(SUM(cpm.comments_count), 0) as total_comments_received,
        ROUND(SUM(cpm.shares_count), 0) as total_shares_received,
        -- Engagement given metrics
        COUNT(DISTINCT c.id) as comments_made,
        COUNT(DISTINCT l.content_id) as likes_given,
        COUNT(DISTINCT f.followee_id) as users_followed,
        -- Quality calculations
        ROUND(COUNT(c.id)::DECIMAL / NULLIF(COUNT(cp.id), 0), 2) as comment_to_post_ratio,
        ROUND(COUNT(l.content_id)::DECIMAL / NULLIF(COUNT(cp.id), 0), 2) as like_to_post_ratio,
        ROUND(AVG(cpm.engagement_rate) * COUNT(cp.id), 2) as total_engagement_impact
    FROM users u
    LEFT JOIN content_posts cp ON u.id = cp.user_id
    LEFT JOIN content_performance_metrics cpm ON cp.id = cpm.content_id
    LEFT JOIN comments c ON u.id = c.user_id
    LEFT JOIN likes l ON u.id = l.user_id
    LEFT JOIN follows f ON u.id = f.follower_id
    GROUP BY u.id, u.username, u.account_type, u.follower_count
),
engagement_quality_classification AS (
    SELECT 
        *,
        CASE 
            WHEN avg_engagement_rate >= 8.0 AND posts_created >= 10 THEN 'High Quality Creator'
            WHEN avg_engagement_rate >= 5.0 AND posts_created >= 5 THEN 'Quality Creator'
            WHEN avg_engagement_rate >= 3.0 AND posts_created >= 3 THEN 'Developing Creator'
            WHEN posts_created >= 1 THEN 'Basic Creator'
            ELSE 'Non-Creator'
        END as creator_quality,
        CASE 
            WHEN comment_to_post_ratio >= 2.0 AND like_to_post_ratio >= 5.0 THEN 'Super Engager'
            WHEN comment_to_post_ratio >= 1.0 AND like_to_post_ratio >= 3.0 THEN 'Active Engager'
            WHEN comment_to_post_ratio >= 0.5 OR like_to_post_ratio >= 2.0 THEN 'Moderate Engager'
            WHEN comment_to_post_ratio > 0 OR like_to_post_ratio > 0 THEN 'Light Engager'
            ELSE 'Passive User'
        END as engagement_quality
    FROM user_engagement_quality
)
SELECT 
    creator_quality,
    engagement_quality,
    COUNT(*) as user_count,
    ROUND(AVG(follower_count), 0) as avg_followers,
    ROUND(AVG(posts_created), 1) as avg_posts_created,
    ROUND(AVG(avg_engagement_rate), 2) as avg_engagement_rate,
    ROUND(AVG(avg_virality_score), 2) as avg_virality_score,
    ROUND(AVG(comment_to_post_ratio), 2) as avg_comment_to_post_ratio,
    ROUND(AVG(like_to_post_ratio), 2) as avg_like_to_post_ratio,
    ROUND(AVG(total_engagement_impact), 2) as avg_total_engagement_impact
FROM engagement_quality_classification
GROUP BY creator_quality, engagement_quality
ORDER BY user_count DESC;

-- 4. USER RETENTION AND CHURN ANALYSIS
-- Analyzes user retention patterns and identifies churn risk
WITH user_retention_analysis AS (
    SELECT 
        u.id,
        u.username,
        u.account_type,
        u.created_at as registration_date,
        COUNT(DISTINCT cp.id) as total_posts,
        MAX(cp.created_at) as last_post_date,
        COUNT(DISTINCT DATE(cp.created_at)) as active_days,
        EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - u.created_at)) as days_since_registration,
        EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - COALESCE(MAX(cp.created_at), u.created_at))) as days_since_last_activity,
        -- Retention metrics
        CASE 
            WHEN MAX(cp.created_at) IS NULL THEN 'Never Active'
            WHEN EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - MAX(cp.created_at))) <= 1 THEN 'Highly Active'
            WHEN EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - MAX(cp.created_at))) <= 7 THEN 'Recently Active'
            WHEN EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - MAX(cp.created_at))) <= 30 THEN 'Moderately Active'
            WHEN EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - MAX(cp.created_at))) <= 90 THEN 'Low Activity'
            ELSE 'Inactive/Churned'
        END as retention_status,
        -- Churn risk assessment
        CASE 
            WHEN MAX(cp.created_at) IS NULL AND EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - u.created_at)) > 30 THEN 'High Churn Risk'
            WHEN EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - MAX(cp.created_at))) > 90 THEN 'Churned'
            WHEN EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - MAX(cp.created_at))) > 30 THEN 'At Risk'
            ELSE 'Retained'
        END as churn_risk
    FROM users u
    LEFT JOIN content_posts cp ON u.id = cp.user_id
    GROUP BY u.id, u.username, u.account_type, u.created_at
)
SELECT 
    retention_status,
    churn_risk,
    COUNT(*) as user_count,
    ROUND(AVG(days_since_registration), 1) as avg_days_since_registration,
    ROUND(AVG(days_since_last_activity), 1) as avg_days_since_last_activity,
    ROUND(AVG(total_posts), 1) as avg_total_posts,
    ROUND(AVG(active_days), 1) as avg_active_days,
    ROUND(COUNT(*)::DECIMAL / (SELECT COUNT(*) FROM users) * 100, 1) as percentage_of_users
FROM user_retention_analysis
GROUP BY retention_status, churn_risk
ORDER BY user_count DESC;

-- 5. USER INFLUENCE NETWORK ANALYSIS
-- Analyzes user influence within the social network
WITH user_influence_metrics AS (
    SELECT 
        u.id,
        u.username,
        u.follower_count,
        u.following_count,
        -- Content influence metrics
        COUNT(cp.id) as posts_created,
        ROUND(AVG(cpm.engagement_rate), 2) as avg_engagement_rate,
        ROUND(SUM(cpm.likes_count), 0) as total_likes_received,
        ROUND(SUM(cpm.comments_count), 0) as total_comments_received,
        ROUND(SUM(cpm.shares_count), 0) as total_shares_received,
        ROUND(SUM(cpm.reach_count), 0) as total_reach,
        -- Social influence metrics
        COUNT(DISTINCT f.follower_id) as followers_count,
        COUNT(DISTINCT f2.followee_id) as following_count,
        COUNT(DISTINCT c.id) as comments_made,
        COUNT(DISTINCT l.content_id) as likes_given,
        -- Influence calculations
        ROUND(follower_count::DECIMAL / NULLIF(following_count, 0), 2) as follower_following_ratio,
        ROUND((SUM(cpm.likes_count) + SUM(cpm.comments_count) + SUM(cpm.shares_count))::DECIMAL / NULLIF(COUNT(cp.id), 0), 2) as avg_engagement_per_post
    FROM users u
    LEFT JOIN content_posts cp ON u.id = cp.user_id
    LEFT JOIN content_performance_metrics cpm ON cp.id = cpm.content_id
    LEFT JOIN follows f ON u.id = f.followee_id
    LEFT JOIN follows f2 ON u.id = f2.follower_id
    LEFT JOIN comments c ON u.id = c.user_id
    LEFT JOIN likes l ON u.id = l.user_id
    GROUP BY u.id, u.username, u.follower_count, u.following_count
),
influence_classification AS (
    SELECT 
        *,
        -- Influence score calculation
        ROUND(
            (follower_count * 0.3) + 
            (avg_engagement_rate * 10 * 0.3) + 
            (avg_engagement_per_post * 0.2) + 
            (follower_following_ratio * 0.2), 2
        ) as influence_score,
        CASE 
            WHEN follower_count >= 10000 AND avg_engagement_rate >= 5.0 THEN 'Mega Influencer'
            WHEN follower_count >= 5000 AND avg_engagement_rate >= 4.0 THEN 'Macro Influencer'
            WHEN follower_count >= 1000 AND avg_engagement_rate >= 3.0 THEN 'Micro Influencer'
            WHEN follower_count >= 500 AND avg_engagement_rate >= 2.0 THEN 'Nano Influencer'
            WHEN follower_count >= 100 THEN 'Rising Influencer'
            ELSE 'Regular User'
        END as influence_tier
    FROM user_influence_metrics
)
SELECT 
    influence_tier,
    COUNT(*) as user_count,
    ROUND(AVG(follower_count), 0) as avg_followers,
    ROUND(AVG(following_count), 0) as avg_following,
    ROUND(AVG(follower_following_ratio), 2) as avg_follower_following_ratio,
    ROUND(AVG(avg_engagement_rate), 2) as avg_engagement_rate,
    ROUND(AVG(avg_engagement_per_post), 2) as avg_engagement_per_post,
    ROUND(AVG(influence_score), 2) as avg_influence_score,
    ROUND(AVG(posts_created), 1) as avg_posts_created
FROM influence_classification
GROUP BY influence_tier
ORDER BY 
    CASE influence_tier
        WHEN 'Mega Influencer' THEN 1
        WHEN 'Macro Influencer' THEN 2
        WHEN 'Micro Influencer' THEN 3
        WHEN 'Nano Influencer' THEN 4
        WHEN 'Rising Influencer' THEN 5
        WHEN 'Regular User' THEN 6
    END;

-- 6. USER CONTENT PREFERENCE ANALYSIS
-- Analyzes user content preferences and posting patterns
WITH user_content_preferences AS (
    SELECT 
        u.id,
        u.username,
        u.account_type,
        cp.content_type,
        cp.content_category,
        COUNT(cp.id) as posts_in_category,
        ROUND(AVG(cpm.engagement_rate), 2) as avg_engagement_rate,
        ROUND(AVG(cpm.virality_score), 2) as avg_virality_score,
        ROUND(SUM(cpm.likes_count), 0) as total_likes,
        ROUND(SUM(cpm.comments_count), 0) as total_comments,
        ROUND(SUM(cpm.shares_count), 0) as total_shares
    FROM users u
    JOIN content_posts cp ON u.id = cp.user_id
    JOIN content_performance_metrics cpm ON cp.id = cpm.content_id
    WHERE cp.created_at >= CURRENT_DATE - INTERVAL '90 days'
    GROUP BY u.id, u.username, u.account_type, cp.content_type, cp.content_category
),
user_preference_ranking AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY posts_in_category DESC, avg_engagement_rate DESC) as preference_rank
    FROM user_content_preferences
)
SELECT 
    username,
    account_type,
    content_type,
    content_category,
    posts_in_category,
    avg_engagement_rate,
    avg_virality_score,
    total_likes,
    total_comments,
    total_shares,
    CASE 
        WHEN preference_rank = 1 THEN 'Primary Preference'
        WHEN preference_rank = 2 THEN 'Secondary Preference'
        WHEN preference_rank = 3 THEN 'Tertiary Preference'
        ELSE 'Other'
    END as preference_level
FROM user_preference_ranking
WHERE preference_rank <= 3
ORDER BY username, preference_rank;

-- 7. USER ENGAGEMENT VELOCITY ANALYSIS
-- Analyzes how quickly users engage with content after posting
WITH user_engagement_velocity AS (
    SELECT 
        u.id,
        u.username,
        u.account_type,
        cp.id as content_id,
        cp.content_type,
        cp.created_at as post_time,
        c.created_at as comment_time,
        l.created_at as like_time,
        EXTRACT(EPOCH FROM (c.created_at - cp.created_at))/60 as minutes_to_comment,
        EXTRACT(EPOCH FROM (l.created_at - cp.created_at))/60 as minutes_to_like
    FROM users u
    JOIN content_posts cp ON u.id = cp.user_id
    LEFT JOIN comments c ON cp.id = c.content_id
    LEFT JOIN likes l ON cp.id = l.content_id
    WHERE cp.created_at >= CURRENT_DATE - INTERVAL '7 days'
),
velocity_analysis AS (
    SELECT 
        id,
        username,
        account_type,
        content_type,
        COUNT(DISTINCT content_id) as total_posts,
        ROUND(AVG(minutes_to_comment), 1) as avg_minutes_to_comment,
        ROUND(AVG(minutes_to_like), 1) as avg_minutes_to_like,
        ROUND(MIN(minutes_to_comment), 1) as fastest_comment_minutes,
        ROUND(MIN(minutes_to_like), 1) as fastest_like_minutes,
        COUNT(DISTINCT CASE WHEN minutes_to_comment <= 5 THEN content_id END) as posts_with_quick_comments,
        COUNT(DISTINCT CASE WHEN minutes_to_like <= 1 THEN content_id END) as posts_with_quick_likes
    FROM user_engagement_velocity
    WHERE minutes_to_comment IS NOT NULL OR minutes_to_like IS NOT NULL
    GROUP BY id, username, account_type, content_type
)
SELECT 
    account_type,
    content_type,
    COUNT(*) as user_count,
    ROUND(AVG(avg_minutes_to_comment), 1) as avg_minutes_to_comment,
    ROUND(AVG(avg_minutes_to_like), 1) as avg_minutes_to_like,
    ROUND(AVG(fastest_comment_minutes), 1) as avg_fastest_comment_minutes,
    ROUND(AVG(fastest_like_minutes), 1) as avg_fastest_like_minutes,
    ROUND(AVG(posts_with_quick_comments::DECIMAL / total_posts * 100), 1) as pct_posts_with_quick_comments,
    ROUND(AVG(posts_with_quick_likes::DECIMAL / total_posts * 100), 1) as pct_posts_with_quick_likes
FROM velocity_analysis
GROUP BY account_type, content_type
ORDER BY account_type, content_type;

-- 8. USER BEHAVIOR CLUSTERING DATA
-- Prepares data for machine learning clustering of user behaviors
SELECT 
    u.id,
    u.username,
    u.account_type,
    u.follower_count,
    u.following_count,
    COUNT(cp.id) as total_posts,
    COUNT(DISTINCT DATE(cp.created_at)) as active_days,
    COUNT(DISTINCT c.id) as comments_made,
    COUNT(DISTINCT l.content_id) as likes_given,
    COUNT(DISTINCT f.followee_id) as users_followed,
    ROUND(AVG(cpm.engagement_rate), 2) as avg_engagement_rate,
    ROUND(AVG(cpm.virality_score), 2) as avg_virality_score,
    ROUND(follower_count::DECIMAL / NULLIF(following_count, 0), 2) as follower_following_ratio,
    ROUND(COUNT(c.id)::DECIMAL / NULLIF(COUNT(cp.id), 0), 2) as comment_to_post_ratio,
    ROUND(COUNT(l.content_id)::DECIMAL / NULLIF(COUNT(cp.id), 0), 2) as like_to_post_ratio,
    EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - u.created_at)) as days_since_registration,
    EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - COALESCE(MAX(cp.created_at), u.created_at))) as days_since_last_activity
FROM users u
LEFT JOIN content_posts cp ON u.id = cp.user_id
LEFT JOIN content_performance_metrics cpm ON cp.id = cpm.content_id
LEFT JOIN comments c ON u.id = c.user_id
LEFT JOIN likes l ON u.id = l.user_id
LEFT JOIN follows f ON u.id = f.follower_id
GROUP BY u.id, u.username, u.account_type, u.follower_count, u.following_count, u.created_at
ORDER BY u.id;
