# SLNET-Metric
SLNET-Metric is a tool to extract metric of Simulink models. It collects metric and stores it in a sqlite3 database.
This tool is an extension of metric collect tool described in this [paper]. We added support for storing the metric in a database along with bug fixes and metrics from official Simulink API.

 
It analyzes the models of the projects in a zip file. It works with projects collected from [SLNet-Miner]

### Requirements

* Windows/Linux (tested on Ubuntu 18.04 and Windows 10)
* MATLAB with Simulink R2018b/R2019b (Additional Toolboxes based used by Simulink models)
* Simulink Test
* Simulink Check 

### Optional Requirements 

* Parallel Computing Toolbox

### Getting Started

Clone the project
```sh
$ git clone <gitlink>
```

#### Running from MATLAB
model_metric_cfg.m contains all the configuration options that lets you configure the directory of the zipped projects (which has models to be analyzed) and database (where you store the all the model metric).  
##### To automatically find Simulink models and extract metrics from them. 
```sh
> cd SLNET_Metrics
> model_metric_obj = model_metric();
> model_metric_obj.process_all_models_file();
```

##### Viewing Reports
After the metrics are collected from the models, you can view cumulative statistics
```sh
> 
> model_metric_obj = model_metric();
> model_metric_obj.total_analyze_metric(<TABLE NAME>,false);
```
Example 
```sh
> model_metric_obj.total_analyze_metric('GitHub_Models',false);
```

##### Dependencies
Currently the zipped projects must have a name that is a number. Example 132.zip

### Development

Want to contribute? Great!
This tool uses MATLAB/Simulink .

#### Todos

 - Write Test case
 - Also Check Issues Tab 
 
 #### Getting Help
 If you run into problems please open a new issue or contact us.



[//]: # (These are reference links used in the body of this note and get stripped out when the markdown processor does its job. There is no need to format nicely because it shouldn't be seen. Thanks SO - http://stackoverflow.com/questions/4823468/store-comments-in-markdown-syntax)
[paper]:http://ranger.uta.edu/~csallner/papers/Chowdhury18Curated.pdf
[SLNet-Miner]: https://github.com/50417/SLNET_Miner
[here]: <https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line#creating-a-token>
