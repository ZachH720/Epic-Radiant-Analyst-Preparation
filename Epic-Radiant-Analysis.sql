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

-- 2. Find the 90th percentile CT wait time for STAT exams.
SELECT wait_time_min AS Min_Wait_Time_At_90th_Percentile FROM (
	SELECT 
		TIMESTAMPDIFF(MINUTE, order_time, exam_end_dttm) AS Wait_Time_Min, 
		NTILE(10) OVER (
			ORDER BY TIMESTAMPDIFF(MINUTE, order_time, exam_end_dttm)
		) AS tile -- Groups the ordered dataset into 10 seperate groups
	FROM Imaging_Exam INNER JOIN Imaging_Order ON Imaging_Exam.ORDER_ID = Imaging_Order.ORDER_ID
	WHERE priority_ = 'STAT' AND exam_end_dttm IS NOT NULL
    ) ranked
WHERE tile = 9
LIMIT 1;

-- Findings:
/*
        Min_Wait_Time_At_90th_Percentile
        ----------------------------
        73
*/

-- 3. Find all STAT exams with a greater wait time than the 90th percentile wait.
WITH select_90th AS (SELECT wait_time_min AS Min_Wait_Time_At_90th_Percentile FROM (
	SELECT 
		TIMESTAMPDIFF(MINUTE, order_time, exam_end_dttm) AS Wait_Time_Min, 
		NTILE(10) OVER (
			ORDER BY TIMESTAMPDIFF(MINUTE, order_time, exam_end_dttm)
		) AS tile -- Groups the ordered dataset into 10 seperate groups
	FROM Imaging_Exam INNER JOIN Imaging_Order ON Imaging_Exam.ORDER_ID = Imaging_Order.ORDER_ID
	WHERE priority_ = 'STAT' AND exam_end_dttm IS NOT NULL
    ) ranked
WHERE tile = 9
LIMIT 1)

SELECT exam_id AS Exam_Id, priority_ AS Priority, TIMESTAMPDIFF(MINUTE, order_time, exam_end_dttm) AS Minutes_Waited
FROM Imaging_Exam INNER JOIN Imaging_Order ON Imaging_Exam.ORDER_ID = Imaging_Order.ORDER_ID
WHERE priority_ = 'STAT' AND exam_end_dttm IS NOT NULL AND TIMESTAMPDIFF(MINUTE, order_time, exam_end_dttm) > (SELECT Min_Wait_Time_At_90th_Percentile FROM select_90th)
ORDER BY Minutes_Waited DESC;

-- Findings:

/*
     Exam_Id | Priority | Minutes_Waited
     -----------------------------------
     123     | STAT     | 97
     25      | STAT     | 96
     489     | STAT     | 93
     437     | STAT     | 92
     138     | STAT     | 91
     385     | STAT     | 87
     7       | STAT     | 86
     203     | STAT     | 85
     149     | STAT     | 84
     454     | STAT     | 84
     114     | STAT     | 83
     180     | STAT     | 83
     434     | STAT     | 83
     239     | STAT     | 82
     386     | STAT     | 82
     59      | STAT     | 81
     139     | STAT     | 80
     338     | STAT     | 80
     108     | STAT     | 77
     189     | STAT     | 76
     242     | STAT     | 76
     293     | STAT     | 76
     425     | STAT     | 76
     213     | STAT     | 75
     222     | STAT     | 75
     257     | STAT     | 75
     279     | STAT     | 75
     14      | STAT     | 74
     109     | STAT     | 74
     167     | STAT     | 74
     400     | STAT     | 74
*/
-- 4. Identify prodecures causing the longest delays.
SELECT proc_name AS Procedure_Name, ROUND(AVG(TIMESTAMPDIFF(MINUTE, order_time, exam_end_dttm)), 2) AS Avg_Min_Delayed 
  FROM imaging_procedure
    INNER JOIN imaging_order ON imaging_order.PROC_ID = imaging_procedure.PROC_ID
    INNER JOIN imaging_exam ON imaging_exam.order_id = imaging_order.order_id
