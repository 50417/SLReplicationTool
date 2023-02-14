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
       source_dir = []


       %directory where the sqlite database which contains metadata tables
       %are. Ideally we want to store in the same db that Slnet-miner populates project metadata.
        dbfile  = ''

        
        %New/Existing table Where Simulink model metrics(Block_Count) will be stored
        table_name;
   
        %Main table that consists of metadata from the source where the
        %simulink projects is collected from 
        foreign_table_name ; 
        
        blk_info_table_name ;
        blk_info_foreign_table_name ;
        
        lvl_info_table_name;
        lvl_info_foreign_table_name;
        
        subsys_info_table_name;
        subsys_info_foreign_table_name

        %DEBUG MODE: 
        DROP_TABLES = false %drop all existing tables and calculates metrics from scratch 
        DEBUG = true %debug mode % prints to the console if TRUE
        
        PROCESS_LIBRARY = false % non compiled metrics can be extracted from the library. 
        %optional
        tmp_unzipped_dir = ''; %Stores UnZipped Files in this directory % Defaults to  current directory with folder tmp/
        %unused right now
        report_dir = ''; %Creates a file and stores results in this directory 
        
    end
    methods
        %Constructor
        function obj = model_metric_cfg()
           %New/Existing table Where Simulink model metrics(Block_Count) will be stored
            obj.table_name = [obj.project_source '_Models'];

            %Main table that consists of metadata from the source where the
            %simulink projects is collected from 
            obj.foreign_table_name = strcat(obj.project_source,'_Projects'); 

            obj.blk_info_table_name = strcat(obj.project_source,'_Blocks');
            obj.blk_info_foreign_table_name = strcat(obj.project_source,'_Projects'); 
            
            obj.lvl_info_table_name = strcat(obj.project_source,'_Model_Hierar');
           obj.lvl_info_foreign_table_name = strcat(obj.project_source,'_Projects');
           
           obj.subsys_info_table_name = strcat(obj.project_source,'_Subsys');
           obj.subsys_info_foreign_table_name = strcat(obj.project_source,'_Projects');

        end
    end
    
end
