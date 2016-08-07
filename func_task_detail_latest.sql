/*
* @author: 	A. Paul Massardo
* @date:	2015/02/24
* @title	task_detail_latest
* @description	This function returns a recordset/table that represents an individual students task evaluations. It also
*		returns the student's lates and absences. This function also filters to only show the very latest individual
*		tasks	
* @param	studentId - INTEGER - mandatory
* @param	staffId - INTEGER - optional
* @param	subjectId - INTEGER - optional
* @param	evaluationDateFrom - DATE - optional
* @param	evaluationDateTo - DATE - optional
* @examples
*		SELECT * FROM task_detail_latest(101);
*
* @note:        to drop/delete the function - DROP FUNCTION IF EXISTS task_detail_latest(integer, integer, integer, date, date);
*/

CREATE OR REPLACE FUNCTION task_detail_latest(studentId INTEGER,staffId INTEGER DEFAULT 0,subjectId INTEGER DEFAULT 0,evaluationDateFrom DATE DEFAULT NULL, evaluationDateTo DATE DEFAULT NULL)

  RETURNS TABLE("teacher" TEXT, 
		"age" FLOAT,
		"student" TEXT,
		"gradeLevelName" VARCHAR(256), 
		"subjectName" VARCHAR(256), 
		"taskName" VARCHAR(256),
		"evaluationDescription" VARCHAR(256), 
		"evaluationValue" SMALLINT, 
		"evaluationDate" TIMESTAMP, 
		"days" INTERVAL,
		"property" VARCHAR(256),
		"lateCount" SMALLINT,
		"absentCount" SMALLINT,
		"evaluationTypeDescription" VARCHAR(256),
		"studentId" INTEGER, 
		"staffId" SMALLINT, 
		"subjectId" SMALLINT,
		"taskId" SMALLINT)  

  AS $BODY$

  BEGIN	

	/* 
		max_date_temp_table
		
		create a temp table to join to the task evaluations to only return the latest (max date) 
		records for a particular student.
		Originally done with a subquery, but moved to the temp table join to improve performance.
	*/
	CREATE TEMPORARY TABLE max_date_temp_table ON COMMIT DROP AS  SELECT max("tblTaskEvaluations"."evaluationDate") AS "max_date","tblTaskEvaluations"."staffId" ,"tblTaskEvaluations"."studentId", "tblTaskEvaluations"."taskId" 
		FROM "tblTaskEvaluations" 
		WHERE "tblTaskEvaluations"."studentId" = studentId 
		GROUP BY "tblTaskEvaluations"."staffId" ,
			"tblTaskEvaluations"."studentId", 
			"tblTaskEvaluations"."taskId";
			
	/* create a unique index to improve performance */
	CREATE UNIQUE INDEX max_date_temp_table_idx ON max_date_temp_table ("max_date","staffId","studentId","taskId");
			
	/*
		Return Statement (RETURN QUERY)
		
		The following select statement calls the task_detail function to return the task evaluations and then 
		INNER JOIN on the max_date_temp_table to only show the latest task evaluations for a student
		
	*/
	RETURN QUERY SELECT base_function."teacher",
		base_function."age",
		base_function."student",
		base_function."gradeLevelName",	
		base_function."subjectName",	
		base_function."taskName",	
		base_function."evaluationDescription",	
		base_function."evaluationValue",	
		base_function."evaluationDate",
		base_function."days",
		base_function."property",
		base_function."lateCount",
		base_function."absentCount",
		base_function."evaluationTypeDescription",
		base_function."studentId", 
		base_function."staffId", 
		base_function."subjectId",  
		base_function."taskId"

		FROM task_detail(studentId,staffId,subjectId,evaluationDateFrom , evaluationDateTo) AS base_function

		INNER JOIN max_date_temp_table ON  base_function."evaluationDate" = max_date_temp_table."max_date"
			AND base_function."staffId" = max_date_temp_table."staffId"
			AND base_function."studentId" = max_date_temp_table."studentId"
			AND base_function."taskId" = max_date_temp_table."taskId";


END;
$BODY$  LANGUAGE plpgsql;