GROUP BY proc_name
ORDER BY Avg_Min_Delayed DESC;

-- Findings:

/*
      Procedure_Name                               | Avg_Min_Delayed
      -------------------------------------------------------------
      CT Lumbar Spine Without Contrast             | 126.62
      CT Thoracic Spine Without Contrast           | 125.80
      CT Chest With Contrast                       | 124.81
      CT Head Without Contrast                     | 124.72
      CT Head With Contrast                        | 123.32
      CT Chest Without Contrast                    | 121.26
      CT Facial Bones Without Contrast             | 115.92
      CT Angiography Head and Neck                 | 114.08
      CT Abdomen Pelvis With and Without Contrast  | 112.55
      CT Sinus Without Contrast                    | 110.22
      CT Cervical Spine Without Contrast           | 109.50
      CT Chest PE Protocol                         | 108.57
      CT Abdomen Pelvis Without Contrast           | 105.64
      CT Abdomen Pelvis With Contrast              | 104.00

*/

-- 5. Compare contrast vs non-contrast throughput.
SELECT 
	CASE
  WHEN contrast_flag = 'Y' THEN 'Contrast'
  WHEN contrast_flag = 'N' THEN 'Non-Contrast'
  END AS Procedure_Type, -- Rename the contrast flag characters to Contrast and Non-Contrast
  ROUND(AVG(TIMESTAMPDIFF(MINUTE, order_time, exam_end_dttm)), 2) AS Avg_Minutes_Order_To_Complete,
  ROUND(AVG(TIMESTAMPDIFF(MINUTE, exam_start_dttm, exam_end_dttm)), 2) AS Avg_Minutes_Start_To_Complete,
  ROUND(AVG(TIMESTAMPDIFF(MINUTE, order_time, exam_start_dttm)), 2) AS Avg_Minutes_Order_To_Start
	FROM imaging_procedure
		INNER JOIN imaging_order ON imaging_order.PROC_ID = imaging_procedure.PROC_ID
		INNER JOIN imaging_exam ON imaging_exam.order_id = imaging_order.order_id
	GROUP BY contrast_flag
    ORDER BY Avg_Minutes_Order_To_Complete, Avg_Minutes_Start_To_Complete, Avg_Minutes_Order_To_Start;
-- Findings
/*
      Procedure_Type | Avg_Minutes_Order_To_Complete | Avg_Minutes_Start_To_Complete | Avg_Minutes_Order_To_Start
      -----------------------------------------------------------------------------------------------------------
      Contrast       | 114.51                        | 25.68                         | 88.29
      Non-Contrast   | 117.42                        | 25.05                         | 95.02
*/


-- 6. Find the cancellation rate by department.
SELECT department_name AS Department,
	(COUNT(CASE WHEN exam_status = 'CANCELLED' THEN 1 END) * 1.0) / COUNT(*) AS Cancel_Rate
FROM department
INNER JOIN imaging_exam ON imaging_exam.DEPARTMENT_ID = department.DEPARTMENT_ID
GROUP BY Department
ORDER BY Cancel_Rate DESC;
-- Findings:
/*
      Department              | Cancel_Rate
      -------------------------------------
      Emergency Department CT | 0.10744
      Outpatient Imaging      | 0.08197
      Main Hospital CT        | 0.05556
      Trauma CT               | 0.02500
*/

-- 7. Compare the ED vs outpatient CT performance.
SELECT department_name AS Department, ROUND(AVG(TIMESTAMPDIFF(MINUTE, order_time, exam_end_dttm)), 2) AS Avg_Total_Order_Time,
  COUNT(CASE WHEN priority_ = 'STAT' THEN 1 END) AS Total_Stat_Exams,
  COUNT(CASE WHEN priority_ = 'ROUTINE' THEN 1 END) AS Total_Routine_Exams
