SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:      <Author, Name>
-- Create Date: <Create Date>
-- Description: Inserts or updates data in the application_month table from JSON input
-- =============================================
ALTER PROCEDURE [dbo].[set_application_month]
    @json NVARCHAR(MAX)
AS
BEGIN
    -- Begin transaction
    BEGIN TRANSACTION

    BEGIN TRY
        -- Extract date and lender_id from the first object in the JSON array		
        DECLARE @date DATE = (SELECT TOP 1 CAST(JSON_VALUE(p.value, '$.date') AS DATE) FROM OPENJSON(@json) AS p)
        DECLARE @lender_id INT = (SELECT TOP 1 CAST(JSON_VALUE(p.value, '$.lender_id') AS INT) FROM OPENJSON(@json) AS p)

        -- Debugging information
        -- PRINT 'Extracted Date: ' + CONVERT(VARCHAR, @date)
        -- PRINT 'Extracted Lender ID: ' + CONVERT(VARCHAR, @lender_id)

        -- If @date or @lender_id are NULL, raise an error
        IF @date IS NULL OR @lender_id IS NULL
        BEGIN
            RAISERROR('Invalid JSON format: Date or Lender ID is missing or incorrect.', 16, 1)
            ROLLBACK TRANSACTION
            RETURN
        END

        -- Delete existing records with the same date and lender_id
        DELETE FROM dbo.application_month
        WHERE [date] = @date AND lender_id = @lender_id

        -- Debugging information
        PRINT 'Deleted existing records.'

        -- Insert data into dbo.application_month table from JSON
        INSERT INTO dbo.application_month (
            [date], 
            branch_id, 
            branch_upload_name, 
            lender_id, 
            [app], 
            [accept], 
            [pending], 
            [decline], 
            [advance]
        )
        SELECT 
            CAST(JSON_VALUE(p.value, '$.date') AS DATE) AS [date],
            JSON_VALUE(p.value, '$.branch_id') AS branch_id, -- NVARCHAR(15)
            JSON_VALUE(p.value, '$.branch_upload_name') AS branch_upload_name, -- NVARCHAR(60)
            CAST(JSON_VALUE(p.value, '$.lender_id') AS INT) AS lender_id,
            CAST(JSON_VALUE(p.value, '$.app') AS INT) AS [app],
            CAST(JSON_VALUE(p.value, '$.accept') AS INT) AS [accept],
            CAST(JSON_VALUE(p.value, '$.pending') AS INT) AS [pending],
            CAST(JSON_VALUE(p.value, '$.decline') AS INT) AS [decline],
            CAST(JSON_VALUE(p.value, '$.advance') AS DECIMAL(9, 2)) AS [advance]
        FROM OPENJSON(@json) AS p

        -- Debugging information
        PRINT 'Inserted new records.'

        -- Commit transaction
        COMMIT TRANSACTION
    END TRY
    BEGIN CATCH
        -- Rollback transaction if an error occurs
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION
        END

        -- Return error information
        DECLARE @ErrorMessage NVARCHAR(4000)
        DECLARE @ErrorSeverity INT
        DECLARE @ErrorState INT

        SELECT 
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE()

        -- Raise the error
        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState)
    END CATCH
END
GO
