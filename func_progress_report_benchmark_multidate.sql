/*
* @author: 	A. Paul Massardo
* @date:	2015/03/15
* @title	progress_report_individual_multidate
* @description	This function returns a recordset/table that represents an individual students progress, or task evaluations, measured against the 
*		benchmark task path. This is an age based generic mapping of what a student needs to complete before they can move on. The task path is made
*		up of prerequisites, once a prerequisite is complete, the student may proceed to the next task. This function is a modification of 
*		the progress_report_benchmark the function drops the data into three date buckets based on the parameters below. Each bucket is delimited
*		by a number 1, 2, and 3 for each date range. Each bucket represents a date range that can be easily parsed in a loop in the GUI/report
* @param	studentId - INTEGER - mandatory
* @param	evaluationDateFromOne - BOOLEAN - mandatory
* @param	evaluationDateToOne - BOOLEAN - mandatory
* @param	evaluationDateFromTwo - BOOLEAN - mandatory
* @param	evaluationDateToTwo - BOOLEAN - mandatory
* @param	evaluationDateFromThree - BOOLEAN - mandatory
* @param	evaluationDateToThree - BOOLEAN - mandatory
* @param	subjectId - INTEGER - optional
* @param	latest - BOOLEAN - optional (this forces the function to only return the latest task when there is one or more attempts)	
*
* @examples
*		SELECT * FROM progress_report_individual_multidate(101,'2002-05-23','2002-07-30','2002-07-31','2002-10-31','2002-11-01','2003-10-28',0,FALSE);
*
* @note:        to drop/delete the function - DROP FUNCTION progress_report_benchmark_multidate(integer, date, date, date, date, date, date, integer, boolean);
*/

CREATE OR REPLACE FUNCTION progress_report_benchmark_multidate(studentId INTEGER,evaluationDateFromOne DATE, evaluationDateToOne DATE , evaluationDateFromTwo DATE , evaluationDateToTwo DATE , evaluationDateFromThree DATE , evaluationDateToThree DATE , subjectId INTEGER DEFAULT 0, latest BOOLEAN DEFAULT FALSE)
/* results will be returned in the form of the following table */
RETURNS TABLE
	(
	"delimiter" INTEGER,
	"minimumEvaluationValue" INTEGER,
	"prerequisiteTaskName" TEXT,
	"taskName" 	VARCHAR(256),
	"subjectCategoryName" 	VARCHAR(256),
	"subjectName" 	VARCHAR(256), 
	"gradeLevelName" 	VARCHAR(256),
	"studentId" INTEGER,
	"prerequisiteTaskId" SMALLINT,
	"suggestedTaskId" SMALLINT,
	"recommededDaysToComplete" SMALLINT,
	"taskId" INTEGER,
	"teacher" TEXT,
	"student" TEXT,
	"evaluationDescription" VARCHAR(256),
	"evaluationTypeDescription" VARCHAR(256),
	"evaluationDate" TIMESTAMP,
	"evaluationValue" INTEGER,
	"firstPresentationDate" TIMESTAMP,
	"daysToComplete" INTEGER,
	"differenceDaysToComplete" INTEGER
	)

AS 