FROM department
INNER JOIN imaging_exam ON department.DEPARTMENT_ID = imaging_exam.DEPARTMENT_ID
INNER JOIN imaging_order ON imaging_order.ORDER_ID = imaging_exam.ORDER_ID
WHERE department_name IN ('Emergency Department CT', 'Outpatient Imaging')
GROUP BY Department
ORDER BY Department;
-- Findings:
/*
     Department              | Avg_Total_Order_Time | Total_Stat_Exams | Total_Routine_Exams
     ---------------------------------------------------------------------------------------
     Emergency Department CT | 116.12               | 43               | 78
     Outpatient Imaging      | 122.19               | 46               | 76
*/

-- 8. Show the daily CT volume trends.
SELECT DATE(exam_end_dttm) AS CT_Exam_Date, COUNT(*) AS Total_Exams
FROM imaging_exam
WHERE exam_end_dttm IS NOT NULL
GROUP BY CT_Exam_Date
ORDER BY CT_Exam_Date;
-- Findings:
/*
     CT_Exam_Date | Total_Exams
     --------------------------
     2025-11-17   | 1
     2025-11-18   | 11
     2025-11-19   | 14
     2025-11-20   | 14
     2025-11-21   | 14
     2025-11-22   | 15
     2025-11-23   | 14
     2025-11-24   | 20
     2025-11-25   | 8
     2025-11-26   | 17
     2025-11-27   | 16
     2025-11-2    | 7
     2025-11-29   | 23
     2025-11-30   | 21
     2025-12-01   | 11
     2025-12-02   | 13
     2025-12-03   | 17
     2025-12-04   | 14
     2025-12-05   | 27
     2025-12-06   | 15
     2025-12-07   | 16
     2025-12-08   | 16
     2025-12-09   | 21
     2025-12-10   | 17
     2025-12-11   | 11
     2025-12-12   | 13
     2025-12-13   | 17
     2025-12-14   | 13
     2025-12-15   | 12
*/

-- 9. Find exams violating a 60-minute STAT SLA in the date range 11/21/25 - 11/25/25.
SELECT proc_name AS CT_Exam, exam_id AS Exam_ID, DATE(exam_end_dttm) AS CT_Exam_Date, 
	TIMESTAMPDIFF(MINUTE, order_time, exam_end_dttm) AS Total_Time
