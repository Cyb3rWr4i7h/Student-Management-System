DROP DATABASE IF EXISTS student_management;

CREATE DATABASE student_management;

USE student_management;

CREATE TABLE students (
    student_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(15),
    date_of_birth DATE,
    enrollment_date DATE NOT NULL,
    major VARCHAR(100) NOT NULL
);

CREATE TABLE courses (
    course_code VARCHAR(10) PRIMARY KEY,
    course_name VARCHAR(100) NOT NULL,
    credits INT NOT NULL,
    department VARCHAR(100),
    semester_offered ENUM('Odd','Even','Both'),
    CONSTRAINT min_credits CHECK (credits > 0)
);


CREATE TABLE grades (
semester INT,
student_id INT,
course_code VARCHAR(10),
grade DECIMAL(3,2),
PRIMARY KEY (student_id,course_code),
FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
FOREIGN KEY (course_code) REFERENCES courses(course_code) ON DELETE CASCADE
);

CREATE TABLE attendance (
    student_id INT NOT NULL,
    course_code VARCHAR(10) NOT NULL,
    date DATE NOT NULL,
    status ENUM('Present', 'Absent') NOT NULL,
	PRIMARY KEY (student_id, course_code, date),
    FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
    FOREIGN KEY (course_code) REFERENCES courses(course_code) ON DELETE CASCADE
);

CREATE TABLE address (
    student_id INT NOT NULL UNIQUE,
    street VARCHAR(100),
    city VARCHAR(50),
    state VARCHAR(50),
    pin_code VARCHAR(10),
    country VARCHAR(50),
    FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE
);

CREATE TABLE emergency_contacts (
    contact_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT NOT NULL,
    contact_name VARCHAR(100) NOT NULL,
    relationship VARCHAR(50) NOT NULL,
    phone VARCHAR(15) NOT NULL,
    email VARCHAR(100),
    FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE
);

CREATE TABLE professors (
    professor_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(15),
    department VARCHAR(100)
);

CREATE TABLE teaching_assistants (
    ta_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(15),
    associated_professor_id INT,
    FOREIGN KEY (associated_professor_id) REFERENCES professors(professor_id) ON DELETE SET NULL
);

CREATE TABLE departments (
    department_id INT AUTO_INCREMENT PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL UNIQUE,
    department_head INT,
    FOREIGN KEY (department_head) REFERENCES professors(professor_id) ON DELETE SET NULL
);

ALTER TABLE professors
ADD department_id INT,
ADD FOREIGN KEY (department_id) REFERENCES departments(department_id) ON DELETE SET NULL;

ALTER TABLE courses
ADD department_id INT,
ADD FOREIGN KEY (department_id) REFERENCES departments(department_id) ON DELETE SET NULL;

CREATE TABLE fees (
    fee_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    due_date DATE,
    status ENUM('Paid', 'Pending', 'Overdue') NOT NULL,
    FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE
);

CREATE TABLE library (
    book_id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    author VARCHAR(100),
    isbn VARCHAR(20) UNIQUE,
    available_copies INT NOT NULL
);

CREATE TABLE book_issue (
    issue_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT NOT NULL,
    book_id INT NOT NULL,
    issue_date DATE NOT NULL,
    return_date DATE,
    FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
    FOREIGN KEY (book_id) REFERENCES library(book_id) ON DELETE CASCADE
);

CREATE TABLE user_accounts (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('Student', 'Professor', 'Admin') NOT NULL,
    student_id INT UNIQUE,
    professor_id INT UNIQUE,
    FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE SET NULL,
    FOREIGN KEY (professor_id) REFERENCES professors(professor_id) ON DELETE SET NULL
);

CREATE TABLE notifications (
    notification_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    message TEXT NOT NULL,
    date_sent DATETIME DEFAULT CURRENT_TIMESTAMP,
    is_read BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (user_id) REFERENCES user_accounts(user_id) ON DELETE CASCADE
);

CREATE TABLE feedback (
    feedback_id INT AUTO_INCREMENT PRIMARY KEY,
    course_code VARCHAR(10),
    student_id INT NOT NULL,
    rating INT CHECK (rating >= 1 AND rating <= 5),
    comments TEXT,
    FOREIGN KEY (course_code) REFERENCES courses(course_code) ON DELETE SET NULL,
    FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE
);

-- Views
CREATE VIEW student_profile AS
SELECT 
    s.student_id,
    s.first_name,
    s.last_name,
    s.email,
    g.course_code,
    g.grade,
    c.course_name,
    c.credits
FROM students s
LEFT JOIN grades g ON s.student_id = g.student_id
LEFT JOIN courses c ON g.course_code = c.course_code;


CREATE VIEW course_enrollment AS
SELECT 
    s.student_id,
    s.first_name,
    s.last_name,
    g.course_code,
    c.course_name
FROM students s
JOIN grades g ON s.student_id = g.student_id
JOIN courses c ON g.course_code = c.course_code;


CREATE VIEW attendance_report AS
SELECT 
    a.student_id,
    s.first_name,
    s.last_name,
    a.course_code,
    a.date,
    a.status
FROM attendance a
JOIN students s ON a.student_id = s.student_id;

ALTER TABLE courses
ADD professor_id INT,
ADD FOREIGN KEY (professor_id) REFERENCES professors(professor_id) ON DELETE SET NULL;

CREATE VIEW professor_courses AS
SELECT 
    p.professor_id,
    p.first_name,
    p.last_name,
    c.course_code,
    c.course_name
FROM professors p
JOIN courses c ON p.professor_id = c.professor_id;


-- Triggers
DELIMITER //

CREATE TRIGGER update_total_credits
AFTER INSERT ON grades
FOR EACH ROW
BEGIN
    UPDATE students 
    SET total_credits = (SELECT SUM(c.credits) FROM courses c
                         JOIN grades g ON g.course_code = c.course_code 
                         WHERE g.student_id = NEW.student_id)
    WHERE student_id = NEW.student_id;
END//

CREATE TRIGGER auto_update_fee_status
BEFORE UPDATE ON fees
FOR EACH ROW
BEGIN
    IF NEW.due_date < CURDATE() AND NEW.status = 'Pending' THEN
        SET NEW.status = 'Overdue';
    END IF;
END//

CREATE TRIGGER prevent_double_issue
BEFORE INSERT ON book_issue
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM book_issue 
               WHERE student_id = NEW.student_id 
               AND book_id = NEW.book_id 
               AND return_date IS NULL) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Book is already issued to this student.';
    END IF;
END//

DELIMITER ;



SHOW TABLES;

DESCRIBE students;
DESCRIBE courses;
DESCRIBE grades;
DESCRIBE attendance;
DESCRIBE address;
DESCRIBE emergency_contacts;
DESCRIBE professors;
DESCRIBE teaching_assistants;
DESCRIBE departments;
DESCRIBE fees;
DESCRIBE library;
DESCRIBE book_issue;
DESCRIBE user_accounts;
DESCRIBE notifications;
DESCRIBE feedback;
