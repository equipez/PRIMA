function pdv()
% PDV tests the Fortran solvers for all Precision, Debugging flags, and Variants.

oldpath = path();  % Record the current path.
restoredefaultpath;  % Restore the "right out of the box" path of MATLAB

olddir = pwd();  % Record the current directory.

matlab_implemented = {'newuoa'};  % Solvers that has a MATLAB implementation.

% mfilepath: directory where this file resides
mfilepath = fileparts(mfilename('fullpath'));

% root_dir: root directory of the project
root_dir = fileparts(fileparts(mfilepath));
[~, root_dir_name] = fileparts(root_dir);

% Prepare the test directory, i.e., `test_dir`.
callstack = dbstack;
funname = callstack(1).name; % Name of the current function
fake_solver_name = root_dir_name;
options.competitor = root_dir_name;
options.compile = true;
test_dir = prepare_test_dir(fake_solver_name, funname, options);

exception = [];

try

    % Go to the test directory.
    solver_dir = fullfile(test_dir, root_dir_name);
    cd(solver_dir);

    % Compile the solvers.
    clear('setup');
    opt=struct();
    opt.verbose = true;
    opt.half = ismac_silicon();
    opt.single = true;
    opt.double = true;
    opt.quadruple = true;
    opt.debug = true;
    %opt.classical = true;
    opt.classical = false;

    tic

    setup(opt);

    solvers = {'cobyla', 'uobyqa', 'newuoa', 'bobyqa', 'lincoa'};
    precisions = {'half', 'single', 'double', 'quadruple'};
    precisions = precisions([opt.half, opt.single, opt.double, opt.quadruple]);
    debug_flags = {true, false};
    %variants = {'modern', 'classical'};
    variants = {'modern'};

    % Show current path information.
    showpath(solvers);

    % Test the solvers.
    fun = @chrosen;
    x0 = [-1; -1];
    for isol = 1 : length(solvers)
        solver = str2func(solvers{isol});
        solver
        options = struct();
        for iprc = 1 : length(precisions)
            options.precision = precisions{iprc};
            for idbg = 1 : length(debug_flags)
                options.debug = debug_flags{idbg};
                for ivar = 1 : length(variants)
                    options.classical = strcmp(variants{ivar}, 'classical');
                    if ismac && strcmp(func2str(solver), 'cobyla') && strcmp(options.precision, 'half') && options.classical
                        % Skip the classical cobyla in half precision on macOS, as it will encounter an infinite cycling.
                        continue;
                    end
                    if ismac && strcmp(func2str(solver), 'bobyqa') && strcmp(options.precision, 'quadruple') && options.classical
                        % Skip the classical bobyqa in quadruple precision on macOS, as it will encounter a segmentation fault.
                        continue;
                    end
                    options.output_xhist = true;
                    options.maxfun = 100*length(x0);
                    options.rhoend = 1.0e-3;
                    options.iprint = randi([-4, 4]);
                    options
                    format long
                    [x, f, exitflag, output] = solver(fun, x0, options)
                    if (ismember(solvers{isol}, matlab_implemented))
                        options_mat = options;
                        options_mat.fortran = false;
                        [x, f, exitflag, output] = solver(fun, x0, options_mat)
                    end
                end
            end
        end
    end

    toc

    % Show current path information again at the end of test.
    showpath(solvers);

catch exception

    % Do nothing for the moment.

end

setpath(oldpath);  % Restore the path to oldpath.
cd(olddir);  % Go back to olddir.
fprintf('\nCurrently in %s\n\n', pwd());

if ~isempty(exception)  % Rethrow any exception caught above.
    rethrow(exception);
end

end
