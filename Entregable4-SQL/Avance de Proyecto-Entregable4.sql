/*

EBAC: Cientifico de Datos
Avance de Proyecto: Empresa Aliada - Entregable 4 (Modulo 42)
Oscar Ian Badillo Velazquez

*/

/* ******************** Creacion de Tablas ******************** */

CREATE TABLE FACT_SALES (
	WEEK VARCHAR(50),
	ITEM_CODE VARCHAR(50),
	TOTAL_UNIT_SALES DECIMAL(10,4),
	TOTAL_VALUE_SALES DECIMAL(10,4),
	TOTAL_UNIT_AVG_WEEKLY_SALES DECIMAL(10,4),
	REGION VARCHAR(255)
);

CREATE TABLE DIM_CALENDAR(
	WEEK VARCHAR(50) PRIMARY KEY,
	YEAR SMALLINT,
	MONTH TINYINT,
	WEEK_NUMBER TINYINT,
	DATE DATE
);

CREATE TABLE DIM_CATEGORY(
	ID_CATEGORY TINYINT PRIMARY KEY,
	CATEGORY VARCHAR(50)
);

CREATE TABLE DIM_PRODUCT(
	MANUFACTURER VARCHAR(100),
	BRAND VARCHAR(100),
	ITEM VARCHAR(255) PRIMARY KEY,
	ITEM_DESCRIPTION VARCHAR(255),
	CATEGORY TINYINT,
	FORMAT VARCHAR(50),
	ATTR1 VARCHAR(100),
	ATTR2 VARCHAR(100),
	ATTR3 VARCHAR(100),
);

CREATE TABLE DIM_SEGMENT (
    CATEGORY TINYINT,
    ATTR1 VARCHAR(100),
    ATTR2 VARCHAR(100),
    ATTR3 VARCHAR(100),
    FORMAT VARCHAR(50),
    SEGMENT VARCHAR(50)
);

/* ******************** Importacion de Datos ******************** */

BULK INSERT FACT_SALES
FROM '/tmp/FACT_SALES.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FIRSTROW = 2
);

BULK INSERT DIM_CATEGORY
FROM '/tmp/DIM_CATEGORY.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FIRSTROW = 2
);

BULK INSERT DIM_CALENDAR
FROM '/tmp/DIM_CALENDAR_fixed.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FIRSTROW = 2
);

BULK INSERT DIM_PRODUCT
FROM '/usr/ProyectoReckittSQL/DIM_PRODUCT.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FIRSTROW = 2
);

ALTER TABLE DIM_PRODUCT DROP CONSTRAINT PK__DIM_PROD__44B08649A1A79F1D;  -- Eliminacion de Primary Key debido a problemas de importacion.

BULK INSERT DIM_SEGMENT
FROM '/usr/ProyectoReckittSQL/DIM_SEGMENT.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FIRSTROW = 2
);

/* ******************** Consultas para comprobar integridad de los datos cargados ******************** */

-- Verificacion de los primeros 5 registros
SELECT TOP 5 * FROM FACT_SALES;
SELECT TOP 5 * FROM DIM_CALENDAR;
SELECT TOP 5 * FROM DIM_CATEGORY;
SELECT TOP 5 * FROM DIM_PRODUCT;
SELECT TOP 5 * FROM DIM_SEGMENT;

-- Total de Registros por Tabla
SELECT 'FACT_SALES' AS Tabla, COUNT(*) AS Registros FROM FACT_SALES
UNION ALL
SELECT 'DIM_CALENDAR', COUNT(*) FROM DIM_CALENDAR
UNION ALL
SELECT 'DIM_CATEGORY', COUNT(*) FROM DIM_CATEGORY
UNION ALL
SELECT 'DIM_PRODUCT', COUNT(*) FROM DIM_PRODUCT
UNION ALL
SELECT 'DIM_SEGMENT', COUNT(*) FROM DIM_SEGMENT;

/* ******************** Insights de las tablas ******************** */

-- Ventas Totales Desglozadas por Region y Semanas de Venta
WITH Sales AS (
				SELECT
				ITEM_CODE,
				SUM(TOTAL_UNIT_SALES) AS TotalSales,
				REGION,
				WEEK
				FROM FACT_SALES
				GROUP BY ITEM_CODE, REGION, WEEK
			)
SELECT dp.ITEM_DESCRIPTION,
		dc.Category,
		s.REGION,
		s.WEEK,
		s.TotalSales
FROM DIM_PRODUCT dp
	INNER JOIN Sales s on dp.ITEM = s.ITEM_CODE
	INNER JOIN DIM_CATEGORY dc ON dp.CATEGORY = dc.ID_CATEGORY
ORDER BY s.REGION, TotalSales DESC;

-- Semana con mas Ventas por Region
WITH SalesByWeekRegion AS (
    SELECT WEEK, 
           REGION, 
           SUM(TOTAL_UNIT_SALES) AS TotalSales
    FROM FACT_SALES
    GROUP BY WEEK, REGION
),
TopWeekByRegion AS (
    SELECT WEEK, 
           REGION, 
           TotalSales,
           ROW_NUMBER() OVER (PARTITION BY REGION ORDER BY TotalSales DESC) AS rn
    FROM SalesByWeekRegion
)
SELECT dp.ITEM_DESCRIPTION,
       dc.CATEGORY,
       fs.REGION,
       fs.WEEK,
       SUM(fs.TOTAL_UNIT_SALES) AS TotalSales
FROM FACT_SALES fs
INNER JOIN TopWeekByRegion tw ON fs.WEEK = tw.WEEK AND fs.REGION = tw.REGION
INNER JOIN DIM_PRODUCT dp ON dp.ITEM = fs.ITEM_CODE
INNER JOIN DIM_CATEGORY dc ON dp.CATEGORY = dc.ID_CATEGORY
WHERE tw.rn = 1
GROUP BY dp.ITEM_DESCRIPTION, dc.CATEGORY, fs.REGION, fs.WEEK
ORDER BY fs.REGION, TotalSales DESC;

-- Ventas Totales por Categoría y Región
SELECT dc.CATEGORY,
       fs.REGION,
       SUM(fs.TOTAL_UNIT_SALES) AS TotalUnits,
       SUM(fs.TOTAL_VALUE_SALES) AS TotalValue
FROM FACT_SALES fs
INNER JOIN DIM_PRODUCT dp ON dp.ITEM = fs.ITEM_CODE
INNER JOIN DIM_CATEGORY dc ON dp.CATEGORY = dc.ID_CATEGORY
GROUP BY dc.CATEGORY, fs.REGION
ORDER BY dc.CATEGORY, TotalValue DESC;

-- Verificacion de Precio Aproximado de Productos para comprension de valores de "TotalSales"
SELECT TOP 10 
    ITEM_CODE,
    TOTAL_UNIT_SALES,
    TOTAL_VALUE_SALES,
    CASE 
        WHEN TOTAL_UNIT_SALES > 0 
        THEN TOTAL_VALUE_SALES / TOTAL_UNIT_SALES 
        ELSE 0 
    END AS PrecioImplicito
FROM FACT_SALES
WHERE TOTAL_UNIT_SALES > 0
ORDER BY TOTAL_UNIT_SALES DESC;