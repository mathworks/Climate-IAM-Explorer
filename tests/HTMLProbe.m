classdef HTMLProbe < handle
    properties
        Ready = false
        Response = struct()
        Error = ""
        ExportedFrame = []
        ExportedSeries = []
    end

    properties (Access = private)
        Folder
        HTML
        ProductionCallback
        Request = 0
    end

    methods
        function obj = HTMLProbe(html)
            obj.HTML = html;
            obj.ProductionCallback = html.HTMLEventReceivedFcn;
            obj.Folder = tempname;
            mkdir(obj.Folder);
            source = string(html.HTMLSource);
            copyfile(fullfile(fileparts(source), "*"), obj.Folder);
            copyfile(fullfile(fileparts(mfilename("fullpath")), "html", "probe.js"), ...
                fullfile(obj.Folder, "js", "probe.js"));
            page = replace(fileread(source), "</head>", ...
                '<script defer src="js/probe.js"></script></head>');
            [~,name,extension] = fileparts(source);
            target = fullfile(obj.Folder, name + extension);
            writelines(page, target);
            html.HTMLEventReceivedFcn = @(src,event) obj.receive(src,event);
            html.HTMLSource = target;
        end

        function response = act(obj, testCase, action)
            import matlab.unittest.constraints.Eventually
            import matlab.unittest.constraints.IsTrue
            obj.Request = obj.Request + 1;
            action.id = obj.Request;
            sendEventToHTMLSource(obj.HTML, "testAction", action);
            testCase.assertThat(@() obj.responded(), ...
                Eventually(IsTrue(), WithTimeoutOf=15));
            testCase.assertEqual(obj.Error, "");
            response = obj.Response.snapshot;
        end

        function recordExport(obj, frame)
            obj.ExportedFrame = frame;
        end

        function exported = recordWorkspaceExport(obj, series)
            obj.ExportedSeries = series;
            exported = true;
        end

        function delete(obj)
            if isfolder(obj.Folder)
                rmdir(obj.Folder, "s");
            end
        end
    end

    methods (Access = private)
        function ready = responded(obj)
            ready = isfield(obj.Response,"id") && obj.Response.id == obj.Request;
        end

        function receive(obj, src, event)
            switch string(event.HTMLEventName)
                case "testReady"
                    obj.Ready = true;
                case "testResponse"
                    obj.Response = event.HTMLEventData;
                case "testError"
                    obj.Error = string(event.HTMLEventData.message);
                otherwise
                    if ~isempty(obj.ProductionCallback)
                        obj.ProductionCallback(src,event);
                    end
            end
        end
    end
end