FROM imaging_procedure
INNER JOIN imaging_order ON imaging_procedure.PROC_ID = imaging_order.PROC_ID
INNER JOIN imaging_exam ON imaging_exam.ORDER_ID = imaging_order.ORDER_ID
WHERE exam_end_dttm IS NOT NULL AND TIMESTAMPDIFF(MINUTE, order_time, exam_end_dttm) > 60 AND DATE(exam_end_dttm) BETWEEN '2025-11-21' AND '2025-11-25'
ORDER BY CT_Exam_Date, exam_id;
-- Findings: 
/*
     CT_Exam                                     | Exam_ID | CT_Exam_Date | Total_Time
     ---------------------------------------------------------------------------------
     CT Chest PE Protocol                        | 30      | 2025-11-21   | 196
     CT Facial Bones Without Contrast            | 39      | 2025-11-21   | 78
     CT Thoracic Spine Without Contrast          | 75      | 2025-11-21   | 203
     CT Thoracic Spine Without Contrast          | 102     | 2025-11-21   | 69
     CT Abdomen Pelvis With and Without Contrast | 128     | 2025-11-21   | 69
     CT Abdomen Pelvis With Contrast             | 131     | 2025-11-21   | 211
     CT Abdomen Pelvis Without Contrast          | 221     | 2025-11-21   | 167
     CT Sinus Without Contrast                   | 366     | 2025-11-21   | 101
     CT Abdomen Pelvis Without Contrast          | 445     | 2025-11-21   | 103
     CT Abdomen Pelvis With and Without Contrast | 449     | 2025-11-21   | 61
     CT Head With Contrast                       | 31      | 2025-11-22   | 158
     CT Thoracic Spine Without Contrast          | 47      | 2025-11-22   | 118
     CT Facial Bones Without Contrast            | 157     | 2025-11-22   | 187
     CT Head With Contrast                       | 248     | 2025-11-22   | 170
     CT Lumbar Spine Without Contrast            | 340     | 2025-11-22   | 61
     CT Cervical Spine Without Contrast          | 397     | 2025-11-22   | 202
     CT Head With Contrast                       | 404     | 2025-11-22   | 149
     CT Abdomen Pelvis With Contrast             | 428     | 2025-11-22   | 184
     CT Head With Contrast                       | 437     | 2025-11-22   | 92
     CT Cervical Spine Without Contrast          | 459     | 2025-11-22   | 86
     CT Head With Contrast                       | 473     | 2025-11-22   | 68
     CT Chest Without Contrast                   | 44      | 2025-11-23   | 162
     CT Cervical Spine Without Contrast          | 103     | 2025-11-23   | 222
     CT Facial Bones Without Contrast            | 124     | 2025-11-23   | 180
     CT Facial Bones Without Contrast            | 189     | 2025-11-23   | 76
     CT Chest Without Contrast                   | 247     | 2025-11-23   | 112
     CT Cervical Spine Without Contrast          | 322     | 2025-11-23   | 65
     CT Head Without Contrast                    | 332     | 2025-11-23   | 94
     CT Abdomen Pelvis With Contrast             | 407     | 2025-11-23   | 99
     CT Lumbar Spine Without Contrast            | 448     | 2025-11-23   | 170
     CT Cervical Spine Without Contrast          | 18      | 2025-11-24   | 218
     CT Abdomen Pelvis With and Without Contrast | 68      | 2025-11-24   | 247
     CT Sinus Without Contrast                   | 71      | 2025-11-24   | 66
     CT Head Without Contrast                    | 76      | 2025-11-24   | 200
     CT Angiography Head and Neck                | 84      | 2025-11-24   | 172
     CT Sinus Without Contrast                   | 118     | 2025-11-24   | 262
     CT Chest Without Contrast                   | 134     | 2025-11-24   | 239
     CT Angiography Head and Neck                | 200     | 2025-11-24   | 68
     CT Thoracic Spine Without Contrast          | 262     | 2025-11-24   | 217
     CT Chest PE Protocol                        | 273     | 2025-11-24   | 185
     CT Abdomen Pelvis Without Contrast          | 309     | 2025-11-24   | 63
     CT Head With Contrast                       | 343     | 2025-11-24   | 205
     CT Abdomen Pelvis With Contrast             | 454     | 2025-11-24   | 84
     CT Chest PE Protocol                        | 474     | 2025-11-24   | 87
     CT Sinus Without Contrast                   | 59      | 2025-11-25   | 81
     CT Cervical Spine Without Contrast          | 70      | 2025-11-25   | 184
     CT Facial Bones Without Contrast            | 74      | 2025-11-25   | 102
     CT Abdomen Pelvis With Contrast             | 100     | 2025-11-25   | 139
     CT Chest Without Contrast                   | 291     | 2025-11-25   | 116
     CT Chest With Contrast                      | 403     | 2025-11-25   | 77
*/

-- 10. Find how many CT exams were completed in the ED 11/29/25.
SELECT department_name AS Department, DATE(exam_end_dttm) AS Exam_Date, COUNT(*) AS Total_CT_Exams
FROM department
INNER JOIN imaging_exam ON imaging_exam.DEPARTMENT_ID = department.DEPARTMENT_ID
WHERE department_name = 'Emergency Department CT' AND DATE(exam_end_dttm) = '2025-11-29'
GROUP BY Exam_Date;
--Findings:
/*
     Department              | Exam_Date  | Total_CT_Exams
     -----------------------------------------------------
     Emergency Department CT | 2025-11-29 | 3
*/

