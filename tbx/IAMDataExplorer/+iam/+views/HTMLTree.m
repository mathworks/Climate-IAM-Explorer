classdef HTMLTree < matlab.mixin.SetGet
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    properties (Access = public)
        HTML matlab.ui.control.HTML = matlab.ui.control.HTML.empty()
    end
    
    properties (Access = private)
        TempFile (1,1) string
    end
    
    methods
        
        function obj = HTMLTree(varargin)
            if isempty(obj.HTML)
                obj.HTML = uihtml(varargin{:});
            else
                set(obj.HTML, varargin{:})
            end
        end
        
        function delete(obj)  
            delete(obj.HTML)
        end
        
        function fillTree(obj, vars)
            
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
                "};"
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
