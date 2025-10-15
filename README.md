# Locomotion Activity Dataset (HD-EMG, IMU, Kinetic, Kinematic)

This repository provides access to and processing information for a high-quality, open-source dataset focused on comprehensive human locomotion activities. The data combines **high-density Electromyography (HD-EMG)**, **Inertial Measurement Units (IMU)**, and **kinetic/kinematic parameters**.

## Data Source and Publication

The dataset and its associated publication are an invaluable resource for biomechanics, rehabilitation, and machine learning research, particularly in areas requiring high-resolution, multi-modal sensing.

| Type | Link |
| :--- | :--- |
| **Scientific Publication (Details)** | https://www.nature.com/articles/s41597-023-02679-x |
| **Raw Data Repository (Figshare)** | https://figshare.com/articles/dataset/High-density_EMG_IMU_Kinetic_and_Kinematic_Open-Source_Dataset/22227337 |

---

## Key Features of the Data

The quality and comprehensiveness of this dataset (published in **Nature Scientific Data**) make it ideal for advanced analysis, including gender-sensitive and interpretable machine learning models.

* **High-Density EMG (HD-EMG):** Directly supports analysis of **muscle activation imbalance**.
* **Integrated Multi-Modal Sensing:** Includes **IMU** data alongside **kinematic** parameters, allowing for calculation of **motion symmetry** and **attitude compensation**.
* **High Quality & Reliability:** The data quality is extremely high (Nature Scientific Data).
* **Advanced ML Support:** Can fully support **gender-sensitive** and **interpretable Machine Learning** models.

---

## Included MATLAB Processing Scripts

The files `RightLeg_Processor.m` and `RightLeg_Processor.m` are MATLAB scripts designed to load, process, and aggregate the raw data files (`Pxx.mat`) from the Figshare repository into a unified, clean CSV format (`AllParticipants_RightLeg_EMG_IMU.csv`, `AllParticipants_LeftLeg_EMG_IMU.csv`) ready for analysis.

This script performs the following key functions:
1.  **Data Traversal:** Navigates the complex nested structure to extract relevant segments (e.g., `Level_Ground` -> `Walking` -> `Self_Selected_Speed`).
2.  **Data Normalization:** Converts various MATLAB data types for EMG and IMU into standardized tables.
3.  **Final Assembly:** Concatenates all segments and participants into a single, consistently ordered table.