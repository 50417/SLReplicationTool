classdef obtain_non_supported_hierarchial_metrics_par < handle
properties
    table_name;
    foreign_table_name;
    cfg;  
    conn;
    colnames = {'File_Name','Model_Name','Depth','Block_count','Conn_count_no_hidden','Conn_count_hidden_only','Child_model_count'};
    coltypes = {'NUMERIC','VARCHAR','NUMERIC','NUMERIC','NUMERIC','NUMERIC','NUMERIC'};
    blk_count;
    
    max_depth;%keeping track of maximum depth to insert into database
    
        blockTypeMap;
        uniqueBlockMap;
        modelrefMap;
        sfun_reuse_map;
        childModelPerLevelMap;
        connectionsLevelMap;
        hconns_level_map;
        blk_count_this_levelMap;
        
        descendants_count;%
        total_lines_count ;% number of connections including hidden lines
        ncs_count;%
        
        
end
methods
    function obj = obtain_non_supported_hierarchial_metrics_par()
            warning on verbose
            %sobj.WriteLog("open");
            
            obj.cfg = model_metric_cfg();
            obj.table_name = obj.cfg.lvl_info_table_name;
            obj.foreign_table_name = obj.cfg.lvl_info_foreign_table_name;
            
            obj.resetting_maps_variables()
            
            obj.connect_table();
    end
    function success =resetting_maps_variables(obj)
            obj.blockTypeMap = mymap();;
            obj.uniqueBlockMap = mymap();
            obj.childModelPerLevelMap = mymap();
            obj.modelrefMap = mymap();
            obj.sfun_reuse_map = mymap();
            obj.connectionsLevelMap = mymap();
            obj.hconns_level_map = mymap();
            obj.blk_count_this_levelMap = mymap();
                            
            obj.descendants_count = 0
            obj.total_lines_count = 0
            obj.ncs_count =0
            success = 1
    end
         %Logging purpose
        %Credits: https://www.mathworks.com/matlabcentral/answers/1905-logging-in-a-matlab-script
        function WriteLog(obj,Data)
            global FID %https://www.mathworks.com/help/matlab/ref/persistent.html Local to functions but values are persisted between calls.
           
            fprintf(FID, '%s: %s\n',datestr(now, 'dd/mm/yy-HH:MM:SS'), Data);
            % Write to the screen at the same time:
            fprintf('%s: %s\n', datestr(now, 'dd/mm/yy-HH:MM:SS'), Data);
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
            ,'( M_ID INTEGER primary key autoincrement ,', cols  ,", CONSTRAINT FK FOREIGN KEY(M_ID) REFERENCES ", obj.foreign_table_name...
                 ,'(id))');
        
            
          
            if obj.cfg.DROP_TABLES
                %obj.WriteLog(sprintf("Dropping %s",obj.table_name))
                obj.drop_table();
                %obj.WriteLog(sprintf("Dropped %s",obj.table_name))
            end
            %obj.WriteLog(create_metric_table);
            exec(obj.conn,create_metric_table);
        end
              
        %drop table Striclty for debugging purposes
        function drop_table(obj)
            %Strictly for debugginf purpose only
            sqlquery = ['DROP TABLE IF EXISTS ' obj.table_name];
            exec(obj.conn,sqlquery);
            %max(data)
        end
        
        %Writes to database 
        function output_bol = write_to_database(obj,id,model_name,Depth,Block_count,Conn_count_no_hidden,Conn_count_hidden_only,Child_model_count)%block_count)
                                        
            insert(obj.conn,obj.table_name,obj.colnames, ...
                {id,model_name,Depth,Block_count,Conn_count_no_hidden,Conn_count_hidden_only,Child_model_count});
            output_bol= 1;
        end
        
    %reimplementation of SLforge recursive function to calculate metrics not supported by API
        function blk_count_this_level = obtain_hierarchy_metrics(obj,file_name, model,depth,isModelReference, is_second_time)
            if  obj.max_depth < depth
                obj.max_depth = depth;
            end
            if isModelReference
                mdlRefName = get_param(model,'ModelName');
                load_system(mdlRefName);
                all_blocks = find_system(mdlRefName,'SearchDepth',1, 'LookUnderMasks', 'all', 'FollowLinks','on');
                all_blocks = all_blocks(2:end); 
                
                lines = find_system(mdlRefName,'SearchDepth','1','FindAll','on', 'LookUnderMasks', 'all', 'FollowLinks','on', 'type','line');

            else
                all_blocks = find_system(model,'SearchDepth',1, 'LookUnderMasks', 'all', 'FollowLinks','on');
                lines = find_system(model,'SearchDepth','1','FindAll','on', 'LookUnderMasks', 'all', 'FollowLinks','on', 'type','line');
            end
            
            blk_count_this_level=0; 
            childCount_onthisLevel=0;%Child models are blocks which are model references and Subsystem
            subsystem_count = 0; % subsystem count in this level (subset of childmodels)
            count_sfunctions = 0;
            
            [blockCount,~] =size(all_blocks);
            
           % slb = slblocks_light(0); TODO Correlation 
            
            hidden_lines = 0;
            hidden_block_type = 'From';
            
            %skip the root model which always comes as the first model
            for i=1:blockCount
                currentBlock = all_blocks(i);
                
                if ~ strcmp(currentBlock, model) 
                        blockType = get_param(currentBlock, 'blocktype');
                    
                    if ~ is_second_time
                        obj.blockTypeMap.inc(blockType{1,1}); % TODO
                    end
                    %TODO
                    %libname = obj.get_lib(blockType{1, 1});
                    
                    %if ~ is_second_time
                     %   obj.libcount_single_model.inc(libname);
                    %    obj.uniqueBlockMap.inc(blockType{1,1});
                    %end
                    
                    if strcmp(blockType,'SubSystem') || strcmp(blockType,'ModelReference')
                        % child model found
                        
                        if strcmp(blockType,'ModelReference')
                            childCount_onthisLevel=childCount_onthisLevel+1;
                            
                            modelName = get_param(currentBlock,'ModelName');
                            is_model_reused = obj.modelrefMap.contains(modelName);
                            obj.modelrefMap.inc(modelName{1,1});
                         
                            %if ~ is_model_reused
                                % Will not count the same referenced model
                                % twice. % TODO since this is commented
                                % out, pass this param to
                                % obtain_hierarchy_metrics
                                obj.obtain_hierarchy_metrics(file_name,currentBlock,depth+1,true, is_model_reused);
                            %end
                        else % block is subsystem Subsystem
                            %TODO: Subsystem Reuse. 
                            inner_count  = obj.obtain_hierarchy_metrics(file_name,currentBlock,depth+1,false, false);
                            if inner_count > 0
                                % There are some subsystems which are not
                                % actually subsystems, they have zero
                                % blocks. Also, masked ones won't show any
                                % underlying implementation
                                childCount_onthisLevel=childCount_onthisLevel+1;
                                subsystem_count = subsystem_count + 1;
                            end
                        end
                    elseif strcmp('S-Function', blockType) % TODO
                        % S-Function found
                        if ~ is_second_time
                            count_sfunctions = count_sfunctions + 1;
                        end
                       
                        sfun_name = char(get_param(currentBlock, 'FunctionName'));
                        obj.sfun_reuse_map.inc(sfun_name);
                    elseif strcmp(hidden_block_type, blockType) % TODO
