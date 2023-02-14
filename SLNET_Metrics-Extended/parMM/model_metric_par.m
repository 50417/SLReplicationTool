classdef model_metric_par < handle
    % Gets Metrics
    % Number of blocks
    % Description of Metrics: https://www.mathworks.com/help/slcheck/ref/model-metric-checks.html#buuybtl-1
    % NOTE : Object variables always have to be appended with obj
    properties
        cfg;
        table_name;
        foreign_table_name;
        
        blk_info;
        lvl_info;
        
        conn;
        colnames = {'FILE_ID','Model_Name','is_Lib','SCHK_Block_count','SLDiag_Block_count','SubSystem_count_Top',...
            'Agg_SubSystem_count','Hierarchy_depth','LibraryLinked_Count',...,
            'compiles','CComplexity',...
            'Sim_time','Compile_time','Alge_loop_Cnt','target_hw','solver_type','sim_mode'...
            ,'total_ConnH_cnt','total_desc_cnt','ncs_cnt','unique_sfun_count','sfun_nam_count'...
            ,'mdlref_nam_count','unique_mdl_ref_count'};
        coltypes = {'INTEGER','VARCHAR','Boolean','NUMERIC','NUMERIC','NUMERIC','NUMERIC',...,
            'NUMERIC','NUMERIC','Boolean','NUMERIC','NUMERIC','NUMERIC','NUMERIC','VARCHAR','VARCHAR','VARCHAR'...
            ,'NUMERIC','NUMERIC','NUMERIC','NUMERIC','VARCHAR'...
            ,'VARCHAR','NUMERIC'}; 

       
    end
    
    methods
        %Constructor
        function obj = model_metric_par()
            warning on verbose
            %obj.WriteLog("open");
            obj.cfg = model_metric_cfg();
            obj.table_name = obj.cfg.table_name;
            obj.foreign_table_name = obj.cfg.foreign_table_name;
            
            obj.blk_info = get_block_info_par(); % extracts block info of top lvl... 
            obj.lvl_info = obtain_non_supported_hierarchial_metrics_par();
            
            %Creates folder to extract zipped filed files in current
            %directory.
            %if obj.cfg.tmp_unzipped_dir==""
            %    obj.cfg.tmp_unzipped_dir = "tmp";
            %end
            %if(~exist(obj.cfg.tmp_unzipped_dir,'dir'))
            %       mkdir(obj.cfg.tmp_unzipped_dir);
            %end
            obj.connect_table();
        end
        %Gets simulation time of the model based on the models
        %configuration. If the stopTime of the model is set to Inf, then it
        % sets the simulation time to -1
        %What is simulation Time: https://www.mathworks.com/matlabcentral/answers/163843-simulation-time-and-sampling-time
        function sim_time = get_simulation_time(~, model) % cs = configuarationSettings of a model
            cs = getActiveConfigSet(model) ;
            startTime = cs.get_param('StartTime');
            stopTime = cs.get_param('StopTime'); %returns a string when time is finite
            try
                startTime = eval(startTime);
                stopTime = eval(stopTime); %making sure that evaluation parts converts to numeric data
                if isfinite(stopTime) && isfinite(startTime) % isfinite() Check whether symbolic array elements are finite
                    
                    assert(isnumeric(startTime) && isnumeric(stopTime));
                    sim_time = stopTime-startTime;
                else
                    sim_time = -1;
                end
            catch
                sim_time = -1;
            end
        end
      
            %Logging purpose
        %Credits: https://www.mathworks.com/matlabcentral/answers/1905-logging-in-a-matlab-script
        function WriteLog(~,Data)
            global FID % https://www.mathworks.com/help/matlab/ref/global.html %https://www.mathworks.com/help/matlab/ref/persistent.html Local to functions but values are persisted between calls.
            % Open the file
            if strcmp(Data, 'open')
              FID = fopen(strcat('Model_Metric_LogFile',datestr(now, 'dd-mm-yy-HH-MM-SS'),'.txt'), 'w');
              if FID < 0
                 error('Cannot open file');
              end
              return;
            elseif strcmp(Data, 'close')
              fclose(FID);
              FID = -1;
            end
            fprintf(FID, '%s: %s\n',datestr(now, 'dd/mm/yy-HH:MM:SS'), Data);
            % Write to the screen at the same time:
            fprintf('%s: %s\n', datestr(now, 'dd/mm/yy-HH:MM:SS'), Data);
        end
        
        %concatenates file with source directory
        function full_path = get_full_path(obj,file)
            full_path = [obj.cfg.source_dir filesep file];
        end
        
        %creates Table to store model metrics 
        function connect_table(obj)
            obj.conn = sqlite(obj.cfg.dbfile,'connect');
            cols = strcat(obj.colnames(1) ," ",obj.coltypes(1)) ;
            for i=2:length(obj.colnames)
                cols = strcat(cols, ... 
                    ',', ... 
                    obj.colnames(i), " ",obj.coltypes(i) ) ;
            end
           create_metric_table = strcat("create table IF NOT EXISTS ", obj.table_name ...
            ,'( ID INTEGER primary key autoincrement ,', cols  ,...
            ", CONSTRAINT FK FOREIGN KEY(FILE_ID) REFERENCES ", obj.foreign_table_name...
                 ,'(id) ,'...
                ,'CONSTRAINT UPair  UNIQUE(FILE_ID, Model_Name) )');
            
            if obj.cfg.DROP_TABLES
                %obj.WriteLog(sprintf("Dropping %s",obj.table_name))
                obj.drop_table();
                %obj.WriteLog(sprintf("Dropped %s",obj.table_name))
            end
             %obj.WriteLog(create_metric_table);
            exec(obj.conn,create_metric_table);
        end
        %Writes to database 
        function output_bol = write_to_database(obj,id,simulink_model_name,isLib,schK_blk_count,block_count,...
                                            subsys_count,agg_subsys_count,depth,linkedcount,compiles, cyclo,...
                                            sim_time,compile_time,num_alge_loop,target_hw,solver_type,sim_mode,...
                                            total_lines_cnt,total_descendant_count,ncs_count,unique_sfun_count,...
                                            sfun_reused_key_val,...
                                            modelrefMap_reused_val,unique_mdl_ref_count)%block_count)
            insert(obj.conn,obj.table_name,obj.colnames, ...
                {id,simulink_model_name,isLib,schK_blk_count,block_count,subsys_count,...
                agg_subsys_count,depth,linkedcount,compiles,cyclo,...
                sim_time,compile_time,num_alge_loop,target_hw,solver_type,sim_mode...
                ,total_lines_cnt,total_descendant_count,ncs_count,unique_sfun_count,...
                sfun_reused_key_val...
                ,modelrefMap_reused_val,unique_mdl_ref_count});%block_count});
            output_bol= 1;
        end
        %gets File Ids and model name from table
        function results = fetch_file_ids_model_name(obj)
            sqlquery = ['SELECT file_id,model_name FROM ' obj.table_name];
            results = fetch(obj.conn,sqlquery);
            
            %max(data)
        end
        
        %Construct matrix that concatenates 'file_id'+'model_name' to
        %avoid recalculating the metrics
        function unique_id_mdl = get_database_content(obj)
            
            file_id_n_model = obj.fetch_file_ids_model_name();
            unique_id_mdl = string.empty(0,length(file_id_n_model));
            for i = 1 : length(file_id_n_model)
                %https://www.mathworks.com/matlabcentral/answers/350385-getting-integer-out-of-cell   
                unique_id_mdl(i) = strcat(num2str(file_id_n_model{i,1}),file_id_n_model(i,2));
            
            end
         
        end
        
        
        %drop table Striclty for debugging purposes
        function drop_table(obj)
            %Strictly for debugginf purpose only
            sqlquery = ['DROP TABLE IF EXISTS ' obj.table_name];
            exec(obj.conn,sqlquery);
            %max(data)
        end
        
        %Deletes content of obj.cfg.tmp_unzipped_dir such that next
        %project can be analyzed
        function delete_tmp_folder_content(~,folder)
             % Get a list of all files in the folder
            list = dir(folder);
            % Get a logical vector that tells which is a directory.
            dirFlags = [list.isdir];
            % Extract only those that are directories.
            subFolders = list(dirFlags);
            tf = ismember( {subFolders.name}, {'.', '..'});
            subFolders(tf) = [];  %remove current and parent directory.
        
             for k = 1 : length(subFolders)
              base_folder_name = subFolders(k).name;
              full_folder_name = fullfile(folder, base_folder_name);
              %obj.WriteLog(sprintf( 'Now deleting %s\n', full_folder_name));
              rmdir(full_folder_name,'s');
             end
            
             file_pattern = fullfile(folder, '*.*'); 
            files = dir(file_pattern);%dir(filePattern);
            tf = ismember( {files.name}, {'.', '..'});
            files(tf) = [];
            for k = 1 : length(files)
              base_file_name = files(k).name;
              full_file_name = fullfile(folder, base_file_name);
              %obj.WriteLog(sprintf( 'Now deleting %s\n', full_file_name));
              delete(full_file_name);
            end
            
        end
        
        %returns number of algebraic loop in the model. 
        %What is algebraic Loops :
        %https://www.mathworks.com/help/simulink/ug/algebraic-loops.html  https://www.mathworks.com/matlabcentral/answers/95310-what-are-algebraic-loops-in-simulink-and-how-do-i-solve-them
        function num_alge_loop = get_number_of_algebraic_loops(~,model)
            alge_loops = Simulink.BlockDiagram.getAlgebraicLoops(model);
            num_alge_loop  = numel(alge_loops);            
        end
        
        %Checks if a models compiles for not
        function compiles = does_model_compile(~,model)
                %eval(['mex /home/sls6964xx/Desktop/UtilityProgramNConfigurationFile/ModelMetricCollection/tmp/SDF-MATLAB-master/C/src/sfun_ndtable.cpp']);
               eval([model, '([], [], [], ''compile'');'])
                %obj.WriteLog([model ' compiled Successfully ' ]); 
               
                compiles = 1;
        end
        
        %Close the model
        % Close the model https://www.mathworks.com/matlabcentral/answers/173164-why-the-models-stays-in-paused-after-initialisation-state
        function obj= close_the_model(obj,model)
            try
               
               %obj.WriteLog(sprintf("Closing %s",model));
         
               close_system(model);
               bdclose(model);
            catch exception

                %obj.WriteLog(exception.message);
                %obj.WriteLog("Trying Again");
                if (strcmp(exception.identifier ,'Simulink:Commands:InvModelDirty' ))
                    %obj.WriteLog("Force Closing");
                    bdclose(model);
                    return;
                end
                %eval([model '([],[],[],''sizes'')']);
                eval([model '([],[],[],''term'')']);
                obj.close_the_model(model);
            end
        end
        
        function [target_hw,solver_type,sim_mode]=get_solver_hw_simmode(~,model)
            cs = getActiveConfigSet(model);
            target_hw = cs.get_param('TargetHWDeviceType');


            solver_type = get_param(model,'SolverType');
            if isempty(solver_type)
                solver_type = 'NA';
            end


            sim_mode = get_param(model, 'SimulationMode');
        end
        
        %Main function to call to extract model metrics
        function obj = process_all_models_file(obj)
            [list_of_zip_files] = dir(obj.cfg.source_dir); %gives struct with date, name, size info, https://www.mathworks.com/matlabcentral/answers/282562-what-is-the-difference-between-dir-and-ls
            tf = ismember( {list_of_zip_files.name}, {'.', '..'});
            list_of_zip_files(tf) = [];  %remove current and parent directory.
            
            %Fetch All File id and model_name from Database to remove redundancy
                    
            file_id_mdl_array = obj.get_database_content(); 
            folderPath = parallel.pool.Constant(@() tempname(pwd));
            metric_File = parallel.pool.Constant(@() fopen(strcat(tempname(pwd),"_metric"),'at'),@fclose);
            hierar_File = parallel.pool.Constant(@() fopen(strcat( tempname(pwd),"_hierar"),'at'),@fclose);
            blk_info_File = parallel.pool.Constant(@() fopen(strcat( tempname(pwd),"_blk_info"),'at'),@fclose);
           %processed_file_count = 1;
           file_length = int8(size(list_of_zip_files,1));
           spmd
               mkdir(folderPath.Value);
               disp(folderPath.Value);
               disp(fopen(metric_File.Value));
               disp(fopen(hierar_File.Value)); disp(fopen(blk_info_File.Value));
           end
        
           %Loop over each Zip File 
           parfor cnt = 1 : file_length
              
                    name =strtrim(char(list_of_zip_files(cnt).name));  
                    obj.get_full_path(name);
                   % log = strcat("Processing #",  num2str(processed_file_count), " :File Id ",list_of_zip_files(cnt).name) ;
                    %%obj.WriteLog(log);
                   
                    tmp_var = strrep(name,'.zip',''); 
                    id = str2double(tmp_var);
         
                    %id==70131 || kr_billiards_debug crashes MATLAB when compiling 
                   %id == 67689 cant find count becuase referenced model has
                   %protected component.
                   %id == 152409754 hangs because requires user input
                   %id == 152409754  testing
                   %id ===24437619 %suspious
                  if (id ==24437619 || id==198236388 || id == 124448612 || id==45571425 || id == 152409754 || id ==25870564) % potential crashes or hangs
                       continue
                  end
             
                   %unzip the file TODO: Try CATCH
                   %%obj.WriteLog('Extracting Files');
                   list_of_unzipped_files = unzip( obj.get_full_path(list_of_zip_files(cnt).name), folderPath.Value);%obj.cfg.tmp_unzipped_dir);
                  %Assumption Zip file always consists of a single folder .
                  %Adapt later.
                  folder_path= folderPath.Value;%obj.cfg.tmp_unzipped_dir;%char(list_of_unzipped_files(1));
                  %disp(folder_path);
                  % add to the MATLAB search path
                  addpath(genpath(folder_path));%genpath doesnot add folder named private or resources in path as it is keyword in R2019a
                   
                   
                  %obj.WriteLog('Searching for slx and mdl file Files');
                  for k = 1: length(list_of_unzipped_files)
                      path = char(list_of_unzipped_files(k));
                       if endsWith(path,"slx") | endsWith(path,"mdl")
                           m= split(path,filesep);
                           
                           %m(end); log
                           %disp(list_of_unzipped_files(cnt));
                           fprintf('\nFound : %s',char(m(end)));
                           
                          
                           model_name = strrep(char(m(end)),'.slx','');
                           model_name = strrep(model_name,'.mdl','');
                          %Skip if Id and model name already in database 
                            if(~isempty(find(file_id_mdl_array==strcat(num2str(id),char(m(end))), 1)))
                               fprintf('File Id %d %s already processed. Skipping', id, char(m(end)) );
                                continue
                            end
                            
                           try
                               load_system(model_name);
                               fprintf(' %s loaded',model_name);      
                           catch ME
                              fprintf('ERROR loading %s',model_name);                    
                               fprintf('ERROR ID : %s', ME.identifier);
                               fprintf(['ERROR MSG : ' ME.message]);
                                continue;
                               %rmpath(genpath(folder_path));
                           end
      
                            try
                       
                               %obj.WriteLog(['Calculating Number of blocks of ' model_name]);
                               blk_cnt=obj.get_total_block_count(model_name);
                               %obj.WriteLog([' Number of blocks of' model_name ':' num2str( blk_cnt)]);

                              
                               %obj.WriteLog(['Populating level wise | hierarchial info of ' model_name]);
                               [total_lines_cnt,total_descendant_count,ncs_count,unique_sfun_count,sfun_reused_key_val,blk_type_count,modelrefMap_reused_val,unique_mdl_ref_count] = obj.lvl_info.populate_hierarchy_info(id, model_name,hierar_File);
                               
                               %obj.WriteLog([' level wise Info Updated of' model_name]);
                               %obj.WriteLog(sprintf("Lines= %d Descendant count = %d NCS count=%d Unique S fun count=%d",...
                               %total_lines_cnt,total_descendant_count,ncs_count,unique_sfun_count));
                                
                                %obj.WriteLog(['Populating block info of ' model_name]); 
                               %[t,blk_type_count]=
                               %sldiagnostics(model_name,'CountBlocks');
                               %Only gives top level block types
                                blk_type_keys = blk_type_count.keys();
                               
                                for K = 1 :length(blk_type_keys)
                                    fprintf(blk_info_File.Value,'%d,%s,%s,%d\n',id,model_name,blk_type_keys{K},blk_type_count.get(blk_type_keys{K}));
                                    %obj.write_to_database(file_name,mdl_name,blk_type_keys{K},blk_type_count.get(blk_type_keys{K}));
                                end
                               %obj.blk_info.populate_block_info(id,model_name,blk_type_count);
                               %obj.WriteLog([' Block Info Updated of' model_name]);
                              
                           
                              %obj.WriteLog(['Calculating other metrics of :' model_name]);
                               [schk_blk_count,agg_subsys_count,subsys_count,depth,liblink_count]=(obj.extract_metrics(model_name));
                               %obj.WriteLog(sprintf(" id = %d Name = %s BlockCount= %d AGG_SubCount = %d SubSys_Count=%d Hierarchial_depth=%d LibLInkedCount=%d",...
                                  % id,char(m(end)),blk_cnt, agg_subsys_count,subsys_count,depth,liblink_count));
                           catch 
                               
                               %obj.WriteLog(sprintf('ERROR Calculating non compiled metrics for  %s',model_name));                    
                                %obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                %obj.WriteLog(['ERROR MSG : ' ME.message]);
                                continue;
                               %rmpath(genpath(folder_path));
                           end
                               isLib = bdIsLibrary(model_name);% Generally Library are precompiled:  https://www.mathworks.com/help/simulink/ug/creating-block-libraries.html
                               if isLib
                                   %obj.WriteLog(sprintf('%s is a library. Skipping calculating cyclomatic metric/compile check',model_name));
                                   obj.close_the_model(model_name);
                                   try
                                   fprintf(metric_File.Value,'%d,%s,%d,%d,%d ,%d,%d,%d,%d,%d,%d, %d,%d,%d,%s,%s,%s, %d,%d,%d,%d, %s,%s,%d\n',id,char(m(end))...
                                       ,1,schk_blk_count,blk_cnt,...
                                       subsys_count,agg_subsys_count,depth,liblink_count,-1,-1 ...
                                   ,-1,-1,-1,'N/A','N/A','N/A'...
                                            ,-1,-1,-1,-1 ...
                                            ,'N/A','N/A',-1);  
                                  
                                   %obj.write_to_database(id,char(m(end)),1,schk_blk_count,blk_cnt,...
                                   %    subsys_count,agg_subsys_count,depth,liblink_count,-1,-1 ...
                                   %,-1,-1,-1,'N/A','N/A','N/A'...
                                   %         ,-1,-1,-1,-1 ...
                                   %         ,'N/A','N/A',-1);%blk_cnt);
                                   catch 
                                       %obj.WriteLog(sprintf('ERROR Inserting to Database %s',model_name));                    
                                        %obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                     %obj.WriteLog(['ERROR MSG : ' ME.message]);
                                   end
                                   continue
                               end
                               
                               cyclo_complexity = -1; % If model compile fails. cant check cyclomatic complexity. Hence -1 
                               compiles = 0;
                               compile_time = -1;
                               num_alge_loop = 0;
                               try                               
                                  %obj.WriteLog(sprintf('Checking if %s compiles?', model_name));
                                  timeout = timer('TimerFcn',' com.mathworks.mde.cmdwin.CmdWinMLIF.getInstance().processKeyFromC(2,67,''C'')','StartDelay',120);
                                    start(timeout);
                                   compiles = obj.does_model_compile(model_name);
                                    stop(timeout);
                                    delete(timeout);
                                    obj.close_the_model(model_name);
                               catch ME
                                   delete(timeout);
                                    %obj.WriteLog(sprintf('ERROR Compiling %s',model_name));                    
                                    %obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                    %obj.WriteLog(['ERROR MSG : ' ME.message]);
                        
                               end
                               if compiles
                                   try
                                        [~, sRpt] = sldiagnostics(model_name, 'CompileStats');
                                        compile_time = sum([sRpt.Statistics(:).WallClockTime]);
                                        %obj.WriteLog(sprintf(' Compile Time of  %s : %d',model_name,compile_time)); 
                                        
                                        %obj.WriteLog(sprintf(' Checking ALgebraic Loop of  %s',model_name)); 
                                        
                                        num_alge_loop = obj.get_number_of_algebraic_loops(model_name);
                                        %obj.WriteLog(sprintf(' Algebraic Loop of  %s : %d',model_name,num_alge_loop)); 
                                        
                                   catch
                                       ME
                                        %obj.WriteLog(sprintf('ERROR calculating compile time or algebraic loop of  %s',model_name)); 
                                        %obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                          %obj.WriteLog(['ERROR MSG : ' ME.message]);
                                       
                                   end
                                   try
                                       %obj.WriteLog(['Calculating cyclomatic complexity of :' model_name]);
                                       cyclo_complexity = obj.extract_cyclomatic_complexity(model_name);
                                       %obj.WriteLog(sprintf("Cyclomatic Complexity : %d ",cyclo_complexity));
                                   catch ME
                                        %obj.WriteLog(sprintf('ERROR Calculating Cyclomatic Complexity %s',model_name));                    
                                        %obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                        %obj.WriteLog(['ERROR MSG : ' ME.message]);
                                   end
                               end
                               %}
                               %if (compiles)
                                   
                                    try
                                       %obj.WriteLog(['Calculating Simulation Time of the model :' model_name]);
                                       simulation_time = obj.get_simulation_time(model_name);
                                       %obj.WriteLog(sprintf("Simulation Time  : %d (-1 means cant calculate due to Inf stoptime) ",simulation_time));
                                   catch 
                                        %obj.WriteLog(sprintf('ERROR Calculating Simulation Time of %s',model_name));                    
                                        %obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                        %obj.WriteLog(['ERROR MSG : ' ME.message]);

                                    end
                                    target_hw = '';
                                    solver_type = '';
                                    sim_mode = '';
                                     try
                                       %obj.WriteLog(['Calculating Target Hardware | Simulation Mode | Solver of ' model_name]);
                                       [target_hw,solver_type,sim_mode] = obj.get_solver_hw_simmode(model_name);
                                       
                                       %obj.WriteLog(sprintf("Target HW : %s Solver Type : %s Sim_mode : %s ",target_hw,solver_type,sim_mode));
                                   catch ME
                                        %obj.WriteLog(sprintf('ERROR Calculating Simulation Time of %s',model_name));                    
                                        %obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                        %obj.WriteLog(['ERROR MSG : ' ME.message]);

                                     end
                                  
                                 
                                   
                                 
                                   
                                 fprintf(metric_File.Value,'%d,%s,%d,%d,%d ,%d,%d,%d,%d,%d,%d, %d,%d,%d,%s,%s,%s, %d,%d,%d,%d, %s,%s,%d\n',id,char(m(end)),...
                                     0,schk_blk_count,blk_cnt,subsys_count,...
                                           agg_subsys_count,depth,liblink_count,compiles,cyclo_complexity...
                                            ,simulation_time,compile_time,num_alge_loop,target_hw,solver_type,sim_mode...
                                           ,total_lines_cnt,total_descendant_count,ncs_count,unique_sfun_count...
                                            ,sfun_reused_key_val...
                                            ,modelrefMap_reused_val,unique_mdl_ref_count);  
                                  
                               %end
                               %obj.WriteLog(sprintf("Writing to Database"));
                               %try
                                %    success = obj.write_to_database(id,char(m(end)),0,schk_blk_count,blk_cnt,subsys_count,...
                                 %           agg_subsys_count,depth,liblink_count,compiles,cyclo_complexity...
                                  %          ,simulation_time,compile_time,num_alge_loop,target_hw,solver_type,sim_mode...
                                   %         ,total_lines_cnt,total_descendant_count,ncs_count,unique_sfun_count...
                                    %        ,sfun_reused_key_val...
                                     %       ,modelrefMap_reused_val,unique_mdl_ref_count);%blk_cnt);
                               %catch
                                    %obj.WriteLog(sprintf('ERROR Inserting to Database %s',model_name));                    
                                    %obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                    %obj.WriteLog(['ERROR MSG : ' ME.message]);
                               %end
                               %if success ==1
                                   %obj.WriteLog(sprintf("Successful Insert to Database"));
                                %   success = 0;
                               %end
                           obj.close_the_model(model_name);
                       end
                  end
                 % close all hidden;
                 
                rmpath(genpath(folder_path));
                try
                    obj.delete_tmp_folder_content(folderPath.Value);
                catch 
                    %obj.WriteLog(sprintf('ERROR deleting'));                    
                                %obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                %obj.WriteLog(['ERROR MSG : ' ME.message]);
                end
                            
                %processed_file_count=processed_file_count+1;

           end
           %obj.WriteLog("Cleaning up Tmp files")
           obj.cleanup()
           obj.write_from_file_to_database()
   
        end
        
        function write_from_file_to_database(obj)
            [list_of_files] = dir(pwd); %gives struct with date, name, size info, https://www.mathworks.com/matlabcentral/answers/282562-what-is-the-difference-between-dir-and-ls
            tf = ismember( {list_of_files.name}, {'.', '..'});
            list_of_files(tf) = [];  %remove current and parent directory.
           %Loop over each Zip File 
           for cnt = 1 : size(list_of_files,1)
              
                    name =strtrim(char(list_of_files(cnt).name));
                   
                    if(endsWith(name,"_metric"))
                        fid = fopen(name);
                        tline = fgetl(fid);
                        while ischar(tline)&& ~isempty(tline)
                            tline_split=split(strtrim(tline),",");
                            try
                            obj.write_to_database(str2double(tline_split{1}),tline_split{2},str2double(tline_split{3}),...
                                        str2double(tline_split{4}),str2double(tline_split{5}),str2double(tline_split{6}),...
                                            str2double(tline_split{7}),str2double(tline_split{8}),str2double(tline_split{9}),...
                                            str2double(tline_split{10}),str2double(tline_split{11}),str2double(tline_split{12}),...
                                           str2double(tline_split{13}),str2double(tline_split{14}),tline_split{15},...
                                           tline_split{16},tline_split{17},str2double(tline_split{18}),...
                                           str2double(tline_split{19}),str2double(tline_split{20}),str2double(tline_split{21}),...
                                           tline_split{22},tline_split{23},str2double(tline_split{24})...
                                           );%blk_cnt);
                            catch ME
                                ME
                                tline = fgetl(fid);
                                continue
                            end

                            tline = fgetl(fid);
                        end
                        
                    elseif(endsWith(name,"_hierar"))
                        fid = fopen(name);
                        tline = fgetl(fid);
                        while ischar(tline) && ~isempty(tline)
                           tline_split=split(strtrim(tline),",");
                            try
                            obj.lvl_info.write_to_database(str2double(tline_split{1}),tline_split{2},str2double(tline_split{3}),str2double(tline_split{4}),...
                                            str2double(tline_split{5}),str2double(tline_split{6}),...
                                            str2double(tline_split{7}));%blk_cnt);
                            catch ME
                                ME
                                tline = fgetl(fid);
                                continue
                            end
                            tline = fgetl(fid);
                        end
                            
                    elseif endsWith(name,"_blk_info")
                        fid = fopen(name);
                        tline = fgetl(fid);
                        while ischar(tline)&& ~isempty(tline)
                            tline_split=split(strtrim(tline),",");
                            try
                            obj.blk_info.write_to_database(str2double(tline_split{1}),tline_split{2},tline_split{3},str2double(tline_split{4}));%blk_cnt);
                            catch ME
                                ME
                               tline = fgetl(fid);
                                continue
                            end
                             tline = fgetl(fid);
                        end
                        
                    end
                    
            
                   
                    
           end
        end
        

        function x = get_total_block_count(~,model)
            %load_system(model)
            [refmodels,modelblock] = find_mdlrefs(model);
           
            % Open dependent models
            for i = 1:length(refmodels)
                load_system(refmodels{i});
                %obj.WriteLog(sprintf(' %s loaded',refmodels{i}));
            end
            %% Count the number of instances
            mCount = zeros(size(refmodels));
            mCount(end) = 1; % Last element is the top model, only one instance
            for i = 1:length(modelblock)
                mod = get_param(modelblock{i},'ModelName');
                mCount = mCount + strcmp(mod,refmodels);
            end
            %%
            %for i = 1:length(mDep)
             %   disp([num2str(mCount(i)) ' instances of' mDep{i}])
            %end
            %disp(' ')

            %% Loop over dependencies, get number of blocks
            s = cell(size(refmodels));
            for i = 1:length(refmodels)
                [~,s{i}] = sldiagnostics(refmodels{i},'CountBlocks');
                %obj.WriteLog([refmodels{i} ' has ' num2str(s{i}(1).count) ' blocks'])
            end
            %% Multiply number of blocks, times model count, add to total
            totalBlocks = 0;
            for i = 1:length(refmodels)
                totalBlocks = totalBlocks + s{i}(1).count * mCount(i);
            end
            %disp(' ')
            %disp(['Total blocks: ' num2str(totalBlocks)])   
            x= totalBlocks;
            %close_system(model)
        end
        
        %Calculates model metrics. Models doesnot need to be compilable.
        function [blk_count,agg_sub_count,subsys_count,subsys_depth,liblink_count] = extract_metrics(~,model)
                
               
                
                %save_system(model,model+_expanded)
                metric_engine = slmetric.Engine();
                %Simulink.BlockDiagram.expandSubsystem(block)
                setAnalysisRoot(metric_engine, 'Root',  model);
                mData ={'mathworks.metrics.SimulinkBlockCount' ,'mathworks.metrics.SubSystemCount','mathworks.metrics.SubSystemDepth',...
                    'mathworks.metrics.LibraryLinkCount'};
                execute(metric_engine,mData)
                % Include referenced models and libraries in the analysis, 
                %     these properties are on by default
                   % metric_engine.ModelReferencesSimulationMode = 'AllModes';
                   % metric_engine.AnalyzeLibraries = 1;
                  res_col = getMetrics(metric_engine,mData,'AggregationDepth','all');
                count =0;
                blk_count =0;
                depth=0;
                agg_count=0;
                liblink_count = 0;
                
                for n=1:length(res_col)
                    if res_col(n).Status == 0
                        results = res_col(n).Results;

                        for m=1:length(results)
                            
                            %disp(['MetricID: ',results(m).MetricID]);
                            %disp(['  ComponentPath: ',results(m).ComponentPath]);
                            %disp(['  Value: ',num2str(results(m).Value)]);
                            if strcmp(results(m).ComponentPath,model)
                                if strcmp(results(m).MetricID ,'mathworks.metrics.SubSystemCount')
                                    count = results(m).Value;
                                    agg_count =results(m).AggregatedValue;
                                elseif strcmp(results(m).MetricID,'mathworks.metrics.SubSystemDepth') 
                                    depth =results(m).Value;
                                elseif strcmp(results(m).MetricID,'mathworks.metrics.SimulinkBlockCount') 
                                    blk_count=results(m).AggregatedValue;
                                elseif strcmp(results(m).MetricID,'mathworks.metrics.LibraryLinkCount')%Only for compilable models
                                    liblink_count=results(m).AggregatedValue;
                                end
                            end
                            %metricData{cnt+1,1} = results(m).MetricID;
                            %metricData{cnt+1,2} = results(m).ComponentPath;
                            %metricData{cnt+1,3} = results(m).Value;
                            %cnt = cnt + 1;
                        end
                    else
                        %obj.WriteLog(['No results for:',res_col(n).MetricID]);
                    end
               
                end
                subsys_count = count;
                subsys_depth = depth;
                agg_sub_count = agg_count;
                
          
                
       
        end
        
        %to clean up files MATLAB generates while processing
        function cleanup(~)
            extensions = {'slxc','c','mat',...
               'tlc','mexw64'}; % cell arrAY.. Add file extesiion 
            for i = 1 :  length(extensions)
                delete( strcat("*.",extensions(i)));
            end
            
        end
        
        %Extract Cyclomatic complexity %MOdels needs to be compilable 
        function [cyclo_metric] = extract_cyclomatic_complexity(~,model)
                
            
                
                %save_system(model,model+_expanded)
                metric_engine = slmetric.Engine();
                %Simulink.BlockDiagram.expandSubsystem(block)
                setAnalysisRoot(metric_engine, 'Root',  model);
                mData ={'mathworks.metrics.CyclomaticComplexity'};
                try
                    execute(metric_engine,mData);
                catch
                    %obj.WriteLog("Error Executing Slmetric API");
                end
                res_col = getMetrics(metric_engine,mData,'AggregationDepth','all');
                
                cyclo_metric = -1 ; %-1 denotes cyclomatic complexit is not computed at all
                for n=1:length(res_col)
                    if res_col(n).Status == 0
                        results = res_col(n).Results;

                        for m=1:length(results)
                            
                            %disp(['MetricID: ',results(m).MetricID]);
                            %disp(['  ComponentPath: ',results(m).ComponentPath]);
                            %disp(['  Value: ',num2str(results(m).Value)]);
                            if strcmp(results(m).ComponentPath,model)
                                if strcmp(results(m).MetricID ,'mathworks.metrics.CyclomaticComplexity')
                                    cyclo_metric =results(m).AggregatedValue;
                                end
                            end
                        end
                    else
                        
                        %obj.WriteLog(['No results for:',res_col(n).MetricID]);
                    end
                    
                end
                
       
        end
    end
    
        
        

end
