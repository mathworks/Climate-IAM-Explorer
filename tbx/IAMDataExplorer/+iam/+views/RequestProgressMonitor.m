classdef RequestProgressMonitor < matlab.net.http.ProgressMonitor
    properties
        ProgHandle
        Direction matlab.net.http.MessageType
        Value uint64
        NewDir matlab.net.http.MessageType = matlab.net.http.MessageType.Request
        ProgressDialog = []
        CancelRequestedByUser (1,1) logical = false
    end
    
    methods
        function obj = RequestProgressMonitor(progressDialog)
            obj.Interval = .001;
            if nargin > 0
                obj.ProgressDialog = progressDialog;
            end
        end
        
        function done(obj)
            obj.showProcessing();
            obj.closeit();
        end
        
        function delete(obj)
            obj.closeit();
        end
        
        function set.Direction(obj, dir)
            obj.Direction = dir;
            obj.changeDir();
        end
        
        function set.Value(obj, value)
            obj.Value = value;
            obj.update();
        end
    end
    
    methods (Access = private)
        function update(obj,~)
            % called when Value is set
            import matlab.net.http.*
            if ~isempty(obj.ProgressDialog)
                obj.updateProgressDialog();
                return
            end
            if ~isempty(obj.Value)
                if isempty(obj.Max)
                    % no maximum means we don't know length, so message 
                    % changes on every call
                    value = 0;
                    if obj.Direction == MessageType.Request
                        msg = sprintf('Sent %d bytes...', obj.Value);
                    else
                        msg = sprintf('Received %d bytes...', obj.Value);
                    end
                else
                    % maximum known, update proportional value
                    value = double(obj.Value)/double(obj.Max);
                    if obj.NewDir == MessageType.Request
                        % message changes only on change of direction
                        if obj.Direction == MessageType.Request
                            msg = 'Sending...';
                        else
                            msg = 'Receiving...';
                        end
                    end
                end
                if isempty(obj.ProgHandle)
                    % if we don't have a progress bar, display it for first time
                    obj.ProgHandle = ...
                        waitbar(value, msg, 'CreateCancelBtn', ...
                            @(~,~)cancelAndClose(obj));
                    obj.NewDir = MessageType.Response;
                elseif obj.NewDir == MessageType.Request || isempty(obj.Max)
                    % on change of direction or if no maximum known, change message
                    waitbar(value, obj.ProgHandle, msg);
                    obj.NewDir = MessageType.Response;
                else
                    % no direction change else just update proportional value
                    waitbar(value, obj.ProgHandle);
                end
            end
            
            function cancelAndClose(obj)
                % Call the required CancelFcn and then close our progress bar. 
                % This is called when user clicks cancel or closes the window.
                obj.CancelFcn();
                obj.closeit();
            end
        end

        function updateProgressDialog(obj)
            dialog = obj.ProgressDialog;
            if isempty(dialog) || ~isvalid(dialog)
                return
            end

            drawnow limitrate
            if dialog.CancelRequested
                if ~obj.CancelRequestedByUser && ~isempty(obj.CancelFcn)
                    obj.CancelRequestedByUser = true;
                    obj.CancelFcn();
                end
                return
            end

            if obj.Direction ~= matlab.net.http.MessageType.Response
                return
            end

            if isempty(obj.Value)
                obj.showProcessing();
            elseif isempty(obj.Max) || obj.Max == 0
                dialog.ShowPercentage = "off";
                dialog.Indeterminate = "on";
                dialog.Message = "Downloading time series (" + ...
                    compose("%.1f MB received", double(obj.Value) / 1e6) + ")...";
            elseif obj.Value >= obj.Max
                obj.showProcessing();
            else
                dialog.Indeterminate = "off";
                dialog.ShowPercentage = "on";
                dialog.Value = double(obj.Value) / double(obj.Max);
                dialog.Message = "Downloading time series...";
            end
        end

        function showProcessing(obj)
            dialog = obj.ProgressDialog;
            if isempty(dialog) || ~isvalid(dialog) || ...
                    obj.Direction ~= matlab.net.http.MessageType.Response || ...
                    obj.CancelRequestedByUser || dialog.CancelRequested
                return
            end
            dialog.ShowPercentage = "off";
            dialog.Indeterminate = "on";
            dialog.Message = "Processing downloaded data...";
            drawnow;
        end
        
        function changeDir(obj,~)
            % Called when Direction is set or changed.  Leave the progress 
            % bar displayed.
            obj.NewDir = matlab.net.http.MessageType.Request;
        end
    end
    
    methods (Access=private)
        function closeit(obj)
            % Close the progress bar by deleting the handle so 
            % CloseRequestFcn isn't called, because waitbar calls 
            % cancelAndClose(), which would cause recursion.
            if ~isempty(obj.ProgHandle)
                delete(obj.ProgHandle);
                obj.ProgHandle = [];
            end
        end
    end
end
