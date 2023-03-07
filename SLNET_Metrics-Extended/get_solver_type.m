function solver_type = get_solver_type(modelName)
    solver_type = get_param(modelName,'SolverType');
    if isempty(solver_type)
        solver_type = 'NA';
    end
end