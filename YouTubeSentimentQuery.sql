--checking the comments dataset
select * from comments
--checking number of rows 
select count(*) from comments
-- shows 18409 rows for comments 


--checking the  dataset
select * from [videos-stats]
--checking number of rows 
select count(*) from [videos-stats]
-- shows 1881 rows for videos-stats  

--  Now need to check for columns with null values 
-- Comments dataset
SELECT 
    COUNT(*) AS TotalRows,
    SUM(CASE WHEN comment IS NULL OR comment = '' THEN 1 ELSE 0 END) AS MissingComments,
    SUM(CASE WHEN likes IS NULL THEN 1 ELSE 0 END) AS MissingLikes,
     SUM(CASE WHEN Video_ID IS NULL THEN 1 ELSE 0 END) AS MissingVideoID,
    SUM(CASE WHEN sentiment IS NULL OR sentiment = '' THEN 1 ELSE 0 END) AS MissingSentiment
FROM Comments;

-- VideoStats dataset
SELECT 
    COUNT(*) AS TotalRows,
    SUM(CASE WHEN Title IS NULL OR title = '' THEN 1 ELSE 0 END) AS MissingTitle,
    SUM(CASE WHEN Video_ID IS NULL OR Video_ID = '' THEN 1 ELSE 0 END) AS MissingVideoID,
    SUM(CASE WHEN Published_At IS NULL THEN 1 ELSE 0 END) AS MissingDate,
    SUM(CASE WHEN Keyword IS NULL OR Keyword = '' THEN 1 ELSE 0 END) AS MissingKeyword,
    SUM(CASE WHEN Likes IS NULL THEN 1 ELSE 0 END) AS MissingLikes,
    SUM(CASE WHEN Comments IS NULL THEN 1 ELSE 0 END) AS MissingComments,
    SUM(CASE WHEN Views IS NULL THEN 1 ELSE 0 END) AS MissingViews
FROM [videos-stats]

/*From the result
Comments table has 36 missing comments, and 2338 missing sentiment 
and
videos-stats table has 2 missing likes 4 missing comments and 2 missing views*/

-- checking for duplicates 
-- Comments dataset (using video_id + comment)
SELECT video_id, comment, COUNT(*) 
FROM Comments
GROUP BY video_id, comment
HAVING COUNT(*) > 1;

-- VideoStats dataset (by videoID)
SELECT Video_ID, COUNT(*) 
FROM [videos-stats]
GROUP BY Video_ID
HAVING COUNT(*) > 1;

/* results shows there are duplicate values, so next step is to remove duplicate values from both dataset 
then after that, fix missing values, trim spaces in comments if needed and also check the dates */

-- removing duplicates for comments 
WITH CTE AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY video_id, comment ORDER BY column1) AS rn
    FROM Comments
)
DELETE FROM CTE
WHERE rn > 1;

-- removing duplicates for Videostats cause each video ID is to appear just once
WITH CTE AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY Video_ID ORDER BY column1) AS rn
    FROM [videos-stats]
)
DELETE FROM CTE
WHERE rn > 1;

-- checking numbers of rows left
SELECT COUNT(*) AS TotalComments FROM Comments;
SELECT COUNT(*) AS TotalVideos FROM [videos-stats];

-- duplicate rows has been removed, now unto dealing with missing values

-- handling missing values in comments table 
/* because there are 36 missing comment rows, these can safely be removed,
but 2338 missing sentiment rows is a significant portion of the dataset, and sentiment is critical for analysis.
will predict misisng sentiment with a model using python and make sure the sentiment is between 0-2 like the dataset  */

DELETE FROM Comments
WHERE comment IS NULL OR comment = '';

--confirming if rows has been deleted 
SELECT COUNT(*) AS RemainingRows FROM Comments;
SELECT COUNT(*) AS MissingComments FROM Comments WHERE comment IS NULL OR comment = '';

/* missing comments is now = 0
sentiment analysis has been carried out using Vader, so now need to confirm by counting missing sentiment also*/

SELECT COUNT(*) AS MissingSentiment
FROM Comments
WHERE sentiment IS NULL;

