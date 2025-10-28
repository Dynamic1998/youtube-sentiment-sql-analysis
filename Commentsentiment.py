import pyodbc
import pandas as pd
from vaderSentiment.vaderSentiment import SentimentIntensityAnalyzer

# 1. connect to database
conn = pyodbc.connect(
    "Driver={SQL Server};"
    "Server=Emmy\SQLEXPRESS;"       
    "Database=YouTubeAnalysis;"   
    "Trusted_Connection=yes;"
)

# 2. Load comments with missing sentiment

query = """
SELECT column1, video_id, comment 
FROM Comments
WHERE sentiment IS NULL
"""
missing_df = pd.read_sql(query, conn)


# 3. Initialize sentiment analyzer

analyzer = SentimentIntensityAnalyzer()

# 4. Predict sentiment and map to 0-2 scale

def predict_sentiment(text):
    if text is None or text.strip() == '':
        return 1  # default neutral if somehow empty
    compound = analyzer.polarity_scores(text)['compound']
    # Map to 0-2 scale
    if compound <= -0.05:
        return 0  # Negative
    elif compound < 0.05:
        return 1  # Neutral
    else:
        return 2  # Positive

missing_df['predicted_sentiment'] = missing_df['comment'].apply(predict_sentiment)


# 5. Update SQL table with predicted sentiment

cursor = conn.cursor()

for index, row in missing_df.iterrows():
    cursor.execute("""
        UPDATE Comments
        SET sentiment = ?
        WHERE column1 = ?
    """, row['predicted_sentiment'], row['column1'])

conn.commit()
cursor.close()
conn.close()

print("Missing sentiment successfully predicted and updated in 0-2 scale.")