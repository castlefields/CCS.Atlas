ALTER PROCEDURE [dbo].[rpt_user_notification]
    @user_email NVARCHAR(255) = NULL,
    @can_run bit = false
AS
BEGIN
    IF (@can_run = 1)
    BEGIN
        DECLARE @row_count int = (Select count(1)
        FROM dbo.crm_user_notification AS un
            LEFT OUTER JOIN dbo.crm_user AS u
            ON un.crm_user_id = u.crm_user_id
        WHERE u.email = @user_email
            AND un.scheduled_end < GETDATE()
            AND un.actual_end IS NULL
            AND un.activity_type IS NOT NULL
            AND un.regarding IS NOT NULL
            AND un.regarding <> '')
        -- Added this condition to check for empty strings too

        if(@row_count > 0)
			select 1;
		else
			select 0;
    END

	ELSE

	BEGIN

        IF (@user_email IS NULL)
		BEGIN
            SELECT TOP (100) PERCENT
                un.scheduled_end,
                CONVERT(VARCHAR, un.scheduled_end, 103) AS scheduled_end_date,
                CASE un.activity_type 
					WHEN 'cal_internalactions' THEN 'Internal Actions' 
					WHEN 'cal_externalactions' THEN 'External Actions' 
					WHEN 'cal_action' THEN 'Action' 
					WHEN 'phonecall' THEN 'Phone Call' 
					WHEN 'appointment' THEN 'Appointment'
					WHEN 'email' THEN 'Email' 
					WHEN 'cal_documentactivity' THEN 'Document Activity' 
					WHEN 'task' THEN 'Task' 
					ELSE 'Not Found' 
				END AS activity_type,
                un.subject,
                un.regarding,
                un.link,
                u.initials,
                u.name
            FROM dbo.crm_user_notification AS un
                LEFT OUTER JOIN dbo.crm_user AS u
                ON un.crm_user_id = u.crm_user_id
            WHERE un.scheduled_end < GETDATE()
                AND un.actual_end IS NULL
                AND un.activity_type IS NOT NULL
                AND un.regarding IS NOT NULL
                AND un.regarding <> ''
            -- Added this condition to check for empty strings too
            ORDER BY un.scheduled_end;
        END
		ELSE
		BEGIN
            SELECT TOP (100) PERCENT
                un.scheduled_end,
                CONVERT(VARCHAR, un.scheduled_end, 103) AS scheduled_end_date,
                CASE un.activity_type 
					WHEN 'cal_internalactions' THEN 'Internal Actions' 
					WHEN 'cal_externalactions' THEN 'External Actions' 
					WHEN 'cal_action' THEN 'Action' 
					WHEN 'phonecall' THEN 'Phone Call' 
					WHEN 'appointment' THEN 'Appointment'
					WHEN 'email' THEN 'Email' 
					WHEN 'cal_documentactivity' THEN 'Document Activity' 
					WHEN 'task' THEN 'Task' 
					ELSE 'Not Found' 
				END AS activity_type,
                un.subject,
                un.regarding,
                un.link,
                u.initials,
                u.name
            FROM dbo.crm_user_notification AS un
                LEFT OUTER JOIN dbo.crm_user AS u
                ON un.crm_user_id = u.crm_user_id
            WHERE u.email = @user_email
                AND un.scheduled_end < GETDATE()
                AND un.actual_end IS NULL
                AND un.activity_type IS NOT NULL
                AND un.regarding IS NOT NULL
                AND un.regarding <> ''
            -- Added this condition to check for empty strings too
            ORDER BY un.scheduled_end;
        END
    END;
END