/*
* @author: 	A. Paul Massardo
* @date:	2015/03/24
* @title	report_student_attendance
* @description	This function returns a recordset/table that represents an student(s) absences and lates. It returns a not only the name
*		but also the student id for further querying.
* @param	studentId - INTEGER - optional
* @param	attendanceDateFrom - DATE - optional
* @param	attendanceDateTo - DATE - optional
* @examples
*		SELECT * FROM report_student_attendance();
*		SELECT * FROM report_student_attendance(101);
*		SELECT * FROM report_student_attendance(NULL,'1900-01-01', '2020-01-01');
* 
* @note:        to drop/delete the function - DROP FUNCTION IF EXISTS report_student_attendance(integer, date, date);
*/

CREATE OR REPLACE FUNCTION report_student_attendance(studentId INTEGER DEFAULT NULL,attendanceDateFrom DATE DEFAULT NULL, attendanceDateTo DATE DEFAULT NULL)

  /* results will be returned in the form of the following table */
  RETURNS TABLE(
		"absentCount" SMALLINT,
		"lateCount" SMALLINT,
		"age" FLOAT,
		"student" TEXT,
		"studentId" INTEGER
				
)    

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
		AND "tblAttendance"."attendanceDate" >= CASE WHEN attendanceDateFrom IS NULL THEN "tblAttendance"."attendanceDate" ELSE attendanceDateFrom END
		AND "tblAttendance"."attendanceDate" <= CASE WHEN attendanceDateTo IS NULL THEN "tblAttendance"."attendanceDate" ELSE attendanceDateTo END
		AND "tblAttendance"."studentId" = CASE WHEN studentId IS NULL THEN "tblAttendance"."studentId" ELSE studentId END  
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
		AND "tblAttendance"."attendanceDate" >= CASE WHEN attendanceDateFrom IS NULL THEN "tblAttendance"."attendanceDate" ELSE attendanceDateFrom END
		AND "tblAttendance"."attendanceDate" <= CASE WHEN attendanceDateTo IS NULL THEN "tblAttendance"."attendanceDate" ELSE attendanceDateTo END
		AND "tblAttendance"."studentId" = CASE WHEN studentId IS NULL THEN "tblAttendance"."studentId" ELSE studentId END  

		GROUP BY "tblAttendance"."studentId";		
		
	/* create a unique index to improve performance */
	CREATE UNIQUE INDEX count_late_temp_table_idx ON count_late_temp_table ("studentId");


	/*
		Return Statement (RETURN QUERY)

		The following returns the student's id, name, age, number of lates and absences. There is no WHERE clause because the WHERE's have been fired on the
		temp tables. The result is ordered by the student's absences, lates, ages, and name. 


	*/
	RETURN QUERY SELECT 
		count_absent_temp_table."absentCount"::SMALLINT AS "absentCount",
		count_late_temp_table."lateCount"::SMALLINT AS "lateCount",
		date_part('year',age("tblStudents"."dateOfBirth")) AS "age",
		"tblStudents"."lastName" || ', ' || "tblStudents"."firstName" AS "student",
		"tblStudents" ."studentId"
		 
		FROM "tblStudents" 
			INNER JOIN count_late_temp_table ON "tblStudents"."studentId" =	count_late_temp_table."studentId" 				
			INNER JOIN count_absent_temp_table ON "tblStudents"."studentId" = count_absent_temp_table."studentId" 

		--ORDER BY 1 DESC,2 DESC,3 DESC,4 DESC;
		ORDER BY "absentCount" DESC,"lateCount" DESC,"age" DESC, "student" ASC;

END;
$BODY$  LANGUAGE plpgsql;


	