%                         if ~ is_second_time
                            hidden_lines = hidden_lines + 1;
%                         end    
                    end
                    
                    blk_count_this_level=blk_count_this_level+1; % number of blocks in each level.
                    obj.blk_count = obj.blk_count + 1; %Total number of blocks in the model.
                    
                    %TODO:
                    %if analyze_complexity.CALCULATE_SCC
                    %    slb.process_new_block(currentBlock);
                    %end
                    
                end
            end
            
%             fprintf('\n');
 %TODO           
            %if analyze_complexity.CALCULATE_SCC
             %   fprintf('Get SCC for %s\n', char(model));
             %   con_com = simulator.get_connected_components(slb);
             %   fprintf('[ConComp] Got %d connected comps\n', con_com.len);

%                obj.scc_count = obj.scc_count + con_com.len;
 %           end
            
  %          if analyze_complexity.CALCULATE_CYCLES
   %             fprintf('Computing Cycles...\n');
    %            obj.cycle_count = obj.cycle_count + getCountCycles(slb);
     %       end
            
            
            
%             fprintf('\tBlock Count: %d\n', blk_count_this_level);
            
            
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
                    end
                end
                
            end
            
            mapKey = int2str(depth);
            
            if blk_count_this_level >0 %If this lvl of the subsystem or model reference contains blocks  