$BODY$

  BEGIN
 	/* 
		temp_firstpresentation_task_evaluation
		
		create a temporary table to store all the first presentations (the first time a student attempts a task)
		first presentations is the start point that is used to measure how long it took a student to complete a
		task.

		This temp table will be joined to show the first presentation data in the returning table
		
	*/
	CREATE TEMPORARY TABLE temp_firstpresentation_task_evaluation ON COMMIT DROP AS 
		SELECT 
			"tblTaskEvaluations"."studentId", 
			"tblTaskEvaluations"."staffId",
			"tblTaskEvaluations"."taskId",
			"tblTaskEvaluations"."evaluationDate" as "firstPresentationDate",
			"tblTaskEvaluations"."evaluationTypeId" 
		
		FROM "tblTaskEvaluations" 

			INNER JOIN "tblEvaluations" ON "tblTaskEvaluations"."evaluationId" = "tblEvaluations"."evaluationId"		
			INNER JOIN "tblEvaluationTypes" ON "tblTaskEvaluations"."evaluationTypeId" = "tblEvaluationTypes"."evaluationTypeId"
			INNER JOIN "tblStaff" ON "tblTaskEvaluations"."staffId" = "tblStaff"."staffId"
			INNER JOIN "tblStudents" ON "tblStudents"."studentId" = "tblTaskEvaluations"."studentId"
		
		WHERE "tblTaskEvaluations"."studentId" = studentId
			AND "tblTaskEvaluations"."evaluationTypeId"= 'FP';
				
	/* create a unique index to improve performance */
	CREATE UNIQUE INDEX temp_firstpresentation_task_idx ON temp_firstpresentation_task_evaluation ("taskId","studentId", "firstPresentationDate");

	/* check to see if only the latest records are required */
	IF latest = TRUE THEN	

		/* 
			max_date_temp_table
			
			create a temp table to join to the task evaluations to only return the latest (max date) 
			records for a particular student.
			Originally done with a subquery, but moved to the temp table join to improve performance.
		*/
		CREATE TEMPORARY TABLE max_date_temp_table ON COMMIT DROP AS  
		SELECT 
			max("tblTaskEvaluations"."evaluationDate") AS "max_date",
			"tblTaskEvaluations"."staffId" ,
			"tblTaskEvaluations"."studentId", 
			"tblTaskEvaluations"."taskId" 
		FROM "tblTaskEvaluations" 
		WHERE "tblTaskEvaluations"."studentId" = studentId
		GROUP BY "tblTaskEvaluations"."staffId" ,
			"tblTaskEvaluations"."studentId", 
			"tblTaskEvaluations"."taskId";	

		/* create a unique index to improve performance */
		CREATE UNIQUE INDEX max_date_temp_table_idx ON max_date_temp_table ("max_date","staffId","studentId","taskId");		
					
		/* 
			temp_latest_task_evaluation
			
			create a temporary table with only the latest task evaluations 
		*/
		CREATE TEMPORARY TABLE temp_latest_task_evaluation ON COMMIT DROP AS 
			SELECT "tblTaskEvaluations"."taskId",
			"tblTaskEvaluations"."studentId", 
			"tblTaskEvaluations"."staffId", 
			"tblTaskEvaluations"."evaluationId",
			"tblTaskEvaluations"."evaluationTypeId",
			"tblTaskEvaluations"."evaluationDate"
			FROM "tblTaskEvaluations"

			/* 
				only return the records that will join to the max_date_temp_table, so only the latest records 
			*/
			INNER JOIN max_date_temp_table ON "tblTaskEvaluations"."evaluationDate" = max_date_temp_table."max_date"
				AND "tblTaskEvaluations"."staffId" = max_date_temp_table."staffId"
				AND "tblTaskEvaluations"."studentId" = max_date_temp_table."studentId"
				AND "tblTaskEvaluations"."taskId" = max_date_temp_table."taskId"
			
			WHERE "tblTaskEvaluations"."studentId" = studentId

			/* 
				  use the CASE to check if to and from dates have been passed, 
					if so, use the to and from dates in the where clause  
					if not, where the field to itself
			*/			
			AND "tblTaskEvaluations"."evaluationDate" >= CASE WHEN evaluationDateFromOne IS NULL THEN "tblTaskEvaluations"."evaluationDate" ELSE evaluationDateFromOne END
			AND "tblTaskEvaluations"."evaluationDate" <= CASE WHEN evaluationDateToThree IS NULL THEN "tblTaskEvaluations"."evaluationDate" ELSE evaluationDateToThree END;
			

	ELSE /* all the task evaluation are required, not just the latest */
							
		CREATE TEMPORARY TABLE temp_latest_task_evaluation ON COMMIT DROP AS 
			SELECT 
			"tblTaskEvaluations"."taskId",
			"tblTaskEvaluations"."studentId", 
			"tblTaskEvaluations"."staffId", 
			"tblTaskEvaluations"."evaluationId",
			"tblTaskEvaluations"."evaluationTypeId",
			"tblTaskEvaluations"."evaluationDate"
			FROM "tblTaskEvaluations"
			WHERE "tblTaskEvaluations"."studentId" = studentId

			/* 
				  use the CASE to check if to and from dates have been passed, 
					if so, use the to and from dates in the where clause  
					if not, where the field to itself
			*/			
			AND "tblTaskEvaluations"."evaluationDate" >= CASE WHEN evaluationDateFromOne IS NULL THEN "tblTaskEvaluations"."evaluationDate" ELSE evaluationDateFromOne END
			AND "tblTaskEvaluations"."evaluationDate" <= CASE WHEN evaluationDateToThree IS NULL THEN "tblTaskEvaluations"."evaluationDate" ELSE evaluationDateToThree END;

			

	END IF;

	/* create a unique index to improve performance */
	CREATE UNIQUE INDEX temp_latest_task_idx ON temp_latest_task_evaluation ("taskId","studentId", "evaluationDate");

	/*
		raw_task_path

		The raw task path is the task path for a student in a particular age group and it can be 
		filtered (where'd) by the subject id. Since the task path is recursive in nature starting 
		task evaluations will not all be represented in the past path. So, the raw table will be 
		used to assist in not only returning actual task path records that exist, but also to 
		assist in completing a complete	task path and show virtual entries to make it easier for 
		the user to understand.

	*/
	
	CREATE TEMPORARY TABLE raw_task_path ON COMMIT DROP AS	

		SELECT "tblBenchMarkTaskPaths"."prerequisiteTaskId", 
			"tblStudents"."studentId", 
			"tblBenchMarkTaskPaths"."daysToComplete", 
			"tblBenchMarkTaskPaths"."minimumEvaluationId", 
			"tblEvaluations"."evaluationValue" AS "minimumEvaluationValue", 
			"tblBenchMarkTaskPaths"."suggestedTaskId",
			"tblTasks_1"."taskName" as "prerequisiteTaskName",
			"tblTasks"."taskName",
			"tblSubjectCategories"."subjectCategoryName",
			"tblSubjects"."subjectName",
			"tblGradeLevels"."gradeLevelName",
			"tblAgeGroups"."ageGroupDescription", 
			date_part('year',age("tblStudents"."dateOfBirth")) as "Age"
								
			FROM "tblStudents" 
				INNER JOIN "tblAgeGroups" ON date_part('year',age("tblStudents"."dateOfBirth")) >= "tblAgeGroups"."ageLowerRange" 
					  AND date_part('year',age("tblStudents"."dateOfBirth")) < "tblAgeGroups"."ageUpperRange" 
				INNER JOIN "tblBenchMarkTaskPaths" ON "tblBenchMarkTaskPaths"."ageGroupId" = "tblAgeGroups"."ageGroupId"
				INNER JOIN "tblEvaluations" ON "tblBenchMarkTaskPaths"."minimumEvaluationId" = "tblEvaluations"."evaluationId"
				INNER JOIN "tblTasks" ON "tblBenchMarkTaskPaths"."suggestedTaskId" = "tblTasks"."taskId"
				INNER JOIN "tblTasks" AS "tblTasks_1" ON "tblBenchMarkTaskPaths"."prerequisiteTaskId" = "tblTasks_1"."taskId"
				INNER JOIN "tblSubjectCategories" ON "tblTasks"."subjectCategoryId" = "tblSubjectCategories"."subjectCategoryId"
				INNER JOIN "tblSubjects" ON "tblSubjectCategories"."subjectId" = "tblSubjects"."subjectId"
				INNER JOIN "tblGradeLevels" ON "tblGradeLevels"."gradeLevelId" = "tblSubjects"."gradeLevelId"

			WHERE "tblStudents"."studentId" = studentId

			/* 
				  use the CASE to check if a subjectId has been passed, 
					if so, use the subjectId in the where clause  
					if not, where the field to itself
			*/
			AND "tblSubjectCategories"."subjectId" = CASE WHEN subjectId = 0 THEN "tblSubjectCategories"."subjectId" ELSE subjectId END;

	/*
		temp_task_path

		The temp task path table is a UNION between what exists and what does not exist. The bench 
		mark task path is recursive so it requires a task to start (prerequisite) and finish 
		(suggested next task) an entry/record. So, if a task is the starting point of a task path 
		this particular task will not have a task path entry because it has no prerequisite. 

		The first portion of the union is to create all the entries that do not exist, by performing a 
		subquery with the raw_task_path table and asking for tasks that do not match in the raw_task_path
		suggestedtaskId to the prerequisite task Id. So if a prerequisite does not exist for a task it 
		will not appear in the pask path table as a prerequiste, but it will appear as a suggested task. 

		The second part of the UNION just return the raw_task_path and now both virtual and real task 
		path entries will appear in the temp_task_path table.

	*/						 
	CREATE TEMPORARY TABLE temp_task_path ON COMMIT DROP AS		
			SELECT DISTINCT "tblBenchMarkTaskPaths"."prerequisiteTaskId", 
			"tblStudents"."studentId", 
			1 AS "daysToComplete", 
			'NN' AS "minimumEvaluationId", 
			0 AS "minimumEvaluationValue", 
			"tblBenchMarkTaskPaths"."prerequisiteTaskId" AS "suggestedTaskId",
			'NA' as "prerequisiteTaskName",
			"tblTasks"."taskName",
			"tblSubjectCategories"."subjectCategoryName",
			"tblSubjects"."subjectName",
			"tblGradeLevels"."gradeLevelName",
			"tblAgeGroups"."ageGroupDescription", 
			date_part('year',age("tblStudents"."dateOfBirth")) as "Age" 
			FROM "tblStudents" 
				INNER JOIN "tblAgeGroups" ON date_part('year',age("tblStudents"."dateOfBirth")) >= "tblAgeGroups"."ageLowerRange" 
					  AND date_part('year',age("tblStudents"."dateOfBirth")) < "tblAgeGroups"."ageUpperRange" 
				INNER JOIN "tblBenchMarkTaskPaths" ON "tblBenchMarkTaskPaths"."ageGroupId" = "tblAgeGroups"."ageGroupId"
			INNER JOIN "tblTasks" ON "tblBenchMarkTaskPaths"."prerequisiteTaskId" = "tblTasks"."taskId"
			INNER JOIN "tblSubjectCategories" ON "tblTasks"."subjectCategoryId" = "tblSubjectCategories"."subjectCategoryId"
			INNER JOIN "tblSubjects" ON "tblSubjectCategories"."subjectId" = "tblSubjects"."subjectId"
			INNER JOIN "tblGradeLevels" ON "tblGradeLevels"."gradeLevelId" = "tblSubjects"."gradeLevelId"

			WHERE  "tblBenchMarkTaskPaths"."prerequisiteTaskId" NOT IN (SELECT raw_task_path."suggestedTaskId" FROM raw_task_path)
			
			AND  "tblStudents"."studentId" = studentId

			/* 
				  use the CASE to check if a subjectId has been passed, 
					if so, use the subjectId in the where clause  
					if not, where the field to itself
			*/			
			AND "tblSubjectCategories"."subjectId" = CASE WHEN subjectId = 0 THEN "tblSubjectCategories"."subjectId" ELSE subjectId END
			

		UNION

		/* 
			  Select everything from the raw_task_path to UNION to the fictitious data
		*/
		SELECT raw_task_path."prerequisiteTaskId", 
			raw_task_path."studentId", 
			raw_task_path."daysToComplete", 
			raw_task_path."minimumEvaluationId", 
			raw_task_path."minimumEvaluationValue", 
			raw_task_path."suggestedTaskId",
			raw_task_path."prerequisiteTaskName",
			raw_task_path."taskName",
			raw_task_path."subjectCategoryName",
			raw_task_path."subjectName",
			raw_task_path."gradeLevelName",
			raw_task_path."ageGroupDescription",
			raw_task_path."Age"
			FROM  raw_task_path;

	/* create a unique index to improve performance */
	CREATE UNIQUE INDEX temp_task_path_idx ON temp_task_path ("studentId", "suggestedTaskId");


	/*
		return_table

		The following section is broken into three parts connect by two UNION statements

		1. records in part one are delimited by the number 1 in the first field and are for
		   records between evaluationDateFromOne and evaluationDateToOne
		2. records in part two are delimited by the number 2 in the first field and are for
		   records between evaluationDateFromTwo and evaluationDateToTwo
		3. records in part three are delimited by the number 3 in the first field and are for
		   records between evaluationDateFromThree and evaluationDateToThree
			
		Each select statement can be broken out into two parts, the first is the temp_task_path which represents
		real and virtual entries that represents a students path through the task/courses whether they have been completed
		or not. This data is based on the "tblBenchMarkTaskPaths" table which is an age based/generic task path. The second 
		part comes from the temp_latest_task_evaluation which are the tasks that a student has attempted and/or completed. 
		Since there is a good chance that a student has not completed all the tasks in the "tblBenchMarkTaskPaths" task path, 
		but all the task path entries will need to be seen to compare the student's task path with the student's evaluations
		we cannot INNER JOIN. The INNER JOIN will only return the data that match in both tables. So, only the task 
		path entries that have matching task evaluations would be returned. Instead, using a LEFT OUTER JOIN, will show 
		everything from the temp_task_path regardless of whether there is a task evaluation that it can be joined to. It will
		also return the records in the temp_latest_task_evaluation table that can be joing to the temp_task_path table. So, 
		we see everything that the student needs to do, as well as, what they have done.

		Since there will be fields for records that do not exist because a task evaluation may not be entered for a particular
		task the COALESCE returns the first non-null value that appears as arguments.	

	*/
	CREATE TEMPORARY TABLE return_table ON COMMIT DROP AS	

	SELECT 1 as "delimiter",
		temp_task_path."minimumEvaluationValue",
		temp_task_path."prerequisiteTaskName",
		temp_task_path."taskName", 
		temp_task_path."subjectCategoryName", 
		temp_task_path."subjectName", 
		temp_task_path."gradeLevelName", 
		temp_task_path."studentId",
		temp_task_path."prerequisiteTaskId",
		temp_task_path."suggestedTaskId",
		temp_task_path."daysToComplete" AS "recommededDaysToComplete",							
		COALESCE(temp_latest_task_evaluation."taskId",0) as "taskId",
		COALESCE("tblStaff"."lastName" || ', ' || "tblStaff"."firstName", '(incomplete)') as "teacher",			
		COALESCE("tblStudents"."lastName" || ', ' || "tblStudents"."firstName", '(incomplete)') as "student",			
		COALESCE("tblEvaluations"."evaluationDescription", '(incomplete)') as "evaluationDescription",
		COALESCE("tblEvaluationTypes"."evaluationTypeDescription", '(incomplete)') as "evaluationTypeDescription",
		COALESCE(temp_latest_task_evaluation."evaluationDate",'1900-01-01') as "evaluationDate",
		COALESCE("tblEvaluations"."evaluationValue", 0) as "evaluationValue", 
		COALESCE(temp_firstpresentation_task_evaluation."firstPresentationDate" ,'1900-01-01') as "firstPresentationDate",
		((((EXTRACT(epoch FROM COALESCE(temp_latest_task_evaluation."evaluationDate" ,'1900-01-01'))))-((EXTRACT(epoch FROM COALESCE(temp_firstpresentation_task_evaluation."firstPresentationDate" ,'1900-01-01'))))::BIGINT)/86400)::INT AS "daysToComplete", 
		temp_task_path."daysToComplete" - ((((EXTRACT(epoch FROM COALESCE(temp_latest_task_evaluation."evaluationDate" ,'1900-01-01'))))-((EXTRACT(epoch FROM COALESCE(temp_firstpresentation_task_evaluation."firstPresentationDate" ,'1900-01-01'))))::BIGINT)/86400)::INT AS "differenceDaysToComplete"
				
		FROM  temp_task_path 
			/*
				Once a OUTER JOIN is used all other JOINS must also be OUTER JOINs. 
			*/			
			LEFT OUTER 
				JOIN temp_latest_task_evaluation ON temp_task_path."suggestedTaskId" = temp_latest_task_evaluation."taskId"
				AND temp_task_path."studentId" = temp_latest_task_evaluation."studentId"		
					
			LEFT OUTER  
				JOIN temp_firstpresentation_task_evaluation ON temp_latest_task_evaluation."staffId" = temp_firstpresentation_task_evaluation."staffId"
				AND temp_latest_task_evaluation."studentId" = temp_firstpresentation_task_evaluation."studentId"
				AND temp_latest_task_evaluation."taskId" = temp_firstpresentation_task_evaluation."taskId"
				
			LEFT OUTER JOIN "tblStaff" ON temp_latest_task_evaluation."staffId" = "tblStaff"."staffId"
			LEFT OUTER JOIN "tblStudents" ON temp_latest_task_evaluation."studentId" = "tblStudents"."studentId"
			LEFT OUTER JOIN "tblEvaluationTypes" ON temp_latest_task_evaluation."evaluationTypeId" = "tblEvaluationTypes"."evaluationTypeId"
			LEFT OUTER JOIN "tblEvaluations" ON temp_latest_task_evaluation."evaluationId" = "tblEvaluations"."evaluationId"

		WHERE temp_latest_task_evaluation."evaluationDate" BETWEEN evaluationDateFromOne AND  evaluationDateToOne

	UNION

		SELECT 	2 as "delimiter",
			temp_task_path."minimumEvaluationValue",
			temp_task_path."prerequisiteTaskName",
			temp_task_path."taskName", 
			temp_task_path."subjectCategoryName", 
			temp_task_path."subjectName", 
			temp_task_path."gradeLevelName", 
			temp_task_path."studentId",
			temp_task_path."prerequisiteTaskId",
			temp_task_path."suggestedTaskId",
			temp_task_path."daysToComplete" AS "recommededDaysToComplete",							
			COALESCE(temp_latest_task_evaluation."taskId",0) as "taskId",
			COALESCE("tblStaff"."lastName" || ', ' || "tblStaff"."firstName", '(incomplete)') as "teacher",			
			COALESCE("tblStudents"."lastName" || ', ' || "tblStudents"."firstName", '(incomplete)') as "student",			
			COALESCE("tblEvaluations"."evaluationDescription", '(incomplete)') as "evaluationDescription",
			COALESCE("tblEvaluationTypes"."evaluationTypeDescription", '(incomplete)') as "evaluationTypeDescription",
			COALESCE(temp_latest_task_evaluation."evaluationDate",'1900-01-01') as "evaluationDate",
			COALESCE("tblEvaluations"."evaluationValue", 0) as "evaluationValue", 
			COALESCE(temp_firstpresentation_task_evaluation."firstPresentationDate" ,'1900-01-01') as "firstPresentationDate",
			((((EXTRACT(epoch FROM COALESCE(temp_latest_task_evaluation."evaluationDate" ,'1900-01-01'))))-((EXTRACT(epoch FROM COALESCE(temp_firstpresentation_task_evaluation."firstPresentationDate" ,'1900-01-01'))))::BIGINT)/86400)::INT AS "daysToComplete", 
			temp_task_path."daysToComplete" - ((((EXTRACT(epoch FROM COALESCE(temp_latest_task_evaluation."evaluationDate" ,'1900-01-01'))))-((EXTRACT(epoch FROM COALESCE(temp_firstpresentation_task_evaluation."firstPresentationDate" ,'1900-01-01'))))::BIGINT)/86400)::INT AS "differenceDaysToComplete"
					
			FROM  temp_task_path 

				/*
					Once a OUTER JOIN is used all other JOINS must also be OUTER JOINs. 
				*/			
				LEFT OUTER 
					JOIN temp_latest_task_evaluation ON temp_task_path."suggestedTaskId" = temp_latest_task_evaluation."taskId"
					AND temp_task_path."studentId" = temp_latest_task_evaluation."studentId"		
						
				LEFT OUTER  
					JOIN temp_firstpresentation_task_evaluation ON temp_latest_task_evaluation."staffId" = temp_firstpresentation_task_evaluation."staffId"
					AND temp_latest_task_evaluation."studentId" = temp_firstpresentation_task_evaluation."studentId"
					AND temp_latest_task_evaluation."taskId" = temp_firstpresentation_task_evaluation."taskId"
					
				LEFT OUTER JOIN "tblStaff" ON temp_latest_task_evaluation."staffId" = "tblStaff"."staffId"
				LEFT OUTER JOIN "tblStudents" ON temp_latest_task_evaluation."studentId" = "tblStudents"."studentId"
				LEFT OUTER JOIN "tblEvaluationTypes" ON temp_latest_task_evaluation."evaluationTypeId" = "tblEvaluationTypes"."evaluationTypeId"
				LEFT OUTER JOIN "tblEvaluations" ON temp_latest_task_evaluation."evaluationId" = "tblEvaluations"."evaluationId"

			WHERE temp_latest_task_evaluation."evaluationDate" BETWEEN evaluationDateFromTwo AND  evaluationDateToTwo

	UNION

		SELECT 3 as "delimiter",
			temp_task_path."minimumEvaluationValue",
			temp_task_path."prerequisiteTaskName",
			temp_task_path."taskName", 
			temp_task_path."subjectCategoryName", 
			temp_task_path."subjectName", 
			temp_task_path."gradeLevelName", 
			temp_task_path."studentId",
			temp_task_path."prerequisiteTaskId",
			temp_task_path."suggestedTaskId",
			temp_task_path."daysToComplete" AS "recommededDaysToComplete",							
			COALESCE(temp_latest_task_evaluation."taskId",0) as "taskId",
			COALESCE("tblStaff"."lastName" || ', ' || "tblStaff"."firstName", '(incomplete)') as "teacher",			
			COALESCE("tblStudents"."lastName" || ', ' || "tblStudents"."firstName", '(incomplete)') as "student",			
			COALESCE("tblEvaluations"."evaluationDescription", '(incomplete)') as "evaluationDescription",
			COALESCE("tblEvaluationTypes"."evaluationTypeDescription", '(incomplete)') as "evaluationTypeDescription",
			COALESCE(temp_latest_task_evaluation."evaluationDate",'1900-01-01') as "evaluationDate",
			COALESCE("tblEvaluations"."evaluationValue", 0) as "evaluationValue", 
			COALESCE(temp_firstpresentation_task_evaluation."firstPresentationDate" ,'1900-01-01') as "firstPresentationDate",
			((((EXTRACT(epoch FROM COALESCE(temp_latest_task_evaluation."evaluationDate" ,'1900-01-01'))))-((EXTRACT(epoch FROM COALESCE(temp_firstpresentation_task_evaluation."firstPresentationDate" ,'1900-01-01'))))::BIGINT)/86400)::INT AS "daysToComplete", 
			temp_task_path."daysToComplete" - ((((EXTRACT(epoch FROM COALESCE(temp_latest_task_evaluation."evaluationDate" ,'1900-01-01'))))-((EXTRACT(epoch FROM COALESCE(temp_firstpresentation_task_evaluation."firstPresentationDate" ,'1900-01-01'))))::BIGINT)/86400)::INT AS "differenceDaysToComplete"
					
			FROM  temp_task_path
			 
				/*
					Once a OUTER JOIN is used all other JOINS must also be OUTER JOINs. 
				*/			
				LEFT OUTER 
					JOIN temp_latest_task_evaluation ON temp_task_path."suggestedTaskId" = temp_latest_task_evaluation."taskId"
					AND temp_task_path."studentId" = temp_latest_task_evaluation."studentId"		
						
				LEFT OUTER  
					JOIN temp_firstpresentation_task_evaluation ON temp_latest_task_evaluation."staffId" = temp_firstpresentation_task_evaluation."staffId"
					AND temp_latest_task_evaluation."studentId" = temp_firstpresentation_task_evaluation."studentId"
					AND temp_latest_task_evaluation."taskId" = temp_firstpresentation_task_evaluation."taskId"
					
				LEFT OUTER JOIN "tblStaff" ON temp_latest_task_evaluation."staffId" = "tblStaff"."staffId"
				LEFT OUTER JOIN "tblStudents" ON temp_latest_task_evaluation."studentId" = "tblStudents"."studentId"
				LEFT OUTER JOIN "tblEvaluationTypes" ON temp_latest_task_evaluation."evaluationTypeId" = "tblEvaluationTypes"."evaluationTypeId"
				LEFT OUTER JOIN "tblEvaluations" ON temp_latest_task_evaluation."evaluationId" = "tblEvaluations"."evaluationId"

			WHERE temp_latest_task_evaluation."evaluationDate" BETWEEN evaluationDateFromThree AND  evaluationDateToThree;


		/* this signifies that the result of this statement will be returned in the in the table/recordset for the function */
		RETURN QUERY 

		/*
			Return Statement (RETURN QUERY)
			This statement just orders the data in the return_table and returns it to the function caller.
		*/
		SELECT * 
		FROM return_table 
		ORDER BY return_table.delimiter, return_table."gradeLevelName", return_table."subjectName", return_table."subjectCategoryName" , return_table."suggestedTaskId", return_table."evaluationDate";

  END
  $BODY$
LANGUAGE 'plpgsql';



	
