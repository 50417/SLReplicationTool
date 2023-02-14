 function ret = get_connected_components(slb)
            
%             fprintf('Inside gcc\n');
            
            ret = mycell();
            
            assert(numel(slb.nodes) == slb.NUM_BLOCKS);
            
            visit_index = cell(1, slb.NUM_BLOCKS);
            low_link = cell(1, slb.NUM_BLOCKS);
            on_stack = zeros(1, slb.NUM_BLOCKS);
            
            index = 0;
            s = CStack();
            
            for out_i=1:slb.NUM_BLOCKS
                if isempty(visit_index{out_i})
                    strongconnect(slb.nodes{out_i});
                end
            end
            
            
            function strongconnect(v)
                visit_index{v.my_id} = index;
                low_link{v.my_id} = index;
                index = index + 1;
         
                s.push(v);
                on_stack(v.my_id) = true;
                
                % onsider successors of v
                
                for i=1:numel(v.out_nodes)
                    for j=1:numel(v.out_nodes{i})
                        chld = v.out_nodes{i}{j};
                        
                        if isempty(visit_index{chld.my_id})
                            strongconnect(chld);
                            low_link{v.my_id} = min(low_link{v.my_id} , low_link{chld.my_id});
                        elseif on_stack(chld.my_id)
                            low_link{v.my_id} = min(low_link{v.my_id} , low_link{chld.my_id});
                        end
                        
                    end
                end
                
                % If v is a root node, pop the stack and generate an SCC
                
                if low_link{v.my_id} == visit_index{v.my_id}
                    % start a new strongly connected component
                    cc = mycell();
                    while true
                        w = s.pop();
                        on_stack(w.my_id) = false;
                        cc.add(w.my_id);
                        
                        if w.my_id == v.my_id
                            break;
                        end
                    end
                    
                    if cc.len > 1
                        ret.add(cc);
                    end
                end
                
            end
        end
