classdef MetaDataTree < iam.views.MetaDataTabs
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    properties (Access = public)
        HTML (:,1) matlab.ui.control.HTML
    end
    
    properties (Access = private)
        TempFile (:,1) string
    end
    
    methods
        
        function obj = MetaDataTree(varargin)
            obj@iam.views.MetaDataTabs(varargin{:});
        end
        
        function addTree(obj, vars, varargin)
            
            t = obj.addTab(varargin{:});
            gl = uigridlayout(t,[1 1]);
            
            if ~isempty(vars)
                st = BuildStruct(vars);
                
                [head,tail] = obj.getHeadAndTail();
                
                str = addNode(head,st);
                str = [str; tail];
                str = strjoin(str,'\n');
                
                newHTML = tempname + ".html";
                obj.TempFile = [obj.TempFile; newHTML];
                
                fileId = fopen(newHTML,'w');
                fwrite(fileId, str );
                fclose(fileId);
                
                obj.HTML = [obj.HTML;uihtml(gl,'HTMLSource',newHTML)];
            end
            
        end
        
        function value = getData(obj, id)
            idx = obj.getTabIdx(id);
            if ~isempty(obj.HTML(idx).Data)
                value = jsondecode(obj.HTML(idx).Data);
            else
                value = struct('ID',{},'VALUE',{});
            end
        end
        
        function cleanTrees(obj)
            
            obj.cleanTempFiles;
            if ~isempty(obj.HTML)
                delete(obj.HTML);
                obj.HTML(1:end) = [];
            end
            obj.TempFile = string.empty();
            obj.cleanTabs();
            
        end
        
        function setDataChangedFcn(obj, id, value)
            idx = obj.getTabIdx(id);
            obj.HTML(idx).DataChangedFcn = value;
        end
        
        function delete(obj)
            obj.cleanTempFiles;
        end
        
    end
    
    methods (Static, Access = private)
        
        function [head,tail] = getHeadAndTail()
            
            fileId = fopen('+iiasa/+views/css/style.css');
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
        
       function cleanTempFiles(obj)
           
            for i = 1 : length(obj.TempFile)
                if isfile(obj.TempFile(i))
                    delete(obj.TempFile(i))
                end
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