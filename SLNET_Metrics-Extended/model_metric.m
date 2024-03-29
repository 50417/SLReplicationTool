classdef model_metric < handle
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
        blk_count_old; % Block Count based on Slcorpus0 custom tool
        childModelMap; % used by  Slcorpus0 custom tool
        hidden_lines_count_old; %used by Slcorpus0 custom tool
        unique_lines_count_old; %used by Slcorpus0 custom tool
        map;%used by Slcorpus0 custom tool
        
        conn;
        colnames = {'FILE_ID','Model_Name','file_path','is_test','is_Lib','SCHK_Block_count','SLDiag_Block_count','C_corpus_blk_count','C_corpus_hidden_conn','C_corpus_conn','C_corpus_hierar_depth','C_corpus_cyclo_metric','SubSystem_count_Top',...
            'Agg_SubSystem_count','Hierarchy_depth','LibraryLinked_Count',...,
            'compiles','CComplexity',...
            'Sim_time','Compile_time','Alge_loop_Cnt','target_hw','solver_type','sim_mode'...
            ,'total_ConnH_cnt','total_desc_cnt','ncs_cnt','scc_cnt','unique_sfun_count','sfun_nam_count'...
            ,'mdlref_nam_count','unique_mdl_ref_count'};
        coltypes = {'INTEGER','VARCHAR','VARCHAR','Numeric','Boolean','NUMERIC','NUMERIC','NUMERIC','Numeric','NUMERIC','NUMERIC','Numeric','Numeric','NUMERIC',...,
            'NUMERIC','NUMERIC','Boolean','NUMERIC','NUMERIC','NUMERIC','NUMERIC','VARCHAR','VARCHAR','VARCHAR'...
            ,'NUMERIC','NUMERIC','NUMERIC','NUMERIC','NUMERIC','VARCHAR'...
            ,'VARCHAR','NUMERIC'};
        
        logfilename = strcat('Model_Metric_LogFile',datestr(now, 'dd-mm-yy-HH-MM-SS'),'.txt')
        
       
    end
    
    
    
    methods
        %Constructor
        function obj = model_metric()
            warning on verbose
            obj.cfg = model_metric_cfg();
            obj.WriteLog("open");
            if obj.cfg.CODE_GEN
                obj.table_name = [obj.cfg.project_source '_Code_Gen'];
                obj.connect_code_gen_table();
            
            else
                obj.table_name = obj.cfg.table_name;
                obj.foreign_table_name = obj.cfg.foreign_table_name;

                obj.blk_info = get_block_info(); % extracts block info of top lvl... 
                obj.lvl_info = obtain_non_supported_hierarchial_metrics();
                obj.connect_table();
            
            end
            %Creates folder to extract zipped filed files in current
            %directory.
            if obj.cfg.tmp_unzipped_dir==""
                obj.cfg.tmp_unzipped_dir = "workdirtmp";
            end
            if(~exist(obj.cfg.tmp_unzipped_dir,'dir'))
                    mkdir(char(obj.cfg.tmp_unzipped_dir));
            end
            
           
        end
        %Gets simulation time of the model based on the models
        %configuration. If the stopTime of the model is set to Inf, then it
        % sets the simulation time to -1
        %What is simulation Time: https://www.mathworks.com/matlabcentral/answers/163843-simulation-time-and-sampling-time
        function sim_time = get_simulation_time(obj, model) % cs = configuarationSettings of a model
            cs = getActiveConfigSet(model) ;
            startTime = cs.get_param('StartTime');
            stopTime = cs.get_param('StopTime'); %returns a string when time is finite
            try
                startTime = eval(startTime);
                stopTime = eval(stopTime); %making sure that evaluation parts converts to numeric data
                if isfinite(stopTime) && isfinite(startTime) % isfinite() Check whether symbolic array elemtableents are finite
                    
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
        function WriteLog(obj,Data)
            global FID % https://www.mathworks.com/help/matlab/ref/global.html %https://www.mathworks.com/help/matlab/ref/persistent.html Local to functions but values are persisted between calls.
            if isempty(FID) & ~strcmp(Data,'open')
                
                 FID = fopen(['logs' filesep obj.logfilename], 'a+');
            end
            % Open the file
            if strcmp(Data, 'open')
                mkdir('logs');
              FID = fopen(['logs' filesep obj.logfilename], 'a+');
              if FID < 0
                 error('Cannot open file');
              end
              return;
            elseif strcmp(Data, 'close')
              fclose(FID);
              FID = -1;
            end
            try
                fprintf(FID, '%s: %s\n',datestr(now, 'dd/mm/yy-HH:MM:SS'), Data);
            catch ME
                ME
            end
            % Write to the screen at the same time:
            if obj.cfg.DEBUG
                fprintf('%s: %s\n', datestr(now, 'dd/mm/yy-HH:MM:SS'), Data);
            end
        end
        
        %concatenates file with source directory
        function full_path = get_full_path(obj,file)
            full_path = [obj.cfg.source_dir filesep file];
        end
        
        %Table for code generation metrics
        function connect_code_gen_table(obj)
            if isfile(obj.cfg.dbfile)
                obj.conn = sqlite(obj.cfg.dbfile,'connect');
            else
                obj.conn = sqlite(obj.cfg.dbfile,'create');
            end
            create_code_gen_table = strcat("CREATE  TABLE IF NOT EXISTS ",obj.table_name," ( ID INTEGER primary key autoincrement ,",...
                "FILE_ID INTEGER,Model_Name VARCHAR,file_path VARCHAR,created_date DATETIME,last_modified DATETIME,",...
                "EmbeddedCoder_SLNET Boolean,EmbeddedCoder Boolean,TargetLink Boolean, System_Target_File VARCHAR, Solver_Type VARCHAR, ",...
                "CONSTRAINT UPair  UNIQUE(FILE_ID, Model_Name,file_path) )");
            
            if obj.cfg.DROP_TABLES
                obj.WriteLog(sprintf("Dropping %s",obj.table_name))
                obj.drop_table();
                obj.WriteLog(sprintf("Dropped %s",obj.table_name))
            end
             obj.WriteLog(create_code_gen_table);
            exec(obj.conn,char(create_code_gen_table));
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
                ,'CONSTRAINT UPair  UNIQUE(FILE_ID, Model_Name,file_path) )');
            
            if obj.cfg.DROP_TABLES
                obj.WriteLog(sprintf("Dropping %s",obj.table_name))
                obj.drop_table();
                obj.WriteLog(sprintf("Dropped %s",obj.table_name))
            end
             obj.WriteLog(create_metric_table);
            exec(obj.conn,char(create_metric_table));
        end
        %Writes to database 
        function output_bol = write_to_database(obj,id,simulink_model_name,file_path, isTest,isLib,schK_blk_count,block_count,c_corpus_blk_cnt,c_corpus_hidden_conn,c_corpus_conn,c_corpus_hierar,c_corpus_cyclo_metric,...
                                            subsys_count,agg_subsys_count,depth,linkedcount,compiles, cyclo,...
                                            sim_time,compile_time,num_alge_loop,target_hw,solver_type,sim_mode,...
                                            total_lines_cnt,total_descendant_count,ncs_count,scc_count,unique_sfun_count,...
                                            sfun_reused_key_val,...
                                            modelrefMap_reused_val,unique_mdl_ref_count)%block_count)
            insert(obj.conn,obj.table_name,obj.colnames, ...
                {id,simulink_model_name,file_path,isTest,isLib,schK_blk_count,block_count,c_corpus_blk_cnt,c_corpus_hidden_conn,c_corpus_conn,c_corpus_hierar,c_corpus_cyclo_metric,subsys_count,...
                agg_subsys_count,depth,linkedcount,compiles,cyclo,...
                sim_time,compile_time,num_alge_loop,target_hw,solver_type,sim_mode...
                ,total_lines_cnt,total_descendant_count,ncs_count,scc_count,unique_sfun_count,...
                sfun_reused_key_val...
                ,modelrefMap_reused_val,unique_mdl_ref_count});%block_count});
            output_bol= 1;
        end
        %gets File Ids and model name and path from table
        function results = fetch_unique_identifier(obj)
            sqlquery = ['SELECT file_id,model_name,file_path FROM ' obj.table_name];
            results = fetch(obj.conn,sqlquery);
            
            %max(data)
        end
        
        %Construct matrix that concatenates 'file_id'+'model_name' to
        %avoid recalculating the metrics
        function unique_id_mdl = get_database_content(obj)
            
            file_id_n_model = obj.fetch_unique_identifier();
            [r,c]= size(file_id_n_model);
            unique_id_mdl = string.empty(0,r);
            for i = 1 : r
                if ispc
                    file_path = strrep(file_id_n_model(i,3),'/',filesep);
                elseif isunix
                    file_path = strrep(file_id_n_model(i,3),'\',filesep);
                end
                %https://www.mathworks.com/matlabcentral/answers/350385-getting-integer-out-of-cell   
                unique_id_mdl(i) = strcat(num2str(file_id_n_model{i,1}),file_id_n_model(i,2),file_path);
            
            end
         
        end
        
        
        %drop table Striclty for debugging purposes
        function drop_table(obj)
            %Strictly for debugginf purpose only
            sqlquery = ['DROP TABLE IF EXISTS ' obj.table_name];
            exec(obj.conn,char(sqlquery));
            %max(data)
        end
        

        
        %Deletes content of obj.cfg.tmp_unzipped_dir such that next
        %project can be analyzed
        function delete_tmp_folder_content(obj,folder)
            %{
            %Get a list of all files in the folder
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
              obj.WriteLog(sprintf( 'Now deleting %s\n', full_folder_name));
              rmdir(full_folder_name,'s');
             end
            
             file_pattern = fullfile(folder, '*.*'); 
            files = dir(file_pattern);%dir(filePattern);
            tf = ismember( {files.name}, {'.', '..'});
            files(tf) = [];
            for k = 1 : length(files)
              base_file_name = files(k).name;
              full_file_name = fullfile(folder, base_file_name);
              obj.WriteLog(sprintf( 'Now deleting %s\n', full_file_name));
              delete(full_file_name);
            end
            %}
            %fclose('all'); %Some files are opened by the models
            global FID;
            arrayfun(@fclose, setdiff(fopen('all'), FID));
            if exist('slprj', 'dir')
                rmdir('slprj','s');
            end
            if ispc
                rmdir(char(obj.cfg.tmp_unzipped_dir),'s');
                %system(strcat('rmdir /S /Q ' ," ",folder));
            elseif isunix
                system(char(strcat('rm -rf'," ",folder)))
            else 
                 rmdir(char(folder),'s');%https://www.mathworks.com/matlabcentral/answers/21413-error-using-rmdir
            end
            obj.WriteLog("open");
            rehash;
            java.lang.Thread.sleep(5);
            mkdir(char(folder));
            obj.cleanup();
            
        end
        
        %returns number of algebraic loop in the model. 
        %What is algebraic Loops :
        %https://www.mathworks.com/help/simulink/ug/algebraic-loops.html  https://www.mathworks.com/matlabcentral/answers/95310-what-are-algebraic-loops-in-simulink-and-how-do-i-solve-them
        function num_alge_loop = get_number_of_algebraic_loops(obj,model)
            alge_loops = Simulink.BlockDiagram.getAlgebraicLoops(model);
            num_alge_loop  = numel(alge_loops);            
        end
        

       
        %Checks if a models compiles for not
        function compiles = does_model_compile(obj,model)
                %eval(['mex /home/sls6964xx/Desktop/UtilityProgramNConfigurationFile/ModelMetricCollection/tmp/SDF-MATLAB-master/C/src/sfun_ndtable.cpp']);
               %'com.mathworks.mde.cmdwin.CmdWinMLIF.getInstance().processKeyFromC(2,67,''C'')'

                %obj.timeout = timer('TimerFcn'," ME = MException('Timeout:TimeExceeded','Time Exceeded While Compiling');throw(ME);",'StartDelay',1);
                %start(obj.timeout);
                eval([model, '([], [], [], ''compile'');'])
                obj.WriteLog([model ' compiled Successfully ' ]); 
                
               % stop(obj.timeout);
                %delete(obj.timeout);
                compiles = 1;
        end
        
        %Close the model
        % Close the model https://www.mathworks.com/matlabcentral/answers/173164-why-the-models-stays-in-paused-after-initialisation-state
        function obj= close_the_model(obj,model)
            try
               mdlWks = get_param(model,'ModelWorkspace');
               if ~isempty(mdlWks)
                   %https://www.mathworks.com/matlabcentral/answers/426-is-the-model-workspace-dirty
                   %intentiaonally setting it to false to close it. 
                  mdlWks.isDirty = 0; % Fix for 'The model '' must be compiled before it can be accessed programmatically'
                     clear(mdlWks);
               end
               obj.WriteLog(sprintf("Closing %s",model));
         
               close_system(model);
               bdclose(model);
            catch exception
               
                obj.WriteLog(exception.message);
                obj.WriteLog("Trying Again");
                if (strcmp(exception.identifier ,'Simulink:Commands:InvModelDirty' ))
                    obj.WriteLog("Force Closing");
                    bdclose(model);
                    return;
                end
                %eval([model '([],[],[],''sizes'')']);
                
                if (strcmp(exception.identifier ,'Simulink:Commands:InvModelClose' ) | strcmp(exception.identifier ,'Simulink:Engine:InvModelClose'))
                    eval([model '([],[],[],''term'')']);
                    close_system(model);
                     bdclose(model);
                     return;

                end
                if (strcmp(exception.identifier ,'Simulink:Commands:InvSimulinkObjectName' ))
                    bdclose('all');
                    return;
                end
                %eval([model '([],[],[],''term'')']);

                bdclose('all');
                %obj.close_the_model(model);
            end
        end
        
        function [target_hw,solver_type,sim_mode]=get_solver_hw_simmode(obj,model)
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
    
               
           processed_file_count = 1;
           %Loop over each Zip File 
           for cnt = 1 : size(list_of_zip_files)
               
                    test_harness = struct([]);

                    name =strtrim(char(list_of_zip_files(cnt).name));  
              
                    obj.get_full_path(name);
                    log = strcat("Processing #",  num2str(processed_file_count), " :File Id ",list_of_zip_files(cnt).name) ;
                    obj.WriteLog(log);
                   
                    tmp_var = strrep(name,'.zip',''); 
                    id = str2num(tmp_var);
         
                    %id==70131 || kr_billiards_debug crashes MATLAB when
                    %compiles in windows only MATLAB 2018b MATLAB 2019b
                   %id == 67689 cant find count becuase referenced model has
                   %protected component.
                   %id == 152409754 hangs because requires select folder for installation input
                
                   %id ===24437619 %suspious56873326
                   %id == 25870564 no license | Not in SLNet 
                   % id==45571425 No license | NOt in SLNet
                   % Cocoteam/benchmark
                   %id == 73878  % Requires user input
                   %id ==722 % crashes on Windowns Matlab 2019b in windows Only while SimCheck extract metrics 2018b not
                   %checked
                   %id==51243 Changes directory while analyzing. 
                   %id == 51705 % Requires user input: Enter morse code. 
                   if ~obj.cfg.CODE_GEN    
                       if ispc
                            if (id==70131 || id==51243 || id ==24437619 || id==198236388 || id == 124448612 ) % potential crashes or hangs
                                continue
                            end
                       end
                       if (id==44836 | id==63223) % models in these project hangs while calculating cyclomatic complexity. Babysit
                           continue
                       end
                       if (id==51705 |  id==51243) %  % Requires user input: Enter morse code. 51234 chnges directory after analysis.. Need to babysit
                                continue
                       end
                   end
         
                   %unzip the file TODO: Try CATCH
                   obj.WriteLog('Extracting Files');
                   list_of_unzipped_files = unzip( char(obj.get_full_path(list_of_zip_files(cnt).name)), char(obj.cfg.tmp_unzipped_dir));
                  %Assumption Zip file always consists of a single folder .
                  %Adapt later.
                  folder_path= obj.cfg.tmp_unzipped_dir;%char(list_of_unzipped_files(1));
                  
                  if strcmp(obj.cfg.project_source,"Tutorial")
                      list_of_unzipped_files = {'sldemo_fuelsys.slx', 'sldemo_auto_climatecontrol.slx', 'sldemo_autotrans.slx', 'sldemo_auto_carelec.slx', 'sldemo_suspn.slx', 'sldemo_auto_climate_elec.slx',...
                'sldemo_absbrake.slx', 'sldemo_enginewc.slx', 'sldemo_engine.slx', 'sldemo_fuelsys_dd.slx', 'sldemo_clutch.slx', 'sldemo_clutch_if.slx',...
                'aero_guidance.slx', 'sldemo_radar_eml.slx', 'aero_atc.slx', 'slexAircraftPitchControlExample.slx', 'aero_six_dof.slx', 'aero_dap3dof.slx',...
                'slexAircraftExample.slx', 'aero_guidance_airframe.slx',...
            'sldemo_antiwindup.slx', 'sldemo_pid2dof.slx', 'sldemo_bumpless.slx',...
            'aeroblk_wf_3dof.slx', 'asbdhc2.slx', 'asbswarm.slx', 'aeroblk_HL20.slx', 'asbQuatEML.slx', 'aeroblk_indicated.slx', 'aeroblk_six_dof.slx',...
                'asbGravWPrec.slx', 'aeroblk_calibrated.slx', 'aeroblk_self_cond_cntr.slx',...
            'sldemo_mdlref_variants_enum.slx', 'sldemo_mdlref_bus.slx','sldemo_mdlref_conversion.slx','sldemo_mdlref_counter_datamngt.slx','sldemo_mdlref_dsm.slx','sldemo_mdlref_dsm_bot.slx','sldemo_mdlref_dsm_bot2.slx','sldemo_mdlref_F2C.slx'};

                  end
                  %disp(folder_path);
                  % add to the MATLAB search path
                  if ~strcmp(obj.cfg.project_source,"Tutorial")
                  addpath(genpath(char(folder_path)));%genpath doesnot add folder named private or resources in path as it is keyword in R2019a
                  end
                  
                  obj.WriteLog('Searching for slx and mdl file Files');
                  for cnt = 1: length(list_of_unzipped_files)
                      
                      file_path = char(list_of_unzipped_files(cnt));
                      
                      %if ~strcmp(file_path,"sldemo_auto_carelec.slx")
                      %%continue
                      %end
                       if endsWith(file_path,"slx") | endsWith(file_path,"mdl")
                            if strcmp(obj.cfg.project_source,"Tutorial")
                                m = string();
                                m(end)= file_path;
                            else
                                 m= split(file_path,filesep);
                            end
                           
                           %m(end); log
                           %disp(list_of_unzipped_files(cnt));
                           obj.WriteLog(sprintf('\nFound : %s',char(m(end))));
                           
                            if strcmp(obj.cfg.project_source,"Tutorial")
                                model_name = char(strrep(m,'.slx',''));
                            else
                           model_name = strrep(char(m(end)),'.slx','');
                           model_name = strrep(model_name,'.mdl','');
                            end
                          %Skip if Id and model name already in database 
                            if(~isempty(find(file_id_mdl_array==strcat(num2str(id),char(m(end)),file_path), 1)))
                               obj.WriteLog(sprintf('File Id %d %s already processed. Skipping', id, char(m(end)) ));
                                continue
                            end
                            
                           try
                               load_system(file_path);
                               obj.WriteLog(sprintf(' %s loaded',model_name));      
                           catch ME
                               obj.WriteLog(sprintf('ERROR loading %s',model_name));                    
                                obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                obj.WriteLog(['ERROR MSG : ' ME.message]);
                                continue;
                               %rmpath(genpath(folder_path));
                           end
                           
                           if ~obj.cfg.CODE_GEN    
                               if ~obj.cfg.PROCESS_LIBRARY
                                   isLib = bdIsLibrary(model_name);% Generally Library are precompiled:  https://www.mathworks.com/help/simulink/ug/creating-block-libraries.html
                                   if isLib
                                       obj.WriteLog(sprintf('%s is a library. Skipping calculating cyclomatic metric/compile check',model_name));
                                       obj.close_the_model(model_name);
                                       try
                                       obj.write_to_database(id,char(m(end)),file_path,-1,1,-1,-1,-1,-1,-1,-1,-1,...
                                           -1,-1,-1,-1,-1,-1 ...
                                       ,-1,-1,-1,'N/A','N/A','N/A'...
                                                ,-1,-1,-1,-1,-1 ...
                                                ,'N/A','N/A',-1);%blk_cnt);
                                       catch ME
                                           obj.WriteLog(sprintf('ERROR Inserting to Database %s',model_name));                    
                                            obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                         obj.WriteLog(['ERROR MSG : ' ME.message]);
                                       end
                                       continue
                                   end
                               end
                           
                           
                             try
                                
                                   %sLDIAGNOSTIC BLOCK COUNT .. BASED ON https://blogs.mathworks.com/simulink/2009/08/11/how-many-blocks-are-in-that-model/
                               obj.WriteLog(['Calculating Number of blocks (BASED ON sLDIAGNOSTIC TOOL) of ' model_name]);
                               blk_cnt=obj.get_total_block_count(model_name);
                               obj.WriteLog([' Number of blocks(BASED ON sLDIAGNOSTIC TOOL) of' model_name ':' num2str( blk_cnt)]);

                              obj.WriteLog(['Calculating  metrics  based on Simulink Check API of :' model_name]);
                               [schk_blk_count,agg_subsys_count,subsys_count,subsys_depth,liblink_count,depth,component_in_every_lvl,mdlref_depth_map]=(obj.extract_metrics(model_name));
                               obj.WriteLog(sprintf(" id = %d Name = %s BlockCount= %d AGG_SubCount = %d SubSys_Count=%d Subsystem_depth=%d LibLInkedCount=%d",...
                                   id,char(m(end)),blk_cnt, agg_subsys_count,subsys_count,depth,liblink_count));
                               
                               
                               
                               obj.WriteLog(['Populating level wise | hierarchial info of ' model_name]);
                               [total_lines_cnt,total_descendant_count,ncs_count,scc_count,unique_sfun_count,sfun_reused_key_val,blk_type_count,modelrefMap_reused_val,unique_mdl_ref_count] = obj.lvl_info.populate_hierarchy_info(id, char(m(end)),depth,component_in_every_lvl,mdlref_depth_map,file_path);
                               obj.WriteLog([' level wise Info Updated of' model_name]);
                               obj.WriteLog(sprintf("Lines= %d Descendant count = %d NCS count=%d Unique S fun count=%d",...
                               total_lines_cnt,total_descendant_count,ncs_count,unique_sfun_count));
                                
                                obj.WriteLog(['Populating block info of ' model_name]); 
                               %[t,blk_type_count]=
                               %sldiagnostics(model_name,'CountBlocks');
                               %Only gives top level block types
                               obj.blk_info.populate_block_info(id,char(m(end)),blk_type_count,file_path);
                               obj.WriteLog([' Block Info Updated of' model_name]);
                              
                               
                                
                             
                           
                              
                           catch ME
                             
                               obj.WriteLog(sprintf('ERROR Calculating non compiled metrics for  %s. Database not updated',model_name));                    
                                obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                obj.WriteLog(['ERROR MSG : ' ME.message]);
                                continue;
                               %rmpath(genpath(folder_path));
                             end
                             
                             isTest = -1;

                               if ~isempty(sltest.harness.find(model_name,'SearchDepth',depth))
                                   test_harness = [test_harness,sltest.harness.find(model_name,'SearchDepth',depth)];
                                    obj.WriteLog(sprintf('File Id %d : model : %s has %d test harness',...
                                        id, char(m(end))  ,length(sltest.harness.find(model_name,'SearchDepth',depth))));
                                end
                           
                           if obj.cfg.PROCESS_LIBRARY
                               isLib = bdIsLibrary(model_name);% Generally Library are precompiled:  https://www.mathworks.com/help/simulink/ug/creating-block-libraries.html
                               if isLib
                                   obj.WriteLog(sprintf('%s is a library. Skipping calculating cyclomatic metric/compile check',model_name));
                                   obj.close_the_model(model_name);
                                   try
                                   obj.write_to_database(id,char(m(end)),file_path,-1,1,schk_blk_count,blk_cnt,c_corpus_blk_cnt,c_corpus_hidden_conn,c_corpus_conn,c_corpus_hierar,c_corpus_cyclo_metric,...
                                       subsys_count,agg_subsys_count,depth,liblink_count,-1,-1 ...
                                   ,-1,-1,-1,'N/A','N/A','N/A'...
                                            ,-1,-1,-1,-1,-1 ...
                                            ,'N/A','N/A',-1);%blk_cnt);
                                   catch ME
                                       obj.WriteLog(sprintf('ERROR Inserting to Database %s',model_name));                    
                                        obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                     obj.WriteLog(['ERROR MSG : ' ME.message]);
                                   end
                                   continue
                               end
                           end
                               
                               cyclo_complexity = -1; % If model compile fails. cant check cyclomatic complexity. Hence -1 
                               c_corpus_cyclo_metric = -1; 
                               compiles = 0;
                               compile_time = -1;
                               num_alge_loop = -1;
                               try                               
                                  obj.WriteLog(sprintf('Checking if %s compiles?', model_name));
                                   timeout = timer('TimerFcn',' com.mathworks.mde.cmdwin.CmdWinMLIF.getInstance().processKeyFromC(2,67,''C'')','StartDelay',120);
                                    start(timeout);
                                   compiles = obj.does_model_compile(model_name);
                                    %To replicate the numbers in Slcorpus0
                                   %Paper : models need to be compiled or
                                   %else block count varies. See sldemo_auto_climate_elec
                                   % Only to be run in R2017a for
                                   % reproducing
                                   obj.blk_count_old = 0;
                                   obj.hidden_lines_count_old = 0;
                                   obj.unique_lines_count_old = 0;
                                   obj.map = mymap();
                                   obj.childModelMap = mymap();
                                   
                                   obj.obtain_hierarchy_metrics_old(model_name,1,false, false);
                                   
                                   c_corpus_blk_cnt = obj.blk_count_old;
                                    c_corpus_hidden_conn = obj.hidden_lines_count_old ;
                                    c_corpus_conn = obj.unique_lines_count_old ;
                                    c_corpus_hierar = obj.map.len_keys();
                                    
                                    stop(timeout);
                                    delete(timeout);
                                    obj.close_the_model(model_name);
                               catch ME
                                    %stop(obj.timeout);
                                    delete(timeout); 
                                   %To replicate the numbers in Slcorpus0
                                   %Paper : models need to be compiled or
                                   %else block count varies. See sldemo_auto_climate_elec
                                   % Only to be run in R2017a for
                                   % reproducing

                                   obj.blk_count_old = 0;
                                   obj.hidden_lines_count_old = 0;
                                   obj.unique_lines_count_old = 0;
                                   obj.childModelMap = mymap();
                                   obj.map = mymap();
                                   
                                   obj.obtain_hierarchy_metrics_old(model_name,1,false, false);
                                   
                                   c_corpus_blk_cnt = obj.blk_count_old;
                                   c_corpus_hidden_conn = obj.hidden_lines_count_old ;
                                    c_corpus_conn = obj.unique_lines_count_old ;
                                    c_corpus_hierar = obj.map.len_keys();
                                    
                                    obj.WriteLog(sprintf('ERROR Compiling %s',model_name));                    
                                    obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                    obj.WriteLog(['ERROR MSG : ' ME.message]);
                        
                               end
                               if compiles
                                   try
                                        [~, sRpt] = sldiagnostics(model_name, 'CompileStats');
                                        compile_time = sum([sRpt.Statistics(:).WallClockTime]);
                                        obj.WriteLog(sprintf(' Compile Time of  %s : %d',model_name,compile_time)); 
                                        
                                        obj.WriteLog(sprintf(' Checking ALgebraic Loop of  %s',model_name)); 
                                        
                                        num_alge_loop = obj.get_number_of_algebraic_loops(model_name);
                                        obj.WriteLog(sprintf(' Algebraic Loop of  %s : %d',model_name,num_alge_loop)); 
                                        
                                   catch
                                       ME
                                        obj.WriteLog(sprintf('ERROR calculating compile time or algebraic loop of  %s',model_name)); 
                                        obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                          obj.WriteLog(['ERROR MSG : ' ME.message]);
                                       
                                   end
                                   try
                                       obj.WriteLog(['Calculating cyclomatic complexity of :' model_name]);
                                       cyclo_complexity = obj.extract_cyclomatic_complexity(model_name);
                                       c_corpus_cyclo_metric = obj.extract_cyclomatic_complexity_C_corpus(model_name);
                                       
                                       obj.WriteLog(sprintf("Cyclomatic Complexity : %d ",cyclo_complexity));
                                   catch ME
                                        obj.WriteLog(sprintf('ERROR Calculating Cyclomatic Complexity %s',model_name));                    
                                        obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                        obj.WriteLog(['ERROR MSG : ' ME.message]);
                                   end
                               end
                               %}
                               %if (compiles)
                                   
                                    try
                                       obj.WriteLog(['Calculating Simulation Time of the model :' model_name]);
                                       simulation_time = obj.get_simulation_time(model_name);
                                       obj.WriteLog(sprintf("Simulation Time  : %d (-1 means cant calculate due to Inf stoptime) ",simulation_time));
                                   catch ME
                                        obj.WriteLog(sprintf('ERROR Calculating Simulation Time of %s',model_name));                    
                                        obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                        obj.WriteLog(['ERROR MSG : ' ME.message]);

                                    end
                                    target_hw = '';
                                    solver_type = '';
                                    sim_mode = '';
                                     try
                                       obj.WriteLog(['Calculating Target Hardware | Simulation Mode | Solver of ' model_name]);
                                       [target_hw,solver_type,sim_mode] = obj.get_solver_hw_simmode(model_name);
                                       obj.WriteLog(sprintf("Target HW : %s Solver Type : %s Sim_mode : %s ",target_hw,solver_type,sim_mode));
                                   catch ME
                                        obj.WriteLog(sprintf('ERROR Calculating Simulation Time of %s',model_name));                    
                                        obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                        obj.WriteLog(['ERROR MSG : ' ME.message]);

                                     end
                                  
                                 
                                   
                                 
                                   
                                   
                               %end
                               obj.WriteLog(sprintf("Writing to Database"));
                               success = 0;
                               try
                                    success = obj.write_to_database(id,char(m(end)),file_path,isTest,0,schk_blk_count,blk_cnt,c_corpus_blk_cnt,c_corpus_hidden_conn,c_corpus_conn,c_corpus_hierar,c_corpus_cyclo_metric,subsys_count,...
                                            agg_subsys_count,depth,liblink_count,compiles,cyclo_complexity...
                                            ,simulation_time,compile_time,num_alge_loop,target_hw,solver_type,sim_mode...
                                            ,total_lines_cnt,total_descendant_count,ncs_count,scc_count,unique_sfun_count...
                                            ,sfun_reused_key_val...
                                            ,modelrefMap_reused_val,unique_mdl_ref_count);%blk_cnt);
                               catch ME
                                    obj.WriteLog(sprintf('ERROR Inserting to Database %s',model_name));                    
                                    obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                    obj.WriteLog(['ERROR MSG : ' ME.message]);
                               end
                               if success ==1
                                   obj.WriteLog(sprintf("Successful Insert to Database"));
                                   success = 0;
                               end
                           else
                               % Extracting code gen related metrics
                               dates = getDates(model_name);
                               target_link = getTargetLinkInfo(model_name);
                               embeddedC = getEmbeddedCoderInfo(model_name);
                               solverType = get_solver_type(model_name);
                               sysTarget = get_param(model_name,'SystemTargetFile');
                               
                               cols = {'FILE_ID','Model_Name','file_path','created_date','last_modified','EmbeddedCoder_SLNET','EmbeddedCoder','TargetLink','System_Target_File','Solver_Type'};
                               results = {id,    char(m(end)),  file_path, dates{1},     dates{2},             0    , embeddedC, target_link, sysTarget, solverType};
                                
                               obj.WriteLog(sprintf("Created : %s LastModified : %s target link : %s  solverType: %s",...
                                   dates{1},dates{2},target_link,solverType));
                               
                               try
                                insert(obj.conn,obj.table_name,cols,results);
                                 catch ME
                                    obj.WriteLog(sprintf('ERROR Inserting to Database %s',model_name));                    
                                    obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                    obj.WriteLog(['ERROR MSG : ' ME.message]);
                               end
                                
                               
                           end
                           
                           
                           obj.close_the_model(model_name);
                       end
                  end
                 % close all hidden;
                 
                rmpath(genpath(char(folder_path)));
                try
                    obj.delete_tmp_folder_content(char(obj.cfg.tmp_unzipped_dir));
                catch ME
                    obj.WriteLog(sprintf('ERROR deleting'));                    
                                obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                obj.WriteLog(['ERROR MSG : ' ME.message]);
                                
                end
                                disp(' ')
                if ~obj.cfg.CODE_GEN           
                    obj.update_test_flag(test_harness,id);    
                end
                processed_file_count=processed_file_count+1;

           end
           obj.WriteLog("Cleaning up Tmp files")
           obj.cleanup()
   
        end
        
        function sucess = update_test_flag(obj,test_harness,id)
        %metrics cannot be extracted using Simulink Check API since they
        %are test harness. Hence we insert the model new table.
           obj.WriteLog(sprintf("Writing to Database"));
           if isempty(test_harness)
               obj.WriteLog(sprintf('Empty Test Harness. Returning'));
               return;
           end
           [r,c] = size(test_harness);
           
           try
              for i = 1: c
                success = obj.write_to_database(id,test_harness(i).name,'xxxxx',1,0,-1,-1,-1,-1,-1,-1,-1,-1,...
                        -1,-1,-1,-1,-1,...
                        -1,-1,-1,'N/A','N/A','N/A',...
                        -1,-1,-1,-1,-1,...
                        'N/A',...
                        'N/A',-1);%blk_cnt);
              end
           catch ME
                obj.WriteLog(sprintf('ERROR Inserting test harness to Database %s',test_harness(i).name));                    
                obj.WriteLog(['ERROR ID : ' ME.identifier]);
                obj.WriteLog(['ERROR MSG : ' ME.message]);
           end
           if success ==1
               obj.WriteLog(sprintf("Successful Insert to Database"));
               success = 0;
           end
        end
     
        

        function x = get_total_block_count(obj,model)
            %load_system(model)
            [refmodels,modelblock] = find_mdlrefs(model);
           
            % Open dependent models
            for i = 1:length(refmodels)
                load_system(refmodels{i});
                obj.WriteLog(sprintf(' %s loaded',refmodels{i}));
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
                [t,s{i}] = sldiagnostics(refmodels{i},'CountBlocks');
                obj.WriteLog([refmodels{i} ' has ' num2str(s{i}(1).count) ' blocks'])
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
        function [blk_count,agg_sub_count,subsys_count,subsys_depth,liblink_count,hierar_depth,component_in_every_lvl,mdlref_depth_map] = extract_metrics(obj,model)
                
               
                
                %save_system(model,model+_expanded)
                metric_engine = slmetric.Engine();
                %Simulink.BlockDiagram.expandSubsystem(block)
                setAnalysisRoot(metric_engine, 'Root',  model);
                % Include referenced models and libraries in the analysis, 
                %     these properties are on by default
                    metric_engine.AnalyzeModelReferences = 1;
                    metric_engine.AnalyzeLibraries = 0;
                   
                mData ={'mathworks.metrics.SimulinkBlockCount' ,'mathworks.metrics.SubSystemCount','mathworks.metrics.SubSystemDepth',...
                    'mathworks.metrics.LibraryLinkCount'};
                execute(metric_engine,mData)
                
                  res_col = getMetrics(metric_engine,mData,'AggregationDepth','all');
                count =0;
                blk_count =0;
                depth=0;
                agg_count=0;
                liblink_count = 0;
                metricData ={'MetricID','ComponentPath','Value'};
                cnt = 1;
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
                                    blks_in_all_level = cell(length(results),1);
                                    for i = 1:length(results)
                                        blks_in_all_level{i,1} = results(1,i).ComponentPath;
                                    end
                                    [hierar_depth,component_in_every_lvl,mdlref_depth_map] = obj.calculate_hierarchy_depth(blks_in_all_level,model);
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
                        obj.WriteLog(['No results for:',res_col(n).MetricID]);
                    end
               
                end
                subsys_count = count;
                subsys_depth = depth;
                agg_sub_count = agg_count;
                
          
                
       
        end
        
        %Calculates hierary depth including model references and subsystem
        % also returns blk in every lvl sorted by numebr of back slash and mdl_ref_depths.
        %blk_in_every_lvl is the components which has at least 1 blocks . 
        %That is why depth = depth + 1
        function [depth,blk_in_every_lvl,mdlref_depth_map] = calculate_hierarchy_depth(obj,all_blocks_in_every_lvl,model_name)
            depth = -1;
            [~,idx]=sort(cellfun(@(x) length(regexp(x,'/')),all_blocks_in_every_lvl));
            all_blocks_in_every_lvl = all_blocks_in_every_lvl(idx);
            mdlref_dpth_map = containers.Map();
            blkcomp_dpth_map = containers.Map();
            for i=1:size(all_blocks_in_every_lvl)
                currentBlock =all_blocks_in_every_lvl(i);
                if strcmp(currentBlock,model_name)
                    depth = 0;
                    blkcomp_dpth_map(char(model_name)) = 0; 
                    continue
                end
                %check if the component has two consecutive slash in
                %it. means the block name has slash
                consec_slash = regexp(currentBlock,'//+');
                if ~isempty(consec_slash{1})
                    curr_name = get_param(currentBlock,'Name');
                    name = char(regexprep(string(curr_name),newline,' '));%split(string(currentBlock),"/");
                    num_of_bslash = cellfun('length',regexp(regexprep(currentBlock,'(/{2,})',''),'/')) ;
                
                else
                    %https://www.mathworks.com/help/matlab/ref/cellfun.html
                    num_of_bslash = cellfun('length',regexp(currentBlock,'/')) ;
                    name = split(string(currentBlock),"/");
                    name = char(name(end));
                end 
                
          
                if num_of_bslash == 0 
                    
                    
                    %This is a model reference
                    %https://www.mathworks.com/help/simulink/slref/find_mdlrefs.html#butnbec-1-allLevels
                    [mdlref,mdlref_name] = find_mdlrefs(model_name,'ReturnTopModelAsLastElement',false);
                    idx = find(strcmp([mdlref], currentBlock));
                    if ~isempty(idx)
                        mdl_ref_fullpath = mdlref_name(idx(1));
                    else 
                        %pause;
                        %POssible cause is the current block is a model
                        %reference and variant subsystem. Investicate
                        %later. 
                        %error('Model reference not found');
                        continue;
                    end
                    mdl_dpth = cellfun('length',regexp(mdl_ref_fullpath,'/')) ;
                    tmp_string = regexprep(string(currentBlock),newline,' ');
                    mdlref_dpth_map(char(tmp_string))=mdl_dpth;
                    if(depth<mdl_dpth)
                        depth = mdl_dpth;
                    end
                   continue;
                end
               
                %check if the component inside the reference model can be found in the parent model
                %if not add it to the map . name consecutive slashes check
                %earlier is to satisfy this . 
                
                % if empty, this is a component(probably subsystem) from model reference. 
                if (isempty(find_system(model_name,'lookundermasks','all','Name',name)))
                    
                    mdl_ref_path = keys(mdlref_dpth_map);
                    if isempty(mdl_ref_path)
                        continue;
                    end
                    for i = 1 : length(mdl_ref_path)
                        mdl_ref_path{i}
                        load_system(mdl_ref_path{i});
                        blk_path = find_system(mdl_ref_path{i},'lookundermasks','all','Name',name);
                        
                        if(~isempty(blk_path))
                            break
                        end
                    end
                    
                    for i = 1 : length(mdl_ref_path)
                        close_system(mdl_ref_path{i});
                    end
                    %adjust depth 
                    %search use model reference (i) for its depth and
                    %blkPath backslash count 
                    num_of_bslash_mdlref_blk = cellfun('length',regexp(blk_path,'/')) ;
                    true_depth_of_mdlref_blk = num_of_bslash_mdlref_blk + mdlref_dpth_map(char(mdl_ref_path{i}));
                    
                    tmp_string = regexprep(string(currentBlock),newline,' ');
                    mdlref_dpth_map(char(tmp_string))=true_depth_of_mdlref_blk;
                    if depth > true_depth_of_mdlref_blk
                        depth = true_depth_of_mdlref_blk;
                    end
                else 
                    %if not in model reference of its component or root model then
                    %if is a component of root model. 

                    tmp_string = regexprep(string(currentBlock),newline,' ');
                    blkcomp_dpth_map(char(tmp_string)) = num_of_bslash;
 
                end
                
                if num_of_bslash > depth
                    depth = num_of_bslash; 
                end  
            end
            depth = depth + 1; % blk_in_every_lvl 
            blk_in_every_lvl = blkcomp_dpth_map; % excludes model references and its components
            mdlref_depth_map  = mdlref_dpth_map;
            
        end
        
        
        %to clean up files MATLAB generates while processing
        function cleanup(obj)
            extensions = {'slxc','c','mat','wav','bmp','log'...
               'tlc','mexw64'}; % cell arrAY.. Add file extesiion 
            for i = 1 :  length(extensions)
                delete( char(strcat("*.",extensions(i))));
            end
            
        end
        
        %Extract Cyclomatic complexity %MOdels needs to be compilable 
        function [cyclo_metric] = extract_cyclomatic_complexity(obj,model)
                
            
                
                %save_system(model,model+_expanded)
                metric_engine = slmetric.Engine();
                %Simulink.BlockDiagram.expandSubsystem(block)
                setAnalysisRoot(metric_engine, 'Root',  model);
                metric_engine.AnalyzeModelReferences = 1;
                metric_engine.AnalyzeLibraries = 0;
                mData ={'mathworks.metrics.CyclomaticComplexity'};
                try
                    execute(metric_engine,mData);
                catch
                    obj.WriteLog("Error Executing Slmetric API");
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
                        
                        obj.WriteLog(['No results for:',res_col(n).MetricID]);
                    end
                    
                end
                
       
        end
        
         function [c_corpus_cyclo_metric] = extract_cyclomatic_complexity_C_corpus(obj,model)
                
                metric_engine = slmetric.Engine();
                %Simulink.BlockDiagram.expandSubsystem(block)
                setAnalysisRoot(metric_engine, 'Root',  model);
                metric_engine.AnalyzeModelReferences = 1;
                metric_engine.AnalyzeLibraries = 1;
                mData ={'mathworks.metrics.CyclomaticComplexity'};
                try
                    execute(metric_engine,mData);
                catch
                    obj.WriteLog("Error Executing Slmetric API");
                end
                res_col = getMetrics(metric_engine,mData,'AggregationDepth','all');
                
                c_corpus_cyclo_metric = -1 ; %-1 denotes cyclomatic complexit is not computed at all
                for n=1:length(res_col)
                    if res_col(n).Status == 0
                        results = res_col(n).Results;

                        for m=1:length(results)
                            
                            %disp(['MetricID: ',results(m).MetricID]);
                            %disp(['  ComponentPath: ',results(m).ComponentPath]);
                            %disp(['  Value: ',num2str(results(m).Value)]);
                            if strcmp(results(m).ComponentPath,model)
                                if strcmp(results(m).MetricID ,'mathworks.metrics.CyclomaticComplexity')
                                    c_corpus_cyclo_metric =results(m).AggregatedValue;
                                end
                            end
                        end
                    else
                        
                        obj.WriteLog(['No results for:',res_col(n).MetricID]);
                    end
                    
                end
                
       
        end
        
        
       %Slcorpus0 recursive function to calculate metrics not supported by API
        function count = obtain_hierarchy_metrics_old(obj,sys,depth,isModelReference, is_second_time)
