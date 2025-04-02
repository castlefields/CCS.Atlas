/****** Object:  StoredProcedure [dbo].[rpt_get_facilities_for_report]    Script Date: 01/04/2025 21:40:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[rpt_get_facilities_for_report]
    @facility_used_by_id UNIQUEIDENTIFIER = NULL,
    @report_group_id UNIQUEIDENTIFIER = NULL
AS
BEGIN
    -- This procedure selects the facilities to include in the report based on parameters

    IF @report_group_id IS NOT NULL
    BEGIN
        -- When using report_group_id, list all facilities in that group
        SELECT DISTINCT 
            facility_used_by_id, 
            facility_used_by_trading_style AS facility_used_by_name
        FROM dbo.account
        WHERE facility_used_by_report_group_id = @report_group_id
        ORDER BY facility_used_by_trading_style;
        
        -- Check if any facilities were found for this report_group_id
        IF @@ROWCOUNT = 0
        BEGIN
            -- If no facilities found, use a default placeholder
            SELECT NULL AS facility_used_by_id, 'Unknown Group' AS facility_used_by_name;
        END
    END
    ELSE
    BEGIN
        -- When not using report_group_id, create a single facility entry
        DECLARE @report_name NVARCHAR(255);
        
        -- Fetch the appropriate report_name based on facility_used_by_id 
        SELECT TOP 1
            @report_name = 
                COALESCE(
                    CASE 
                        WHEN @facility_used_by_id IS NOT NULL THEN facility_used_by_legal_name
                        ELSE 'Consumer Credit Solutions'
                    END, 
                    'Consumer Credit Solutions'
                )
        FROM dbo.account
        WHERE (@facility_used_by_id IS NULL OR facility_used_by_id = @facility_used_by_id);
        
        -- Ensure @report_name is not NULL
        IF @report_name IS NULL
            SET @report_name = 'Consumer Credit Solutions';
        
        -- Return the facility information
        SELECT @facility_used_by_id AS facility_used_by_id, @report_name AS facility_used_by_name;
    END
END;