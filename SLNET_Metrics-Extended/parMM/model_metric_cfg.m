classdef model_metric_cfg < handle
    properties(Constant)
    %GitHub and MATLAB Central choose one 
        project_source = 'GitHub';
        %project_source = 'MATC';
    end
    properties
        % How to use properties : https://www.mathworks.com/help/matlab/matlab_oop/how-to-use-properties.html
        % NOTE : Constant properties val cant be obtained using get methods  
        
        %  Simulink models Zip files  directory to be analyzed
       %directory where the Simulink projects(in zip format) are stored 
       %source_dir = [ filesep 'home' filesep 'sls6964xx' filesep 'Desktop' filesep 'UtilityProgramNConfigurationFile' filesep  'TestCollectingSimulinkModels' filesep  'dir_to_download'] 
       %source_dir = [filesep 'home' filesep 'sls6964xx' filesep 'Downloads' filesep 'SLNet_v1' filesep  'SLNET_GitHub']
       %source_dir = ['C:' filesep 'Users' filesep 'sls6964xx' filesep 'Desktop' filesep 'SLNet_v1' filesep 'SLNET_GitHub']
       %source_dir = ['C:' filesep 'Users' filesep 'sls6964xx' filesep 'Desktop' filesep 'SLNet_v1' filesep 'SLNET_MATLABCentral']
       source_dir = [filesep 'home' filesep 'sls6964xx' filesep 'Downloads' filesep 'SLNet_v1'   filesep  'Test']
       %directory where the sqlite database which contains metadata tables
       %are
        %dbfile = [filesep 'home' filesep 'sls6964xx' filesep 'Desktop' filesep 'UtilityProgramNConfigurationFile' filesep 'TestCollectingSimulinkModels'  filesep 'xyz.sqlite']
        %dbfile = ['C:' filesep 'Users' filesep 'sls6964xx' filesep 'Desktop' filesep 'SLNet_v1' filesep  'slnet_v1_git.sqlite'] % Has github metrics completed.
        dbfile = [filesep 'home' filesep 'sls6964xx' filesep 'Downloads' filesep 'SLNet_v1'   filesep 'slnet_v1.sqlite']
        
        %New/Existing table Where Simulink model metrics(Block_Count) will be stored
        table_name;
   
        %Main table that consists of metadata from the source where the
        %simulink projects is collected from 
        foreign_table_name ; 
        
        blk_info_table_name ;
        blk_info_foreign_table_name ;
        
        lvl_info_table_name;
        lvl_info_foreign_table_name;

        %DEBUG MODE: 
        DROP_TABLES = true %drop all existing tables and calculates metrics from scratch 
        
        %optional
        tmp_unzipped_dir = ''; %Stores UnZipped Files in this directory % Defaults to  current directory with folder tmp/
        %unused right now
        report_dir = ''; %Creates a file and stores results in this directory 
        
    end
    methods
        %Constructor
        function obj = model_metric_cfg()
           %New/Existing table Where Simulink model metrics(Block_Count) will be stored
            obj.table_name = [obj.project_source '_Metric'];

            %Main table that consists of metadata from the source where the
            %simulink projects is collected from 
            obj.foreign_table_name = strcat(obj.project_source,'_Projects'); 

            obj.blk_info_table_name = strcat(obj.project_source,'_Block_Info');
            obj.blk_info_foreign_table_name = strcat(obj.project_source,'_Metric'); 
            
            obj.lvl_info_table_name = strcat(obj.project_source,'_Hierar_Info');
           obj.lvl_info_foreign_table_name = strcat(obj.project_source,'_Metric');

        end
    end
    
end