%             sys
%             fprintf('\n[DEBUG] OHM - %s\n', char(sys));
            if isModelReference
                mdlRefName = get_param(sys,'ModelName');
                load_system(mdlRefName);
                all_blocks = find_system(mdlRefName,'SearchDepth',1, 'LookUnderMasks', 'all', 'FollowLinks','on');
%                 assert(strcmpi(all_blocks(1), mdlRefName));
                all_blocks = all_blocks(2:end);
                lines = find_system(mdlRefName,'SearchDepth','1','FindAll','on', 'LookUnderMasks', 'all', 'FollowLinks','on', 'type','line');
%                 fprintf('[V] ReferencedModel %s; depth %d\n', char(mdlRefName), depth);
            else
                all_blocks = find_system(sys,'SearchDepth',1, 'LookUnderMasks', 'all', 'FollowLinks','on');
%                 assert(strcmpi(all_blocks(1), sys));
                lines = find_system(sys,'SearchDepth','1','FindAll','on', 'LookUnderMasks', 'all', 'FollowLinks','on', 'type','line');
%                 fprintf('[V] SubSystem %s; depth %d\n', char(sys), depth);
            end
            
            count=0;
            childCountLevel=0;
            subsystem_count = 0;
            count_sfunctions = 0;
            
            [blockCount,~] =size(all_blocks);
            
            %slb = slblocks_light(0);
            
            hidden_lines = 0;
            hidden_block_type = 'From';
            
            %skip the root model which always comes as the first model
            for i=1:blockCount
                currentBlock = all_blocks(i);
