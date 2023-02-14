classdef get_block_info < handle
properties
    table_name;
    foreign_table_name;
    cfg;  
    conn;
    colnames = {'File_ID','Model_Name','file_path','BLK_TYPE','Count'};
    coltypes = {'NUMERIC','VARCHAR','VARCHAR','VARCHAR','NUMERIC'};

    
end
methods
    function obj = get_block_info()
            warning on verbose
            %obj.WriteLog("open");
            
            obj.cfg = model_metric_cfg();
            obj.table_name = obj.cfg.blk_info_table_name;
            obj.foreign_table_name = obj.cfg.blk_info_foreign_table_name;
            
      
            obj.connect_table();
    end
    
       %Logging purpose
        function WriteLog(obj,Data)
            global FID 
          
            fprintf(FID, '%s: %s\n',datestr(now, 'dd/mm/yy-HH:MM:SS'), Data);
            % Write to the screen at the same time:
           if obj.cfg.DEBUG
                fprintf('%s: %s\n', datestr(now, 'dd/mm/yy-HH:MM:SS'), Data);
            end
        end
    %creates Table to store model metrics 
        function connect_table(obj)
            if ~isfile(obj.cfg.dbfile)
                obj.conn = sqlite(obj.cfg.dbfile,'create');
            else
                obj.conn = sqlite(obj.cfg.dbfile,'connect');
            end
            cols = strcat(obj.colnames(1) ," ",obj.coltypes(1)) ;
            for i=2:length(obj.colnames)
                cols = strcat(cols, ... 
                    ',', ... 
                    obj.colnames(i), " ",obj.coltypes(i) ) ;
            end
           create_metric_table = strcat("create table IF NOT EXISTS ", obj.table_name ...
            ,'( M_ID INTEGER primary key autoincrement ,', cols  ,",CONSTRAINT UPair UNIQUE(File_id,Model_Name,file_path,BLK_TYPE), CONSTRAINT FK FOREIGN KEY(File_ID) REFERENCES ", obj.foreign_table_name...
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
        function output_bol = write_to_database(obj,id,model_name,file_path,blk_type,block_count)%block_count)
                                        
            insert(obj.conn,obj.table_name,obj.colnames, ...
                {id,model_name,file_path,blk_type,block_count});
            output_bol= 1;
        end
        
        
    function success = populate_block_info(obj,file_name, mdl_name,blk_type_count,file_path)
        blk_type_keys = blk_type_count.keys();
        obj.WriteLog(sprintf("Writing to %s",obj.table_name))
        try 
        for K = 1 :length(blk_type_keys)
            obj.WriteLog(sprintf("FileName = %d modelName = %s BlockType = %s BlockCount = %d ",file_name,mdl_name,blk_type_keys{K},blk_type_count.get(blk_type_keys{K})))
            obj.write_to_database(file_name,mdl_name,file_path,blk_type_keys{K},blk_type_count.get(blk_type_keys{K}));
        end
         catch ME
               
           obj.WriteLog(sprintf('ERROR Inserting into database: Blk Info for %s',mdl_name));                    
            obj.WriteLog(['ERROR ID : ' ME.identifier]);
            obj.WriteLog(['ERROR MSG : ' ME.message]);
           %rmpath(genpath(folder_path));
       end
        success = 1;
 
    end
end


end
