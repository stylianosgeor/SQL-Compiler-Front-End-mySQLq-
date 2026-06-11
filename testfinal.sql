CREATE TABLE Customers ( cust_id int, name varchar(50) );
CREATE TABLE Orders ( order_id int, cust_id int, total float );
CREATE TABLE Employees ( 
    emp_id int, 
    salary float,
    first_name varchar(50)
);

SELECT c.name
FROM Customers AS c
ORDER BY c.name
JOIN Orders AS o ON c.cust_id = o.cust_id
JOIN Employees ON emp_id = o.cust_id
WHERE o.total > 50.0 AND c.cust_id IN (1, 2, 3)

LIMIT 10;