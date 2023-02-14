classdef obtain_non_supported_hierarchial_metrics < handle
properties
    table_name;
    foreign_table_name;
    cfg;  
    conn;
    colnames = {'File_id','Model_Name','file_path','Depth','Block_count','Conn_count_no_hidden','Conn_count_hidden_only','Child_model_count'};
    coltypes = {'NUMERIC','VARCHAR','VARCHAR','NUMERIC','NUMERIC','NUMERIC','NUMERIC','NUMERIC'};
    blk_count;
    
    subsys_info; 
    
    max_depth;%keeping track of maximum depth to insert into database
    
        blockTypeMap;
        uniqueBlockMap;
        modelrefMap;
        sfun_reuse_map;
        childModelPerLevelMap;
        connectionsLevelMap;
        hconns_level_map;
        blk_count_this_levelMap;
        
        descendants_count = 0;
        total_lines_count = 0; % number of connections including hidden lines
        ncs_count =0;
        
        scc_count = 0;
        
end
methods
    function obj = obtain_non_supported_hierarchial_metrics()
            warning on verbose
            %sobj.WriteLog("open");
            
            obj.cfg = model_metric_cfg();
            obj.table_name = obj.cfg.lvl_info_table_name;
            obj.foreign_table_name = obj.cfg.lvl_info_foreign_table_name;
            obj.subsys_info = subsystem_info();
            
            obj.resetting_maps_variables();
            
            obj.connect_table();
    end
    function success =resetting_maps_variables(obj)
            obj.blockTypeMap = mymap();
            obj.uniqueBlockMap = mymap();
            obj.childModelPerLevelMap = mymap();
            obj.modelrefMap = mymap();
            obj.sfun_reuse_map = mymap();
            obj.connectionsLevelMap = mymap();
            obj.hconns_level_map = mymap();
            obj.blk_count_this_levelMap = mymap();
                            
            obj.descendants_count = 0;
            obj.total_lines_count = 0;
            obj.ncs_count =0;
            
            obj.scc_count= 0; 
            success = 1;
    end
    
         %Logging purpose
        %Credits: https://www.mathworks.com/matlabcentral/answers/1905-logging-in-a-matlab-script
        function WriteLog(obj,Data)
            global FID %https://www.mathworks.com/help/matlab/ref/persistent.html Local to functions but values are persisted between calls.
           
            fprintf(FID, '%s: %s\n',datestr(now, 'dd/mm/yy-HH:MM:SS'), Data);
            if obj.cfg.DEBUG
                fprintf('%s: %s\n', datestr(now, 'dd/mm/yy-HH:MM:SS'), Data);
            end
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
            ,'( M_ID INTEGER primary key autoincrement ,', cols  ,",  CONSTRAINT UPair UNIQUE(File_id,Model_Name,Depth,file_path),CONSTRAINT FK FOREIGN KEY(File_id) REFERENCES ", obj.foreign_table_name...
                 ,'(id))');
        
            
          
            if obj.cfg.DROP_TABLES
                obj.WriteLog(sprintf("Dropping %s",obj.table_name))
                obj.drop_table();
                obj.WriteLog(sprintf("Dropped %s",obj.table_name))
            end
            obj.WriteLog(create_metric_table);
            exec(obj.conn,char(create_metric_table));
        end
              
        %drop table Striclty for debugging purposes
        function drop_table(obj)
            %Strictly for debugginf purpose only
            sqlquery = ['DROP TABLE IF EXISTS ' obj.table_name];
            exec(obj.conn,char(sqlquery));
            %max(data)
        end
        
        %Writes to database 
        function output_bol = write_to_database(obj,id,model_name,file_path,Depth,Block_count,Conn_count_no_hidden,Conn_count_hidden_only,Child_model_count)%block_count)
                                        
            insert(obj.conn,obj.table_name,obj.colnames, ...
                {id,model_name,file_path,Depth,Block_count,Conn_count_no_hidden,Conn_count_hidden_only,Child_model_count});
            output_bol= 1;
        end
        %returns all components at a particular depth 
        function key_of_map = get_modelcomponent(obj,map_comp_dpth,dpth)
            ind = cellfun(@(x)isequal(x,dpth),values(map_comp_dpth));
            testkeys = keys(map_comp_dpth);
            key_of_map = testkeys(ind);
        end
        
        function [blk_lst_this_lvl,root_blk] = list_of_blocks_in_this_lvl(obj,model_name, component_in_every_lvl,mdlref_depth_map,dpth)
            blk_lst_this_lvl = {};
            root_blk = {};
           
                main_comp = obj.get_modelcomponent(component_in_every_lvl,dpth-1);
                mdlref_comp = obj.get_modelcomponent(mdlref_depth_map,dpth-1);
                
                [r,c] = size(main_comp);
                for p = 1: c
                    component_blocks = find_system(main_comp(p),'SearchDepth',1,'LookUnderMasks', 'all', 'FollowLinks','off');
                    for j = 1: length(component_blocks)
                        if ~ strcmp(component_blocks{j},main_comp(p)) 
                            blk_lst_this_lvl(end+1,1) = component_blocks(j);
                        end
                    end
                    root_blk(end+1,1) =main_comp(p);
                end
                    
                [r,c] = size(mdlref_comp);
                 for p = 1: c
                     mdl_component_blocks = find_system(mdlref_comp(p),'SearchDepth',1,'LookUnderMasks', 'all', 'FollowLinks','off');
                        for j = 1: length(mdl_component_blocks)
                            if ~ strcmp(mdl_component_blocks{j}, mdlref_comp(p)) 
                                blk_lst_this_lvl(end+1,1) = mdl_component_blocks(j);
                            end
                        end
                        root_blk(end+1,1) = mdlref_comp(p);
                 end
                   %{ 
                main_comp_cur_lvl = obj.get_modelcomponent(component_in_every_lvl,dpth);
                mdlref_com_cur_lvl = obj.get_modelcomponent(mdlref_depth_map,dpth);
                
                [r,c] = size(main_comp_cur_lvl);
                for p = 1: c
                    blk_lst_this_lvl(end+1,1) = main_comp_cur_lvl(p);
                end
                    
                [r,c] = size(mdlref_com_cur_lvl);
                 for p = 1: c
                    blk_lst_this_lvl(end+1,1) = mdlref_com_cur_lvl(p);
                end
              
                
                
                blk_name_of_component = get_param(component_in_every_lvl(i),'Name');
                
                %https://www.mathworks.com/help/matlab/ref/cellfun.html
                num_of_bslash = cellfun('length',regexp(component_in_every_lvl(i),'/')) ;
                if num_of_bslash == dpth - 1 && ~isKey(mdlref_depth_map,(string(component_in_every_lvl(i)))) 
                    %if (isempty(find_system(model_name,'lookundermasks','all','Name',blk_name_of_component(end))))
                    %end 
                    
                   
                elseif isKey(mdlref_depth_map,string(component_in_every_lvl(i))) && mdlref_depth_map(string(component_in_every_lvl(i))) == dpth
                    %https://www.mathworks.com/help/simulink/slref/find_mdlrefs.html#butnbec-1-allLevels
                    [mdlref,mdlref_name] = find_mdlrefs(model_name,'ReturnTopModelAsLastElement',false);
                    idx = find(strcmp([mdlref], blk_name_of_component));
                    if ~isempty(idx)
                        mdl_ref_fullpath = mdlref_name(idx(1));
                    else 
                        mdl_ref_fullpath ={}
                    end

                    if(isempty(mdl_ref_fullpath))
                        blk_lst_this_lvl(end+1,1) = component_in_every_lvl(i);
                    else
                        blk_lst_this_lvl(end+1,1) = mdl_ref_fullpath;
                    end
                end
                if isKey(mdlref_depth_map,string(component_in_every_lvl(i))) && mdlref_depth_map(string(component_in_every_lvl(i))) == dpth -1
                    mdl_component_blocks = find_system(component_in_every_lvl(i),'SearchDepth',1,'LookUnderMasks', 'all', 'FollowLinks','off');
                    for j = 1: length(mdl_component_blocks)
                        if ~ strcmp(mdl_component_blocks{j}, component_in_every_lvl(i)) 
                            blk_lst_this_lvl(end+1,1) = mdl_component_blocks(j);
                        end
                    end
                    root_blk(end+1,1) = component_in_every_lvl(i);
                end
                
            end
                 %}
            
            blk_lst_this_lvl =  unique(blk_lst_this_lvl,'stable');
            root_blk =   unique(root_blk,'stable');
        end

    
        
    %reimplementation of SLforge/Curated corpus recursive function to
    %iterative one to calculate metrics not supported by API. Also removed
    %max depth hyperparameters and support counting of model reference
    %block counts and line counts
        function blk_count_this_level = obtain_hierarchy_metrics(obj, model,file_name,mdl_name,component_in_every_lvl,mdlref_depth_map,file_path)
            max_depth_from_api = obj.max_depth;% max_depth api calculated by hacking Simulink Check API. 
            %all_blocks_in_every_lvl = find_system(model,'SearchDepth',max_depth_from_api,'LookUnderMasks', 'all', 'FollowLinks','off');
            
            for depth = 1:max_depth_from_api
                blk_count_this_level = 0; 
                childCount_onthisLevel = 0;%Child models are blocks which are model references and Subsystem (Child Representing blocks)
                subsystem_count = 0; % subsystem count in this level (subset of childmodels) (NCS)
                count_sfunctions = 0;
                
                
                %Separating the blocks that is in current level from the full list and also return the root model separately. 
                [blk_lst_this_lvl,root_blk] = obj.list_of_blocks_in_this_lvl(model,component_in_every_lvl,mdlref_depth_map,depth);
                
                
                
                slb = slblocks_light(0);
            
                hidden_lines = 0;
                hidden_block_type = 'From'; % Earlier Implementation counts hidden line/connections as any line coming from FROM blocktype
                                            %hidden line is then added to
                                            %full line count on the level.
                                            %which is incorrect based on
                                            %this video https://www.youtube.com/watch?v=Uh7cYDo1vfU
                
                [blockCount,~] =size(blk_lst_this_lvl);   
                for i=1:blockCount
                    currentBlock = blk_lst_this_lvl(i);

                    if ~ strcmp(currentBlock, model) 
                        
                        blockType = get_param(currentBlock, 'blocktype');
                        obj.blockTypeMap.inc(blockType{1,1});
                        
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
                                %is_model_reused = obj.modelrefMap.contains(modelName);
                                obj.modelrefMap.inc(modelName{1,1});
                            else % block is subsystem Subsystem
                           
                                [inner_count,~]  = size(find_system(currentBlock,'SearchDepth',1,'LookUnderMasks', 'all', 'FollowLinks','off'));
                                if inner_count-1 > 0%inner_count-1 to skip the root model
                                    % There are some subsystems which are not
                                    % actually subsystems, they have zero
                                    % blocks. Also, masked ones won't show any
                                    % underlying implementation
                                    %Writing to a database 
                                    obj.WriteLog(sprintf("Populating Subsystem Info Table "))
                                    obj.subsys_info.write_to_database(file_name,mdl_name,file_path,depth,currentBlock,inner_count-1);%inner_count-1 to skip the root model
                                    childCount_onthisLevel=childCount_onthisLevel+1;
                                    subsystem_count = subsystem_count + 1;
                                end
                            end
                        elseif strcmp('S-Function', blockType) 
                            % S-Function found
          
                                count_sfunctions = count_sfunctions + 1;
                       
                            sfun_name = char(get_param(currentBlock, 'FunctionName'));
                            obj.sfun_reuse_map.inc(sfun_name);
                        elseif strcmp(hidden_block_type, blockType) %
                                hidden_lines = hidden_lines + 1;

                        end

                        blk_count_this_level = blk_count_this_level+1; % number of blocks in each level.
                        obj.blk_count = obj.blk_count + 1; %Total number of blocks in the model.

                        %TODO:
                        %if analyze_complexity.CALCULATE_SCC
                            slb.process_new_block(currentBlock);
                        %end

                    end
                end
                                       
                  
                 
                %if analyze_complexity.CALCULATE_SCC
                  fprintf('Get SCC for %s\n', char(model));
                   con_com = get_connected_components(slb);
                   %fprintf('[ConComp] Got %d connected comps\n', con_com.len);

                   obj.scc_count = obj.scc_count + con_com.len;
                %end
                
                %TODO
              %if analyze_complexity.CALCULATE_CYCLES
                   %fprintf('Computing Cycles...\n');
                   %cycle_count = getCountCycles(slb)
                   %obj.cycle_count = obj.cycle_count + cycle_count;
              %end

                %}
                 %Calculating number of lines /connections for this lvl
                [rootCount,~] =size(root_blk);  
                unique_lines = 0;
                unique_line_map = mymap();
                for i=1:rootCount
                    
                    lines = find_system(root_blk(i),'SearchDepth','1','FindAll','on', 'LookUnderMasks', 'all', 'FollowLinks','off', 'type','line');
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
                end

                mapKey = int2str(depth);% To make it consistent with the Simulink Check API Hierarchy Depth

                if blk_count_this_level >0 %If this lvl of the subsystem or model reference contains blocks  
    %                 fprintf('Found %d blocks\n', count);

                    obj.blk_count_this_levelMap.insert_or_add(mapKey, blk_count_this_level);
                    % If there are blocks, only then it makes sense to count
                    % connections
                    obj.connectionsLevelMap.insert_or_add(mapKey,unique_lines);
                    obj.childModelPerLevelMap.insert_or_add(mapKey, childCount_onthisLevel); %WARNING shouldn't we do this only when count>0?
                    obj.hconns_level_map.insert_or_add(mapKey,hidden_lines);

                    obj.descendants_count = obj.descendants_count + childCount_onthisLevel; %Model Reference Count and Subsystem
                    obj.total_lines_count = obj.total_lines_count + unique_lines; % + hidden_lines Removed as it may not be correct
                    obj.ncs_count = obj.ncs_count + subsystem_count;

                else
                    assert(unique_lines == 0); % sanity check
                end
           
            
           
            %}
            end
            
            
            %{
            if isModelReference
                mdlRefName = get_param(model,'ModelName');
                load_system(mdlRefName);
                all_blocks = find_system(mdlRefName,'SearchDepth',1, 'LookUnderMasks', 'all', 'FollowLinks','off'); % changed from 'FollowLinks','on');
                all_blocks = all_blocks(2:end); 
                
                lines = find_system(mdlRefName,'SearchDepth','1','FindAll','on', 'LookUnderMasks', 'all', 'FollowLinks','off', 'type','line');

            else
                all_blocks = find_system(model,'SearchDepth',1, 'LookUnderMasks', 'all', 'FollowLinks','off');
                lines = find_system(model,'SearchDepth','1','FindAll','on', 'LookUnderMasks', 'all', 'FollowLinks','off', 'type','line');
            end
            %}
    
        end
        
        function load_reference_model(obj,mdlref_depth_map)
            mdl= mdlref_depth_map.keys();
            for i = 1: length(mdl)
            load_system(mdl(i));
            end
        end
        function close_reference_model(obj,mdlref_depth_map)
            mdl= mdlref_depth_map.keys();
            for i = 1: length(mdl)
            close_system(mdl(i));
            end
        end
    function [total_lines_cnt,total_descendant_count,ncs_count,scc_count,unique_sfun_count,sfun_reused_key_val,blk_type_count,modelrefMap_reused_val,unique_mdl_ref_count] = populate_hierarchy_info(obj,file_name, mdl_name,depth,component_in_every_lvl,mdlref_depth_map,file_path)
       obj.max_depth = depth;
       obj.resetting_maps_variables();
       model_name = strrep(mdl_name,'.slx','');
       model_name = strrep(model_name,'.mdl','');
       
       
        try
            obj.load_reference_model(mdlref_depth_map);
            obj.obtain_hierarchy_metrics(model_name,file_name,mdl_name,component_in_every_lvl,mdlref_depth_map,file_path); % filename and mdl_name is to populate subsystem info table. 
            obj.close_reference_model(mdlref_depth_map);
        catch ME
            obj.close_reference_model(mdlref_depth_map);
              obj.WriteLog(sprintf("ERROR Obtaining Hierarchy metric for  %s",mdl_name));                    
            obj.WriteLog(['ERROR ID : ' ME.identifier]);
            obj.WriteLog(['ERROR MSG : ' ME.message]);
            return;
           %rmpath(genpath(folder_path));
        end
        %Writing To Database
        obj.WriteLog(sprintf("Writing to %s",obj.table_name))
        try
            for i = 1:obj.max_depth
                 obj.WriteLog(sprintf("FileName = %d modelName = %s hierarchyLvl = %d BlockCount = %d ConnectionCount = %d HConnCount = %d ChildModelCount = %d ",...
                                file_name,mdl_name,i,...
                              obj.blk_count_this_levelMap.get(int2str(i)),obj.connectionsLevelMap.get(int2str(i)),obj.hconns_level_map.get(int2str(i))...
                             ,obj.childModelPerLevelMap.get(int2str(i))))

                obj.write_to_database(file_name,mdl_name,file_path,i,...
                              obj.blk_count_this_levelMap.get(int2str(i)),obj.connectionsLevelMap.get(int2str(i)),obj.hconns_level_map.get(int2str(i))...
                             ,obj.childModelPerLevelMap.get(int2str(i))); %WARNING childCount_onthisLevel: shouldn't we do this only when blk_count_this_level inside it>0?

            end
         catch ME
               
           obj.WriteLog(sprintf("ERROR Inserting into database Hierar Info for  %s",mdl_name));                    
            obj.WriteLog(['ERROR ID : ' ME.identifier]);
            obj.WriteLog(['ERROR MSG : ' ME.message]);
           %rmpath(genpath(folder_path));
       end
        sfun_val_str='';% variable that has sfunction with its count separate by comma, FORMAT: ,sfunname_count, 
        sfun_key = obj.sfun_reuse_map.keys();
        for K = 1 :length(sfun_key)

                sfun_val_str = strcat(sfun_val_str,',',sfun_key{K},'_',int2str(obj.sfun_reuse_map.get(sfun_key{K})));
        end
        
        mdlref_val_str='';% variable that has mdlref with its count separate by comma, FORMAT: ,mdl_ref_count, 
        mdlref_key = obj.modelrefMap.keys();
        for K = 1 :length(mdlref_key)
           mdlref_val_str = strcat(mdlref_val_str,',',mdlref_key{K},'_',int2str(obj.modelrefMap.get(mdlref_key{K})));          
        end
        total_descendant_count = obj.descendants_count ;%Model Reference + subsystem Count
         total_lines_cnt =   obj.total_lines_count; 
         ncs_count = obj.ncs_count; % num of contained subsystem
         scc_count = obj.scc_count;
         unique_sfun_count = length(sfun_key);
         sfun_reused_key_val= sfun_val_str; % list of s function used more than once
         blk_type_count = obj.blockTypeMap;
        
         modelrefMap_reused_val = mdlref_val_str; % list of mdlref used and its count
         unique_mdl_ref_count = length(mdlref_key);
  
      
    end
end


end
