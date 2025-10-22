-- Library System Management SQL Project

-- CREATE DATABASE library_system_project2;

-- Create table "Branch"
DROP TABLE IF EXISTS branch;
CREATE TABLE branch
(
            branch_id VARCHAR(10) PRIMARY KEY,
            manager_id VARCHAR(10),
            branch_address VARCHAR(30),
            contact_no VARCHAR(15)
);


-- Create table "Employee"
DROP TABLE IF EXISTS employees;
CREATE TABLE employees
(
            emp_id VARCHAR(10) PRIMARY KEY,
            emp_name VARCHAR(30),
            position VARCHAR(30),
            salary DECIMAL(10,2),
            branch_id VARCHAR(10),
            FOREIGN KEY (branch_id) REFERENCES  branch(branch_id)
);


-- Create table "Members"
DROP TABLE IF EXISTS members;
CREATE TABLE members
(
            member_id VARCHAR(10) PRIMARY KEY,
            member_name VARCHAR(30),
            member_address VARCHAR(30),
            reg_date DATE
);



-- Create table "Books"
DROP TABLE IF EXISTS books;
CREATE TABLE books
(
            isbn VARCHAR(50) PRIMARY KEY,
            book_title VARCHAR(80),
            category VARCHAR(30),
            rental_price DECIMAL(10,2),
            status VARCHAR(10),
            author VARCHAR(30),
            publisher VARCHAR(30)
);



-- Create table "IssueStatus"
DROP TABLE IF EXISTS issued_status;
CREATE TABLE issued_status
(
            issued_id VARCHAR(10) PRIMARY KEY,
            issued_member_id VARCHAR(30),
            issued_book_name VARCHAR(80),
            issued_date DATE,
            issued_book_isbn VARCHAR(50),
            issued_emp_id VARCHAR(10),
            FOREIGN KEY (issued_member_id) REFERENCES members(member_id),
            FOREIGN KEY (issued_emp_id) REFERENCES employees(emp_id),
            FOREIGN KEY (issued_book_isbn) REFERENCES books(isbn) 
);



-- Create table "Return_Status"
DROP TABLE IF EXISTS return_status;
CREATE TABLE return_status
(
            return_id VARCHAR(10) PRIMARY KEY,
            issued_id VARCHAR(30),
            return_book_name VARCHAR(80),
            return_date DATE,
            return_book_isbn VARCHAR(50),
            FOREIGN KEY (return_book_isbn) REFERENCES books(isbn)
);



-- PROJECT TASK
/* Task 1. Create a Table of Books with Rental Price Above a Certain Threshold 7usd */

CREATE TABLE rental_prive_above_threshold
AS
SELECT *
FROM books
WHERE rental_price >= 7;

    
/* Task 2: Identify Members with Overdue Books
Write a query to identify members who have overdue books (assume a 30-day return period). Display the member's name, book title, issue date, and days overdue.
*/

SELECT m.member_id,
	m.member_name,
	ist.issued_book_name,
    ist.issued_date,
    r.return_date,
    (CURRENT_DATE() - ist.issued_date) AS overdue_days
FROM issued_status ist
JOIN members m
	ON m.member_id = ist.issued_member_id
JOIN books bk
	ON bk.isbn = ist.issued_book_isbn
LEFT JOIN return_status r
	ON r.issued_id = ist.issued_id
WHERE r.return_date IS NULL
	AND (CURRENT_DATE() - ist.issued_date)  > 30
ORDER BY 1;



/* Task 3: Update Book Status on Return
Write a query to update the status of books in the books table to "available" when they are returned (based on entries in the return_status table).*/

DROP PROCEDURE IF EXISTS add_return_books;
DELIMITER $$
CREATE PROCEDURE add_return_books (p_return_id VARCHAR(10), p_issued_id VARCHAR(30), p_book_quality VARCHAR(10))

BEGIN
	DECLARE 
			v_isbn VARCHAR(50);
            
	INSERT INTO return_status(return_id, issued_id, return_date, book_quality)
    VALUES (p_return_id, p_issued_id, CURRENT_DATE, p_book_quality);
    
    SELECT issued_book_isbn
			INTO v_isbn
	FROM issued_status
    WHERE issued_id = p_issued_id;
            
    UPDATE books
    SET status = 'Yes'
    WHERE isbn = v_isbn;

END $$
DELIMITER ;

CALL add_return_books ('RS125', 'IS136', 'Good');


-- Testing Functions
SELECT *
FROM issued_status
;

SELECT *
FROM books
WHERE isbn = '978-0-7432-7357-1';

SELECT *
FROM return_status
;


/* Task 4: Branch Performance Report
Create a query that generates a performance report for each branch, showing the number of books issued, the number of books returned, and the total revenue generated from book rentals.
*/

