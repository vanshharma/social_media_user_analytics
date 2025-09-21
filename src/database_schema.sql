/* © 2024 Social Media Analytics Platform. All rights reserved. 
@https://github.com/yourusername/social-media-analytics-platform
*/

CREATE DATABASE IF NOT EXISTS social_media_analytics;

-- Enhanced Users table with additional analytics fields
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) NOT NULL UNIQUE,
    email VARCHAR(255),
    full_name VARCHAR(255),
    bio TEXT,
    profile_picture_url VARCHAR(500),
    follower_count INTEGER DEFAULT 0,
    following_count INTEGER DEFAULT 0,
    post_count INTEGER DEFAULT 0,
    engagement_score DECIMAL(5,2) DEFAULT 0.0,
    account_type VARCHAR(50) DEFAULT 'personal', -- personal, business, creator, influencer
    verification_status BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_active_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Enhanced Photos table with content analysis fields
CREATE TABLE content_posts (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    content_url VARCHAR(500) NOT NULL,
    content_type VARCHAR(50) NOT NULL, -- photo, video, carousel, story, reel
    caption TEXT,
    location VARCHAR(255),
    content_category VARCHAR(100), -- lifestyle, food, travel, fashion, etc.
    hashtags TEXT[], -- Array of hashtags
    mentions TEXT[], -- Array of user mentions
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    scheduled_at TIMESTAMP,
    is_promoted BOOLEAN DEFAULT FALSE,
    promotion_budget DECIMAL(10,2) DEFAULT 0.0,
    FOREIGN KEY (user_id) REFERENCES users (id)
);

-- Enhanced Comments table with sentiment analysis
CREATE TABLE comments (
    id SERIAL PRIMARY KEY,
    content_id INT NOT NULL,
    user_id INT NOT NULL,
    comment_text TEXT NOT NULL,
    parent_comment_id INT, -- For reply threads
    sentiment_score DECIMAL(3,2), -- -1.0 to 1.0
    sentiment_label VARCHAR(20), -- positive, negative, neutral
    is_spam BOOLEAN DEFAULT FALSE,
    is_verified_user BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (content_id) REFERENCES content_posts (id),
    FOREIGN KEY (user_id) REFERENCES users (id),
    FOREIGN KEY (parent_comment_id) REFERENCES comments (id)
);

-- Enhanced Likes table with additional metadata
CREATE TABLE likes(
    user_id INT NOT NULL,
    content_id INT NOT NULL,
    like_type VARCHAR(20) DEFAULT 'standard', -- standard, double_tap, super_like
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY(user_id) REFERENCES users(id),
    FOREIGN KEY(content_id) REFERENCES content_posts(id),
    PRIMARY KEY(user_id, content_id)
);

-- Enhanced Follows table with relationship metadata
CREATE TABLE follows (
    follower_id INT NOT NULL,
    followee_id INT NOT NULL,
    relationship_type VARCHAR(50) DEFAULT 'follow', -- follow, close_friend, family
    created_at TIMESTAMP DEFAULT NOW(),
    is_mutual BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (follower_id) REFERENCES users(id),
    FOREIGN KEY (followee_id) REFERENCES users(id),
    PRIMARY KEY (follower_id, followee_id)
);

