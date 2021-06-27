USE Dognition

--Checking how many different users and dogs we have data on
SELECT COUNT(DISTINCT user_guid ) FROM users 
SELECT COUNT(DISTINCT dog_guid ) FROM dogs

/* There are 33110 users and 34197 which shows that multiple dogs can belong to the same user*/

--Showing a list of users who got a free start

--Count of free_start_user

SELECT
	CASE
		WHEN ISNULL(free_start_user,0) = 0 THEN 0
		WHEN free_start_user  = 0 THEN 0
		ELSE 1
	END AS free_start,
	COUNT(DISTINCT user_guid)
FROM
	users
WHERE
	exclude = 0 OR exclude IS NULL
GROUP BY
	CASE
		WHEN ISNULL(free_start_user,0) = 0 THEN 0
		WHEN free_start_user  = 0 THEN 0
		ELSE 1
	END

--How many different tests are there
SELECT
	DISTINCT test_name
FROM
	complete_tests

--How many dogs completed at least one test
SELECT
	COUNT(DISTINCT dog_guid)
FROM
	complete_tests


--Breakdown of the number of different tests completed in different months
SELECT
	test_name,
	MONTH(created_at) AS month,
	COUNT(*) AS no_of_test
FROM
	complete_tests
GROUP BY
	test_name,
	MONTH(created_at)
ORDER BY
	no_of_test DESC

--No of distinct female and male dogs by breed group
SELECT
	gender,
	breed_group,
	COUNT(DISTINCT dog_guid) AS no_of_dogs
FROM
	dogs
WHERE
	breed_group IS NOT NULL
	AND
	breed_group <> ''
GROUP BY
	gender,
	breed_group

--No of users by country
SELECT
	country,
	COUNT(DISTINCT user_guid) AS total_users
FROM
	users
GROUP BY
	country
ORDER BY
	total_users DESC

--Count of reviews provided by different membership type
SELECT 
	u.membership_type, 
	COUNT(DISTINCT r.user_guid) AS no_of_reviews
FROM 
	users u
INNER JOIN
	reviews r
ON 
	u.user_guid = r.user_guid
GROUP BY 
	u.membership_type


--Count of tests completed by each dog
SELECT 
    d.dog_guid, 
    COUNT(t.test_name) AS tests_completed
FROM 
    dogs d 
LEFT JOIN 
    complete_tests t 
ON 
    d.dog_guid = t.dog_guid 
GROUP BY
    d.dog_guid
ORDER BY
	tests_completed DESC


--Unique users who are not in dogs table
SELECT
	user_guid
FROM
	users u
WHERE 
	NOT EXISTS
	(
	SELECT 
		1
	FROM 
		dogs d
	WHERE
		u.user_guid = d.user_guid
	)


--Users from US vs the rest of the world
SELECT
	IIF(country = 'US', 'US', 'Rest Of the world') AS country,
	COUNT(DISTINCT user_guid) AS no_of_users
FROM
	users
WHERE
	country IS NOT NULL
	AND
	user_guid IS NOT NULL
GROUP BY 
	IIF(country = 'US', 'US', 'Rest Of the world')


--No of tests completed by each dog and its personality dimension
SELECT
	d.dog_guid,
	d.dimension,
	COUNT(c.created_at) AS no_tests_completed
FROM
	dogs d
INNER JOIN
	complete_tests c
ON
	d.dog_guid = c.dog_guid
GROUP BY
	d.dog_guid,
	d.dimension
ORDER BY
	no_tests_completed DESC

--Average tests completed by each dimension
WITH 
	cte_tests_completed(dog_guid,dimension,no_tests_completed)
AS
(
SELECT
	d.dog_guid,
	d.dimension,
	CAST(COUNT(c.created_at) AS FLOAT) AS no_tests_completed
FROM
	dogs d
INNER JOIN
	complete_tests c
ON
	d.dog_guid = c.dog_guid
WHERE
	(d.exclude IS NULL 
	OR 
	d.exclude <> 1)
	AND
	d.dimension IS NOT NULL
GROUP BY
	d.dog_guid,
	d.dimension
)
SELECT
	dimension,
	CAST(AVG(no_tests_completed) AS FLOAT) AS avg_tests_completed
