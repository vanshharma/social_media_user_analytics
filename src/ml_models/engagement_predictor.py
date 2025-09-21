#!/usr/bin/env python3
"""
Social Media Analytics Platform - Engagement Prediction Model
© 2024 Social Media Analytics Platform. All rights reserved.
"""

import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestRegressor, GradientBoostingRegressor
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.metrics import mean_squared_error, r2_score, mean_absolute_error
import joblib
import logging
from typing import Dict, List, Tuple, Optional
import os
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class EngagementPredictor:
    """
    Machine Learning model for predicting content engagement
    """
    
    def __init__(self):
        self.model = None
        self.scaler = StandardScaler()
        self.label_encoders = {}
        self.feature_columns = []
        self.is_trained = False
        
    def prepare_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Prepare features for machine learning model
        
        Args:
            df: Raw DataFrame with content data
            
        Returns:
            pd.DataFrame: Processed DataFrame with features
        """
        try:
            # Create a copy to avoid modifying original
            features_df = df.copy()
            
            # Extract temporal features
            features_df['posting_hour'] = pd.to_datetime(features_df['created_at']).dt.hour
            features_df['posting_day'] = pd.to_datetime(features_df['created_at']).dt.dayofweek
            features_df['posting_month'] = pd.to_datetime(features_df['created_at']).dt.month
            features_df['is_weekend'] = (features_df['posting_day'] >= 5).astype(int)
            
            # Content features
            features_df['caption_length'] = features_df['caption'].fillna('').str.len()
            features_df['has_hashtags'] = features_df['hashtags'].notna().astype(int)
            features_df['has_location'] = features_df['location'].notna().astype(int)
            features_df['is_promoted'] = features_df['is_promoted'].astype(int)
            
            # User features
            features_df['user_follower_count'] = features_df['follower_count']
            features_df['user_following_count'] = features_df['following_count']
            features_df['user_engagement_score'] = features_df['engagement_score']
            features_df['user_account_type'] = features_df['account_type']
            
            # Encode categorical variables
            categorical_columns = ['content_type', 'content_category', 'user_account_type']
            
            for col in categorical_columns:
                if col in features_df.columns:
                    if col not in self.label_encoders:
                        self.label_encoders[col] = LabelEncoder()
                        features_df[col] = self.label_encoders[col].fit_transform(features_df[col].fillna('Unknown'))
                    else:
                        features_df[col] = self.label_encoders[col].transform(features_df[col].fillna('Unknown'))
            
            # Select feature columns
            self.feature_columns = [
                'posting_hour', 'posting_day', 'posting_month', 'is_weekend',
                'caption_length', 'has_hashtags', 'has_location', 'is_promoted',
                'user_follower_count', 'user_following_count', 'user_engagement_score',
                'content_type', 'content_category', 'user_account_type'
            ]
            
            # Filter to available columns
            available_columns = [col for col in self.feature_columns if col in features_df.columns]
            features_df = features_df[available_columns].fillna(0)
            
            return features_df
            
        except Exception as e:
            logger.error(f"Failed to prepare features: {e}")
            return pd.DataFrame()
    
    def train(self, X: pd.DataFrame, y: pd.Series, model_type: str = 'random_forest') -> Dict:
        """
        Train the engagement prediction model
        
        Args:
            X: Feature matrix
            y: Target variable (engagement rate)
            model_type: Type of model to use ('random_forest' or 'gradient_boosting')
            
        Returns:
            Dict: Training results and metrics
        """
        try:
            # Split data
            X_train, X_test, y_train, y_test = train_test_split(
                X, y, test_size=0.2, random_state=42
            )
            
            # Scale features
            X_train_scaled = self.scaler.fit_transform(X_train)
            X_test_scaled = self.scaler.transform(X_test)
            
            # Initialize model
            if model_type == 'random_forest':
                self.model = RandomForestRegressor(
                    n_estimators=100,
                    max_depth=10,
                    random_state=42,
                    n_jobs=-1
                )
            elif model_type == 'gradient_boosting':
                self.model = GradientBoostingRegressor(
                    n_estimators=100,
                    max_depth=6,
                    learning_rate=0.1,
                    random_state=42
                )
            else:
                raise ValueError(f"Unknown model type: {model_type}")
            
            # Train model
            self.model.fit(X_train_scaled, y_train)
            
            # Make predictions
            y_pred = self.model.predict(X_test_scaled)
            
            # Calculate metrics
            mse = mean_squared_error(y_test, y_pred)
            rmse = np.sqrt(mse)
            mae = mean_absolute_error(y_test, y_pred)
            r2 = r2_score(y_test, y_pred)
            
            # Cross-validation score
            cv_scores = cross_val_score(
                self.model, X_train_scaled, y_train, cv=5, scoring='r2'
            )
            
            self.is_trained = True
            
            results = {
                'model_type': model_type,
                'mse': mse,
                'rmse': rmse,
                'mae': mae,
                'r2': r2,
                'cv_mean': cv_scores.mean(),
                'cv_std': cv_scores.std(),
                'feature_importance': dict(zip(
                    self.feature_columns, 
                    self.model.feature_importances_
                ))
            }
            
            logger.info(f"Model trained successfully. R² Score: {r2:.4f}")
            return results
            
        except Exception as e:
            logger.error(f"Failed to train model: {e}")
            return {}
    
    def predict(self, X: pd.DataFrame) -> np.ndarray:
        """
        Make predictions using trained model
        
        Args:
            X: Feature matrix
            
        Returns:
            np.ndarray: Predictions
        """
        try:
            if not self.is_trained:
                raise ValueError("Model must be trained before making predictions")
            
            # Prepare features
            X_processed = self.prepare_features(X)
            
            # Scale features
            X_scaled = self.scaler.transform(X_processed)
            
            # Make predictions
            predictions = self.model.predict(X_scaled)
            
            return predictions
            
        except Exception as e:
            logger.error(f"Failed to make predictions: {e}")
            return np.array([])
    
    def save_model(self, filepath: str) -> bool:
        """
        Save trained model to file
        
        Args:
            filepath: Path to save model
            
        Returns:
            bool: Success status
        """
        try:
            if not self.is_trained:
                raise ValueError("No trained model to save")
            
            model_data = {
                'model': self.model,
                'scaler': self.scaler,
                'label_encoders': self.label_encoders,
                'feature_columns': self.feature_columns,
                'is_trained': self.is_trained
            }
            
            joblib.dump(model_data, filepath)
            logger.info(f"Model saved to {filepath}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to save model: {e}")
            return False
    
    def load_model(self, filepath: str) -> bool:
        """
        Load trained model from file
        
        Args:
            filepath: Path to model file
            
        Returns:
            bool: Success status
        """
        try:
            if not os.path.exists(filepath):
                raise FileNotFoundError(f"Model file not found: {filepath}")
            
            model_data = joblib.load(filepath)
            
            self.model = model_data['model']
            self.scaler = model_data['scaler']
            self.label_encoders = model_data['label_encoders']
            self.feature_columns = model_data['feature_columns']
            self.is_trained = model_data['is_trained']
            
            logger.info(f"Model loaded from {filepath}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to load model: {e}")
            return False

class ContentRecommendationEngine:
    """
    Content recommendation engine based on user behavior and content performance
    """
    
    def __init__(self):
        self.user_profiles = {}
        self.content_features = {}
        self.recommendation_model = None
        
    def build_user_profiles(self, user_data: pd.DataFrame, engagement_data: pd.DataFrame):
        """
        Build user profiles based on engagement history
        
        Args:
            user_data: User information DataFrame
            engagement_data: User engagement metrics DataFrame
        """
        try:
            for _, user in user_data.iterrows():
                user_id = user['id']
                
                # Get user's engagement history
                user_engagements = engagement_data[engagement_data['user_id'] == user_id]
                
                if not user_engagements.empty:
                    profile = {
                        'preferred_content_types': user_engagements['content_type'].value_counts().to_dict(),
                        'preferred_categories': user_engagements['content_category'].value_counts().to_dict(),
                        'avg_engagement_rate': user_engagements['engagement_rate'].mean(),
                        'preferred_posting_times': user_engagements['posting_hour'].value_counts().to_dict(),
                        'hashtag_preferences': user_engagements['hashtags'].value_counts().to_dict()
                    }
                    
                    self.user_profiles[user_id] = profile
            
            logger.info(f"Built profiles for {len(self.user_profiles)} users")
            
        except Exception as e:
            logger.error(f"Failed to build user profiles: {e}")
    
    def recommend_content_strategy(self, user_id: int) -> Dict:
        """
        Recommend content strategy for a specific user
        
        Args:
            user_id: User ID
            
        Returns:
            Dict: Content strategy recommendations
        """
        try:
            if user_id not in self.user_profiles:
                return {"error": "User profile not found"}
            
            profile = self.user_profiles[user_id]
            
            # Generate recommendations
            recommendations = {
                'optimal_posting_times': sorted(
                    profile['preferred_posting_times'].items(), 
                    key=lambda x: x[1], 
                    reverse=True
                )[:3],
                'recommended_content_types': sorted(
                    profile['preferred_content_types'].items(), 
                    key=lambda x: x[1], 
                    reverse=True
                )[:3],
                'recommended_categories': sorted(
                    profile['preferred_categories'].items(), 
                    key=lambda x: x[1], 
                    reverse=True
                )[:3],
                'engagement_insights': {
                    'avg_engagement_rate': profile['avg_engagement_rate'],
                    'performance_level': self._classify_performance(profile['avg_engagement_rate'])
                }
            }
            
            return recommendations
            
        except Exception as e:
            logger.error(f"Failed to generate recommendations for user {user_id}: {e}")
            return {"error": str(e)}
    
    def _classify_performance(self, engagement_rate: float) -> str:
        """
        Classify user performance level based on engagement rate
        
        Args:
            engagement_rate: User's average engagement rate
            
        Returns:
            str: Performance level classification
        """
        if engagement_rate >= 8.0:
            return "Excellent"
        elif engagement_rate >= 5.0:
            return "Good"
        elif engagement_rate >= 3.0:
            return "Average"
        else:
            return "Needs Improvement"

def main():
    """Main function for model training and evaluation"""
    
    # This would typically load data from database
    # For demonstration, we'll create sample data
    np.random.seed(42)
    
    # Sample data
    n_samples = 1000
    sample_data = pd.DataFrame({
        'id': range(n_samples),
        'user_id': np.random.randint(1, 100, n_samples),
        'content_type': np.random.choice(['photo', 'video', 'carousel', 'story'], n_samples),
        'content_category': np.random.choice(['lifestyle', 'food', 'travel', 'fashion'], n_samples),
        'caption': ['Sample caption ' + str(i) for i in range(n_samples)],
        'hashtags': ['#sample #test'] * n_samples,
        'location': np.random.choice([None, 'New York', 'London', 'Tokyo'], n_samples),
        'is_promoted': np.random.choice([0, 1], n_samples),
        'created_at': pd.date_range('2024-01-01', periods=n_samples, freq='H'),
        'follower_count': np.random.randint(100, 10000, n_samples),
        'following_count': np.random.randint(50, 5000, n_samples),
        'engagement_score': np.random.uniform(1, 10, n_samples),
        'account_type': np.random.choice(['personal', 'business', 'creator'], n_samples)
    })
    
    # Simulate engagement rates
    engagement_rates = np.random.uniform(1, 15, n_samples)
    
    # Initialize predictor
    predictor = EngagementPredictor()
    
    # Prepare features
    X = predictor.prepare_features(sample_data)
    y = pd.Series(engagement_rates)
    
    # Train model
    results = predictor.train(X, y, model_type='random_forest')
    
    print("Model Training Results:")
    print(f"R² Score: {results['r2']:.4f}")
    print(f"RMSE: {results['rmse']:.4f}")
    print(f"MAE: {results['mae']:.4f}")
    
    # Save model
    predictor.save_model('engagement_predictor_model.pkl')
    
    print("✅ Model training completed successfully!")

if __name__ == "__main__":
    main()
