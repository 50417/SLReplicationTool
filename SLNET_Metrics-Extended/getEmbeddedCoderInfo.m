function ECinModel = getEmbeddedCoderInfo(modelName)
atomicSubsystemsInModel = find_system(modelName, 'type', 'block', 'blocktype', 'SubSystem', 'TreatAsAtomicUnit', 'on');
functionPackagingOfAtomicSubsystems = get_param(atomicSubsystemsInModel,'RTWSystemCode');
if sum(~strcmp(functionPackagingOfAtomicSubsystems, 'Auto')) > 0
    ECinModel = 1;
else
    ECinModel = 0;
end