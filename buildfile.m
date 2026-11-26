function plan = buildfile
import matlab.buildtool.tasks.CodeIssuesTask
import matlab.buildtool.tasks.TestTask

% Create a plan from task functions
plan = buildplan(localfunctions);

% Add the "check" task to identify code issues
fc = matlab.buildtool.io.FileCollection.fromPaths('tbx/**/*.m');
plan("check") = CodeIssuesTask(fc, WarningThreshold = 0);

% Add the "test" task to run tests
plan("test") = TestTask('tests', Tag = ["GUI", "UNIT", "Unit"], ...
    SourceFiles="tbx", OutputDetail = 2, ...
    TestResults = "public/results.html", ...
    CodeCoverageResults= ["public/coverage.html",  "public/coverage.xml"]);

plan('doc') = DocMakerTask( ...
    fullfile( currentProject().RootFolder, "tbx", "doc", "**", "*.md") ...
    );

% Make the "archive" task the default task in the plan
plan.DefaultTasks = "archive";

% Make the "archive" task dependent on the "check" and "test" tasks
plan("archive").Dependencies = ["check" "test"];
end

function archiveTask(~)
% Create ZIP file

v = ver('IAMDataExplorer');

copyfile(resolveFilePath('README.md'), 'tbx')

opts = matlab.addons.toolbox.ToolboxOptions('tbx', '5ed2c037-ac9c-4feb-8032-469d0a2b0285');

% md removal
mdfiles = dir( fullfile('tbx', 'doc', '*.md') );
[~,idx] = ismember( fullfile( {mdfiles.folder}, {mdfiles.name}), opts.ToolboxFiles);
opts.ToolboxFiles(idx) = [];

opts.ToolboxMatlabPath = [fullfile("tbx", "IAMDataExplorer"), fullfile("tbx", "IAMDataExplorer", "app"), fullfile("tbx", "ISMIPExplorer")];

opts.AuthorName = "Eduard Benet";
opts.AuthorCompany = "MathWorks";
opts.AuthorEmail = "ebenetce@mathworks.com";
opts.Description = "This repository contains a set of tools to allow users explore integrated assesmemnt models and some examples showcasing how one can use this information in conjuntion to financial applications. The models accessible by the tool include the different datasets hosted by the IIASA Energy program (ENE), but it is extensible to your own custom models.";
opts.Summary = "App to explore Integrated Assessment Model results";
opts.Readme = resolveFilePath(fullfile('tbx','README.md'));
opts.AppGalleryFiles = fullfile("tbx", "IAMDataExplorer", "app", "IAMDataExplorer.mlapp");
opts.ToolboxGettingStartedGuide = fullfile("tbx", "doc", "mfiles", "GettingStarted.m");
opts.ToolboxName = "Climate IAM Explorer";
opts.PackageName = "ClimateIAMExplorer";
opts.ToolboxVersion = v.Version;
opts.OutputFile = fullfile("releases", "IAMDataExplorer.mltbx");

matlab.addons.toolbox.packageToolbox(opts)

end
