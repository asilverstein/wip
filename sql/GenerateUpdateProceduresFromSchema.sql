DROP TABLE IF EXISTS #ColumnTemp;
DROP TABLE IF EXISTS #ResultsTemp;
GO
SET NOCOUNT ON;
GO
SELECT 
	c.TABLE_SCHEMA, 
	c.TABLE_NAME, 
	c.COLUMN_NAME,	
	CONCAT(
		'@', 
		c.COLUMN_NAME, 
		' ', 
		c.DATA_TYPE, 
		IIF(c.CHARACTER_MAXIMUM_LENGTH IS NOT NULL, 
			CONCAT('(', IIF(c.CHARACTER_MAXIMUM_LENGTH = -1, 'max', CAST(c.CHARACTER_MAXIMUM_LENGTH AS NVARCHAR(10))), ')'), 
			IIF(c.DATA_TYPE NOT IN ('int', 'bigint') AND c.NUMERIC_PRECISION_RADIX IS NOT NULL, 
				CONCAT('(', c.NUMERIC_PRECISION, ',', c.NUMERIC_SCALE, ')'
			), '')
		)
	) 
	AS ParameterDefinition,
	IIF(c.COLUMN_NAME = CONCAT(c.TABLE_NAME, 'Id'), 1, 0) AS IsKeyColumn,
	c.ORDINAL_POSITION,
	CONCAT('[', c.COLUMN_NAME, '] = IIF(@', c.COLUMN_NAME, ' IS NULL, [', c.COLUMN_NAME, '], @', c.COLUMN_NAME, ')') AS Patch
INTO #ColumnTemp
FROM INFORMATION_SCHEMA.COLUMNS c
WHERE c.TABLE_SCHEMA NOT IN ('sys')
AND OBJECTPROPERTY(OBJECT_ID(CONCAT('[', TABLE_SCHEMA, '].[', TABLE_NAME, ']')), 'IsView') = 0
AND COLUMNPROPERTY(OBJECT_ID(CONCAT('[',TABLE_SCHEMA, '].[', TABLE_NAME, ']')),COLUMN_NAME, 'IsComputed') = 0
ORDER BY c.TABLE_SCHEMA, c.TABLE_NAME, c.ORDINAL_POSITION;

CREATE TABLE #ResultsTemp (SchemaName sysname NOT NULL, TableName sysname NOT NULL, GeneratedSql NVARCHAR(MAX));

DECLARE @sql NVARCHAR(max) = '', @schemaName sysname, @tableName sysname, 
@columnName sysname, @parameterDef NVARCHAR(max), @isKey BIT, @ordPos INT, @marker NVARCHAR(max) = CONCAT(CHAR(10), ''), 
@maxOrdPos INT, @tab NVARCHAR(1) = CHAR(9), @keyColumnName NVARCHAR(max), @patch NVARCHAR(max), @patchAgg NVARCHAR(max),
@patchMarker NVARCHAR(4000);

DECLARE ColumnCursor CURSOR FOR 
	SELECT *
	FROM #ColumnTemp c
	ORDER BY c.TABLE_SCHEMA, c.TABLE_NAME, c.ORDINAL_POSITION;

OPEN ColumnCursor;

FETCH NEXT FROM ColumnCursor INTO @schemaName, @tableName, @columnName, @parameterDef, @isKey, @ordPos, @patch;

DECLARE @now DATE = CAST(GETDATE() AS DATE);

SET @sql = CONCAT('DROP PROC IF EXISTS [', @schemaName, '].[', @tableName, 'Patch]', @marker, 'GO', @marker, '-- AUTO-GENERATED ', @now, ' - DO NOT MODIFY - ALL CHANGES WILL BE LOST --', @marker, 'CREATE PROC [', @schemaName, '].[', @tableName, 'Patch]', @marker, '(');

WHILE @@FETCH_STATUS = 0
BEGIN
	SELECT @maxOrdPos = MAX(ORDINAL_POSITION) FROM #ColumnTemp WHERE TABLE_NAME = @tableName;
	SELECT @keyColumnName = COLUMN_NAME FROM #ColumnTemp WHERE TABLE_NAME = @tableName AND IsKeyColumn = 1;

	SET @sql = @sql + CONCAT(@marker, @tab, @parameterDef, IIF(@isKey = 1, '', ' = NULL'), ', ');	

	IF @ordPos = @maxOrdPos
	BEGIN
		SET @sql = SUBSTRING(@sql, 0, LEN(@sql));
		SET @sql = CONCAT(@sql, @marker, ')', @marker, 'AS', @marker, 'BEGIN');
		SET @sql = CONCAT(@sql, @marker, @tab, 'UPDATE [', @schemaName, '].[', @tableName, ']');

		SELECT @patchMarker = CONCAT(', ', @marker, @tab, @tab);

		SELECT @patchAgg = STRING_AGG(Patch, @patchMarker)
		FROM #ColumnTemp 
		WHERE TABLE_NAME = @tableName 
		AND IsKeyColumn = 0;

		SET @sql = CONCAT(@sql, @marker, @tab, 'SET ', @patchAgg);
		SET @sql = CONCAT(@sql, @marker, @tab, 'WHERE [', @keyColumnName, '] = @', @keyColumnName, ';', @marker);
		SET @sql = CONCAT(@sql, @marker, 'END;', @marker, 'GO', @marker);

		INSERT INTO #ResultsTemp
		SELECT @schemaName, @tableName, @sql;

		PRINT CAST(@sql AS NTEXT);

		FETCH NEXT FROM ColumnCursor INTO @schemaName, @tableName, @columnName, @parameterDef, @isKey, @ordPos, @patch;

		SET @sql = CONCAT('DROP PROC IF EXISTS [', @schemaName, '].[', @tableName, 'Patch]', @marker, 'GO', @marker, '-- AUTO-GENERATED ', @now, ' - DO NOT MODIFY - ALL CHANGES WILL BE LOST --', @marker, 'CREATE PROC [', @schemaName, '].[', @tableName, 'Patch]', @marker, '(');
	END
	ELSE 
	BEGIN
		FETCH NEXT FROM ColumnCursor INTO @schemaName, @tableName, @columnName, @parameterDef, @isKey, @ordPos, @patch;
	END;	
END;

CLOSE ColumnCursor;
DEALLOCATE ColumnCursor;
GO
DROP TABLE IF EXISTS #ColumnTemp;
GO
SELECT *
FROM #ResultsTemp
ORDER BY SchemaName, TableName;
GO
DROP TABLE IF EXISTS #ResultsTemp;