CREATE TABLE branch_report
AS
SELECT br.branch_id,
		COUNT(ist.issued_id) AS number_of_books_issued,
        COUNT(r.return_id) AS number_of_book_return,
        SUM(bk.rental_price) AS total_revenue_rental
FROM issued_status ist
JOIN books bk
	ON bk.isbn = ist.issued_book_isbn
JOIN employees e
	ON e.emp_id = ist.issued_emp_id
LEFT JOIN return_status r
	ON ist.issued_id = r.issued_id
LEFT JOIN branch br
	ON br.branch_id = e.branch_id
GROUP BY 1;


SELECT *
FROM branch_report;



/* Task 5: CTAS: Create a Table of Active Members
Use the CREATE TABLE AS (CTAS) statement to create a new table active_members containing members who have issued at least one book in the last 6 months.
*/

DROP TABLE IF EXISTS active_members;

CREATE TABLE active_members
AS
SELECT member_id,
	issued_id,
    number_of_books_issued,
    issued_date
FROM
(
SELECT m.member_id,
	ist.issued_id,
	COUNT(ist.issued_book_name) AS number_of_books_issued,
    ist.issued_date,
    ist.issued_date > CURRENT_DATE - INTERVAL 6 MONTH AS month_issued
FROM issued_status ist
JOIN members m 
	ON m.member_id = ist.issued_member_id
GROUP BY 1,2
) t1
WHERE month_issued = 1
;

SELECT *
FROM active_members;


/* Task 6: Find Employees with the Most Book Issues Processed
Write a query to find the top 3 employees who have processed the most book issues. Display the employee name, number of books processed, and their branch.
*/

SELECT e.emp_id,
	e.branch_id,
	e.emp_name,
    COUNT(ist.issued_book_name) AS number_of_book_issued
FROM issued_status ist
JOIN employees e
	ON ist.issued_emp_id = e.emp_id
GROUP BY 1
ORDER BY COUNT(ist.issued_book_name) DESC
LIMIT 3;



/* Task 7: Identify Members Issuing High-Risk Books
Write a query to identify members who have issued books more than twice with the status "damaged" in the books table. Display the member name, book title, and the number of times they've issued damaged books.    
*/

SELECT *
FROM issued_status ist
JOIN books bk
	ON ist.issued_book_isbn = bk.isbn
JOIN return_status r
	ON ist.issued_id = r.issued_id
WHERE r.book_quality = 'Damaged'
;

SELECT *
FROM members;


/* Task 8: Stored Procedure 
Objective: Create a stored procedure to manage the status of books in a library system.
    Description: Write a stored procedure that updates the status of a book based on its issuance or return. Specifically:
    If a book is issued, the status should change to 'no'.
    If a book is returned, the status should change to 'yes'.
*/
 
DROP PROCEDURE IF EXISTS book_status_update;    

DELIMITER $$
CREATE PROCEDURE book_status_update (p_issued_id VARCHAR(10), p_issued_member_id VARCHAR(30), p_issued_date DATE, p_issued_book_isbn VARCHAR(50), p_issued_emp_id VARCHAR(10))
BEGIN
	DECLARE v_status VARCHAR(10);
    -- checking for the status of the book
    SELECT status
		INTO
        v_status
    FROM books
    WHERE isbn = p_issued_book_isbn;
    
    IF v_status = 'yes' THEN 
			INSERT INTO issued_status (issued_id, issued_member_id, issued_date, issued_book_isbn, issued_emp_id)
            VALUES (p_issued_id, p_issued_member_id, CURRENT_DATE, p_issued_book_isbn, p_issued_emp_id);
            
            UPDATE books
            SET status = 'No'
			WHERE isbn = p_issued_book_isbn;
    ELSE 
			SELECT 'Action completed successfully' AS notice;
    END IF;
END $$
DELIMITER ;    

call book_status_update('IS156', 'C105', CURRENT_DATE, '978-0-06-112008-4', 'E105');

-- Testing the procedures
SELECT *
FROM issued_status;

SELECT *
FROM books
WHERE isbn = '978-0-06-112008-4';



/* Task 9: 
Description: Write a CTAS query to create a new table that lists each member and the books they have issued but not returned within 30 days. The table should include:
    The number of overdue books.
    The total fines, with each day's fine calculated at $0.50.
    The number of books issued by each member.
    The resulting table should show:
    Member ID
    Number of overdue books
    Total fines
*/

CREATE TABLE overdue_books_fines
AS
SELECT issued_member_id,
	CURRENT_DATE - DATE(issued_date) AS days_overdue,
	COUNT(ist.issued_book_isbn) AS no_of_overdue_books,
    (CURRENT_DATE - DATE(issued_date)) * 0.50 AS total_fines
FROM issued_status ist
LEFT JOIN return_status r
	ON r.issued_id = ist.issued_id
WHERE return_id IS NULL
AND issued_date > CURRENT_DATE - INTERVAL 60 DAY
GROUP BY 1, 2, 4;
