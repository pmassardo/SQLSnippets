/*
* @author: 	A. Paul Massardo
* @date:	2015/02/24
* @title	report_card
* @description	This function returns a recordset/table that represents either an individual student or a number of students grades based on 
*		report card category subjects that are related to tasks or groups of tasks in the table that holds the task. This function
*		also reports the average for a reporrt card task achieved by a student, as well as, the letter grade and the range that that
*		grade represents. 
* @param	studentId - INTEGER - optional
* @param	evaluationDateFrom - DATE - optional
* @param	evaluationDateTo - DATE - optional
* @examples
*		SELECT * FROM report_card(101);
*
*		SELECT * FROM report_card();
*
*		SELECT * FROM report_card(0,'1990-01-01','2016-01-01');
*
*		SELECT * FROM report_card(102,'1990-01-01','2016-01-01');
*
* @note:        to drop/delete the function - DROP FUNCTION report_card(integer, date, date);
*/

CREATE OR REPLACE FUNCTION report_card(studentId INTEGER DEFAULT 0, evaluationDateFrom DATE DEFAULT NULL, evaluationDateTo DATE DEFAULT NULL) 

	/* results will be returned in the form of the following table */
	RETURNS TABLE("student" TEXT,
		"teacher" TEXT,
		"subjectName" VARCHAR(256),
		"reportCardCategoryName" VARCHAR(256),
		"task_average" NUMERIC, 
		"rangeBottom" SMALLINT,
		"rangeTop" SMALLINT,
		"letterGrade" VARCHAR(256)) 

AS $BODY$

  BEGIN

 	/* 
		temp_average_task_evaluation
		
		create a temporary table to store a students average for a given reprot card category
		which may represent 1 to many task, and by extension, 1 to many task evaluations.
		
	*/
	CREATE TEMPORARY TABLE temp_average_task_evaluation ON COMMIT DROP AS
	SELECT  
		"tblStudents"."lastName" || ', ' || "tblStudents"."firstName" AS "student",
		"tblStaff"."lastName" || ', ' || "tblStaff"."firstName" AS "teacher",
		round(avg("tblEvaluations"."evaluationValue")) AS "task_average", 
		"tblTasks"."reportCardCategoryId", 
		"tblReportCardCategories"."reportCardCategoryName",
		"tblSubjects"."subjectName"	
		
		FROM "tblTaskEvaluations" INNER JOIN "tblEvaluations" ON "tblTaskEvaluations"."evaluationId" = "tblEvaluations"."evaluationId" 
					INNER JOIN "tblTasks" ON "tblTaskEvaluations"."taskId" = "tblTasks"."taskId" 
					INNER JOIN "tblReportCardCategories" ON "tblTasks"."reportCardCategoryId" = "tblReportCardCategories"."reportCardCategoryId"
					INNER JOIN "tblSubjectCategories" ON "tblTasks"."subjectCategoryId" = "tblSubjectCategories"."subjectCategoryId"
					INNER JOIN "tblSubjects" ON "tblSubjectCategories"."subjectId" = "tblSubjects"."subjectId"
					INNER JOIN "tblStudents" ON "tblTaskEvaluations"."studentId" = "tblStudents"."studentId"
					INNER JOIN "tblStaff" ON "tblTaskEvaluations"."staffId" = "tblStaff"."staffId"
						
		WHERE  "tblTaskEvaluations"."evaluationTypeId" = 'EV'
		
		/* 
			  use the CASE to check if a studentId has been passed, 
				if so, use the studentId in the where clause  
				if not, where the field to itself
		*/
		AND  "tblTaskEvaluations"."studentId" = CASE WHEN studentId = 0 THEN "tblTaskEvaluations"."studentId" ELSE studentId END 


		/* 
			  use the CASE to check if TO and FROM dates have been passed, 
				if so, use the TO and FROM dates in the where clause  
				if not, where the field to itself
		*/
		AND "tblTaskEvaluations"."evaluationDate" >= CASE WHEN evaluationDateFrom IS NULL THEN "tblTaskEvaluations"."evaluationDate" ELSE evaluationDateFrom END
		AND "tblTaskEvaluations"."evaluationDate" <= CASE WHEN evaluationDateTo IS NULL THEN "tblTaskEvaluations"."evaluationDate" ELSE evaluationDateTo END
		
		GROUP BY   "tblTasks"."reportCardCategoryId", "tblReportCardCategories"."reportCardCategoryName","tblSubjects"."subjectId" ,"tblSubjects"."subjectName", "student", "teacher";

		/* 
			Return Statement (RETURN QUERY)
			
			This part of the function returns to the caller the avaerage as well as the letter grade and
			the range the letter represents. It does this by INNER JOINing the task average to the letter
			grade bottom and top range, creating an INNER JOIN BETWEEN statement.
			
		*/

		/* this signifies that the result of this statement will be returned in the in the table/recordset for the function */
		RETURN QUERY

		SELECT   
			temp_average_task_evaluation."student", 
			temp_average_task_evaluation."teacher", 
			temp_average_task_evaluation."subjectName",
			temp_average_task_evaluation."reportCardCategoryName",
			temp_average_task_evaluation.task_average, 
			"tblReportCardGrades"."rangeBottom", 
			"tblReportCardGrades"."rangeTop",
			"tblReportCardGrades"."gradeLetter"  
		FROM temp_average_task_evaluation

		/*
			INNER JOIN the task average to the grade bottom and top range, creating an INNER JOIN BETWEEN statement.
			
		*/
		INNER JOIN "tblReportCardGrades" ON temp_average_task_evaluation.task_average >= "tblReportCardGrades"."rangeBottom"
						AND temp_average_task_evaluation.task_average <= "tblReportCardGrades"."rangeTop"

		ORDER BY temp_average_task_evaluation."student", temp_average_task_evaluation."subjectName",task_average;
						
  END;
  $BODY$
LANGUAGE 'plpgsql';