%                 get_param(currentBlock, 'handle')
                
                if ~ strcmp(currentBlock, sys) 
                    blockType = get_param(currentBlock, 'blocktype');
%                     if strcmp(char(blockType), 'SubSystem')
%                         fprintf('<SS>');
%                     end
%                     fprintf('(b) %s \t', char(get_param(currentBlock, 'name')));
                    
                    %if ~ is_second_time
                    %    obj.blockTypeMap.inc(blockType{1,1});
                    %end
                    
                    %libname = obj.get_lib(blockType{1, 1});
                    
                    %if ~ is_second_time
                    %    obj.libcount_single_model.inc(libname);
                    %   obj.uniqueBlockMap.inc(blockType{1,1});
                    %end
                    
                    if strcmp(blockType,'SubSystem') || strcmp(blockType,'ModelReference')
                        % child model found
                        
                        if strcmp(blockType,'ModelReference')
                            %childCountLevel=childCountLevel+1;
                            
                            modelName = get_param(currentBlock,'ModelName');
                            is_model_reused = obj.childModelMap.contains(modelName);
                            obj.childModelMap.inc(modelName{1,1});
                            
                            %if ~ is_model_reused
                                % Will not count the same referenced model
                                % twice. % TODO since this is commented
                                % out, pass this param to
                                % obtain_hierarchy_metrics
                                obj.obtain_hierarchy_metrics_old(currentBlock,depth+1,true, is_model_reused);
                            %end
                        else
                            inner_count  = obj.obtain_hierarchy_metrics_old(currentBlock,depth+1,false, false);
                            %if inner_count > 0
                                % There are some subsystems which are not
                                % actually subsystems, they have zero
                                % blocks. Also, masked ones won't show any
                                % underlying implementation
                                %childCountLevel=childCountLevel+1;
                                %subsystem_count = subsystem_count + 1;
                            %end
                        end
                    %elseif util.cell_str_in({'S-Function'}, blockType) % TODO
                        % S-Function found
                        %if ~ is_second_time
                            %count_sfunctions = count_sfunctions + 1;
                        %end
                        %disp('Sfun name:');
                        %sfun_name = char(get_param(currentBlock, 'FunctionName'))
                        %obj.sfun_reuse_map.inc(sfun_name);
                    elseif strcmp(hidden_block_type, blockType) % 
