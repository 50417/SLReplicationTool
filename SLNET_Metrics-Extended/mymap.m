classdef mymap < handle
    %MYMAP HashMap Implementation
        %{
     
BSD 3-Clause License
Copyright (c) 2019, The University of Texas at Arlington
All rights reserved.
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.
3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.
    %}
    %   Detailed explanation goes here
    
    properties
        data
        data_keys = [];                  % WARNING Value of this field is valid ONLY after calling keys() method.
    end
    
    
    methods (Static)
      function ret = create_from_cell(data)
         ret = mymap();
         
         for i=1:numel(data)
            ret.put(data{i}, 1);
         end
      end
   end
    
    methods
        function obj = mymap(varargin)
            obj.data = struct;
            
            if nargin >0
%                 disp('MyMap called with argument!');
                for i = 1:2:numel(varargin)
                    obj.put(varargin{i}, varargin{i+1});
                end
%             else
%                 disp('MyMap with NO arguments');
            end
            
        end
        
%         function obj = test(obj, a, b)
%             fprintf('varargin: %d\n', nargin);
%          end
        
        function ret =  create_if_not_exists(obj, k, classn)
            if obj.contains(k)
                ret = obj.get(k);
            else
                ret = feval(classn);
                obj.put(k, ret);
            end
        end
        
        
        function put(obj, k, v)
            effective_key = obj.mvn(k);
            obj.data.(effective_key) = v;
        end
        
        function ret = contains(obj, k)
            ret = isfield(obj.data, obj.mvn(k));
        end
        
        function ret = mvn(obj,s)
            % Make a valid name using parameter `s`
            ret = matlab.lang.makeValidName(s);
        end
        
        function ret = get(obj, k)
            if ~ isfield(obj.data, obj.mvn(k))
                ret = [];
            else
                ret = obj.data.(obj.mvn(k));
            end
        end
        
        function ret = keys(obj)
            ret = fieldnames(obj.data);
            obj.data_keys = ret;
        end
        
        function ret  = key(obj, index)
            %  WARNING only call this after calling `keys()` or `len_keys()`
            %  otherwise you might not get updated values.
            ret = obj.data_keys{index};
        end
        
        function obj = print_all(obj)
            fprintf('Printing MyMap -->\n');
            for i=1:numel(obj.keys)
                k = obj.keys{i};
                fprintf('%s --> %s \t', k, obj.get(k));
            end
            fprintf('\n');
        end
        
        function obj = print_keys(obj)
             fprintf('Printing MyMap Keys -->\n');
            for i=1:numel(obj.keys)
                k = obj.keys{i};
                fprintf('%s; \t', k);
            end
            fprintf('\n');

        end
        
        function ret = len_keys(obj)
            ret = numel(obj.keys());
        end
        
        function [vectorTemp, sortedVector] = sort_by_value(obj)
            len = numel(obj.keys());
            keys = obj.data_keys;
            vectorTemp = strings(len,1);
            vectorTemp(:,1)=keys;
            
            countTemp = zeros(len,2);
            for k = 1:len
               countTemp(k,1)=k;
               countTemp(k,2)=obj.data.(keys{k});
            end
            sortedVector = sortrows(countTemp,2);
        end
        
        function obj = inc(obj, k)
            if obj.contains(k)
                obj.put(k, obj.get(k) + 1);
            else
                obj.put(k, 1);
            end
        end
        
        function obj = insert_or_add(obj, k, v)
            if obj.contains(k)
                obj.put(k, obj.get(k) + v);
            else
                obj.put(k, v);
            end

        end
        
    end
    
end