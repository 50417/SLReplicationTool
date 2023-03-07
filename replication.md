# Replication of the Model Based Study
This wiki contains information about reproducing the numbers and plots reported in the paper. Our study replicated results from the following papers: 
1. [A Curated Corpus of Simulink Models from Model-Based Empirical Studies] (SLC)
2. [Characteristics, potentials, and limitations of open-source Simulink projects for empirical research] (SLC_20)
3. [SLNET: A Redistributable Corpus of 3rd-party Simulink Models] (SLNET)

The analysis data can be downloaded from [FigShare]. We were able to reproduce the numbers from [SLNET]

## Model Metrics Replication
To replicate model metrics of SLC_R, SLC_20R and SLNET. 
SLC_R = sqlite extracted using R2017A

- Open MATLAB (We use MATLAB R2020b). [MATLAB Installation]
- Go to SLNET_Metrics-Extended and update the database location in model_metric_cfg.m file
- Create an model_metric object
````
	> model_metric_obj = model_metric();
````
- To reproduce numbers for SLC_R
````
	> model_metric_obj.total_analyze_metric(<Models_TABLE_NAME>,true);
	> model_metric_obj.grand_total_analyze_metric(true);
````
- To reproduce numbers for SLNET
````
	> model_metric_obj.total_analyze_metric(<Models_TABLE_NAME>,false);
	> model_metric_obj.grand_total_analyze_metric(false);
````
- We reproduce numbers for SLC_20R using [Data Analysis]
	- Set up python environment based on README fie
	- Update SLC_20R database location in get_boll_metric.py
````
	> python get_boll_metric.py
````

## Modeling practices of SLC_R and SLNET
- Open MATLAB (We use MATLAB R2020b).  [MATLAB Installation]
- Go to SLNET_Metrics-Extended and update the database location in model_metric_cfg.m file
- Create an model_metric object
````
	> model_metric_obj = model_metric();
````
- To get modeling practices insight on SLC_R
````
	> model_metric_obj.analyze_metrics(true)
````
- To  get modeling practices insight on SLNET
````
	> model_metric_obj.analyze_metrics(false)

````

## Project and Model Metric Distribution
- Navigate to [Data Analysis]
- Set up python environment based on README fie
- Update SLC_R,SLC_20R and SLNET database location downloaded from [FigShare] in compare_metric_distribution.py

````
	> python compare_metric_distribution.py
````
## Most Frequently Used BlockType Plot
- Navigate to [Data Analysis]
- Set up python environment based on README fie
- Update SLC_R and SLNET database location downloaded from [FigShare] in get_combined_most_freq_block.py
````
	> python get_combined_most_freq_block.py
````
 
## Insight of SLNET project and model distribution
- Navigate to [Data Analysis]
- Set up python environment based on README fie
- Update SLNET database location downloaded from [FigShare] in compare_metric_distribution.py
````
	> python get_SLNET_plot.py
````
## Insight on SLNET Project evolution and Code generating models
- Navigate to [Data Analysis]
- Set up python environment based on README fie
- Update SLNET_analysis_data database location downloaded from [FigShare] in analyzeProjects.py
````
	> python analyzeProjects.py
````

To get the plots for SLNET project and model lifecycle 
- Update SLNET_analysis_data database location downloaded from [FigShare] in analyze_lifecycle.py
````
	> python analyze_lifecycle.py
````

To get projects with the code generating models. Update the 2020b database for all corpus on get_codegen.py file
````
	> python get_codegen.py
````
## Correlation Analysis

- Open MATLAB (We use MATLAB R2020b).[MATLAB Installation]
- Go to SLNET_Metrics-Extended and update the database location in model_metric_cfg.m file
- Create an model_metric object
````
	> model_metric_obj = model_metric();
````
To get correlation values of SLC_R that only includes all  models.
````
	> model_metric_obj.correlation_analysis(true,'GitHub','Tutorial','sourceforge','matc','Others') .
````
To choose non-simple SLC_R models, update list_of_model_name() function. Comment out/in original_study_mdl_name_cell

To get correlation values of SLNET that includes all models. 
````
	> model_metric_obj.correlation_analysis(false,'GitHub','matc') .
````
To choose subset Of SLNET models, Update function correlation_analysis() in else part of flag add 'Schk_block_count >= 200 or similiar '


To get correlation values of SLC_20R that includes all models.
````
	> model_metric_obj.correlation_analysis(false,'All') .
````
  To choose industry + industry mathworks Of SLC_20R models, Update function correlation_analysis() in else part of flag add '
FILE_ID IN (5,7,15,22,32,38,41,58,65,66,79,87,95,102,105,106,118,123,125,126,133,156,182,187,189,2,9,10,11,13,14,57,60,63,71,78,97,103,113,114,119,127,141,143,152,155,157,162,163,164,167,169,177,180,181,184,191,192,193)'



[//]: # (These are reference links used in the body of this note and get stripped out when the markdown processor does its job. There is no need to format nicely because it shouldn't be seen. Thanks SO - http://stackoverflow.com/questions/4823468/store-comments-in-markdown-syntax)
   [A Curated Corpus of Simulink Models from Model-Based Empirical Studies]: <https://ieeexplore.ieee.org/document/8445079>
   [Characteristics, potentials, and limitations of open-source Simulink projects for empirical research]: <https://link.springer.com/article/10.1007/s10270-021-00883-0>
   [SLNET: A Redistributable Corpus of 3rd-party Simulink Models]: <https://dl.acm.org/doi/abs/10.1145/3524842.3528001>
   [Simulink Installation]: <https://github.com/Anonymous-double-blind/SimReplicationTool/wiki/Simulink-Model-Version>
   [SLNET]: <https://zenodo.org/record/4898432#.Y-utZ9LMIYs>
   [Data Analysis]: <https://github.com/Anonymous-double-blind/SimReplicationTool/tree/main/analyze_data>
   [MATLAB Installation]: <https://github.com/Anonymous-double-blind/SLReplicationTool/blob/main/MatlabInstallation.md>
   [FigShare]: <https://figshare.com/s/97cbb9e2585b84553c83>