-- 11. Find the average order-to-scan time by procedure.
SELECT proc_name AS CT_Exam, ROUND(AVG(TIMESTAMPDIFF(MINUTE, order_time, exam_start_dttm)), 2) AS Avg_Order_To_Scan_Time_Min
FROM imaging_procedure
INNER JOIN imaging_exam ON imaging_procedure.PROC_ID = imaging_exam.PROC_ID
INNER JOIN imaging_order ON imaging_order.ORDER_ID = imaging_exam.ORDER_ID
GROUP BY CT_Exam
ORDER BY Avg_Order_To_Scan_Time_Min DESC;
--Findings:
/*
     CT_Exam                                     | Avg_Order_To_Scan_Time_Min
     --------------------------------------------------------------------
     CT Lumbar Spine Without Contrast            | 103.27
     CT Chest Without Contrast                   | 101.44
     CT Thoracic Spine Without Contrast          | 100.78
     CT Facial Bones Without Contrast            | 96.38
     CT Chest With Contrast                      | 94.45
     CT Head Without Contrast                    | 94.26
     CT Sinus Without Contrast                   | 93.49
     CT Abdomen Pelvis With and Without Contrast | 93.48
     CT Angiography Head and Neck                | 89.35
     CT Head With Contrast                       | 89.13
     CT Abdomen Pelvis Without Contrast          | 85.97
     CT Chest PE Protocol                        | 84.00
     CT Cervical Spine Without Contrast          | 81.79
     CT Abdomen Pelvis With Contrast             | 80.41

*/

-- 12. Find the top 5 most ordered CT procedures.
SELECT proc_name AS CT_Exam_Name, COUNT(*) AS Total_Exams_Ordered
FROM imaging_procedure
INNER JOIN imaging_order ON imaging_order.PROC_ID = imaging_procedure.PROC_ID
GROUP BY CT_Exam_Name
ORDER BY Total_Exams_Ordered DESC
LIMIT 5;
-- Findings:
/*
     CT_Exam_Name                       | Total_Exams_Ordered
     --------------------------------------------------------
     CT Thoracic Spine Without Contrast | 50
     CT Sinus Without Contrast          | 43
     CT Facial Bones Without Contrast   | 40
     CT Head With Contrast              | 38
     CT Chest PE Protocol               | 38

*/

-- 13. Find the exam name and longest time waited in minutes for each ct exam type.
SELECT proc_name AS CT_Exam_Name,  MAX(TIMESTAMPDIFF(MINUTE, order_time, exam_end_dttm)) AS Max_Wait_Time_Minutes
FROM imaging_procedure
INNER JOIN imaging_exam ON imaging_exam.PROC_ID = imaging_procedure.PROC_ID
INNER JOIN imaging_order ON imaging_order.ORDER_ID = imaging_exam.ORDER_ID
WHERE exam_end_dttm IS NOT NULL
GROUP BY CT_Exam_Name
ORDER BY Max_Wait_Time_Minutes DESC;
--Findings:
/*
     CT_Exam_Name                                | Max_Wait_Time_Minutes
     ---------------------------------------------------------------
     CT Sinus Without Contrast                   | 262
     CT Head With Contrast                       | 261
     CT Angiography Head and Neck                | 260
     CT Chest Without Contrast                   | 251
     CT Abdomen Pelvis Without Contrast          | 250
     CT Chest With Contrast                      | 249
     CT Abdomen Pelvis With and Without Contrast | 247
     CT Lumbar Spine Without Contrast            | 246
     CT Head Without Contrast                    | 244
     CT Chest PE Protocol                        | 241
     CT Abdomen Pelvis With Contrast             | 241
     CT Thoracic Spine Without Contrast          | 239
     CT Facial Bones Without Contrast            | 224
     CT Cervical Spine Without Contrast          | 222
*/

-- 14. Find the top ten patients who waited the longest to start their exams.
SELECT pat_name AS Patient, MAX(TIMESTAMPDIFF(MINUTE, order_time, exam_start_dttm)) AS Wait_Time_Min
FROM patient
INNER JOIN imaging_order ON imaging_order.PAT_ID = patient.PAT_ID
INNER JOIN imaging_exam ON imaging_exam.ORDER_ID = imaging_order.ORDER_ID
GROUP BY Patient
ORDER BY Wait_Time_Min DESC
LIMIT 10;
-- Findings:
/*
     Patient     | Wait_Time_Min
     ---------------------------
     Patient 152 | 220
     Patient 25  | 220
     Patient 61  | 219
     Patient 69  | 216
     Patient 48  | 216
     Patient 200 | 216
     Patient 125 | 215
     Patient 237 | 215
     Patient 162 | 214
     Patient 160 | 214
*/