FROM
	cte_tests_completed
GROUP BY
	dimension



--Average tests completed by different breed groups
WITH 
	cte_num_test(dogID,breed_group,numtests)
AS
(
SELECT 
	d.dog_guid AS dogID, 
	d.breed_group AS breed_group, 
	CAST(count(c.created_at) AS FLOAT) AS numtests
FROM 
	dogs d 
JOIN 
	complete_tests c
ON 
	d.dog_guid=c.dog_guid
WHERE 
	(d.exclude IS NULL 
	OR 
	d.exclude = 0)
GROUP BY 
	d.dog_guid,
	d.breed_group
)
SELECT 
    breed_group,
    AVG(numtests) AS avg_tests,
    COUNT(DISTINCT dogId) AS no_of_dogs
FROM
	cte_num_test
GROUP BY
    breed_group


--relationship of tests completed and breed type
SELECT 
    num_test.breed_type,
    AVG(numtests),
    COUNT(DISTINCT dogID)
FROM
(
    SELECT 
        d.dog_guid AS dogID, 
        d.breed_type AS breed_type, 
        CAST(count(c.created_at) AS FLOAT) AS numtests
    FROM 
        dogs d JOIN complete_tests c
    ON 
        d.dog_guid=c.dog_guid
    WHERE 
        (d.exclude IS NULL OR d.exclude = 0)
    GROUP BY 
        d.dog_guid,
		d.breed_type
) num_test
GROUP BY
    num_test.breed_type


--Checking average tsts completed by pure vs non pure breed
SELECT 
    num_test.breed_type,
    AVG(numtests) AS avg_tests_completed,
    COUNT(DISTINCT dogID) AS no_of_dogs
FROM
(
    SELECT 
        d.dog_guid AS dogID, 
        CASE
			WHEN d.breed_type = 'Pure Breed' THEN 'Pure breed'
			ELSE 'Non-Pure Breed'
		END AS breed_type, 
        CAST(count(c.created_at) AS FLOAT) AS numtests
    FROM 
        dogs d JOIN complete_tests c
    ON 
        d.dog_guid=c.dog_guid
    WHERE 
        (d.exclude IS NULL OR d.exclude = 0)
    GROUP BY 
        d.dog_guid,
		CASE
			WHEN d.breed_type = 'Pure Breed' THEN 'Pure breed'
			ELSE 'Non-Pure Breed'
		END
) num_test
GROUP BY
    num_test.breed_type


--Tests Completed by day of the week
SELECT
	DATENAME(DW,c.created_at) AS dayname,
	COUNT(*) AS no_of_tests
FROM
	complete_tests c
INNER JOIN
	dogs d
ON
	c.dog_guid = d.dog_guid
WHERE
	d.exclude IS NULL 
	OR 
	d.exclude<>1
GROUP BY
	DATENAME(DW,c.created_at)
ORDER BY
	no_of_tests DESC



--Creating view to rank tests
CREATE VIEW 
	test_ranks
