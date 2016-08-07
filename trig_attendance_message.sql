/*
* @author: 	A. Paul Massardo
* @date:	2015/02/24
* @title	attendance_message
* @description	This function/trigger insert or update records into the messages tables to send messages to the administration staff
*		when a tblAttendance table is updated. This is triggered by the person saving the record setting flagAdministrator
*		to true. Before the trigger/function is complete it will set the flagAdministrator to false.
* @examples
*		INSERT INTO "tblAttendance"("studentId", "staffId", "attendanceDate", "attendanceStatusId","note","flagAdministrator") VALUES (101, 101, '2015-03-18', 1,'TESTNOTEINSERT',true);
*
*		UPDATE "tblAttendance" SET "note" = 'TESTNOTEUPDATE', "flagAdministrator" = 't' WHERE "note" = 'TESTNOTEINSERT'
*
*		--DELETE FROM "tblAttendance" WHERE "note" = 'TESTNOTEUPDATE'
*
* @note:        to drop/delete the function - DROP TRIGGER IF EXISTS trigger_insert_messsage_from_attendance_message ON "tblAttendance" ;
* @note:        to drop/delete the function - DROP FUNCTION insert_messsage_from_attendance();
*

SELECT * FROM "tblAttendance"
SELECT * FROM "tblMessages"

*/

CREATE OR REPLACE FUNCTION insert_messsage_from_attendance()
  RETURNS trigger AS
$BODY$

DECLARE

	Id int;
	t2_row "tblUsers"%ROWTYPE;

BEGIN
	/*
		if the flagAdministrator is set to true then the person
		saving this record intended to send this data to all the
		administrator staff
	*/
	IF NEW."flagAdministrator" = 't' THEN
		INSERT INTO  "tblMessages" ("senderUserId","text")
			VALUES ((SELECT "tblStaff"."userId" FROM "tblStaff" WHERE "tblStaff"."staffId" = NEW."staffId") ,
				(SELECT 'Teacher-' || "tblStaff"."lastName" || '/' || "tblStaff"."firstName" FROM "tblStaff" where "tblStaff"."staffId"= NEW."staffId") || ' - ' ||
					(SELECT 'Student-' || "tblStudents"."lastName" || '/' || "tblStudents"."firstName" FROM "tblStudents" where "tblStudents"."studentId"= NEW."studentId") || ' - ' || NEW."note") RETURNING "messageId" INTO Id;


		/* resets the flag before the update is complete */
		/* so this will always be false in the database */
		NEW."flagAdministrator" = 'f';
	END IF;

	/* insert a user message for each administrator in the database */
	INSERT INTO "tblUserMessages" ("messageId","recipientUserId") SELECT Id, "tblUsers"."userId"  FROM "tblUsers" WHERE "tblUsers"."userType" = 'A';

	RETURN NEW;
END;
$BODY$ LANGUAGE plpgsql;

/* Trigger for the function above */
CREATE TRIGGER trigger_insert_messsage_from_attendance_message
	BEFORE UPDATE OR INSERT
	ON "tblAttendance"
	FOR EACH ROW
	WHEN (NEW."flagAdministrator" = 't')
	EXECUTE PROCEDURE insert_messsage_from_attendance();