--Missing sentiment is now = 0
-- now to check if all sentiment values are between the range of 0 and 2
SELECT MIN(sentiment) AS MinSentiment, MAX(sentiment) AS MaxSentiment
FROM Comments;

-- now to check the results to see if any error 
SELECT * from comments
where Sentiment IS NOT NULL
ORDER BY column1 DESC;

-- Comments table duplicates by video_id + comment
SELECT video_id, comment, COUNT(*) AS cnt
FROM Comments
GROUP BY video_id, comment
HAVING COUNT(*) > 1;

-- VideoStats duplicates by videoID
SELECT Video_ID, COUNT(*) AS cnt
FROM [videos-stats]
GROUP BY Video_ID
HAVING COUNT(*) > 1;

-- confirmed that there is no more duplicates, so will check number of rows and columns left

select count(*) from comments as Comment_count
select count(*) from [videos-stats] as videostats_count

-- now to handle missing value in the videos-stats
-- had just about 8 missing values altogether, so will delete this rows instead 

DELETE FROM [videos-stats]
WHERE likes IS NULL
   OR comments IS NULL
   OR views IS NULL;

SELECT 
    SUM(CASE WHEN likes IS NULL THEN 1 ELSE 0 END) AS MissingLikes,
    SUM(CASE WHEN comments IS NULL THEN 1 ELSE 0 END) AS MissingComments,
    SUM(CASE WHEN views IS NULL THEN 1 ELSE 0 END) AS MissingViews
FROM [videos-stats];

/*Finally will need to clean the comment colum, to remove leading or trailing spaces
remove unusual symbol,standardise the case*/

-- Remove leading and trailing spaces
UPDATE Comments
SET comment = LTRIM(RTRIM(comment));

-- Replacing multiple consecutive spaces with a single space

UPDATE Comments
SET comment = REPLACE(REPLACE(comment, '  ', ' '), '  ', ' ');

-- Remove newline (\n) and carriage return (\r) characters
UPDATE Comments
SET comment = REPLACE(REPLACE(comment, CHAR(13), ''), CHAR(10), '');

-- Remove unusual special characters

UPDATE Comments
SET comment = REPLACE(comment, CHAR(9), '');  -- remove tabs

--  Convert all comments to lowercase
UPDATE Comments
SET comment = LOWER(comment);


select Comment from comments;

/* data cleaning has been completed
now will start checking for findings*/

/* Question 1 
. Which keywords are associated with the highest-performing videos?
Consider analyzing by views, likes, and comments.
Are there common patterns in topics or content types?*/


-- Aggregate performance by keyword
SELECT TOP 10
    keyword,
    COUNT(Video_ID) AS VideoCount,
    AVG(views) AS AvgViews,
    AVG(likes) AS AvgLikes,
    AVG(comments) AS AvgComments,
    SUM(views + likes + comments) AS TotalPerformanceScore
FROM [videos-stats]
GROUP BY keyword
--HAVING COUNT(Video_ID) >= 3   -- optional: only keywords appearing in at least 3 videos
ORDER BY TotalPerformanceScore DESC;




-- question 2
/*
Do videos with high engagement (likes/views/comments) tend to have more positive, negative, or neutral comments?

Use average sentiment across comments per video.
Do high-performing videos attract more extreme sentiment?*/

WITH VideoSentiment AS (
    SELECT
        video_id,
        COUNT(*) AS TotalComments,
        SUM(CASE WHEN sentiment = 0 THEN 1 ELSE 0 END) AS NegativeCount,
        SUM(CASE WHEN sentiment = 1 THEN 1 ELSE 0 END) AS NeutralCount,
        SUM(CASE WHEN sentiment = 2 THEN 1 ELSE 0 END) AS PositiveCount,
        AVG(CAST(sentiment AS FLOAT)) AS AvgSentiment,
        CAST(SUM(CASE WHEN sentiment = 0 THEN 1 ELSE 0 END) AS FLOAT)/COUNT(*) AS FractionNegative,
        CAST(SUM(CASE WHEN sentiment = 1 THEN 1 ELSE 0 END) AS FLOAT)/COUNT(*) AS FractionNeutral,
        CAST(SUM(CASE WHEN sentiment = 2 THEN 1 ELSE 0 END) AS FLOAT)/COUNT(*) AS FractionPositive,
        CAST(SUM(CASE WHEN sentiment IN (0,2) THEN 1 ELSE 0 END) AS FLOAT)/COUNT(*) AS FractionExtreme
    FROM Comments
    GROUP BY video_id
)
SELECT
    v.Video_ID,
    v.title,
    v.views,
    v.likes,
    v.comments AS VideoComments,
    vs.TotalComments AS CommentCount,
    vs.AvgSentiment,
    vs.FractionNegative,
    vs.FractionNeutral,
    vs.FractionPositive,
    vs.FractionExtreme
