/*
* @author: 	A. Paul Massardo
* @date:	2015/02/24
* @title	task_summary
* @description	This function returns a recordset/table that represents an the average grade a teacher's students have acheived
* @param	staffId - INTEGER - mandatory
* @param	subjectId - INTEGER - optional
* @param	evaluationDateFrom - DATE - optional
* @param	evaluationDateTo - DATE - optional
* @examples
*		SELECT * FROM task_summary(102);
*
* @note:        to drop/delete the function - DROP FUNCTION IF EXISTS task_summary(integer, integer,integer, integer, DATE, DATE);
*/

CREATE OR REPLACE FUNCTION task_summary(staffId INTEGER,subjectId INTEGER DEFAULT 0, evaluationDateFrom DATE DEFAULT NULL, evaluationDateTo DATE DEFAULT NULL)
  RETURNS TABLE
	(
	"teacher" text,
	"gradeLevelName" varchar(256) ,
	"subjectName" varchar(256),
	"taskName" varchar(256),
	"evaluationAverage" numeric,
	"staffId" smallint,
	"subjectId" smallint
	)
  AS $BODY$
  BEGIN
		/*
			max_date_temp_table

			create a temp table to join to the task evaluations to only return the latest (max date)
			records for a particular student.
			Originally done with a subquery, but moved to the temp table join to improve performance.
		*/
		CREATE TEMPORARY TABLE max_date_temp_table ON COMMIT DROP AS
			SELECT max("TE2"."evaluationDate") as "max_date",
				"TE2"."staffId" ,
				"TE2"."studentId",
				"TE2"."taskId"
			FROM "tblTaskEvaluations" AS "TE2"
			WHERE "TE2"."staffId" = staffId
			GROUP BY "TE2"."staffId" ,"TE2"."studentId", "TE2"."taskId";

		/* create a unique index to improve performance */
		CREATE UNIQUE INDEX max_date_temp_table_idx ON max_date_temp_table ("max_date","staffId","studentId","taskId");


		/*
			task_summary_table

			This temp table returns all the the latest task evaluations a teacher has performed and assigned marks.

		*/
		CREATE TEMPORARY TABLE task_summary_table ON COMMIT DROP AS
			SELECT  "tblStaff"."lastName" || ', ' || "tblStaff"."firstName" AS "teacher",
				"tblGradeLevels"."gradeLevelName",
				"tblSubjects"."subjectName",
				"tblTasks"."taskName",
				"tblEvaluations"."evaluationValue",
				"tblStaff"."staffId",
				"tblSubjects"."subjectId"

				FROM "tblTaskEvaluations"
					INNER JOIN "tblEvaluations" ON "tblEvaluations"."evaluationId" = "tblTaskEvaluations"."evaluationId"
					INNER JOIN "tblStaff" ON "tblTaskEvaluations"."staffId" = "tblStaff"."staffId"
					INNER JOIN "tblTasks" ON "tblTaskEvaluations"."taskId" = "tblTasks"."taskId"
					INNER JOIN "tblSubjectCategories" ON "tblTasks"."subjectCategoryId" = "tblSubjectCategories"."subjectCategoryId"
					INNER JOIN "tblSubjects" ON "tblSubjectCategories"."subjectId" = "tblSubjects"."subjectId"
					INNER JOIN "tblStudents" ON "tblStudents"."studentId" = "tblTaskEvaluations"."studentId"
					INNER JOIN "tblGradeLevels" ON "tblSubjects"."gradeLevelId" = "tblGradeLevels"."gradeLevelId"
					INNER JOIN max_date_temp_table ON "tblTaskEvaluations"."evaluationDate" = max_date_temp_table."max_date"
						AND "tblTaskEvaluations"."staffId" = max_date_temp_table."staffId"
						AND "tblTaskEvaluations"."studentId" = max_date_temp_table."studentId"
						AND "tblTaskEvaluations"."taskId" = max_date_temp_table."taskId"

					INNER JOIN "tblStaffStudents" ON "tblTaskEvaluations"."staffId" = "tblStaffStudents"."staffId"
						AND "tblTaskEvaluations"."studentId" = "tblStaffStudents"."studentId"

					WHERE "tblTaskEvaluations"."staffId" = staffId

						/*
							  use the CASE to check if to and from dates have been passed,
								if so, use the to and from dates in the where clause
								if not, where the field to itself
						*/
						AND "tblTaskEvaluations"."evaluationDate" >= CASE WHEN evaluationDateFrom IS NULL THEN "tblTaskEvaluations"."evaluationDate" ELSE evaluationDateFrom END
						AND "tblTaskEvaluations"."evaluationDate" <= CASE WHEN evaluationDateTo IS NULL THEN "tblTaskEvaluations"."evaluationDate" ELSE evaluationDateTo END


						AND "tblSubjectCategories"."subjectId" = CASE WHEN subjectId = 0 THEN "tblSubjectCategories"."subjectId" ELSE subjectId END;

				/*
					Return Statement (RETURN QUERY)

					This select statement returns the aggregate average per subject for the teacher.

				*/
				RETURN QUERY SELECT
					task_summary_table."teacher",
					task_summary_table."gradeLevelName",
					task_summary_table."subjectName",
					task_summary_table."taskName",
					avg(task_summary_table."evaluationValue") AS "evaluationAverage",
					task_summary_table."staffId",
					task_summary_table."subjectId" FROM task_summary_table

				GROUP BY task_summary_table."teacher", task_summary_table."gradeLevelName" , task_summary_table."subjectName", task_summary_table."taskName", task_summary_table."staffId", task_summary_table."subjectId"
				ORDER BY task_summary_table."teacher", task_summary_table."gradeLevelName" , task_summary_table."subjectName",  task_summary_table."taskName";

END;

$BODY$ LANGUAGE plpgsql;
