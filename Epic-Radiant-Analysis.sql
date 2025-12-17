/* 
I'm using MySQL to analyze close to realistic Epic Radiant datasets. The datasets are synthetic and created using AI. 
*/
-- Create a database
CREATE DATABASE epic_radiant;

-- Selecting the database.
USE epic_radiant;

-- Create relational tables for patient, department, imaging procedure, imaging exam and order.
CREATE TABLE Patient (
  PAT_ID INT PRIMARY KEY,
  PAT_MRN_ID VARCHAR(20) NOT NULL,
  PAT_NAME VARCHAR(100) NOT NULL,
  DOB DATE,
  SEX CHAR(1) 
);

CREATE TABLE Department (
  DEPARTMENT_ID INT PRIMARY KEY,
  DEPARTMENT_NAME VARCHAR(100) NOT NULL
);

CREATE TABLE Imaging_Procedure (
  PROC_ID INT PRIMARY KEY,
  PROC_NAME VARCHAR(150) NOT NULL,
  MODALITY VARCHAR(10) NOT NULL, -- CT, MR, US, DX, NM
  CONTRAST_FLAG CHAR(1) CHECK (CONTRAST_FLAG IN('Y', 'N'))
);

CREATE TABLE Imaging_Order (
  ORDER_ID INT PRIMARY KEY,
  PAT_ID INT NOT NULL,
  PROC_ID INT NOT NULL,
  ORDER_TIME DATETIME NOT NULL,
  PRIORITY_ VARCHAR(10) CHECK (PRIORITY_ IN('STAT', 'ROUTINE', 'ASAP')),

  FOREIGN KEY (PAT_ID) REFERENCES Patient(PAT_ID),
  FOREIGN KEY (PROC_ID) REFERENCES Imaging_Procedure(PROC_ID)
);

CREATE TABLE Imaging_Exam (
  EXAM_ID INT PRIMARY KEY,
  ORDER_ID INT NOT NULL,
  PROC_ID INT NOT NULL,
  DEPARTMENT_ID INT NOT NULL,
  EXAM_START_DTTM DATETIME,
  EXAM_END_DTTM DATETIME,
  EXAM_STATUS VARCHAR(20),

  FOREIGN KEY (ORDER_ID) REFERENCES Imaging_Order(ORDER_ID),
  FOREIGN KEY (PROC_ID) REFERENCES Imaging_Procedure(PROC_ID),
  FOREIGN KEY (DEPARTMENT_ID) REFERENCES Department(DEPARTMENT_ID)
);

-- SQL Queries

-- 1. Find the average order-to-scan time by priority and department.
SELECT department_name AS Department, priority_ AS Priority, ROUND(AVG(TIMESTAMPDIFF(MINUTE, order_time, exam_start_dttm)), 2) AS Avg_Min_Order_to_Start_Scan FROM department
INNER JOIN imaging_exam ON imaging_exam.department_id = department.department_id
INNER JOIN imaging_order ON imaging_exam.exam_id = imaging_order.order_id
GROUP BY department_name, priority_
ORDER BY Avg_Min_Order_to_Start_Scan DESC;

-- Findings:

/*
                Department              | Priority | Avg_Min_Order_to_Start_Scan
                ---------------------------------------------------
                Trauma CT               | ROUTINE  | 137.46
                Outpatient Imaging      | ROUTINE  | 135.82
                Emergency Department CT | ROUTINE  | 130.99
                Main Hospital CT        | ROUTINE  | 123.47
                Trauma CT               | STAT     | 32.38
                Emergency Department CT | STAT     | 32.28
                Outpatient Imaging      | STAT     | 30.67
                Main Hospital CT        | STAT     | 29.00
*/

-- 2. Find exams above the 90th percentile CT wait time for STAT exams.

-- 3. Identify prodecures causing the longest delays.

-- 4. Compare contrast vs non-contrast throughput.

-- 5. Find the cancellation rate by department.

-- 6. Compare the ED vs outpatient CT performance.

-- 7. Show the daily CT volume trends.

-- 8. Find exams violating a 60-minute STAT SLA. 

-- 9. Find how many CT exams were completed in the ED yeasterday.

-- 10. Find the average order-to-scan time by procedure.

-- 11. Find the top 5 most ordered CT procedures.

-- 12. Find the patients name and date time that waited the longest for each different CT exam.