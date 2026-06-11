CREATE TABLE Customers ( 
    cust_id int, 
    name varchar(50) 
);
CREATE TABLE Orders ( 
    order_id int, 
    cust_id int, 
    total float 
);

SELECT c.name, o.total
FROM Customers AS c
JOIN Orders AS o ON c.cust_id = o.cust_id
WHERE o.total > 50.0;