/*
* @author: 	A. Paul Massardo
* @date:	2015/02/24
* @title	task_evaluation_message
* @description	This function/trigger insert or update records into the messages tables to send messages to the administration staff
*		when a task evaluation is updated. This is triggered by the person saving the record setting flagAdministrator
*		to true. Before the trigger/function is complete it will set the flagAdministrator to false.
* @examples
*		INSERT INTO "tblTaskEvaluations"("studentId", "staffId", "taskId", "evaluationId","evaluationDate","note", "propertyId", "flagAdministrator","evaluationTypeId") VALUES (101, 101, 1, 'NA','2001-05-24 00:00:00' ,'Test Message Trigger insert', 0,true, 'AS');
*
*		UPDATE "tblTaskEvaluations" SET "evaluationId" = 'MA', "flagAdministrator" = 't' WHERE "studentId" = 101 and "staffId" = 101 and "taskId" = 1 and "evaluationId" = 'NA' and "evaluationDate" = '2001-05-24 00:00:00' and "propertyId" = 0 and "evaluationTypeId" = 'AS'
*
*
* @note:        to drop/delete the function - DROP TRIGGER IF EXISTS trigger_insert_messsage_from_task_evaluation ON "tblTaskEvaluations" ;
*
*/

CREATE OR REPLACE FUNCTION insert_messsage_from_task_evaluation()
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
					(SELECT 'Student-' || "tblStudents"."lastName" || '/' || "tblStudents"."firstName" FROM "tblStudents" where "tblStudents"."studentId"= NEW."studentId") || ' - ' ||
					(SELECT 'Evaluation-' || "tblEvaluations"."evaluationDescription" || '(' || "tblEvaluations"."evaluationValue" || ')' FROM "tblEvaluations" where "tblEvaluations"."evaluationId"= NEW."evaluationId") || ' - ' ||
					(SELECT "taskName" FROM "tblTasks" where "taskId"= NEW."taskId") || ' - ' || NEW."note") RETURNING "messageId" INTO Id;

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
CREATE TRIGGER trigger_insert_messsage_from_task_evaluation
	BEFORE UPDATE OR INSERT
	ON "tblTaskEvaluations"
	FOR EACH ROW
	WHEN (NEW."flagAdministrator" = 't')
	EXECUTE PROCEDURE insert_messsage_from_task_evaluation();
