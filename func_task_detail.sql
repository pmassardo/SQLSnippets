/*
* @author: 	A. Paul Massardo
* @date:	2015/02/24
* @title	task_detail
* @description	This function returns a recordset/table that represents an individual students task evaluations. It also
*		returns the student's lates and absences
* @param	studentId - INTEGER - mandatory
* @param	staffId - INTEGER - optional
* @param	subjectId - INTEGER - optional
* @param	evaluationDateFrom - DATE - optional
* @param	evaluationDateTo - DATE - optional
* @examples
*		SELECT * FROM task_detail(101);
*
* @note:        to drop/delete the function - DROP FUNCTION IF EXISTS task_detail(integer, integer, integer, date, date);
*/

CREATE OR REPLACE FUNCTION task_detail(studentId INTEGER,staffId INTEGER DEFAULT 0,subjectId INTEGER DEFAULT 0,evaluationDateFrom DATE DEFAULT NULL, evaluationDateTo DATE DEFAULT NULL)

  /* results will be returned in the form of the following table */
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
		count_absent_temp_table
		
		Create a temporary table with an agregate of count for all the absences

		This count_absent_temp_table table will be joined to the result to be return to display all the absences	
	*/
 
	CREATE TEMPORARY TABLE count_absent_temp_table ON COMMIT DROP AS 
		SELECT count("attendanceStatusId") AS "absentCount", "tblAttendance"."studentId" 
		FROM "tblAttendance" 
		WHERE "tblAttendance"."attendanceStatusId" = 2 	
		/* 
			  use the CASE to check if to and from dates have been passed, 
				if so, use the to and from dates in the where clause  
				if not, where the field to itself
		*/
		AND "tblAttendance"."attendanceDate" >= CASE WHEN evaluationDateFrom IS NULL THEN "tblAttendance"."attendanceDate" ELSE evaluationDateFrom END
		AND "tblAttendance"."attendanceDate" <= CASE WHEN evaluationDateTo IS NULL THEN "tblAttendance"."attendanceDate" ELSE evaluationDateTo END
		AND "tblAttendance"."studentId" = studentId 
		GROUP BY "tblAttendance"."studentId"; 

	/* create a unique index to improve performance */
	CREATE UNIQUE INDEX count_absent_temp_table_idx ON count_absent_temp_table ("studentId");



	/* 
		count_late_temp_table
		
		Create a temporary table with an agregate of count for all the lates

		This count_late_temp_table table will be joined to the result to be return to display all the absences	
	*/
	CREATE TEMPORARY TABLE count_late_temp_table ON COMMIT DROP AS 
		SELECT count("attendanceStatusId") AS "lateCount", "tblAttendance"."studentId" 
		FROM "tblAttendance" 
		WHERE "tblAttendance"."attendanceStatusId" = 3

		/* 
			  use the CASE to check if to and from dates have been passed, 
				if so, use the to and from dates in the where clause  
				if not, where the field to itself
		*/
		AND "tblAttendance"."attendanceDate" >= CASE WHEN evaluationDateFrom IS NULL THEN "tblAttendance"."attendanceDate" ELSE evaluationDateFrom END
		AND "tblAttendance"."attendanceDate" <= CASE WHEN evaluationDateTo IS NULL THEN "tblAttendance"."attendanceDate" ELSE evaluationDateTo END
		AND "tblAttendance"."studentId" = studentId 

		GROUP BY "tblAttendance"."studentId";		
		
	/* create a unique index to improve performance */
	CREATE UNIQUE INDEX count_late_temp_table_idx ON count_late_temp_table ("studentId");
		

	RETURN QUERY SELECT "tblStaff"."lastName" || ', ' || "tblStaff"."firstName" AS "teacher",
		date_part('year',age("tblStudents"."dateOfBirth")) AS "age",
		"tblStudents"."lastName" || ', ' || "tblStudents"."firstName" AS "student",
		"tblGradeLevels"."gradeLevelName" AS "gradeLevelName",	
		"tblSubjects"."subjectName" AS "subjectName",	
		"tblTasks"."taskName" AS "taskName",	
		"tblEvaluations"."evaluationDescription" AS "evaluationDescription",	
		"tblEvaluations"."evaluationValue" AS "evaluationValue",	
		"tblTaskEvaluations"."evaluationDate" AS "evaluationDate",
		"tblTaskEvaluations"."evaluationDate" - '1900-01-01' AS "days",
		"tblProperty"."property" AS "property",
		count_late_temp_table."lateCount"::SMALLINT AS "lateCount",
		count_absent_temp_table."absentCount"::SMALLINT AS "absentCount",
		"tblEvaluationTypes"."evaluationTypeDescription" AS "evaluationTypeDescription",
		"tblTaskEvaluations"."studentId", 
		"tblTaskEvaluations"."staffId",  
		"tblSubjectCategories"."subjectId",
		"tblTasks"."taskId" AS "taskId"  

		FROM "tblTaskEvaluations"
			INNER JOIN "tblStaff" ON "tblStaff"."staffId" = "tblTaskEvaluations"."staffId" 
			INNER JOIN "tblStudents" ON "tblStudents"."studentId" = "tblTaskEvaluations"."studentId"
			INNER JOIN "tblTasks" ON "tblTaskEvaluations"."taskId" = "tblTasks"."taskId" 				
			INNER JOIN "tblSubjectCategories" ON "tblTasks"."subjectCategoryId" = "tblSubjectCategories"."subjectCategoryId" 
			INNER JOIN "tblSubjects" ON "tblSubjectCategories"."subjectId" = "tblSubjects"."subjectId" 
			INNER JOIN "tblGradeLevels" ON "tblSubjects"."gradeLevelId" = "tblGradeLevels"."gradeLevelId"
			INNER JOIN "tblEvaluations" ON "tblTaskEvaluations"."evaluationId" = "tblEvaluations"."evaluationId"
			INNER JOIN "tblProperty" ON "tblTaskEvaluations"."propertyId" = "tblProperty"."propertyId"
			INNER JOIN count_late_temp_table ON "tblStudents"."studentId" =	count_late_temp_table."studentId" 				
			INNER JOIN count_absent_temp_table ON "tblStudents"."studentId" = count_absent_temp_table."studentId" 
			INNER JOIN "tblEvaluationTypes" ON "tblTaskEvaluations"."evaluationTypeId" = "tblEvaluationTypes"."evaluationTypeId"

			/* 
				  use the CASE to check if to and from dates have been passed, 
					if so, use the to and from dates in the where clause  
					if not, where the field to itself
			*/
			WHERE "tblTaskEvaluations"."evaluationDate" >= CASE WHEN evaluationDateFrom IS NULL THEN "tblTaskEvaluations"."evaluationDate" ELSE evaluationDateFrom END
				AND "tblTaskEvaluations"."evaluationDate" <= CASE WHEN evaluationDateTo IS NULL THEN "tblTaskEvaluations"."evaluationDate" ELSE evaluationDateTo END
				AND "tblTaskEvaluations"."studentId" = studentId 
				AND "tblTaskEvaluations"."staffId" = CASE WHEN staffId = 0 THEN "tblTaskEvaluations"."staffId" ELSE staffId END 
				AND "tblSubjectCategories"."subjectId" = CASE WHEN subjectId = 0 THEN "tblSubjectCategories"."subjectId" ELSE subjectId END

			ORDER BY "teacher", "age", "student", "tblGradeLevels"."gradeLevelName" ,"tblSubjects"."subjectName", "tblTasks"."taskId", "tblTaskEvaluations"."evaluationDate" ASC;

END;
$BODY$  LANGUAGE plpgsql;