%                 fprintf('Found %d blocks\n', count);
                
                obj.blk_count_this_levelMap.insert_or_add(mapKey, blk_count_this_level);
                % If there are blocks, only then it makes sense to count
                % connections
                obj.connectionsLevelMap.insert_or_add(mapKey,unique_lines);
                obj.childModelPerLevelMap.insert_or_add(mapKey, childCount_onthisLevel); %WARNING shouldn't we do this only when count>0?
                obj.connectionsLevelMap.insert_or_add(mapKey,unique_lines);
                obj.hconns_level_map.insert_or_add(mapKey,hidden_lines);
                
                obj.descendants_count = obj.descendants_count + childCount_onthisLevel; %Model Reference Count and Subsystem
                obj.total_lines_count = obj.total_lines_count + hidden_lines + unique_lines;
                obj.ncs_count = obj.ncs_count + subsystem_count;
            
            else
                assert(unique_lines == 0); % sanity check
            end
           
            
           
            
        end
        
        
    function [total_lines_cnt,total_descendant_count,ncs_count,unique_sfun_count,sfun_reused_key_val,blk_type_count,modelrefMap_reused_val,unique_mdl_ref_count] = populate_hierarchy_info(obj,file_name, mdl_name,hierar_File)
        obj.max_depth = 1;
       
        obj.resetting_maps_variables()
        obj.obtain_hierarchy_metrics(file_name,mdl_name,1,false, false);
        
        
        %Writing To Database
        %obj.WriteLog(sprintf("Writing to %s",obj.table_name))
        for i = 1:obj.max_depth
             fprintf(hierar_File.Value,'%d, %s, %d, %d, %d ,%d , %d\n',...
                            file_name,mdl_name,i,...
                          obj.blk_count_this_levelMap.get(int2str(i)),obj.connectionsLevelMap.get(int2str(i)),obj.hconns_level_map.get(int2str(i))...
                         ,obj.childModelPerLevelMap.get(int2str(i)));
           
            %obj.write_to_database(file_name,mdl_name,i,...
             %             obj.blk_count_this_levelMap.get(int2str(i)),obj.connectionsLevelMap.get(int2str(i)),obj.hconns_level_map.get(int2str(i))...
              %           ,obj.childModelPerLevelMap.get(int2str(i))); %WARNING childCount_onthisLevel: shouldn't we do this only when blk_count_this_level inside it>0?
 
        end
        sfun_val_str='';% variable that has sfunction with its count separate by comma, FORMAT: ,sfunname_count, 
        sfun_key = obj.sfun_reuse_map.keys();
        for K = 1 :length(sfun_key)

                sfun_val_str = strcat(sfun_val_str,'.',sfun_key{K},'_',int2str(obj.sfun_reuse_map.get(sfun_key{K})));
        end
        
        mdlref_val_str='';% variable that has mdlref with its count separate by comma, FORMAT: ,mdl_ref_count, 
        mdlref_key = obj.modelrefMap.keys();
        for K = 1 :length(mdlref_key)
           mdlref_val_str = strcat(mdlref_val_str,'.',mdlref_key{K},'_',int2str(obj.modelrefMap.get(mdlref_key{K})));          
        end
        total_descendant_count = obj.descendants_count ;%Model Reference + subsystem Count 
         total_lines_cnt =   obj.total_lines_count; 
         ncs_count = obj.ncs_count; % num of contained subsystem
         unique_sfun_count = length(sfun_key);
         sfun_reused_key_val= sfun_val_str; % list of s function used more than once
         blk_type_count = obj.blockTypeMap;
        
         modelrefMap_reused_val = mdlref_val_str; % list of mdlref used and its count
         unique_mdl_ref_count = length(mdlref_key);
      
    end
end


end
