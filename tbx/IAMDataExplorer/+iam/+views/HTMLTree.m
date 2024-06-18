classdef HTMLTree < matlab.mixin.SetGet
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    properties (Access = public)
        HTML matlab.ui.control.HTML = matlab.ui.control.HTML.empty()

        Selected (:,1) string = []
        Variables (:,1) string
        LastChange (1,1) struct

    end
    
    properties (Access = private)
        TempFile (1,1) string
    end

    events 
        SelectionChanged
    end
    
    methods
        
        function obj = HTMLTree(varargin)
            if isempty(obj.HTML)
                obj.HTML = uihtml(varargin{:});
                obj.HTML.DataChangedFcn = @(s,e) obj.ChangedSelection(s,e);
            else
                set(obj.HTML, varargin{:})
            end
        end

        function ChangedSelection(obj,~,e)
            event = jsondecode(e.Data);
            VarName = obj.Variables(str2double(event.ID));
            obj.LastChange = struct(VALUE = event.VALUE, NAME = VarName);
            if event.VALUE
                obj.Selected = [obj.Selected;VarName];
            else
                obj.Selected = setdiff(obj.Selected, VarName);
            end

            notify(obj, 'SelectionChanged')
        end
        
        function delete(obj)  
            delete(obj.HTML)
        end
        
        function fillTree(obj, vars)

            vars = unique(vars);

            obj.Variables = vars;
            
            if ~isempty(vars)
                
                st = BuildStruct(vars);
                
                [head,tail] = obj.getHeadAndTail();
                
                str = addNode(head,st);
                str = [str; tail];
                str = strjoin(str,'\n');
                
                obj.HTML.HTMLSource = str;

            else
                obj.HTML.HTMLSource = "<html></html>";
            end
            
        end

        function SyncSelection(obj,data)
            % Data comes from edit field, 
            % Separate by comas
            data = strtrim(strsplit(data, ";;"));

            % Find variables to Check
            [~,ToCheck] = ismember(data, obj.Variables);
            ToCheck(ToCheck == 0) = [];

            % Find variables to Uncheck
            ToUncheck = setdiff(obj.Selected, data);
            [~,ToUncheck] = ismember(ToUncheck, obj.Variables);

            % Construct message
            toSend = struct(ToCheck = [], ToUncheck = []);     
            toSend.ToCheck = num2cell(ToCheck);
            toSend.ToUncheck = num2cell(ToUncheck)';
            
            % Sync
            obj.Selected = string(obj.Variables(ToCheck));
            obj.HTML.Data = toSend;
        end
        
    end
    
    methods (Static, Access = private)
        
        function [head,tail] = getHeadAndTail()
            fileId = fopen(fullfile(fileparts(mfilename('fullpath')),'css/style.css'));
            style = fread(fileId,'*char')';
            fclose(fileId);
            
            head = [...
                "<html>";
                "<head>";
                "<meta name=""viewport"" content=""width=device-width, initial-scale=1"">";
                "<style>";
                string(style);
                "</style>";
                "</head>";
                "<body>";
                "<ul id=""myUL"">"];
            
            tail = [...
                "</ul>";
                "<script>";
                "var toggler = document.getElementsByClassName(""caret"");";
                "var elem = document.getElementsByTagName(""input"");";
                "var i";
                "for (i = 0; i < toggler.length; i++) {";
                "  toggler[i].addEventListener(""click"", function() {";
                "    this.parentElement.querySelector("".nested"").classList.toggle(""active"");";
                "    this.classList.toggle(""caret-down"");";
                "  });";
                "}";
                "function makeItHappen(id, htmlComponent) {";
                "    var el = document.getElementById(id);";
                "    htmlComponent.Data =JSON.stringify({ ID: id, VALUE: el.checked })";
                "}";
                "function setup(htmlComponent) {";
                "    for (var i = 0; i < elem.length; i ++) {";
                "        (function () {";
                "            var id = elem[i].id;";
                "            elem[i].addEventListener(""click"", function() { makeItHappen(id, htmlComponent); }, false);";
                "        }()); // immediate invocation";
                "    }";
                "    htmlComponent.addEventListener(""DataChanged"", function(event) {";
                "       checkNodesById(htmlComponent.Data.ToCheck, htmlComponent.Data.ToUncheck);";
                "    });";
                "};";
                "function checkNodesById(idsToCheck, idsToUncheck) {";
                "   // Convert all incoming IDs to numbers for comparison";
                "   idsToCheck.forEach(function (id) {";
                "      var checkbox = document.getElementById(id);";
                "      checkbox.checked = true;";
                "   })";
                "   idsToUncheck.forEach(function (id) {";
                "       var checkbox = document.getElementById(id);";
                "       checkbox.checked = false;";
                "   })";
                "}";
                "</script>";
                "</body>";
                "</html>";];
        end
        
    end
        
    methods (Access = private)
        
        function removeTempFile(obj)
            
            if ~isempty(obj) && isfile(obj.TempFile)
                delete(obj.TempFile)            
                delete(obj.HTML)
            end
        end
        
    end
    
end

function p = addNode(p,st)

f = fields(st);
for i = 1 : numel(f)
    if st.(f{i}).Id == 0
        checkBox = "";
    else
        checkBox = "<input type=""checkbox"" id=""" + st.(f{i}).Id + """/>";
    end
    if isempty(st.(f{i}).Value)
        p = [p;"<li><div class=""checkbox"">" + checkBox + "</div>" + st.(f{i}).Name + " </li>"]; %#ok<AGROW>
    else
        p = [p;"<li><div class=""checkbox"">" + checkBox + "</div>" + st.(f{i}).Name + " <span class=""caret""></span><ul class=""nested"">"; ...
            addNode(string.empty(), st.(f{i}).Value);
            "</ul></li>"]; %#ok<AGROW>
    end
end

end
