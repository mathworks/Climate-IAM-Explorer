function plan = buildfile
import matlab.buildtool.tasks.CodeIssuesTask
import matlab.buildtool.tasks.TestTask

% Create a plan from task functions
plan = buildplan(localfunctions);

% Add the "check" task to identify code issues
fc = matlab.buildtool.io.FileCollection.fromPaths('tbx/**/*.m');
plan("check") = CodeIssuesTask(fc, WarningThreshold = 0);

% Add the "test" task to run tests
plan("test") = TestTask('tests', Tag = ["GUI", "UNIT"], ...
    SourceFiles="tbx", OutputDetail = 2, ...
    TestResults = "tests/reports/test-results/report.html", ...
    CodeCoverageResults="tests/reports/code-coverage/report.html");

% Make the "archive" task the default task in the plan
plan.DefaultTasks = "archive";

% Make the "archive" task dependent on the "check" and "test" tasks
plan("archive").Dependencies = ["check" "test"];
end

function archiveTask(~)
% Create ZIP file
opts = matlab.addons.toolbox.ToolboxOptions('tbx', '5ed2c037-ac9c-4feb-8032-469d0a2b0285');

opts.AuthorName = "Eduard Benet";
opts.AuthorCompany = "MathWorks";
opts.AuthorEmail = "ebenetce@mathworks.com";
opts.Description = "This repository contains a set of tools to allow users explore integrated assesmemnt models and some examples showcasing how one can use this information in conjuntion to financial applications. The models accessible by the tool include the different datasets hosted by the IIASA Energy program (ENE), but it is extensible to your own custom models.";
opts.Summary = "App to explore Integrated Assessment Model results";
opts.AppGalleryFiles = "tbx/IAMDataExplorer/app/IAMDataExplorer.mlapp";
opts.ToolboxGettingStartedGuide = "tbx/doc/GettingStarted.mlx";
opts.ToolboxName = "Climate IAM Explorer";
opts.ToolboxVersion = "1.3.4";
opts.ToolboxMatlabPath = ["tbx/IAMDataExplorer", "tbx/IAMDataExplorer/app", "tbx/ISMIPExplorer"];
opts.OutputFile = 'IAMDataExplorer.mltbx';

matlab.addons.toolbox.packageToolbox(opts)
end