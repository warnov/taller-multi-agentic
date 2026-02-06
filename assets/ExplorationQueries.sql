SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
ORDER BY TABLE_NAME;


select * from customerrelationshiptype

select top 10 * from hst_conversations

select * from customer where CustomerId = 'CID-009'


SELECT 
    OrderId,
    OrderNumber,
    OrderDate,
    OrderStatus,
    OrderTotal
FROM Orders
WHERE CustomerId = 'CID-009'
ORDER BY OrderDate DESC;



SELECT TOP 5
    CustomerId,
    COUNT(OrderId) AS NumOrders
FROM Orders
GROUP BY CustomerId
ORDER BY NumOrders DESC;


SELECT pc.CategoryName, SUM(ol.Quantity * ol.UnitPrice) AS TotalSpent FROM Orders o INNER JOIN OrderLine ol ON o.OrderId = ol.OrderId INNER JOIN Product p ON ol.ProductId = p.ProductID INNER JOIN ProductCategory pc ON p.ProductCategoryID = pc.CategoryID WHERE o.CustomerId = 'CID-069' GROUP BY pc.CategoryName ORDER BY TotalSpent DESC;



SELECT
    COALESCE(p.CategoryName, 'Sin categoría') AS CategoryName,
    SUM(
        COALESCE(ol.LineTotal, 0)
        - COALESCE(ol.DiscountAmount, 0)
        + COALESCE(ol.TaxAmount, 0)
    ) AS TotalSpent
FROM orders o
INNER JOIN orderline ol
    ON ol.OrderId = o.OrderId
INNER JOIN product p
    ON p.ProductID = ol.ProductId
WHERE o.CustomerId = 'CID-069'
GROUP BY COALESCE(p.CategoryName, 'Sin categoría')
ORDER BY TotalSpent DESC;


SELECT
    p.CategoryName AS CategoryName,
    SUM(COALESCE(ol.LineTotal, 0)) AS BaseTotalSpent
FROM orders o
INNER JOIN orderline ol
    ON ol.OrderId = o.OrderId
INNER JOIN product p
    ON p.ProductID = ol.ProductId
WHERE o.CustomerId = 'CID-069'
GROUP BY p.CategoryName
ORDER BY BaseTotalSpent DESC;



SELECT
    o.OrderId,
    o.OrderNumber,
    ol.OrderLineNumber,
    ol.ProductId,
    ol.Quantity,
    ol.UnitPrice,
    ol.LineTotal,
    (ol.Quantity * ol.UnitPrice) AS CalcBase,
    (COALESCE(ol.LineTotal, 0) - COALESCE(ol.Quantity, 0) * COALESCE(ol.UnitPrice, 0)) AS Diff,
    p.ProductCategoryID,
    pc.CategoryID,
    pc.CategoryName
FROM Orders o
INNER JOIN OrderLine ol
    ON o.OrderId = ol.OrderId
INNER JOIN Product p
    ON ol.ProductId = p.ProductID
LEFT JOIN ProductCategory pc
    ON p.ProductCategoryID = pc.CategoryID
WHERE o.CustomerId = 'CID-069'
  AND (
        ol.LineTotal IS NULL
        OR ol.Quantity IS NULL
        OR ol.UnitPrice IS NULL
        OR ABS(COALESCE(ol.LineTotal, 0) - (COALESCE(ol.Quantity, 0) * COALESCE(ol.UnitPrice, 0))) > 0.0001
        OR pc.CategoryID IS NULL
      )
ORDER BY ABS(COALESCE(ol.LineTotal, 0) - (COALESCE(ol.Quantity, 0) * COALESCE(ol.UnitPrice, 0))) DESC;
