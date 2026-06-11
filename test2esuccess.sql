CREATE TABLE Employees ( 
    emp_id int, 
    salary float,
    first_name varchar(50)
);

SELECT first_name 
FROM Employees 
WHERE emp_id = 100 
  AND salary >= 1500.50 
  AND first_name IN ('John', 'Maria');