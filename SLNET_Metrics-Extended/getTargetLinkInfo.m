function TLinModel = getTargetLinkInfo(modelName)
 if ~isempty(find_system(modelName, 'type', 'block', 'blocktype', 'SubSystem', 'masktype', 'TL_SimFrame'))
     TLinModel = 1;
 else
     TLinModel = 0; 
 end
end