%                         if ~ is_second_time
                            hidden_lines = hidden_lines + 1;
%                         end    
                    end
                    
                    count=count+1;
                    obj.blk_count_old = obj.blk_count_old + 1;
                    
                    %if analyze_complexity.CALCULATE_SCC
                    %    slb.process_new_block(currentBlock);
                    %end
                    
                end
            end
            
%             fprintf('\n');
            
            %if analyze_complexity.CALCULATE_SCC
             %   fprintf('Get SCC for %s\n', char(sys));
             %   con_com = simulator.get_connected_components(slb);
             %   fprintf('[ConComp] Got %d connected comps\n', con_com.len);

              %  obj.scc_count = obj.scc_count + con_com.len;
            %end
            
            %if analyze_complexity.CALCULATE_CYCLES
              %  fprintf('Computing Cycles...\n');
              %  obj.cycle_count = obj.cycle_count + getCountCycles(slb);
            %end
            
            mapKey = int2str(depth);
            
%             fprintf('\tBlock Count: %d\n', count);
            
            
            unique_lines = 0;
            
            unique_line_map = mymap();
            
            for l_i = 1:numel(lines)
                c_l = get(lines(l_i));
                c_l.SrcBlockHandle;
                c_l.DstBlockHandle;
%                 fprintf('[LINE] %s %f\n',  get_param(c_l.SrcBlockHandle, 'name'), lines(l_i));
                for d_i = 1:numel(c_l.DstBlockHandle)
                    ulk = [num2str(c_l.SrcBlockHandle) '_' num2str(c_l.SrcPortHandle) '_' num2str(c_l.DstBlockHandle(d_i)) '_' num2str(c_l.DstPortHandle(d_i))];
                    if ~ unique_line_map.contains(ulk)
                        unique_line_map.put(ulk, 1);
                        unique_lines = unique_lines + 1;
