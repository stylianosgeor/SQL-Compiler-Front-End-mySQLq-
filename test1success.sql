CREATE TABLE Products (
    prod_id int,
    price float
);

SELECT prod_id 
FROM Products 
WHERE price > 10.0 
GROUP BY prod_id 
ORDER BY prod_id 
LIMIT 5;