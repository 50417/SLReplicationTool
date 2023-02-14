classdef get_block_info_par < handle
properties
    table_name;
    foreign_table_name;
    cfg;  
    conn;
    colnames = {'File_Name','Model_Name','BLK_TYPE','Count'};
    coltypes = {'NUMERIC','VARCHAR','VARCHAR','NUMERIC'};

    
end
methods
    function obj = get_block_info_par()
            warning on verbose
            %obj.WriteLog("open");
            
            obj.cfg = model_metric_cfg();
            obj.table_name = obj.cfg.blk_info_table_name;
            obj.foreign_table_name = obj.cfg.blk_info_foreign_table_name;
            
      
            obj.connect_table();
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
                obj.drop_table();
              end
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
        function output_bol = write_to_database(obj,id,model_name,blk_type,block_count)%block_count)
                                        
            insert(obj.conn,obj.table_name,obj.colnames, ...
                {id,model_name,blk_type,block_count});
            output_bol= 1;
        end
        
        
    function success = populate_block_info(obj,file_name, mdl_name,blk_type_count)
        blk_type_keys = blk_type_count.keys();
        for K = 1 :length(blk_type_keys)
            blk_type_count.get(blk_type_keys{K})
            %obj.write_to_database(file_name,mdl_name,blk_type_keys{K},blk_type_count.get(blk_type_keys{K}));
        end
        success = 1;
 
    end
end


end