%                         fprintf('[LINE] %s \t\t ---> %s\n',get_param(c_l.SrcBlockHandle, 'name'), get_param(c_l.DstBlockHandle(d_i), 'name'));
%                         hilite_system(lines(l_i));
%                         pause();
                    end
                end
                
            end
            
            
            if count >0
%                 fprintf('Found %d blocks\n', count);
                
                %if depth <= obj.max_level
                %    obj.bp_block_count_level_wise.add(count, mapKey)
                %    obj.bp_connections_depth_count.add(unique_lines,mapKey);
                %end
                
                obj.map.insert_or_add(mapKey, count);
                % If there are blocks, only then it makes sense to count
                % connections
                %obj.connectionsLevelMap.insert_or_add(mapKey,unique_lines);
                %obj.childModelPerLevelMap.insert_or_add(mapKey, childCountLevel); %WARNING shouldn't we do this only when count>0?
                obj.hidden_lines_count_old = obj.hidden_lines_count_old + hidden_lines ;
                obj.unique_lines_count_old = obj.unique_lines_count_old  + unique_lines;
            else
                assert(unique_lines == 0); % sanity check
            end
            
            
            
        end
        
        % FUNCTIONS BELOW ARE ANALYSIS of the EXTRACTED METRICS

        % correlation analysis : Cyclomatic complexity with other metrics 
        function correlation_analysis(obj, flag , varargin)
            % Can be called as obj.correlation_analysis('GitHub')
            % obj.correlation_analysis(false,'GitHub','MATC') %for SLNET
            % obj.correlation_analysis(true,'GitHub','Tutorial','sourceforge','matc','Others')for
            % Slcorpus0
            % flag = true for earlier study and false for SLNET  
            
            original_mdl_name = obj.list_of_model_name();
            
            format short;
            CC_compare_with = 'select  CComplexity,compile_time, Schk_block_count,total_connH_cnt, hierarchy_Depth,total_desc_cnt,ncs_cnt,scc_cnt ,cnt,C_corpus_hierar_depth from ( ';
            if flag
                where_clause = [' ) where is_lib = 0 and is_test = -1 and compiles = 1 and CComplexity !=-1 and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ') Order by CComplexity'];
            else    
                where_clause = ' ) where is_lib = 0 and is_test = -1 and compiles = 1 and CComplexity !=-1 Order by CComplexity';
            end
                innerquery = ['select b.*, a.cnt from  ',varargin{1}, '_Models b join ( select File_id, Model_Name, count(blk_type) as cnt from ',varargin{1}, ...
                    '_blocks group by File_id,Model_Name) a on a.File_id = b.File_id and  a.Model_Name = b.Model_Name'];
           if nargin > 1
                for i = 2:nargin-2
                    innerquery = [innerquery,' union all select b.*, a.cnt from  ',varargin{i}, '_Models b join ( select File_id, Model_Name, count(blk_type) as cnt from ',varargin{i}, ...
                    '_blocks group by File_id,Model_Name) a on a.File_id = b.File_id and  a.Model_Name = b.Model_Name'];
                    
                end
            end
               
            sqlquery = [CC_compare_with,innerquery,where_clause ];

           
            results = fetch(obj.conn,sqlquery);
            results = cellfun(@(x)double(x),results);
            %{
            try
                for i=1:6
                    single_metric = sort(results(:,i));
                    normalized_metric = (single_metric - mean(single_metric))/std(single_metric) ;
                    disp(kstest( normalized_metric ));
                end
            catch e
                fprintf('Err in normality test: \n');
                return;
            end
              %}
            %metrics = cell2mat(results)
            %[rho,pval] = corrcoef(results);
            %Correlation of Cyclomatic complexity with the following
            %metrics
            Cc_corr_with ={'compile_time', 'block_count','connection', 'max depth','child representing blocks','NCS','SCC','Unique blk Count','C_corpus_hierar_depth'};
            res ={};
            for i = 2:length(Cc_corr_with)+1
                % obj.WriteLog(sprintf('%s',Cc_corr_with{i-1}));
                [tau, kpal] = corr(results(:,1),results(:,i), 'type', 'Kendall', 'rows', 'pairwise');
                [Sm, Sp] = corr(results(:,1),results(:,i), 'type', 'Spearman', 'rows', 'pairwise');
                %fprintf('Kendall : %2.4f %d \n',tau,kpal);
                %fprintf('Spearman : %2.4f %d \n\n',Sm, Sp);
                res{i-1,1} = string(Cc_corr_with{i-1});
                res{i-1,2} = tau;
            end
            
            %fprintf("%0.3f & %0.3f & %0.3f & %0.3f & %0.3f & %0.3f & %0.3f\n",...
            %    res{7,2},res{2,2},res{3,2}, res{1,2},res{4,2},res{5,2},res{6,2} );
            
            fprintf("%0.4f & %0.4f & %0.4f & %0.4f & %0.4f",...
                 res{1,2},res{9,2},res{4,2},res{5,2},res{6,2} );
           % [tau, kpal] = corr(results, 'type', 'Kendall', 'rows', 'pairwise');
            sortrows(res,[2,2])
            %res{9,2}
    
        end
        
        function median_val = median(obj, list )
            %list is sorted based on last columns
                [~,idx] = sort(list(:,length(list(1,:))));
                sorted_results = list(idx,:);
                median_val = (length(sorted_results) + 1)/2;
                
                if(mod(median_val,2)==0)
                    median_val = sorted_results(median_val,length(list(1,:)));
                else
                    median_val = sorted_results(ceil(median_val),length(list(1,:)))+ sorted_results(floor(median_val),length(list(1,:)))/2;
                end
        
        end
        function analyze_metrics(obj,flag)
            format long;
            %total models analyzed :
             original_mdl_name = obj.list_of_model_name();
            if(flag)
                total_analyzed_mdl_query = ['select count(*) from',...
                                ' (select * from github_models where  is_lib=0 and is_test = -1 and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ')',...
                                 '   union all',...
                                  '  select * from  matc_models where  is_lib=0 and is_test = -1 and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ')',...
                                  '   union all',...
                                  '  select * from  sourceforge_models where  is_lib=0 and is_test = -1 and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ')',...
                                  '   union all',...
                                  '  select * from  tutorial_models where  is_lib=0 and is_test = -1 and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ')',...
                                    '   union all',...
                                  '  select * from  others_models where  is_lib=0 and is_test = -1 and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ')',...
                                   ' )'];
            else
                total_analyzed_mdl_query = ['select count(*) from',...
                                ' (select * from github_models where  is_lib=0 and is_test = -1 ',...
                                 '   union all',...
                                  '  select * from  matc_models where  is_lib=0 and is_test = -1 ',...
                                   ' )'];
            end
            total_models_analyzed =  fetch(obj.conn,total_analyzed_mdl_query);
            %Fetching from db 
            if flag
                query_hierar_median_blk_cnt =['select depth,block_count from ',...
                '(select * from GitHub_Subsys where (file_id,Model_Name)',...
                ' not in (select file_id,Model_Name from github_models where is_lib=1) and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ') ',...
                ' union all',...
                ' select * from matc_subsys where (file_id,Model_Name)', ...
                'not in (select file_id,Model_Name from matc_models where is_lib=1) and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ')',...
                 ' union all',...
                ' select * from tutorial_Subsys where (file_id,Model_Name)', ...
                'not in (select file_id,Model_Name from tutorial_models  where is_lib=1) and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ')',...
                 ' union all',...
                ' select * from sourceforge_Subsys where (file_id,Model_Name)', ...
                'not in (select file_id,Model_Name from sourceforge_models  where is_lib=1) and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ')',...
                 ' union all',...
                ' select * from others_Subsys where (file_id,Model_Name)', ...
                'not in (select file_id,Model_Name from others_models  where is_lib=1) and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ')',...
                ')'];
            else
                query_hierar_median_blk_cnt =['select depth,block_count from ',...
                '(select * from GitHub_Subsys where (file_id,Model_Name)',...
                ' not in (select file_id,Model_Name from github_models where is_lib=1)',...
                ' union all',...
                ' select * from matc_subsys where (file_id,Model_Name)', ...
                'not in (select file_id,Model_Name from matc_models where is_lib=1))'];
             
            end
            obj.WriteLog(sprintf("Fetching   block counts of each subsystem per hierarchial lvl with query \n %s",query_hierar_median_blk_cnt));
            results = fetch(obj.conn,query_hierar_median_blk_cnt);
            results = cellfun(@(x)double(x),results);
            obj.WriteLog(sprintf("Fetched   %d results ",length(results)));
            max_depth = max(results(:,1));
            obj.WriteLog(sprintf("Max Depth =  %d  ",max_depth-1));%lvl 1 = lvl 0 as the subsystem is in lvl 0 and its corresponding blocks are in lvl 1 .
            %results_per_hierar = cell(max_depth,1);
            max_val = 0; % maximum number of blocks among all hierarchy lvl . 
            for i = 1:max_depth
                %results_per_hierar(i,1) = {results(results(:,1)==i,:)};
                tmp_results_of_hierar_i = results(results(:,1)==i,:);
                val = obj.median(tmp_results_of_hierar_i);
                 obj.WriteLog(sprintf("Depth =  %d Median number of blocks per subsystem = %d  ",i-1,val));%lvl 1 = lvl 0 as the subsystem is in lvl 0 and its corresponding blocks are in lvl 1 .
     
                if(val>max_val)
                    max_val = round(val);
                end
            end
            
            query_matc_models = 'select avg(SCHK_Block_count) from matc_models where is_lib=0 and is_test = -1 ';
            obj.WriteLog(sprintf("Fetching  Avg block counts in Matlab Central Models"));
            avg_block = fetch(obj.conn,query_matc_models);
            if(flag)
                models_over_1000_blk_query = ['select sum(c) from(',...
            ' select count(*) as c from github_models where C_corpus_blk_count>1000 and is_lib=0 and is_test = -1 and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ') ',...
            ' union all',...
            ' select count(*) as c from  matc_models where C_corpus_blk_count>1000 and is_lib=0 and is_test = -1 and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ')',...
            ' union all',...
            ' select count(*) as c from  sourceforge_models where C_corpus_blk_count>1000 and is_lib=0 and is_test = -1 and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ')',...
            ' union all',...
            ' select count(*) as c from  tutorial_models where C_corpus_blk_count>1000 and is_lib=0 and is_test = -1 and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ')',...
                      ' union all',...
            ' select count(*) as c from  others_models where C_corpus_blk_count>1000 and is_lib=0 and is_test = -1 and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ')' ,...
            ' )'
            ];
            else
            models_over_1000_blk_query = ['select sum(c) from(',...
            ' select count(*) as c from github_models where C_corpus_blk_count>1000 and is_lib=0 and is_test = -1 ',...
            ' union all',...
            ' select count(*) as c from  matc_models where C_corpus_blk_count>1000 and is_lib=0 and is_test = -1 ',...
            ' )'
            ];
            end
            models_over_1000blk_cnt = fetch(obj.conn,models_over_1000_blk_query);
            
            %model referencing 
            if (flag)
                models_use_mdlref_query = ['select mdlref_nam_count from',...
                                ' (select * from github_models where unique_mdl_ref_count>0 and  is_lib=0 and is_test = -1 and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ')',...
                                 '   union all',...
                                  '  select * from  matc_models where unique_mdl_ref_count>0 and is_lib=0 and is_test = -1 and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ')',...
                                  '   union all',...
                                  '  select * from  sourceforge_models where unique_mdl_ref_count>0 and is_lib=0 and is_test = -1 and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ')',...
                                  '   union all',...
                                  '  select * from  tutorial_models where unique_mdl_ref_count>0 and is_lib=0 and is_test = -1 and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ')',...
                                      '   union all',...
                                  '  select * from  others_models where unique_mdl_ref_count>0 and is_lib=0 and is_test = -1 and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ')',...
                                   ' )'];
            else
            models_use_mdlref_query = ['select mdlref_nam_count from',...
                                ' (select * from github_models where unique_mdl_ref_count>0 and  is_lib=0 and is_test = -1 ',...
                                 '   union all',...
                                  '  select * from  matc_models where unique_mdl_ref_count>0 and is_lib=0 and is_test = -1 ',...
                                   ' )'];
            end
            models_use_mdlref = fetch(obj.conn,models_use_mdlref_query);
            mdl_ref_reuse_count = 0 ;
            for j = 1 : length(models_use_mdlref)
                mdl_ref_list = split(models_use_mdlref{j},',');
                for k = 2 : length(mdl_ref_list) % 2 because there is always 0 char array at the beginning index
                    tmp = split(mdl_ref_list{k},'_');
                    mdl_ref_count = str2double(tmp{length(tmp)});
                    if(mdl_ref_count>1)
                       
                        mdl_ref_reuse_count = mdl_ref_reuse_count+1; 
                        break;
                    end
                end
            end
            
             %models using algebraic loop count
            if flag
                models_use_algebraicloop_query = ['select count(*) from',...
                                ' (select * from github_models where is_lib=0 and is_test = -1 and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ')',...
                                 '   union all',...
                                  '  select * from  matc_models where  is_lib=0 and is_test = -1 and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ')',...
                                   '   union all',...
                                  '  select * from  tutorial_models where  is_lib=0 and is_test = -1 and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ')',...
                                   '   union all',...
                                  '  select * from  sourceforge_models where  is_lib=0 and is_test = -1 and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ')',...
                                      '   union all',...
                                  '  select * from  others_models where  is_lib=0 and is_test = -1 and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ')',...
                                   ' ) where alge_loop_cnt >0'];
            else
                
            models_use_algebraicloop_query = ['select count(*) from',...
                                ' (select * from github_models where  is_lib=0 and is_test = -1 ',...
                                 '   union all',...
                                  '  select * from  matc_models where  is_lib=0 and is_test = -1 ',...
                                   ' ) Where alge_loop_cnt >0'];
            end
            models_use_algebraicloop = fetch(obj.conn,models_use_algebraicloop_query);
            
            
            %sfun_use_query
            if flag
                models_use_sfun_query = ['select sfun_nam_count from',...
                                ' (select * from github_models where unique_sfun_count>0 and  is_lib=0 and is_test = -1 and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ')',...
                                 '   union all',...
                                  '  select * from  matc_models where unique_sfun_count>0 and is_lib=0 and is_test = -1 and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ')',...
                                   '   union all',...
                                  '  select * from  tutorial_models where unique_sfun_count>0 and is_lib=0 and is_test = -1 and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ')',...
                                   '   union all',...
                                  '  select * from  sourceforge_models where unique_sfun_count>0 and is_lib=0 and is_test = -1 and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ')',...
                                      '   union all',...
                                  '  select * from  others_models where unique_sfun_count>0 and is_lib=0 and is_test = -1 and substr(Model_Name,0,length(Model_name)-3) IN (' original_mdl_name{1} ')',...
                                   ' )'];
            else
                
            models_use_sfun_query = ['select sfun_nam_count from',...
                                ' (select * from github_models where unique_sfun_count>0 and  is_lib=0 and is_test = -1 ',...
                                 '   union all',...
                                  '  select * from  matc_models where unique_sfun_count>0 and is_lib=0 and is_test = -1 ',...
                                   ' )'];
            end
            models_use_sfun = fetch(obj.conn,models_use_sfun_query);

            %sfun_reuse_vector = [];
            sfun_reuse_count = 0 ;
            for j = 1 : length(models_use_sfun)
                sfun_list = split(models_use_sfun{j},',');
                for k = 2 : length(sfun_list) % 2 because there is always 0 char array at the beginning index
                    tmp = split(sfun_list{k},'_');
                    sfun_count = str2double(tmp{length(tmp)});
                    if(sfun_count>1)
                     %  sfun_reuse_vector(end+1) = 1;
                        sfun_reuse_count = sfun_reuse_count+1; 
                        break;
                    
                    end
                    
                end
                %if sfun_count<=1
                 %        sfun_reuse_vector(end+1) = 0;
                 %   end
            end
            %median_sfun= obj.median(transpose(sfun_reuse_vector));
            
            
            most_frequentlused_blocks_query_git = ['select BLK_TYPE,sum(count)  as c from GitHub_Blocks group by BLK_TYPE order by  c desc'];
            
            most_frequentlused_blocks_query_matc = ['select  BLK_TYPE,sum(count)  as c from matc_Blocks  group by BLK_TYPE order by  c desc'];
            
            if(flag)
                most_frequentlused_blocks_query_tut = ['select  BLK_TYPE,sum(count)  as c from tutorial_Blocks  group by BLK_TYPE order by  c desc'];
                most_frequentlused_blocks_query_sourceforge = ['select  BLK_TYPE,sum(count)  as c from sourceforge_Blocks  group by BLK_TYPE order by  c desc'];
                most_frequentlused_blocks_query_others = ['select  BLK_TYPE,sum(count)  as c from others_Blocks  group by BLK_TYPE order by  c desc'];

                most_frequentlused_blocks_tut = fetch(obj.conn,most_frequentlused_blocks_query_tut);
                most_frequentlused_blocks_sourceforge = fetch(obj.conn,most_frequentlused_blocks_query_sourceforge);
                most_frequentlused_blocks_others = fetch(obj.conn,most_frequentlused_blocks_query_others);
            end
            most_frequentlused_blocks_git = fetch(obj.conn,most_frequentlused_blocks_query_git);
            most_frequentlused_blocks_matc = fetch(obj.conn,most_frequentlused_blocks_query_matc);
            
            %15 most frequently used block besides top 3 . 
            most_15_freq_used_blks_git = most_frequentlused_blocks_git{4};
            most_15_freq_used_blks_matc = most_frequentlused_blocks_matc{4};
            if flag
                 most_15_freq_used_blks_tut = most_frequentlused_blocks_tut{4};
                most_15_freq_used_blks_sourceforge = most_frequentlused_blocks_sourceforge{4};
                most_15_freq_used_blks_others = most_frequentlused_blocks_others{4};
            end
            
            for i = 5 : 18
                most_15_freq_used_blks_git = strcat(most_15_freq_used_blks_git,",",most_frequentlused_blocks_git{i});
                most_15_freq_used_blks_matc = strcat(most_15_freq_used_blks_matc,",",most_frequentlused_blocks_matc{i});
                if flag
                    most_15_freq_used_blks_tut = strcat(most_15_freq_used_blks_tut,",",most_frequentlused_blocks_tut{i});
                    most_15_freq_used_blks_sourceforge = strcat(most_15_freq_used_blks_sourceforge,",",most_frequentlused_blocks_sourceforge{i});
                    most_15_freq_used_blks_others = strcat(most_15_freq_used_blks_others,",",most_frequentlused_blocks_others{i});
                end
            end
            obj.WriteLog(sprintf("==============RESULTS=================="));
            obj.WriteLog(sprintf("Total Models analyzed : %d ",total_models_analyzed{1}));
            
            obj.WriteLog(sprintf("Medium number of block per hierarchial lvl does not exceed  %d (vs 17)",max_val));
            obj.WriteLog(sprintf("Average  number of block in Matlab Central models: %2.2f (which is %d times smaller than industrial models(752 models))",...
                avg_block{1},(752/avg_block{1})));
            obj.WriteLog(sprintf("Number of models with over 1000 blocks : %d (vs 93 models)",models_over_1000blk_cnt{1}));
            obj.WriteLog(sprintf("Number of models that use model referencing : %d\n Number of models that reused referenced models : %d (vs 1 models) ",length(models_use_mdlref),mdl_ref_reuse_count));
            obj.WriteLog(sprintf("Number of models that use S-functions : %d\n Number of models that reused sfun : %d\n Fraction of model reusing sfun = %d",length(models_use_sfun),sfun_reuse_count,sfun_reuse_count/length(models_use_sfun)));
            obj.WriteLog(sprintf("Most Frequently used blocks in GitHub projects : \n %s ",most_15_freq_used_blks_git));
            obj.WriteLog(sprintf("Most Frequently used blocks in Matlab Central projects : \n %s ",most_15_freq_used_blks_matc));
            obj.WriteLog(sprintf("Number of models that use algebraic loop: %d\n ",models_use_algebraicloop{1}));
            
            
            
            if(flag)
                obj.WriteLog(sprintf("Most Frequently used blocks in Tutorial projects : \n %s ",most_15_freq_used_blks_tut));
                obj.WriteLog(sprintf("Most Frequently used blocks in Source Forge projects : \n %s ",most_15_freq_used_blks_sourceforge));
                obj.WriteLog(sprintf("Most Frequently used blocks in others projects : \n %s ",most_15_freq_used_blks_others));
            end
        end
        
        function res = total_analyze_metric(obj,choice,original_flag)
            %{
               analyzes the metrics . 
               This function can be be called from
               grand_total_analyze_metric() to get a aggregated results. 
            arguments: 
                choice : a particular table name 
            original_flag: true if for original study
                            false if for SLNET
            
            Example : 
            obj.total_analyze_metric('github_models',true)
            
                
            %}
          
            
         
                    blk_connec_query = ['select sum(C_corpus_blk_count),sum(SCHK_block_count),sum(total_ConnH_cnt),sum(C_corpus_conn),sum(C_corpus_hidden_conn) from ', choice ,' where is_Lib = 0 and is_test = -1 '];
                    solver_type_query = ['select solver_type,count(solver_type) from ', choice, ' where is_Lib = 0 and is_test = -1 group by solver_type'];
                    sim_mode_query = ['select sim_mode,count(sim_mode) from ',choice,' where is_Lib = 0 and is_test = -1 group by sim_mode'];
                    total_analyzedmdl_query = ['select count(*) from ', choice,' where is_Lib = 0  and is_test = -1 '];
                    total_model_compiles = ['select count(*) from ',choice,' where is_Lib = 0  and is_test = -1 and compiles = 1'];
                    total_hierarchial_model_query = ['select count(*) from ',choice, ' where is_Lib = 0 and is_test = -1  and Hierarchy_depth>1'];
                    total_C_corpus_hierarchial_model_query = ['select count(*) from ',choice, ' where is_Lib = 0 and is_test = -1  and C_corpus_hierar_depth>1'];
                    
                    if original_flag
                        original_mdl_name = obj.list_of_model_name();
                        
                        blk_connec_query = strcat(blk_connec_query,' and substr(Model_Name,0,length(Model_name)-3) IN (',original_mdl_name,')');
                        solver_type_query = strcat('select solver_type,count(solver_type) from ',...
                            {' '},choice,{' '}, ' where is_Lib = 0 and is_test = -1 and substr(Model_Name,0,length(Model_name)-3) IN (',original_mdl_name,')',...
                            {' '},'group by solver_type');
                        
                        sim_mode_query = strcat('select sim_mode,count(sim_mode) from ',...
                             {' '},choice,{' '},' where is_Lib = 0 and is_test = -1 and substr(Model_Name,0,length(Model_name)-3) IN (',original_mdl_name,')',...
                             {' '},'group by sim_mode');
                        total_analyzedmdl_query = strcat(total_analyzedmdl_query,' and substr(Model_Name,0,length(Model_name)-3) IN (',original_mdl_name,')');
                        
                        total_model_compiles = strcat(total_model_compiles,' and substr(Model_Name,0,length(Model_name)-3) IN (',original_mdl_name,')');
                        total_hierarchial_model_query = strcat(total_hierarchial_model_query,' and substr(Model_Name,0,length(Model_name)-3) IN (',original_mdl_name,')');
                        total_C_corpus_hierarchial_model_query = strcat(total_C_corpus_hierarchial_model_query,' and substr(Model_Name,0,length(Model_name)-3) IN (',original_mdl_name,')');
                    end
                   
                    
                    switch lower(choice)
                        case 'github_models'
                             if original_flag
                                 original_mdl_name = obj.list_of_model_name();
                                 most_frequentlused_blocks_query = strcat('select BLK_TYPE,sum(count)  as c from GitHub_Blocks  where (File_id,Model_Name) in ( ',...
                                     ' select File_id,Model_Name from github_models where is_Lib=0 and is_test = -1  and substr(Model_Name,0,length(Model_name)-3) IN (',...
                                     original_mdl_name,') )',...
                                     ' group by BLK_TYPE order by  c desc');
                                 total_hidden_conn_query = strcat('select sum(Conn_count_hidden_only) from github_model_hierar where (File_id,Model_Name) in (SELECT distinct File_id,Model_Name from ',...
                                     {' '},choice,{' '},'   where is_Lib = 0 and is_test = -1',...
                                     {' '},' and substr(Model_Name,0,length(Model_name)-3) IN (',original_mdl_name,') )  ');
                            
                             else
                                 most_frequentlused_blocks_query = ['select BLK_TYPE,sum(count)  as c from GitHub_Blocks  where (File_id,Model_Name) in ( ',...
                                     ' select File_id,Model_Name from github_models where is_Lib=0 and is_test = -1  )',...
                                     ' group by BLK_TYPE order by  c desc'];
                                  total_hidden_conn_query = ['select sum(Conn_count_hidden_only) from github_model_hierar where (File_id,Model_Name) in (SELECT distinct File_id,Model_Name from ',choice,'   where is_Lib = 0 and is_test = -1  )  '];
                            end
                        case 'matc_models'
                            if original_flag
                             original_mdl_name = obj.list_of_model_name();
                                 most_frequentlused_blocks_query = strcat('select BLK_TYPE,sum(count)  as c from matc_Blocks  where (File_id,Model_Name) in ( ',...
                                     ' select File_id,Model_Name from matc_models where is_Lib=0 and is_test = -1  and substr(Model_Name,0,length(Model_name)-3) IN (',...
                                     original_mdl_name,') )',...
                                     ' group by BLK_TYPE order by  c desc');
                                 total_hidden_conn_query = strcat('select sum(Conn_count_hidden_only) from matc_model_hierar where (File_id,Model_Name) in (SELECT distinct File_id,Model_Name from ',...
                                     {' '},choice,{' '},'   where is_Lib = 0 and is_test = -1',...
                                     {' '},' and substr(Model_Name,0,length(Model_name)-3) IN (',original_mdl_name,') )  ');
                            else
                                most_frequentlused_blocks_query = ['select BLK_TYPE,sum(count)  as c from Matc_Blocks where (File_id,Model_Name) in ( ',...
                                 ' select File_id,Model_Name from matc_models where is_Lib=0 and is_test = -1 )',...
                                 '  group by BLK_TYPE order by  c desc'];
                              total_hidden_conn_query = ['select sum(Conn_count_hidden_only) from matc_model_hierar where (File_id,Model_Name) in (SELECT distinct File_id,Model_Name from ',choice,'   where is_Lib = 0 and is_test = -1  )  '];
                            end
                        case 'sourceforge_models'
                            if original_flag
                            original_mdl_name = obj.list_of_model_name();
                                 most_frequentlused_blocks_query = strcat('select BLK_TYPE,sum(count)  as c from sourceforge_Blocks  where (File_id,Model_Name) in ( ',...
                                     ' select File_id,Model_Name from sourceforge_Models where is_Lib=0 and is_test = -1  and substr(Model_Name,0,length(Model_name)-3) IN (',...
                                     original_mdl_name,') )',...
                                     ' group by BLK_TYPE order by  c desc');
                                 total_hidden_conn_query = strcat('select sum(Conn_count_hidden_only) from sourceforge_Model_Hierar where (File_id,Model_Name) in (SELECT distinct File_id,Model_Name from ',...
                                     {' '},choice,{' '},'   where is_Lib = 0 and is_test = -1',...
                                     {' '},' and substr(Model_Name,0,length(Model_name)-3) IN (',original_mdl_name,') )  ');
                            else
                                   most_frequentlused_blocks_query = ['select BLK_TYPE,sum(count)  as c from sourceforge_Block_Info where (File_id,Model_Name) in ( ',...
                                 ' select File_id,Model_Name from sourceforge_Metric where is_Lib=0 and is_test = -1  )',...
                                 '  group by BLK_TYPE order by  c desc'];
                               total_hidden_conn_query = ['select sum(Conn_count_hidden_only) from sourceforge_Hierar_Info where (File_id,Model_Name) in (SELECT distinct File_id,Model_Name from ',choice,'   where is_Lib = 0 and is_test = -1  )  '];
                    
                            end
                       case 'tutorial_models'
                           if original_flag
                               
                             original_mdl_name = obj.list_of_model_name();
                                 most_frequentlused_blocks_query = strcat('select BLK_TYPE,sum(count)  as c from tutorial_Blocks  where (File_id,Model_Name) in ( ',...
                                     ' select File_id,Model_Name from tutorial_Models where is_Lib=0 and is_test = -1  and substr(Model_Name,0,length(Model_name)-3) IN (',...
                                     original_mdl_name,') )',...
                                     ' group by BLK_TYPE order by  c desc');
                                 total_hidden_conn_query = strcat('select sum(Conn_count_hidden_only) from tutorial_Model_Hierar where (File_id,Model_Name) in (SELECT distinct File_id,Model_Name from ',...
                                     {' '},choice,{' '},'   where is_Lib = 0 and is_test = -1',...
                                     {' '},' and substr(Model_Name,0,length(Model_name)-3) IN (',original_mdl_name,') )  ');
                           else 
                               most_frequentlused_blocks_query = ['select BLK_TYPE,sum(count)  as c from tutorial_Block_Info where (File_id,Model_Name) in ( ',...
                                 ' select File_id,Model_Name from tutorial_Metric where is_Lib=0 and is_test = -1 )',...
                                 '  group by BLK_TYPE order by  c desc'];
                              total_hidden_conn_query = ['select sum(Conn_count_hidden_only) from tutorial_Hierar_Info where (File_id,Model_Name) in (SELECT distinct File_id,Model_Name from ',choice,'   where is_Lib = 0 and is_test = -1  )  '];
                         
                           end
                       case 'others_models'
                           if original_flag
                            original_mdl_name = obj.list_of_model_name();
                                 most_frequentlused_blocks_query = strcat('select BLK_TYPE,sum(count)  as c from others_Blocks  where (File_id,Model_Name) in ( ',...
                                     ' select File_id,Model_Name from others_models where is_Lib=0 and is_test = -1  and substr(Model_Name,0,length(Model_name)-3) IN (',...
                                     original_mdl_name,') )',...
                                     ' group by BLK_TYPE order by  c desc');
                                 total_hidden_conn_query = strcat('select sum(Conn_count_hidden_only) from others_Model_Hierar where (File_id,Model_Name) in (SELECT distinct File_id,Model_Name from ',...
                                     {' '},choice,{' '},'   where is_Lib = 0 and is_test = -1',...
                                     {' '},' and substr(Model_Name,0,length(Model_name)-3) IN (',original_mdl_name,') )  ');
                           else
                                most_frequentlused_blocks_query = ['select BLK_TYPE,sum(count)  as c from others_Block_Info where (File_id,Model_Name) in ( ',...
                                 ' select File_id,Model_Name from others_Metric where is_Lib=0 and is_test = -1  and substr(Model_Name,0,length(Model_name)-3) IN (',original_mdl_name,') )',...
                                 '  group by BLK_TYPE order by  c desc'];
                             total_hidden_conn_query = ['select sum(Conn_count_hidden_only) from others_Hierar_Info where (File_id,Model_Name) in (SELECT distinct File_id,Model_Name from ',choice,'   where is_Lib = 0 and is_test = -1  )  '];
                           
                           end
                    end 
               
            obj.WriteLog(sprintf("Fetching Total hidden connections count of %s choice with query \n %s",choice,total_hidden_conn_query));
            total_hidden_conn = fetch(obj.conn, total_hidden_conn_query);
            
            
            obj.WriteLog(sprintf("Fetching Total Analyzed model of %s choice with query \n %s",choice,total_analyzedmdl_query));
            total_analyzedmdl = fetch(obj.conn, total_analyzedmdl_query);
            
            res.analyzedmdl = total_analyzedmdl{1};
            
            obj.WriteLog(sprintf("Fetching Total readily compilable model of %s choice with query \n %s",choice,total_model_compiles));
            total_model_compiles = fetch(obj.conn, total_model_compiles);
            
            res.mdl_compiles = total_model_compiles{1};
            
            obj.WriteLog(sprintf("Fetching Total hierarchial model of %s choice with query \n %s",choice,total_hierarchial_model_query));
            total_hierarchial_model = fetch(obj.conn, total_hierarchial_model_query);
            
            res.total_hierar = total_hierarchial_model{1};
            
            obj.WriteLog(sprintf("Fetching Total Slcorpus0 hierarchial model of %s choice with query \n %s",choice,total_C_corpus_hierarchial_model_query));
            total_C_corpus_hierarchial_model = fetch(obj.conn, total_C_corpus_hierarchial_model_query);
            
            res.total_C_corpus_hierar = total_C_corpus_hierarchial_model{1};
            
            obj.WriteLog(sprintf("Fetching Total counts of %s choice with query \n %s",choice,blk_connec_query));
            blk_connec_cnt = fetch(obj.conn, blk_connec_query);
            
            res.C_corpus_blk_cnt = blk_connec_cnt{1};
            res.slchk = blk_connec_cnt{2};
            res.connec = blk_connec_cnt{3};
            res.C_corpus_connec =  blk_connec_cnt{4};
            res.C_corpus_hconnec =  blk_connec_cnt{5};
            res.hconnec = total_hidden_conn{1} ;
            
            obj.WriteLog(sprintf("Fetching solver type of %s choice with query \n %s",choice,solver_type_query));
            solver_type = fetch(obj.conn, solver_type_query);
            res.other_solver = 0 ;
            [row,~] = size(solver_type);
            for i = 1 : row
                if(strcmp(solver_type{i,1},'Fixed-step'))
                    res.fix = solver_type{i,2};
                elseif (strcmp(solver_type{i,1},'Variable-step'))
                     res.var = solver_type{i,2};
                else 
                    res.other_solver = res.other_solver + solver_type{i,2};
                end
            end
            
            
            obj.WriteLog(sprintf("Fetching simulation mode of %s choice with query \n %s",choice,sim_mode_query));
            sim_mode = fetch(obj.conn, sim_mode_query);
            res.other_sim = 0 ;
            res.pil = 0;
            res.acc = 0;
            res.rpdacc = 0;
            res.ext  = 0;
            
            [row,~] = size(sim_mode);
            
            for i = 1 : row
                switch sim_mode{i,1}
                    case 'accelerator'
                        res.acc = sim_mode{i,2};
                    case 'external'
                        res.ext = sim_mode{i,2};
                    case 'normal'
                        res.normal = sim_mode{i,2};
                    case 'processor-in-the-loop (pil)'
                        res.pil = sim_mode{i,2};
                    case 'rapid-accelerator'
                        res.rpdacc = sim_mode{i,2};
                    otherwise
                        res.other_sim = res.other_sim + sim_mode{i,2};
                end
            end
            
             most_frequentlused_blocks = fetch(obj.conn,most_frequentlused_blocks_query);
            
            %18 most frequently used block 
            most_15_freq_used_blks = most_frequentlused_blocks{1};
            
            for i = 2 : 15
                most_15_freq_used_blks = strcat(most_15_freq_used_blks,",",most_frequentlused_blocks{i});
            end
            res.most_freq_blks = most_15_freq_used_blks;
           %fprintf("%d & %d & %d & %d & %d & %d & %d & %d & %d & %d & %d & %d & %d & %d & %d\n",...
           %    res.analyzedmdl,res.mdl_compiles,res.total_hierar,res.slchk,res.C_corpus_blk_cnt,res.connec,res.hconnec,res.fix,res.var,...
            %   res.normal,res.ext,res.pil,res.acc,res.rpdacc)
            
         
              fprintf("\n%d & %d & %d & %d & %d & %d & %d & %d & %d & %d & %d & %d & %d & %d ",...
               res.analyzedmdl,res.mdl_compiles,res.total_hierar,res.total_C_corpus_hierar,res.slchk,res.C_corpus_blk_cnt,res.connec,res.C_corpus_connec,res.fix,res.var,...
               res.normal,res.ext,res.pil,res.acc)
        end
             
        function res = grand_total_analyze_metric(obj,flag)
            % concatenates the results of  different metrics of the different table. 
            % flag is set to true if grand total of earlier replication. Or else set to
            % false if calculating for slnet
            % used to produce the results in the total column of the table
            if flag 
                github = obj.total_analyze_metric('github_models',true);
                matc = obj.total_analyze_metric('matc_models',true);
            else
                   github = obj.total_analyze_metric('github_models',false);
                matc = obj.total_analyze_metric('matc_models',false);
            end
            fn = fieldnames(matc);
            fn = union(fn, fieldnames(github));
            if(flag)
                sourceforge = obj.total_analyze_metric('sourceforge_models',true);
                tutorial  = obj.total_analyze_metric('tutorial_models',true);
                others  = obj.total_analyze_metric('others_models',true);
                fn = union(fn, fieldnames(sourceforge));
                fn = union(fn, fieldnames(tutorial));
                 fn = union(fn, fieldnames(others));
            end 
            
            
            
            
            for i = 1 : length(fn)
                res.(fn{i}) = 0;
                if(flag)
                    if ismember(fn{i},fieldnames(github)) 
                        res.(fn{i}) = github.(fn{i}) + res.(fn{i});
                    end
                    if ismember(fn{i},fieldnames(matc)) 
                        res.(fn{i}) = res.(fn{i}) + matc.(fn{i})
                    end
                     if ismember(fn{i},fieldnames(sourceforge)) 
                        res.(fn{i}) = res.(fn{i}) + sourceforge.(fn{i})
                     end
                     if ismember(fn{i},fieldnames(tutorial)) 
                        res.(fn{i}) = res.(fn{i}) + tutorial.(fn{i})
                     end
                     if ismember(fn{i},fieldnames(others)) 
                        res.(fn{i}) = res.(fn{i}) + others.(fn{i})
                     end
                else
                    if ismember(fn{i},fieldnames(github)) & ismember(fn{i},fieldnames(matc) )
                        res.(fn{i}) = github.(fn{i}) + matc.(fn{i});
                    elseif  ismember(fn{i},fieldnames(github))
                         res.(fn{i}) = github.(fn{i})
                    elseif  ismember(fn{i},fieldnames(matc))
                            res.(fn{i}) = matc.(fn{i})
                    end
                    
                end
        
            end
              %      fprintf("\n%d & %d & %d & %d & %d & %d & %d & %d & %d & %d & %d & %d & %d & %d & %d",...
              %% res.analyzedmdl,res.mdl_compiles,res.total_hierar,res.slchk,res.C_corpus_blk_cnt,res.connec,res.hconnec,res.fix,res.var,...
              % res.normal,res.ext,res.pil,res.acc,res.rpdacc)
              fprintf( "\nHIdden connection are %d % larger\n",cast(res.hconnec,'double')/cast(res.connec,'double') * 100 )
            fprintf( "\nHIdden connection using C_corpus are %d % larger\n",cast(res.C_corpus_hconnec,'double')/cast(res.C_corpus_connec,'double') * 100)
       fprintf("\n%d & %d & %d & %d & %d & %d & %d & %d & %d & %d & %d & %d & %d & %d ",...
               res.analyzedmdl,res.mdl_compiles,res.total_hierar,res.total_C_corpus_hierar,res.slchk,res.C_corpus_blk_cnt,res.connec,res.C_corpus_connec,res.fix,res.var,...
               res.normal,res.ext,res.pil,res.acc)
            %simple = obj.total_analyze_metric('Simple');
            %advanced = obj.total_analyze_metric('Advanced');
            %fn = fieldnames(simple);
            %for i = 1 : length(fn)
            %    res_sa.(fn{i}) = simple.(fn{i}) + advanced.(fn{i});
            %end
            
            %for i = 1 : length(fn)
             %   if(strcmp(fn{i},'most_freq_blks'))
             %       continue
             %   end
              %  assert(res.(fn{i}) ==res_sa.(fn{i}), ['Error comparing ',fn{i}]);
            %end
            
      
        end
        function original_study_mdl_name = list_of_model_name(obj)
            
            loc = 'slcorpus0.csv';
            m = readtable(loc);
            data = table2cell(m);
            tutorial  = data(:,1);
            tutorial = tutorial(~cellfun('isempty',tutorial));
            tutorial =  cellfun(@(x)string(strrep(x,"'","")),tutorial);
            simple = data(:,2);
            simple = simple(~cellfun('isempty',simple));
            simple =  cellfun(@(x)string(strrep(x,"'","")),simple);
            
            advanced = data(:,3);
            advanced = advanced(~cellfun('isempty',advanced));
            advanced =  cellfun(@(x)string(strrep(x,"'","")),advanced);
            
            other = data(:,4);
            other = other(~cellfun('isempty',other));
            other =  cellfun(@(x)string(strrep(x,"'","")),other);
            %original_study_mdl_name_cell = [simple;advanced;other;tutorial];
            original_study_mdl_name_cell = [advanced;other;tutorial]
            [r,c] = size(original_study_mdl_name_cell);
            original_study_mdl_name = "";
            for k = 1:r-1
                original_study_mdl_name=  strcat(original_study_mdl_name,"'",original_study_mdl_name_cell{k},"',");
            end
            
            original_study_mdl_name = strcat(original_study_mdl_name,"'",original_study_mdl_name_cell{r},"'");
          %{
            
                    query = ['select distinct substr(Model_Name,1,length(MOdel_name)-4) from ( '...
'select * from github_models union ALL '...
'select * from matc_models union ALL '...
'select * from SourceForge_Metric union ALL '... 
'select * from Others_Metric union ALL '...
'select * from Tutorial_Metric '...
') where is_Lib = 0']
            model = fetch(obj.conn, query);
            model = cellfun(@(x)string(x),model);
            simple_intersect = intersect((simple),(model),'rows');
            advanc_intersect = intersect((advanced),(model),'rows');
            tutorial_intersect = intersect((tutorial),(model),'rows');
            other_intersect = intersect((other),(model),'rows');
            total_intersect = length(simple_intersect)+length(advanc_intersect)+length(tutorial_intersect)+length(other_intersect);
            obj.WriteLog(sprintf("Total Intersection in models : %d", total_intersect))
            
            [other_diff,i] = setdiff((other),(model)); %8 difference Total : 7 model files from 1 missing project. Other 1 has a different name
            
            [tutot_diff,i] = setdiff((tutorial),(model));
            
            [simple_diff,i] = setdiff((simple),(model));%23 total difference : 16 diff due to name changes in updated project. 
            
            [advanced_diff,i] = setdiff((advanced),(model)); %14 difference : 5 diff due to models removed from project and updated with new one
            
            obj.WriteLog(sprintf("Total Difference in models : %d", sum(length(other_diff)+length(tutot_diff)+length(simple_diff)+length(advanced_diff))))
            %}
        % to check the number of models from meta data to 
        end
        
        function res = reproduce_number_C_Corpus(obj,choice)
                %{
               reproduce the numbers int he Slcorpus0 paper.  per table
               This function can be be called from
               grand_total_reproduce_numbers() to get a aggregated results. 
            arguments: 
                choice : a particular table name 
            Example : 
            obj.reproduce_number_C_Corpus('github_models')
            
                
            %}
            original_mdl_name = obj.list_of_model_name();
            
                  blk_connec_query = ['select sum(SLDiag_Block_count),sum(SCHK_block_count),sum(total_ConnH_cnt),sUm(C_corpus_blk_count),SUM(C_corpus_conn),SUM(C_corpus_conn+C_corpus_hidden_conn) as All_C from ', choice ,' where is_Lib = 0 and is_test = -1 '];
                  total_hierarchial_model_query = ['select count(*) from ',choice, ' where is_Lib = 0 and is_test = -1  and C_corpus_hierar_depth>1'];
                    
                 blk_connec_query = strcat(blk_connec_query,' and substr(Model_Name,0,length(Model_name)-3) IN (',original_mdl_name,')');
                 total_hierarchial_model_query = strcat(total_hierarchial_model_query,' and substr(Model_Name,0,length(Model_name)-3) IN (',original_mdl_name,')');
              
         obj.WriteLog(sprintf("Fetching Total hierarchial model of %s choice with query \n %s",choice,total_hierarchial_model_query));
            total_hierarchial_model = fetch(obj.conn, total_hierarchial_model_query);
            
            obj.WriteLog(sprintf("Fetching Total counts of %s choice with query \n %s",choice,blk_connec_query));
            blk_connec_cnt = fetch(obj.conn, blk_connec_query);
            
            res.sldiag = blk_connec_cnt{1};
            res.slchk = blk_connec_cnt{2};
            res.connec = blk_connec_cnt{3};
            res.c_corpus_blk =  blk_connec_cnt{4};
             res.c_corpus_conn =  blk_connec_cnt{5};
            res.c_corpus_connH =  blk_connec_cnt{6};
            

            
             res.total_hierar = total_hierarchial_model{1};
             
             fprintf("%d & %d & %d & %d \n",...
                res.total_hierar,res.c_corpus_blk,res.c_corpus_conn, res.c_corpus_connH );
            
        end
        function res = grand_total_reproduce_numbers(obj)
            % concatenates the results of  different metrics of the different table. 
            % 
            % used to produce the results in the total column of the table
             github = obj.reproduce_number_C_Corpus('github_models');
            matc = obj.reproduce_number_C_Corpus('matc_models');
   
            fn = fieldnames(matc);

                sourceforge = obj.reproduce_number_C_Corpus('sourceforge_models');
                tutorial  = obj.reproduce_number_C_Corpus('tutorial_models');
                others  = obj.reproduce_number_C_Corpus('others_models');
                
                for i = 1 : length(fn)
                    res.(fn{i}) = 0;
                    if ismember(fn{i},fieldnames(github)) 
                        res.(fn{i}) = github.(fn{i}) + res.(fn{i});
                    end
                    if ismember(fn{i},fieldnames(matc)) 
                        res.(fn{i}) = res.(fn{i}) + matc.(fn{i});
                    end
                     if ismember(fn{i},fieldnames(sourceforge)) 
                        res.(fn{i}) = res.(fn{i}) + sourceforge.(fn{i});
                     end
                     if ismember(fn{i},fieldnames(tutorial)) 
                        res.(fn{i}) = res.(fn{i}) + tutorial.(fn{i});
                     end
                     if ismember(fn{i},fieldnames(others)) 
                        res.(fn{i}) = res.(fn{i}) + others.(fn{i});
                     end
                end
                fprintf("%d & %d & %d & %d \n",...
                res.total_hierar,res.c_corpus_blk,res.c_corpus_conn, res.c_corpus_connH );
            
        end
        
        
       
        
    end
    
        
        

end
