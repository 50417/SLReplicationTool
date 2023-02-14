classdef subsystem_info < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        table_name;
        foreign_table_name;
        cfg;  
        conn;
        colnames = {'File_id','Model_Name','file_path','Depth','Subsystem','Block_count'};
        coltypes = {'NUMERIC','VARCHAR','VARCHAR','NUMERIC','VARCHAR','NUMERIC'};
        blk_count;

    
    end
    
    methods
        %Logging purpose
        %Credits: https://www.mathworks.com/matlabcentral/answers/1905-logging-in-a-matlab-script
        function WriteLog(obj,Data)
            global FID %https://www.mathworks.com/help/matlab/ref/persistent.html Local to functions but values are persisted between calls.
           
            fprintf(FID, '%s: %s\n',datestr(now, 'dd/mm/yy-HH:MM:SS'), Data);
            if obj.cfg.DEBUG
                fprintf('%s: %s\n', datestr(now, 'dd/mm/yy-HH:MM:SS'), Data);
            end
        end
        
        function obj = subsystem_info()
            warning on verbose
            %sobj.WriteLog("open");
            
            obj.cfg = model_metric_cfg();
            obj.table_name = obj.cfg.subsys_info_table_name;
            obj.foreign_table_name = obj.cfg.subsys_info_foreign_table_name;
            
            
            obj.connect_table();
        end
        function connect_table(obj)
            obj.conn = sqlite(obj.cfg.dbfile,'connect');
            cols = strcat(obj.colnames(1) ," ",obj.coltypes(1)) ;
            for i=2:length(obj.colnames)
                cols = strcat(cols, ... 
                    ',', ... 
                    obj.colnames(i), " ",obj.coltypes(i) ) ;
            end
           create_metric_table = strcat("create table IF NOT EXISTS ", obj.table_name ...
            ,'( S_ID INTEGER primary key autoincrement ,', cols  ,",  CONSTRAINT UPair UNIQUE(File_id,Model_Name,file_path,Depth,Subsystem),CONSTRAINT FK FOREIGN KEY(File_id) REFERENCES ", obj.foreign_table_name...
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
        function output_bol = write_to_database(obj,id,model_name,file_path,Depth,subsys,Block_count)
            obj.WriteLog(sprintf("File id = %d hierarchyLvl = %d subsys= %s BlockCount = %d",...
                                id,Depth,subsys{1},Block_count ));
            try
                insert(obj.conn,obj.table_name,obj.colnames, ...
                    {id,model_name,file_path,Depth,subsys{1},Block_count});
                output_bol= 1;
             
            catch ME
                obj.WriteLog(sprintf("ERROR Inserting into database Subsys Info for  %s",model_name));                    
                obj.WriteLog(['ERROR ID : ' ME.identifier]);
                obj.WriteLog(['ERROR MSG : ' ME.message]);
            end 
        end
       
       
      
    end

        
end

