# Replicating Study on Simulink Models
This work replicates various findings related to Simulink models and modeling practices and analyzes publicly available corpora of Simulink models. The work replicates results from following papers: 
1. [A Curated Corpus of Simulink Models from Model-Based Empirical Studies]
2. [Characteristics, potentials, and limitations of open-source Simulink projects for empirical research]
3. [SLNET: A Redistributable Corpus of 3rd-party Simulink Models]


We have different tools in the repository that work with each other:
1. [Project Evolution]
2. [SLNET-Metrics-Extended]
3. [Data Analysis]

Clone the project and install the dependencies
```sh
$ git clone <gitlink>
$ cd SLReplicationTool
```

## Installation

Tested on Ubuntu 18.04 

First, create virtual environment using  [Anaconda] so that the installation does not conflict with system wide installs.
```sh
$ conda create -n <envname> python=3.7
```

Activate environment and Install the dependencies.
```sh
$ conda activate <envname>
$ pip install -r requirements.txt
```

## Usage

### 1. Project Evolution
The tool extracts project and model commit history of GitHub Projects. The tool leverages the mined data from ([SLNET-Miner] | [SLNET-Miner-archive]). The mined data consist of GitHub urls which this tool uses to extract project/model commit information. All project evolution data is stored in SQLite database.

In this work, we mined GitHub based simulink project evolution data. But the tool can be used to mine the project commit data of any GitHub project. The model commit data will be mined if the project is a Simulink project. 

#### Replication
In this work, we mined GitHub based simulink project's evolution data of [SLNET]. 
- Download and extract [SLNET].
- Update the source database with one from SLNET (i.e. slnet_v1.sqlite) and destination database (say slnet_analysis_data.sqlite) in project_evol.py file.
```sh
$ cd project_evolution
$ python project_evol.py
```
Note that the commits extracted are upto the time when [SLNET] are packaged. To get the most latest commits, remove ''to_commit'' argument in  get_<project/model>_level_commits.py file

#### 2. SLNET-Metrics-Extended is a extension of [SLNET-Metrics]. It is used to extract metrics of Simulink Model and analyze data of Simulink corpus.
Refer to [Replication.md] to reproduce the numbers reported in the paper.

#### 3. Data Analysis
The script is used to reproduce some of the numbers reported in the paper. Refer to [Replication.md] to reproduce the numebrs reported in the paper.


[//]: # (These are reference links used in the body of this note and get stripped out when the markdown processor does its job. There is no need to format nicely because it shouldn't be seen. Thanks SO - http://stackoverflow.com/questions/4823468/store-comments-in-markdown-syntax)
   [Anaconda]: <https://www.anaconda.com/distribution/>
   [SLNET]: <https://zenodo.org/record/4898432#.Y-utZ9LMIYs>
   [Replication.md]: <https://github.com/Anonymous-double-blind/SLReplicationTool/blob/main/replication.md>
   [SLNET-Metrics]: <https://github.com/50417/SLNET_Metrics>
   [SLNET-Metrics-Extended]: <https://github.com/Anonymous-double-blind/SLReplicationTool/tree/main/SLNET_Metrics-Extended>
   [Project Evolution]: <https://github.com/Anonymous-double-blind/SLReplicationTool/tree/main/project_evolution> 
   [Data Analysis]: <https://github.com/Anonymous-double-blind/SLReplicationTool/tree/main/analyze_data>
   [SLNET-Miner]: <https://github.com/50417/SLNet_Miner>
   [SLNET-Miner-archive]: <https://zenodo.org/record/6336034#.Y-VIZdLMIYs>
   [A Curated Corpus of Simulink Models from Model-Based Empirical Studies]: <https://ieeexplore.ieee.org/document/8445079>
   [Characteristics, potentials, and limitations of open-source Simulink projects for empirical research]: <https://link.springer.com/article/10.1007/s10270-021-00883-0>
   [SLNET: A Redistributable Corpus of 3rd-party Simulink Models]: <https://dl.acm.org/doi/abs/10.1145/3524842.3528001>
   [MATLAB Installation]: <https://github.com/Anonymous-double-blind/SLReplicationTool/blob/main/MatlabInstallation.md>
   [Analysis Data]: <https://figshare.com/s/97cbb9e2585b84553c83>