AS
SELECT 
	DISTINCT *,
	ROW_NUMBER() OVER (PARTITION BY dog_guid ORDER BY created_at ASC) AS test_number,
	LAG(created_at) OVER (PARTITION BY dog_guid ORDER BY created_at ASC) AS previous_test_date,
	CAST(DATEDIFF(SECOND, LAG(created_at) OVER (PARTITION BY dog_guid ORDER BY created_at ASC), created_at) AS FLOAT)/(60*60*24) AS date_diff_days,
	CAST(DATEDIFF(SECOND, LAG(created_at) OVER (PARTITION BY dog_guid ORDER BY created_at ASC), created_at) AS FLOAT)/(60) AS date_diff_mins,
	FIRST_VALUE(created_at) OVER (PARTITION BY dog_guid ORDER BY created_at ASC) AS first_test_date,
	FIRST_VALUE(created_at) OVER (PARTITION BY dog_guid ORDER BY created_at DESC) AS last_test_date,
	CAST(DATEDIFF(SECOND,FIRST_VALUE(created_at) OVER (PARTITION BY dog_guid ORDER BY created_at ASC), FIRST_VALUE(created_at) OVER (PARTITION BY dog_guid ORDER BY created_at DESC)) AS FLOAT)/(60*60*24) AS diff_between_first_and_last_test_days,
	CAST(DATEDIFF(SECOND,FIRST_VALUE(created_at) OVER (PARTITION BY dog_guid ORDER BY created_at ASC), FIRST_VALUE(created_at) OVER (PARTITION BY dog_guid ORDER BY created_at DESC)) AS FLOAT)/(60) AS diff_between_first_and_last_test_mins
FROM	
	complete_tests c
WHERE
	dog_guid IS NOT NULL

SELECT * FROM test_ranks


--Aggregating complete_tests data
SELECT
	dog_guid,
	MAX(test_number) AS [Total Tests Completed],
	AVG(date_diff_days) AS [mean_iti(days)],
	AVG(date_diff_mins) AS [mean_iti(mins)],
	AVG(diff_between_first_and_last_test_days) AS [Time diff between first and last game (days)],
	AVG(diff_between_first_and_last_test_mins) AS [Time diff between first and last game (mins)]
INTO
	#tests_aggregated
FROM
	test_ranks
GROUP BY
	dog_guid


SELECT 
	* 
FROM
	#tests_aggregated

--Joining finalized tables for visulaization
SELECT
	t.*,
	u.user_guid,
	d.gender,
	d.birthday,
	d.breed,
	d.breed_type,
	d.breed_group,
	d.weight,
	d.dog_fixed,
	d.dna_tested,
	d.dimension,
	u.sign_in_count,
	u.max_dogs,
	u.membership_id,
	u.subscribed,
	u.city,
	u.state,
	u.zip,
	u.country,
	u.exclude,
	u.free_start_user,
	u.last_active_at,
	u.membership_type
INTO
	dognition_data_aggregated_by_dog_id
FROM
	#tests_aggregated t
INNER JOIN
	(
	SELECT
		DISTINCT *
	FROM
		dogs
	) d
ON
	d.dog_guid = t.dog_guid
INNER JOIN
	(
	SELECT
		DISTINCT *
	FROM
		users
	) u
ON
	d.user_guid = u.user_guid


	SELECT * FROM dognition_data_aggregated_by_dog_id

--Un aggregated table for visualization
SELECT
	c.created_at,
	c.updated_at,
	u.user_guid,
	c.dog_guid,
	c.test_name,
	c.subcategory_name,
	d.gender,
	d.birthday,
	d.breed,
	d.breed_type,
	d.breed_group,
	d.weight,
	d.dog_fixed,
	d.dna_tested,
	d.dimension,
	u.sign_in_count,
	u.max_dogs,
	u.membership_id,
	u.subscribed,
	u.city,
	u.state,
	u.zip,
	u.country,
	CASE
		WHEN u.exclude = 1 OR d.exclude = 1 THEN 1
		ELSE 0
	END AS exclude,
	ISNULL(u.free_start_user,0) AS free_start_user,
	u.last_active_at,
	u.membership_type,
	ROW_NUMBER() OVER (PARTITION BY u.user_guid ORDER BY c.created_at) AS Rank_by_user_id,
	ROW_NUMBER() OVER (PARTITION BY d.dog_guid ORDER BY c.created_at) AS Rank_by_dog_id
FROM
	(
	SELECT 
		DISTINCT *
	FROM
		complete_tests
	) c
INNER JOIN
	(
	SELECT 
		DISTINCT *
	FROM
		dogs
	) d
ON
	d.dog_guid = c.dog_guid
INNER JOIN 
	(
	SELECT
		DISTINCT *
	FROM
		users
	) u
ON
	u.user_guid = d.user_guid