# Estimating Labor Market Transition Probabilities in Brazil Using PNADC

This repository contains Stata code developed by Eric Torres (etorresram@gmail.com) to estimate annual labor market transition probabilities using data from the Brazilian National Household Sample Survey (PNADC). The code processes raw data, constructs panel datasets, applies advanced panel identification methods, harmonizes key labor variables across years to account for changes in the survey in the time, and finally computes weighted transition probabilities.

---

## Table of Contents

- [Overview](#overview)
- [Data Preparation](#data-preparation)
  - [Environment Setup](#environment-setup)
  - [Dictionary Conversion](#dictionary-conversion)
  - [Household and Individual ID Creation](#household-and-individual-id-creation)
  - [Appending Databases](#appending-databases)
  - [Dividing Panels](#dividing-panels)
- [Panel Identification](#panel-identification)
  - [Ribas and Soares Method](#ribas-and-soares-method)
- [Variable Harmonization](#variable-harmonization)
  - [Labor Variables](#labor-variables)
  - [Education Variables](#education-variables)
- [Transition Probability Estimation](#transition-probability-estimation)
  - [Time-Series Setup and Panel Generation](#time-series-setup-and-panel-generation)
  - [Computing Annual Transitions](#computing-annual-transitions)
- [How to Run the Code](#how-to-run-the-code)
- [Requirements](#requirements)

---

## Overview

The goal of this project is to estimate the probabilities of transitions between different labor market states (e.g., inactive, unemployed, formal/informal employed, public sector, independent, and unpaid family work) on an annual basis using PNADC data from 2012 to 2022. The code is organized into several sections that progressively transform raw survey data into a final panel dataset ready for time-series analysis.

---

## Data Preparation

### Environment Setup

- **Clearing the Workspace and Setting Memory:**  
  The code starts by clearing any existing data and setting the memory allocation to 1.4GB to handle large datasets.

- **Global Paths:**  
  Global macros define directories for the original data, input files, and output files. Make sure to update these paths to match your local file system.

### Dictionary Conversion

- **Converting Text Dictionaries:**  
  For each region (coded as 01, 02, 03, 04) and each year (2012–2022), dictionary files in TXT format are converted to Stata (.dta) format. This standardizes the metadata needed for subsequent processing.

### Household and Individual ID Creation

- **Generating Unique Identifiers:**  
  The code creates:
  - A household ID (`hous_id`) by concatenating variables (e.g., UPA, V1008, V1014)
  - An individual ID (`ind_id`) by further appending a person-specific variable (V2003)
  
  These identifiers are essential for consistently tracking individuals and households over time.

### Appending Databases

- **Merging Data Across Years and Regions:**  
  Individual datasets for each combination of region and year are appended into one large panel dataset. Duplicate observations (e.g., a repeated first quarter of 2012) are removed, and the data is sorted appropriately for further processing.

### Dividing Panels

- **Splitting Data by Group:**  
  The final panel dataset is divided into ten groups based on the variable V1014. This facilitates parallel processing or group-specific analysis later in the project.

---

## Panel Identification

### Ribas and Soares Method

- **Panel Matching Process:**  
  An advanced matching algorithm based on the Ribas and Soares method is applied to create longitudinal panels. The process includes:
  - **Defining Panel Variables:** Creating variables such as `id_dom` and `id_chefe` for household identification.
  - **Initial Identification:** Generating an initial identification variable (`p201`) using data from the first interview.
  - **Looping for Matching:**  
    - The first loop matches each pair of interviews by comparing household information, personal characteristics (sex, day, month, and year of birth), and differences between periods.
    - An advanced matching step further refines the matches when some characteristics (such as sex or birth year) do not perfectly align.
    - A second retrospective loop recovers individuals who left the panel and later returned.

This multi-step method is crucial to ensuring a reliable longitudinal dataset.

---

## Variable Harmonization

### Labor Variables

- **Creating Labor Market State Indicators:**  
  Binary variables are generated to capture different labor states:
  - **Inactivity (`inactivo`)** – Ensures that no one is left out.
  - **Employment (`ocupado`)** – Employed
  - **Unemployment (`desocupado`)** – Unemployed
  - **Salaried Employment (`asalariado`),** including domestic workers.
  - **Self-Employment (`independiente`)** – Combining self-employed and employer indicators.
  - **Social Security Contributions (`cotiza1`)** – Indicates if an individual contributes in the main activity.
  - **Public Sector Employment (`publico`)** - Employed in the public sector
  - **Unpaid Family Work (`noremunerado`)** - Unpaid family worker

- **Generating Labor Market Sector Variables:**  
  A categorical variable (`laborsec`) is created to classify individuals into:
  - Inactive
  - Unemployed
  - Formal private salaried workers
  - Informal private salaried workers
  - Public salaried workers
  - Independents
  - Unpaid family workers (TFNR)

  Additionally, a secondary classification (`laborsec2`) distinguishes between formal and informal salaried employment.

### Education Variables

- **Constructing Education Categories:**  
  Using several survey variables, education levels are defined (stored in `aedu_ci`). These levels are then grouped into broader categories (`edu_group`) for further analysis.

---

## Transition Probability Estimation

### Time-Series Setup and Panel Generation

- **Age Subsetting:**  
  The analysis is restricted to individuals aged between 14 and 64.

- **Time Identifiers:**  
  Unique time identifiers are created by combining the year and quarter. The data is then set up as a panel using the individual ID and time group.

- **Biannual Panels:**  
  New variables (panel_1 through panel_10) are generated to capture transitions over one-year intervals by grouping adjacent years.

### Computing Annual Transitions

- **Lagged Variable Creation:**  
  For each individual, lagged labor market state variables (`laborsec1year` and `laborsec21year`) are produced using Stata’s time-series operators.

- **Looping for Transition Tables:**  
  A loop iterates through each panel and quarter, filtering the data accordingly and computing weighted transition tables (using the weight variable `peso`). The transition tables are then exported as Excel files, with each file corresponding to a specific group and quarter.

---

## How to Run the Code

1. **Update Global Paths:**  
   Edit the global macro definitions (`dict`, `data_orig`, `data_final`) to match the file paths on your system.

2. **Run Sequentially:**  
   It is recommended to run the code in sections (e.g., dictionary conversion, ID creation, appending datasets) to verify that each step works correctly.

3. **Check Outputs:**  
   The final panel datasets (e.g., `PNADC_panel_v3_rs.dta`, `PNADC_panel_v5_rs.dta`) and Excel files with the transition tables will be saved in the output directory.

---

## Requirements

- **Stata (version 14 or later recommended)**
- **Sufficient Memory:** At least 1.4GB memory allocated in Stata.
- **PNADC Data:** Access to the raw PNADC data files.
- **Basic Knowledge of Stata:** Familiarity with loops, macros, and panel data operations in Stata.

---
