#!/usr/bin/env python3
"""
Social Media Analytics Platform - Data Processing Module
© 2024 Social Media Analytics Platform. All rights reserved.
"""

import pandas as pd
import numpy as np
import psycopg2
from sqlalchemy import create_engine
import logging
from typing import Dict, List, Optional, Tuple
import os
from datetime import datetime, timedelta
import json

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SocialMediaDataProcessor:
    """
    Main class for processing social media analytics data
    """
    
    def __init__(self, db_config: Dict[str, str]):
        """
        Initialize the data processor with database configuration
        
        Args:
            db_config: Dictionary containing database connection parameters
        """
        self.db_config = db_config
        self.engine = self._create_engine()
        
    def _create_engine(self):
        """Create SQLAlchemy engine for database connection"""
        try:
            connection_string = (
                f"postgresql://{self.db_config['user']}:{self.db_config['password']}"
                f"@{self.db_config['host']}:{self.db_config['port']}/{self.db_config['database']}"
            )
            return create_engine(connection_string)
        except Exception as e:
            logger.error(f"Failed to create database engine: {e}")
            raise
    
    def load_csv_data(self, file_path: str, table_name: str) -> bool:
        """
        Load CSV data into PostgreSQL database
        
        Args:
            file_path: Path to CSV file
            table_name: Target table name
            
        Returns:
            bool: Success status
        """
        try:
            df = pd.read_csv(file_path)
            df.to_sql(table_name, self.engine, if_exists='replace', index=False)
            logger.info(f"Successfully loaded {len(df)} rows into {table_name}")
            return True
        except Exception as e:
            logger.error(f"Failed to load data into {table_name}: {e}")
            return False
    
    def calculate_engagement_metrics(self) -> pd.DataFrame:
        """
        Calculate advanced engagement metrics for all content
        
        Returns:
            pd.DataFrame: DataFrame with engagement metrics
        """
        try:
            query = """
            SELECT 
                cp.id as content_id,
                cp.user_id,
                cp.content_type,
                cp.content_category,
                cp.created_at,
                COUNT(DISTINCT l.user_id) as likes_count,
                COUNT(DISTINCT c.id) as comments_count,
                COUNT(DISTINCT s.user_id) as shares_count,
                COUNT(DISTINCT sv.user_id) as saves_count,
                COUNT(DISTINCT v.user_id) as profile_visits,
                COUNT(DISTINCT wc.user_id) as website_clicks
            FROM content_posts cp
            LEFT JOIN likes l ON cp.id = l.content_id
            LEFT JOIN comments c ON cp.id = c.content_id
            LEFT JOIN shares s ON cp.id = s.content_id
            LEFT JOIN saves sv ON cp.id = sv.content_id
            LEFT JOIN profile_visits v ON cp.id = v.content_id
            LEFT JOIN website_clicks wc ON cp.id = wc.content_id
            GROUP BY cp.id, cp.user_id, cp.content_type, cp.content_category, cp.created_at
            """
            
            df = pd.read_sql(query, self.engine)
            
            # Calculate engagement rate
            df['engagement_rate'] = (
                (df['likes_count'] + df['comments_count'] + df['shares_count']) / 
                df['likes_count'].replace(0, 1) * 100
            )
            
            # Calculate virality score
            df['virality_score'] = (
                df['shares_count'] * 0.4 + 
                df['comments_count'] * 0.3 + 
                df['saves_count'] * 0.3
            )
            
            # Calculate reach and impressions (simulated)
            df['reach_count'] = df['likes_count'] * np.random.uniform(2, 5, len(df))
            df['impressions_count'] = df['reach_count'] * np.random.uniform(1.2, 2.0, len(df))
            
            return df
            
        except Exception as e:
            logger.error(f"Failed to calculate engagement metrics: {e}")
            return pd.DataFrame()
    
    def update_content_performance_metrics(self) -> bool:
        """
        Update content performance metrics table
        
        Returns:
            bool: Success status
        """
        try:
            metrics_df = self.calculate_engagement_metrics()
            
            if metrics_df.empty:
                logger.warning("No engagement metrics calculated")
                return False
            
            # Update the content_performance_metrics table
            metrics_df.to_sql(
                'content_performance_metrics', 
                self.engine, 
                if_exists='replace', 
                index=False
            )
            
            logger.info(f"Updated content performance metrics for {len(metrics_df)} posts")
            return True
            
        except Exception as e:
            logger.error(f"Failed to update content performance metrics: {e}")
            return False
    
    def calculate_user_engagement_metrics(self) -> pd.DataFrame:
        """
        Calculate daily user engagement metrics
        
        Returns:
            pd.DataFrame: DataFrame with user engagement metrics
        """
        try:
            query = """
            SELECT 
                u.id as user_id,
                DATE(cp.created_at) as date,
                COUNT(cp.id) as posts_created,
                SUM(cpm.likes_count) as likes_received,
                SUM(cpm.comments_count) as comments_received,
                SUM(cpm.shares_count) as shares_received,
                AVG(cpm.engagement_rate) as avg_engagement_rate,
                SUM(cpm.reach_count) as reach_count,
                SUM(cpm.impressions_count) as impressions_count
            FROM users u
            LEFT JOIN content_posts cp ON u.id = cp.user_id
            LEFT JOIN content_performance_metrics cpm ON cp.id = cpm.content_id
            WHERE cp.created_at >= CURRENT_DATE - INTERVAL '30 days'
            GROUP BY u.id, DATE(cp.created_at)
            """
            
            df = pd.read_sql(query, self.engine)
            
            # Calculate additional metrics
            df['followers_gained'] = np.random.randint(-5, 20, len(df))
            df['followers_lost'] = np.random.randint(0, 5, len(df))
            df['profile_views'] = df['reach_count'] * np.random.uniform(0.1, 0.3, len(df))
            df['website_clicks'] = df['profile_views'] * np.random.uniform(0.05, 0.15, len(df))
            
            return df
            
        except Exception as e:
            logger.error(f"Failed to calculate user engagement metrics: {e}")
            return pd.DataFrame()
    
    def update_user_engagement_metrics(self) -> bool:
        """
        Update user engagement metrics table
        
        Returns:
            bool: Success status
        """
        try:
            metrics_df = self.calculate_user_engagement_metrics()
            
            if metrics_df.empty:
                logger.warning("No user engagement metrics calculated")
                return False
            
            # Update the user_engagement_metrics table
            metrics_df.to_sql(
                'user_engagement_metrics', 
                self.engine, 
                if_exists='replace', 
                index=False
            )
            
            logger.info(f"Updated user engagement metrics for {len(metrics_df)} user-days")
            return True
            
        except Exception as e:
            logger.error(f"Failed to update user engagement metrics: {e}")
            return False
    
    def calculate_hashtag_trends(self) -> pd.DataFrame:
        """
        Calculate hashtag popularity and trend scores
        
        Returns:
            pd.DataFrame: DataFrame with hashtag trends
        """
        try:
            query = """
            SELECT 
                h.id as hashtag_id,
                h.tag_name,
                h.category,
                COUNT(ch.content_id) as usage_count_7d,
                COUNT(DISTINCT ch.content_id) as unique_posts_7d,
                AVG(cpm.engagement_rate) as avg_engagement_rate,
                AVG(cpm.virality_score) as avg_virality_score
            FROM hashtags h
            LEFT JOIN content_hashtags ch ON h.id = ch.hashtag_id
            LEFT JOIN content_posts cp ON ch.content_id = cp.id 
                AND cp.created_at >= CURRENT_DATE - INTERVAL '7 days'
            LEFT JOIN content_performance_metrics cpm ON cp.id = cpm.content_id
            GROUP BY h.id, h.tag_name, h.category
            """
            
            df = pd.read_sql(query, self.engine)
            
            # Calculate trend scores
            df['popularity_score'] = df['usage_count_7d'] * 0.6 + df['unique_posts_7d'] * 0.4
            df['trend_score'] = df['avg_engagement_rate'] * 0.5 + df['avg_virality_score'] * 0.5
            
            return df
            
        except Exception as e:
            logger.error(f"Failed to calculate hashtag trends: {e}")
            return pd.DataFrame()
    
    def update_hashtag_trends(self) -> bool:
        """
        Update hashtag trends in the database
        
        Returns:
            bool: Success status
        """
        try:
            trends_df = self.calculate_hashtag_trends()
            
            if trends_df.empty:
                logger.warning("No hashtag trends calculated")
                return False
            
            # Update hashtag popularity and trend scores
            for _, row in trends_df.iterrows():
                update_query = """
                UPDATE hashtags 
                SET popularity_score = %s, trend_score = %s, last_used_at = CURRENT_TIMESTAMP
                WHERE id = %s
                """
                
                with self.engine.connect() as conn:
                    conn.execute(update_query, (row['popularity_score'], row['trend_score'], row['hashtag_id']))
                    conn.commit()
            
            logger.info(f"Updated hashtag trends for {len(trends_df)} hashtags")
            return True
            
        except Exception as e:
            logger.error(f"Failed to update hashtag trends: {e}")
            return False
    
    def process_all_metrics(self) -> bool:
        """
        Process all analytics metrics
        
        Returns:
            bool: Success status
        """
        try:
            logger.info("Starting comprehensive metrics processing...")
            
            # Update content performance metrics
            if not self.update_content_performance_metrics():
                return False
            
            # Update user engagement metrics
            if not self.update_user_engagement_metrics():
                return False
            
            # Update hashtag trends
            if not self.update_hashtag_trends():
                return False
            
            logger.info("Successfully processed all analytics metrics")
            return True
            
        except Exception as e:
            logger.error(f"Failed to process metrics: {e}")
            return False

def main():
    """Main function for data processing"""
    
    # Database configuration
    db_config = {
        'host': os.getenv('DB_HOST', 'localhost'),
        'port': os.getenv('DB_PORT', '5432'),
        'database': os.getenv('DB_NAME', 'social_media_analytics'),
        'user': os.getenv('DB_USER', 'postgres'),
        'password': os.getenv('DB_PASSWORD', 'password')
    }
    
    # Initialize processor
    processor = SocialMediaDataProcessor(db_config)
    
    # Process all metrics
    success = processor.process_all_metrics()
    
    if success:
        print("✅ Data processing completed successfully!")
    else:
        print("❌ Data processing failed!")
        exit(1)

if __name__ == "__main__":
    main()