-- Enhanced Tags table with analytics
CREATE TABLE hashtags (
    id SERIAL PRIMARY KEY,
    tag_name VARCHAR(255) UNIQUE NOT NULL,
    category VARCHAR(100), -- lifestyle, business, entertainment, etc.
    popularity_score DECIMAL(5,2) DEFAULT 0.0,
    trend_score DECIMAL(5,2) DEFAULT 0.0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_used_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Enhanced photo_tags junction table
CREATE TABLE content_hashtags (
    content_id INT NOT NULL,
    hashtag_id INT NOT NULL,
    position INTEGER, -- Order of hashtag in the post
    FOREIGN KEY (content_id) REFERENCES content_posts (id),
    FOREIGN KEY (hashtag_id) REFERENCES hashtags (id),
    PRIMARY KEY (content_id, hashtag_id)
);

-- NEW: User Engagement Analytics Table
CREATE TABLE user_engagement_metrics (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    date DATE NOT NULL,
    posts_created INTEGER DEFAULT 0,
    likes_received INTEGER DEFAULT 0,
    comments_received INTEGER DEFAULT 0,
    shares_received INTEGER DEFAULT 0,
    followers_gained INTEGER DEFAULT 0,
    followers_lost INTEGER DEFAULT 0,
    engagement_rate DECIMAL(5,2) DEFAULT 0.0,
    reach_count INTEGER DEFAULT 0,
    impressions_count INTEGER DEFAULT 0,
    profile_views INTEGER DEFAULT 0,
    website_clicks INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users (id),
    UNIQUE(user_id, date)
);

-- NEW: Content Performance Analytics Table
CREATE TABLE content_performance_metrics (
    id SERIAL PRIMARY KEY,
    content_id INT NOT NULL,
    likes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    shares_count INTEGER DEFAULT 0,
    saves_count INTEGER DEFAULT 0,
    reach_count INTEGER DEFAULT 0,
    impressions_count INTEGER DEFAULT 0,
    profile_visits INTEGER DEFAULT 0,
    website_clicks INTEGER DEFAULT 0,
    engagement_rate DECIMAL(5,2) DEFAULT 0.0,
    virality_score DECIMAL(5,2) DEFAULT 0.0,
    peak_engagement_time TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (content_id) REFERENCES content_posts (id)
);

-- NEW: User Segments Table
CREATE TABLE user_segments (
    id SERIAL PRIMARY KEY,
    segment_name VARCHAR(100) NOT NULL,
    description TEXT,
    criteria JSONB, -- JSON criteria for segment classification
    user_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- NEW: User Segment Assignments
CREATE TABLE user_segment_assignments (
    user_id INT NOT NULL,
    segment_id INT NOT NULL,
    confidence_score DECIMAL(3,2) DEFAULT 1.0,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users (id),
    FOREIGN KEY (segment_id) REFERENCES user_segments (id),
    PRIMARY KEY (user_id, segment_id)
);

-- NEW: Content Categories Table
CREATE TABLE content_categories (
    id SERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    parent_category_id INT,
    description TEXT,
    performance_benchmark DECIMAL(5,2) DEFAULT 0.0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (parent_category_id) REFERENCES content_categories (id)
);

-- NEW: Influencer Network Table
CREATE TABLE influencer_network (
    id SERIAL PRIMARY KEY,
    influencer_id INT NOT NULL,
    follower_id INT NOT NULL,
    influence_score DECIMAL(5,2) DEFAULT 0.0,
    relationship_strength DECIMAL(3,2) DEFAULT 0.0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (influencer_id) REFERENCES users (id),
    FOREIGN KEY (follower_id) REFERENCES users (id),
    PRIMARY KEY (influencer_id, follower_id)
);

-- NEW: Campaign Tracking Table
CREATE TABLE campaigns (
    id SERIAL PRIMARY KEY,
    campaign_name VARCHAR(255) NOT NULL,
    campaign_type VARCHAR(100) NOT NULL, -- brand_awareness, engagement, conversion
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    budget DECIMAL(12,2) DEFAULT 0.0,
    target_audience JSONB,
    status VARCHAR(50) DEFAULT 'active', -- active, paused, completed, cancelled
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- NEW: Campaign Content Association
CREATE TABLE campaign_content (
    campaign_id INT NOT NULL,
    content_id INT NOT NULL,
    performance_score DECIMAL(5,2) DEFAULT 0.0,
    cost_per_engagement DECIMAL(8,4) DEFAULT 0.0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (campaign_id) REFERENCES campaigns (id),
    FOREIGN KEY (content_id) REFERENCES content_posts (id),
    PRIMARY KEY (campaign_id, content_id)
);

-- Create indexes for better performance
CREATE INDEX idx_users_engagement_score ON users(engagement_score);
CREATE INDEX idx_users_account_type ON users(account_type);
CREATE INDEX idx_content_posts_created_at ON content_posts(created_at);
CREATE INDEX idx_content_posts_category ON content_posts(content_category);
CREATE INDEX idx_comments_sentiment ON comments(sentiment_score);
CREATE INDEX idx_user_engagement_metrics_date ON user_engagement_metrics(date);
CREATE INDEX idx_content_performance_metrics_engagement ON content_performance_metrics(engagement_rate);
CREATE INDEX idx_hashtags_popularity ON hashtags(popularity_score);
CREATE INDEX idx_hashtags_trend ON hashtags(trend_score);

-- Create views for common analytics queries
CREATE VIEW user_engagement_summary AS
SELECT 
    u.id,
    u.username,
    u.follower_count,
    u.following_count,
    u.post_count,
    u.engagement_score,
    u.account_type,
    COALESCE(AVG(ue.engagement_rate), 0) as avg_daily_engagement,
    COALESCE(SUM(ue.posts_created), 0) as total_posts_30d,
    COALESCE(SUM(ue.likes_received), 0) as total_likes_30d,
    COALESCE(SUM(ue.comments_received), 0) as total_comments_30d
FROM users u
LEFT JOIN user_engagement_metrics ue ON u.id = ue.user_id 
    AND ue.date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY u.id, u.username, u.follower_count, u.following_count, 
         u.post_count, u.engagement_score, u.account_type;

CREATE VIEW content_performance_summary AS
SELECT 
    cp.id,
    cp.user_id,
    u.username,
    cp.content_type,
    cp.content_category,
    cp.created_at,
    cpm.likes_count,
    cpm.comments_count,
    cpm.shares_count,
    cpm.engagement_rate,
    cpm.virality_score,
    cpm.reach_count,
    cpm.impressions_count
FROM content_posts cp
JOIN users u ON cp.user_id = u.id
LEFT JOIN content_performance_metrics cpm ON cp.id = cpm.content_id
ORDER BY cpm.engagement_rate DESC;

CREATE VIEW trending_hashtags AS
SELECT 
    h.id,
    h.tag_name,
    h.category,
    h.popularity_score,
    h.trend_score,
    COUNT(ch.content_id) as usage_count_7d,
    COUNT(DISTINCT ch.content_id) as unique_posts_7d
FROM hashtags h
LEFT JOIN content_hashtags ch ON h.id = ch.hashtag_id
LEFT JOIN content_posts cp ON ch.content_id = cp.id 
    AND cp.created_at >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY h.id, h.tag_name, h.category, h.popularity_score, h.trend_score
ORDER BY h.trend_score DESC, usage_count_7d DESC;