FROM [videos-stats] v
JOIN VideoSentiment vs
    ON v.Video_ID = vs.video_id
ORDER BY v.views DESC;  -- or ORDER BY v.likes DESC / v.comments DESC

-- Do videos with more comments have more polarized (0 or 2) reactions?

WITH  VideoSentiment AS (
    SELECT
        video_id,
        COUNT(*) AS TotalComments,
        CAST(SUM(CASE WHEN sentiment IN (0,2) THEN 1 ELSE 0 END) AS FLOAT)/COUNT(*) AS FractionExtreme,
        CAST(SUM(CASE WHEN sentiment = 1 THEN 1 ELSE 0 END) AS FLOAT)/COUNT(*) AS FractionNeutral
    FROM Comments
    GROUP BY video_id
)
SELECT TOP 30
    v.Video_ID,
    v.title,
    v.views,
    v.likes,
    v.comments AS VideoComments,
    vs.TotalComments,
    vs.FractionExtreme,
    vs.FractionNeutral
FROM [videos-stats] v
JOIN VideoSentiment vs
    ON v.Video_ID = vs.video_id
ORDER BY vs.TotalComments DESC;



-- Top  liked comments per video
WITH RankedComments AS (
    SELECT
        column1,
        video_id,
        comment,
        likes AS CommentLikes,
        sentiment,
        ROW_NUMBER() OVER(PARTITION BY video_id ORDER BY likes DESC) AS rn
    FROM Comments
)
SELECT TOP 
    rc.video_id,
    v.title,
    rc.comment,
    rc.CommentLikes,
    rc.sentiment,
    v.views,
    v.likes AS VideoLikes
FROM RankedComments rc
JOIN [videos-stats] v
    ON rc.video_id = v.Video_ID
WHERE rc.rn = 1  -- only top liked comment per video
ORDER BY rc.CommentLikes DESC;


-- Average sentiment and average top comment likes per keyword
WITH TopCommentLikes AS (
    SELECT
        video_id,
        MAX(likes) AS MaxCommentLikes
    FROM Comments
    GROUP BY video_id
)
SELECT top 20
    v.keyword,
    AVG(c.sentiment) AS AvgCommentSentiment,
    AVG(tc.MaxCommentLikes) AS AvgTopCommentLikes,
    COUNT(DISTINCT v.Video_ID) AS VideoCount
FROM [videos-stats] v
JOIN Comments c
    ON v.Video_ID = c.video_id
JOIN TopCommentLikes tc
    ON v.Video_ID = tc.video_id
GROUP BY v.keyword
HAVING COUNT(DISTINCT v.Video_ID) >= 3
ORDER BY AvgTopCommentLikes DESC;



-- -- Aggregate performance by publication date
SELECT top 20
    CAST(published_at AS DATE) AS PublishDate,
    COUNT(v.Video_ID) AS NumVideos,
    AVG(views) AS AvgViews,
    AVG(likes) AS AvgLikes,
    AVG(comments) AS AvgComments,
    AVG(sentiment) AS AvgSentiment
FROM [videos-stats] v
JOIN (
    SELECT video_id, AVG(CAST(sentiment AS FLOAT)) AS sentiment
    FROM Comments
    GROUP BY video_id
) c
ON v.Video_ID = c.video_id
GROUP BY CAST(published_at AS DATE)
ORDER BY PublishDate ASC;

